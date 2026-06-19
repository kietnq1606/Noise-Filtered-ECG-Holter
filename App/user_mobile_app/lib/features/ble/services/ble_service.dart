import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart' as ble;

class BlePacketType {
  static const int pingEcg = 0x01;
  static const int ecgOk = 0x02;
  static const int start = 0x10;
  static const int ackStart = 0x11;
  static const int stop = 0x12;
  static const int ackStop = 0x13;
  static const int ecgData = 0x20;
  static const int ack = 0x30;
  static const int nack = 0x31;
  static const int error = 0x7F;
}

class BleFrame {
  final int type;
  final int seq;
  final List<int> payload;

  const BleFrame({
    required this.type,
    required this.seq,
    required this.payload,
  });
}

class BleService extends ChangeNotifier {
  BleService._internal();
  static final BleService instance = BleService._internal();

  static const String _targetServiceUuid =
      '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String _targetCharacteristicUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const Duration _ackTimeout = Duration(seconds: 2);
  static const Duration _prepareTimeout = Duration(seconds: 3);
  static const String _lastDeviceIdKey = 'ble_last_device_id';
  static const String _lastDeviceNameKey = 'ble_last_device_name';

  ble.BleDevice? connectedDevice;
  bool isConnected = false;
  bool isPrepared = false;
  bool isStreaming = false;

  List<ble.BleService> discoveredServices = [];
  ble.BleCharacteristic? notifyCharacteristic;
  ble.BleCharacteristic? writeCharacteristic;

  String? lastTextPacket;
  List<int> lastEcgSamples = [];
  String? lastTransmittedPacket;
  String? lastReceivedPacket;
  int? lastAckSeq;
  int? lastNackSeq;
  int ackCount = 0;
  int nackCount = 0;
  int timeoutCount = 0;

  StreamSubscription<List<int>>? _notifySubscription;
  Timer? _connectionWatchdogTimer;
  bool _isWatchdogChecking = false;
  final List<int> _rxBuffer = <int>[];
  int _nextTxSeq = 0;
  String? _lastRxFrameKey;
  int _lastRxFrameAtMs = 0;

  final Map<int, Completer<BleFrame>> _pendingByType =
      <int, Completer<BleFrame>>{};

  final StreamController<List<int>> _rawBytesController =
      StreamController<List<int>>.broadcast();
  final StreamController<String> _textPacketController =
      StreamController<String>.broadcast();
  final StreamController<List<int>> _ecgSamplesController =
      StreamController<List<int>>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  Stream<List<int>> get rawBytesStream => _rawBytesController.stream;
  Stream<String> get textPacketStream => _textPacketController.stream;
  Stream<List<int>> get ecgSamplesStream => _ecgSamplesController.stream;
  Stream<String> get logStream => _logController.stream;

  String get linkStatus {
    if (!isConnected) return 'Disconnected';
    if (!isPrepared) return 'Connected';
    if (isStreaming) return 'Streaming';
    return 'Prepared';
  }

  Future<String?> getLastConnectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastDeviceIdKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<String?> getLastConnectedDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastDeviceNameKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setConnectedDevice(ble.BleDevice device) async {
    if (isConnected &&
        connectedDevice?.deviceId.trim() == device.deviceId.trim() &&
        isPrepared) {
      _addLog('Device already connected and prepared; skip re-prepare.');
      return;
    }

    connectedDevice = device;
    isConnected = await device.isConnected;
    isPrepared = false;
    isStreaming = false;
    notifyListeners();

    if (!isConnected) {
      await clearConnectedDevice(disconnect: true);
      throw Exception('Device is not connected.');
    }

    try {
      await _prepareConnection();
      _startConnectionWatchdog();
      await _saveLastConnectedDevice(device);
    } catch (_) {
      await clearConnectedDevice(disconnect: true);
      rethrow;
    }
  }

  Future<void> _saveLastConnectedDevice(ble.BleDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDeviceIdKey, device.deviceId.trim());
    await prefs.setString(_lastDeviceNameKey, getDeviceName(device));
  }

  Future<void> _prepareConnection() async {
    final device = connectedDevice;
    if (device == null) {
      throw Exception('No BLE device selected.');
    }

    _addLog('Preparing BLE connection...');
    discoveredServices = await device.discoverServices();
    _findTargetCharacteristics();

    if (notifyCharacteristic == null || writeCharacteristic == null) {
      throw Exception('ECG device UUID FFE0/FFE1 not found.');
    }

    await _subscribeToNotifications();

    final ok = await _sendAndWait(
      type: BlePacketType.pingEcg,
      expectType: BlePacketType.ecgOk,
      timeout: _prepareTimeout,
    );
    if (!ok) {
      throw Exception('ECG handshake timeout. Device validation failed.');
    }

    isPrepared = true;
    _addLog('ECG device validated (PING_ECG -> ECG_OK).');
    notifyListeners();
  }

  Future<void> clearConnectedDevice({bool disconnect = false}) async {
    final device = connectedDevice;
    _stopConnectionWatchdog();
    await stopEcg();
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _pendingByType.clear();
    _rxBuffer.clear();
    if (disconnect && device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Ignore disconnect errors while clearing local state.
      }
    }

    connectedDevice = null;
    isConnected = false;
    isPrepared = false;
    isStreaming = false;
    discoveredServices = [];
    notifyCharacteristic = null;
    writeCharacteristic = null;
    lastTextPacket = null;
    lastEcgSamples = [];
    lastTransmittedPacket = null;
    lastReceivedPacket = null;
    lastAckSeq = null;
    lastNackSeq = null;
    ackCount = 0;
    nackCount = 0;
    timeoutCount = 0;
    notifyListeners();
  }

  void _startConnectionWatchdog() {
    _stopConnectionWatchdog();
    _connectionWatchdogTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkConnectionWatchdog(),
    );
  }

  void _stopConnectionWatchdog() {
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = null;
  }

  Future<void> _checkConnectionWatchdog() async {
    if (_isWatchdogChecking) return;
    final device = connectedDevice;
    if (device == null) return;

    _isWatchdogChecking = true;
    try {
      final connected = await device.isConnected;
      if (connected) return;

      _addLog('BLE connection lost. Switching to disconnected state.');
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      _pendingByType.clear();
      _rxBuffer.clear();
      isConnected = false;
      isPrepared = false;
      isStreaming = false;
      notifyCharacteristic = null;
      writeCharacteristic = null;
      connectedDevice = null;
      _stopConnectionWatchdog();
      notifyListeners();
    } catch (e) {
      _addLog('Connection watchdog check failed: $e');
    } finally {
      _isWatchdogChecking = false;
    }
  }

  Future<bool> refreshConnectionState() async {
    final device = connectedDevice;
    if (device == null) {
      isConnected = false;
      isPrepared = false;
      isStreaming = false;
      _stopConnectionWatchdog();
      notifyListeners();
      return false;
    }

    isConnected = await device.isConnected;
    if (!isConnected) {
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      isPrepared = false;
      isStreaming = false;
      notifyCharacteristic = null;
      writeCharacteristic = null;
      connectedDevice = null;
      _pendingByType.clear();
      _rxBuffer.clear();
      _stopConnectionWatchdog();
    } else {
      _startConnectionWatchdog();
    }
    notifyListeners();
    return isConnected;
  }

  Future<void> startEcg() async {
    if (!isPrepared) {
      throw Exception('Device is not prepared.');
    }

    final ok = await _sendAndWait(
      type: BlePacketType.start,
      expectType: BlePacketType.ackStart,
      timeout: _ackTimeout,
    );
    if (!ok) {
      throw Exception('No ACK_START from MCU.');
    }

    isStreaming = true;
    _addLog('ECG stream started.');
    notifyListeners();
  }

  Future<void> stopEcg() async {
    if (!isPrepared) {
      isStreaming = false;
      notifyListeners();
      return;
    }

    final ok = await _sendAndWait(
      type: BlePacketType.stop,
      expectType: BlePacketType.ackStop,
      timeout: _ackTimeout,
    );
    if (!ok) {
      throw Exception('No ACK_STOP from MCU.');
    }

    isStreaming = false;
    _addLog('ECG stream stopped.');
    notifyListeners();
  }

  void _findTargetCharacteristics() {
    notifyCharacteristic = null;
    writeCharacteristic = null;

    for (final service in discoveredServices) {
      final sUuid = service.uuid.toLowerCase();
      if (sUuid != _targetServiceUuid) continue;

      for (final characteristic in service.characteristics) {
        final cUuid = characteristic.uuid.toLowerCase();
        if (cUuid != _targetCharacteristicUuid) continue;

        notifyCharacteristic = characteristic;
        writeCharacteristic = characteristic;
        _addLog('Found ECG char: ${characteristic.uuid}');
        return;
      }
    }
  }

  Future<void> _subscribeToNotifications() async {
    final notifyChar = notifyCharacteristic;
    if (notifyChar == null) {
      throw Exception('Notify characteristic is null.');
    }

    await _notifySubscription?.cancel();
    await notifyChar.notifications.subscribe();
    _notifySubscription = notifyChar.onValueReceived.listen(
      _handleReceivedBytes,
      onError: (error) => _addLog('Notification error: $error'),
    );
  }

  Future<bool> _sendAndWait({
    required int type,
    required int expectType,
    List<int> payload = const <int>[],
    Duration timeout = _ackTimeout,
  }) async {
    final completer = Completer<BleFrame>();
    _pendingByType[expectType] = completer;

    try {
      await sendFrame(type: type, payload: payload);
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      timeoutCount += 1;
      _addLog('Timeout waiting type=0x${expectType.toRadixString(16)}');
      return false;
    } finally {
      _pendingByType.remove(expectType);
    }
  }

  Future<void> sendFrame({
    required int type,
    List<int> payload = const <int>[],
  }) async {
    final writeChar = writeCharacteristic;
    if (writeChar == null) {
      throw Exception('Write characteristic not found.');
    }

    final frame = _buildFrame(type: type, payload: payload);
    await writeChar.write(frame);
    lastTransmittedPacket = frame
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    _addLog(
      'TX: ${frame.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    notifyListeners();
  }

  List<int> _buildFrame({required int type, required List<int> payload}) {
    final seq = _nextTxSeq & 0xFF;
    _nextTxSeq = (_nextTxSeq + 1) & 0xFF;

    final len = payload.length & 0xFF;
    final frame = <int>[type & 0xFF, seq, len, ...payload.map((b) => b & 0xFF)];
    frame.add(_checksum(frame));
    return frame;
  }

  // Checksum rule: XOR of all bytes before CS.
  int _checksum(List<int> bytes) {
    int cs = 0;
    for (final b in bytes) {
      cs ^= (b & 0xFF);
    }
    return cs & 0xFF;
  }

  void _handleReceivedBytes(List<int> bytes) {
    _rawBytesController.add(bytes);
    _rxBuffer.addAll(bytes);

    while (true) {
      if (_rxBuffer.length < 4) return;

      final len = _rxBuffer[2] & 0xFF;
      final frameSize = 4 + len;
      if (_rxBuffer.length < frameSize) return;

      final frameBytes = _rxBuffer.sublist(0, frameSize);
      _rxBuffer.removeRange(0, frameSize);

      final withoutCs = frameBytes.sublist(0, frameBytes.length - 1);
      final cs = frameBytes.last & 0xFF;
      final valid = _checksum(withoutCs) == cs;
      final type = frameBytes[0] & 0xFF;
      final seq = frameBytes[1] & 0xFF;
      final payload = frameBytes.sublist(3, 3 + len);
      lastReceivedPacket = frameBytes
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(' ');

      if (!valid) {
        _addLog('RX invalid checksum; send NACK for ECG seq=$seq');
        lastNackSeq = seq;
        nackCount += 1;
        unawaited(sendFrame(type: BlePacketType.nack, payload: [seq]));
        notifyListeners();
        continue;
      }

      final frame = BleFrame(type: type, seq: seq, payload: payload);
      if (_isDuplicateFrame(frame)) {
        _addLog(
          'Drop duplicate RX frame type=0x${frame.type.toRadixString(16)} seq=${frame.seq}',
        );
        continue;
      }
      _onFrame(frame);
      notifyListeners();
    }
  }

  bool _isDuplicateFrame(BleFrame frame) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final payloadHex = frame.payload
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
    final key = '${frame.type}:${frame.seq}:$payloadHex';
    final isDup = (_lastRxFrameKey == key) && (now - _lastRxFrameAtMs <= 300);
    _lastRxFrameKey = key;
    _lastRxFrameAtMs = now;
    return isDup;
  }

  void _onFrame(BleFrame frame) {
    _addLog(
      'RX type=0x${frame.type.toRadixString(16)} seq=${frame.seq} len=${frame.payload.length}',
    );

    final waiter = _pendingByType[frame.type];
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(frame);
    }

    if (frame.type == BlePacketType.ecgData) {
      final samples = _parseEcgUint16Payload(frame.payload);
      if (samples.isEmpty) {
        lastNackSeq = frame.seq;
        nackCount += 1;
        unawaited(sendFrame(type: BlePacketType.nack, payload: [frame.seq]));
        _addLog('ECG_DATA payload invalid; NACK sent.');
        return;
      }

      lastEcgSamples = samples;
      lastTextPacket = samples.take(12).join(', ');
      _ecgSamplesController.add(samples);
      _textPacketController.add(lastTextPacket!);
      lastAckSeq = frame.seq;
      ackCount += 1;
      unawaited(sendFrame(type: BlePacketType.ack, payload: [frame.seq]));
      notifyListeners();
      return;
    }

    if (frame.type == BlePacketType.ack) {
      final confirmedSeq = frame.payload.isNotEmpty
          ? frame.payload.first
          : frame.seq;
      lastAckSeq = confirmedSeq;
      ackCount += 1;
      _addLog('MCU ACK confirms seq=$confirmedSeq');
      return;
    }

    if (frame.type == BlePacketType.nack) {
      final rejectedSeq = frame.payload.isNotEmpty
          ? frame.payload.first
          : frame.seq;
      lastNackSeq = rejectedSeq;
      nackCount += 1;
      _addLog('MCU NACK rejects seq=$rejectedSeq');
      return;
    }

    if (frame.type == BlePacketType.error) {
      final code = frame.payload.isEmpty ? -1 : frame.payload.first;
      _addLog('MCU error code: $code');
    }
  }

  List<int> _parseEcgUint16Payload(List<int> payload) {
    if (payload.isEmpty || payload.length.isOdd) return const <int>[];
    final data = ByteData.sublistView(Uint8List.fromList(payload));
    final out = <int>[];
    for (int i = 0; i < payload.length; i += 2) {
      out.add(data.getUint16(i, Endian.little));
    }
    return out;
  }

  String getDeviceName(ble.BleDevice device) {
    final String name = (device.name ?? '').trim();
    return name.isNotEmpty ? name : 'Unnamed BLE Device';
  }

  void _addLog(String message) {
    debugPrint('[BleService] $message');
    _logController.add(message);
  }
}
