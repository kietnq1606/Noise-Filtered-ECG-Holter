import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_ble/universal_ble.dart' as ble;

import '../services/ble_service.dart';
import '../../../shared/widgets/bottom_popup.dart';

class BleConnectPage extends StatefulWidget {
  final bool showAppBar;

  const BleConnectPage({super.key, this.showAppBar = true});

  @override
  State<BleConnectPage> createState() => _BleConnectPageState();
}

class _BleConnectPageState extends State<BleConnectPage> {
  final BleService _bleService = BleService.instance;
  static const String _preferredNameKeyword = 'HOLTER';
  static const String _secondaryPrefix = 'JDY';
  // Store scanned devices.
  final Map<String, ble.BleDevice> _availableDevices = {};

  // Store connected devices in this session.
  final Map<String, ble.BleDevice> _pairedDevices = {};

  // Store connection error by device id.
  final Map<String, String> _connectionErrors = {};
  String? _failedConnectionDeviceId;
  // Listen to scan results.
  StreamSubscription<ble.BleDevice>? _scanSubscription;

  // Listen to phone bluetooth state.
  StreamSubscription<ble.AvailabilityState>? _bleStateSubscription;

  // Stop scan automatically.
  Timer? _scanTimer;

  // Page states.
  bool _bleUiEnabled = true;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isAutoReconnecting = false;

  String? _connectingDeviceId;
  ble.BleDevice? _connectedDevice;
  String? _lastDeviceId;

  String _statusText = 'BLE is ready. Press Scan to find devices.';

  // Scan timeout duration.
  static const Duration _scanDuration = Duration(seconds: 10);
  static const Duration _scanToConnectQuietGap = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _bleService.addListener(_syncUiWithServiceState);

    // Sync the page switch with phone bluetooth state.
    _bleStateSubscription = ble.UniversalBle.availabilityStream.listen((state) {
      _handleBleStateChange(state);
    });

    // Listen to scanned devices.
    _scanSubscription = ble.UniversalBle.scanStream.listen(
      (device) {
        if (!mounted) return;

        final String deviceId = device.deviceId.trim();
        if (deviceId.isEmpty) return;

        // Skip unnamed and already paired devices to reduce scan noise.
        if (!_isTargetBleDevice(device)) return;
        if (_isPairedDevice(device)) return;

        setState(() {
          _availableDevices[deviceId] = device;
        });

        if (_isAutoReconnecting &&
            _lastDeviceId == deviceId &&
            !_isConnecting) {
          _connectToDevice(device);
        }
      },
      onError: (error) {
        debugPrint('BLE scan stream error: $error');
      },
    );

    _loadConnectedDeviceFromService();
    _checkBleState().then((_) => _tryAutoReconnectLastDevice());
  }

  @override
  void dispose() {
    // Clear listeners and scan timer.
    _bleStateSubscription?.cancel();
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    ble.UniversalBle.stopScan();
    _bleService.removeListener(_syncUiWithServiceState);

    super.dispose();
  }

  void _syncUiWithServiceState() {
    if (!mounted) return;

    final serviceDevice = _bleService.connectedDevice;
    final serviceConnected = _bleService.isConnected;

    if (!serviceConnected) {
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _connectingDeviceId = null;
        _statusText = 'Device disconnected.';
      });
      return;
    }

    if (serviceDevice == null) return;

    setState(() {
      _isConnected = true;
      _connectedDevice = serviceDevice;
      _pairedDevices[serviceDevice.deviceId] = serviceDevice;
      _statusText = 'Connected to ${_deviceTitle(serviceDevice)}.';
    });
  }

  // Update ui when phone bluetooth state changes.
  Future<void> _handleBleStateChange(ble.AvailabilityState state) async {
    final bool isPoweredOn = state == ble.AvailabilityState.poweredOn;

    if (!isPoweredOn) {
      await _stopScan();
      await BleService.instance.clearConnectedDevice(disconnect: true);
    }

    if (!mounted) return;

    setState(() {
      _bleUiEnabled = isPoweredOn;

      if (isPoweredOn) {
        _statusText = _isConnected && _connectedDevice != null
            ? 'Connected to ${_deviceTitle(_connectedDevice!)}.'
            : 'BLE is on. Press Scan to find nearby devices.';
      } else {
        _availableDevices.clear();
        _isConnected = false;
        _isAutoReconnecting = false;
        _connectedDevice = null;
        _connectingDeviceId = null;
        _statusText = 'Bluetooth or Location is turned off.';
      }
    });
  }

  // Load connected device saved in service.
  void _loadConnectedDeviceFromService() {
    final device = _bleService.connectedDevice;

    if (device == null || !_bleService.isConnected) return;

    setState(() {
      _isConnected = true;
      _connectedDevice = device;
      _pairedDevices[device.deviceId] = device;
      _statusText = 'Connected to ${_deviceTitle(device)}.';
    });
  }

  // Only show devices that have a name.
  bool _isTargetBleDevice(ble.BleDevice device) {
    final String deviceName = (device.name ?? '').trim();

    if (deviceName.isEmpty) {
      return false;
    }

    final String normalized = deviceName.toUpperCase();
    return normalized.contains(_preferredNameKeyword) ||
        normalized.startsWith(_secondaryPrefix);
  }

  bool _isPairedDevice(ble.BleDevice device) {
    return _pairedDevices.containsKey(device.deviceId);
  }

  // Check current bluetooth state.
  Future<void> _checkBleState() async {
    try {
      final state = await ble.UniversalBle.getBluetoothAvailabilityState();
      if (!mounted) return;

      final bool isPoweredOn = state == ble.AvailabilityState.poweredOn;

      setState(() {
        _bleUiEnabled = isPoweredOn;

        if (isPoweredOn) {
          _statusText = _isConnected && _connectedDevice != null
              ? 'Connected to ${_deviceTitle(_connectedDevice!)}.'
              : 'BLE is on. Press Scan to find nearby devices.';
        } else {
          _statusText = 'Bluetooth or Location is turned off.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusText = 'Unable to check BLE status.';
      });
    }
  }

  // Handle switch action inside the app.
  Future<void> _toggleBleUi(bool value) async {
    if (value) {
      final state = await ble.UniversalBle.getBluetoothAvailabilityState();

      if (state != ble.AvailabilityState.poweredOn) {
        await ble.UniversalBle.enableBluetooth();
      }

      await _checkBleState();
      await _tryAutoReconnectLastDevice();
      return;
    }

    setState(() {
      _bleUiEnabled = false;
      _isAutoReconnecting = false;
    });

    await _stopScan();

    if (!mounted) return;

    setState(() {
      _availableDevices.clear();
      _statusText = 'BLE controls are off. Turn on to scan devices.';
    });
  }

  // Ask for permissions before scanning.
  Future<bool> _requestBlePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final bool scanDenied =
        statuses[Permission.bluetoothScan]?.isDenied ?? true;

    final bool connectDenied =
        statuses[Permission.bluetoothConnect]?.isDenied ?? true;

    if (scanDenied || connectDenied) {
      if (!mounted) return false;

      await showBottomPopup(
        context,
        message: 'Bluetooth permission denied.',
        isError: true,
      );

      return false;
    }

    return true;
  }

  Future<void> _tryAutoReconnectLastDevice() async {
    if (!_bleUiEnabled || _isConnected || _isConnecting || _isScanning) return;

    final service = BleService.instance;
    final lastId = await service.getLastConnectedDeviceId();
    final lastName = await service.getLastConnectedDeviceName();
    if (lastId == null || !mounted) return;

    setState(() {
      _isAutoReconnecting = true;
      _lastDeviceId = lastId;
      _statusText = lastName == null || lastName.isEmpty
          ? 'Reconnecting last BLE device...'
          : 'Reconnecting to $lastName...';
    });

    await _startScan();

    _scanTimer?.cancel();
    _scanTimer = Timer(_scanDuration, () async {
      if (!mounted || !_isAutoReconnecting || _isConnected) return;
      await _stopScan();
      if (!mounted) return;
      setState(() {
        _isAutoReconnecting = false;
      });
      await showBottomPopup(
        context,
        message: 'Auto reconnect failed. Please select device manually.',
        isError: true,
      );
    });
  }

  // Start scanning.
  Future<void> _startScan() async {
    if (!_bleUiEnabled || _isScanning || _isConnecting) return;

    try {
      final bool hasPermission = await _requestBlePermissions();
      if (!hasPermission) return;

      final state = await ble.UniversalBle.getBluetoothAvailabilityState();

      if (state != ble.AvailabilityState.poweredOn) {
        setState(() {
          _statusText = 'Bluetooth or Location is turned off.';
        });
        if (!mounted) return;

        await showBottomPopup(
          context,
          message: 'Please enable Bluetooth and Location first.',
          isError: true,
        );
        return;
      }

      setState(() {
        _availableDevices.clear();
        _connectionErrors.clear();
        _failedConnectionDeviceId = null;
        _isScanning = true;
        _statusText = 'Scanning BLE devices named HOLTER...';
      });

      await ble.UniversalBle.startScan();

      _scanTimer?.cancel();
      _scanTimer = Timer(_scanDuration, () async {
        if (!mounted || !_isScanning) return;
        await _stopScan();
      });
    } catch (e) {
      if (!mounted) return;

      _scanTimer?.cancel();

      setState(() {
        _isScanning = false;
        _statusText = 'Failed to start BLE scan.';
      });

      await showBottomPopup(context, message: 'Scan failed: $e', isError: true);
    }
  }

  // Stop scanning.
  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;

    try {
      await ble.UniversalBle.stopScan();
    } catch (_) {
      // Ignore stop scan error.
    }

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      if (_isAutoReconnecting && !_isConnected) {
        _isAutoReconnecting = false;
      }

      if (_availableDevices.isEmpty) {
        _statusText = _isConnected && _connectedDevice != null
            ? 'Connected to ${_deviceTitle(_connectedDevice!)}.'
            : 'No named BLE devices found nearby.';
      } else {
        _statusText = 'Scan stopped. Select a device to connect.';
      }
    });
  }

  // Build the scan button.
  Widget _scanActionButton() {
    if (!_bleUiEnabled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: _isConnecting
            ? null
            : (_isScanning ? _stopScan : _startScan),
        icon: _isScanning
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.search_rounded, size: 18),
        label: Text(_isScanning ? 'Stop' : 'Scan'),
      ),
    );
  }

  // Connect to a device.
  Future<void> _connectToDevice(ble.BleDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _connectingDeviceId = device.deviceId;
      _connectionErrors.remove(device.deviceId);
      _failedConnectionDeviceId = null;
      _statusText = 'Connecting to BLE device...';
    });

    await _stopScan();
    // Let Android BLE stack settle after scan stop to reduce GATT 133.
    await Future<void>.delayed(_scanToConnectQuietGap);

    try {
      const int maxAttempts = 10;
      const Duration connectTimeout = Duration(seconds: 15);
      Object? lastError;
      bool connected = false;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        final int backoffMs = switch (attempt) {
          1 => 1500,
          2 => 2200,
          3 => 3000,
          4 => 3800,
          5 => 4600,
          6 => 5400,
          _ => 6200,
        };

        debugPrint(
          '[BLE] connect attempt $attempt/$maxAttempts to ${device.deviceId}',
        );
        _statusText = 'Connecting attempt $attempt/$maxAttempts...';
        if (mounted) setState(() {});

        try {
          // Hard disconnect before every attempt to reset Android GATT state.
          try {
            await device.disconnect();
            await Future<void>.delayed(const Duration(milliseconds: 900));
          } catch (_) {}

          // Extra guard gap before opening a new GATT session.
          await Future<void>.delayed(const Duration(milliseconds: 350));
          await device.connect().timeout(connectTimeout);
          connected = await device.isConnected;
          if (connected) {
            debugPrint('[BLE] connected on attempt $attempt');
            break;
          }
          lastError = Exception('Connection failed.');
        } catch (e) {
          lastError = e;
          debugPrint('[BLE] attempt $attempt failed: $e');
        }

        final String errText = (lastError ?? '').toString().toLowerCase();
        final bool shouldRetry133 = errText.contains('status=133') ||
            errText.contains('status 133') ||
            errText.contains('gatt 133') ||
            errText.contains('timeoutexception') ||
            errText.contains('timeout');
        if (!shouldRetry133 || attempt == maxAttempts) {
          break;
        }

        _statusText = 'Retrying BLE connection (${attempt + 1}/$maxAttempts)...';
        if (mounted) setState(() {});
        try {
          await device.disconnect();
        } catch (_) {}
        // Hard cooldown after failed attempt (helps on Android GATT 133).
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
      }

      if (!connected) {
        throw (lastError ?? Exception('Connection failed.'));
      }

      await BleService.instance.setConnectedDevice(device);

      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _isAutoReconnecting = false;
        _isConnected = true;
        _connectedDevice = device;
        _connectingDeviceId = null;
        _pairedDevices[device.deviceId] = device;
        _availableDevices.remove(device.deviceId);
        _connectionErrors.remove(device.deviceId);
        _failedConnectionDeviceId = null;
        _statusText = 'Connected to ${_deviceTitle(device)}.';
      });

      await showBottomPopup(
        context,
        message: 'Connected to ${_deviceTitle(device)}.',
      );
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      await BleService.instance.clearConnectedDevice();
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _isAutoReconnecting = false;
        _connectingDeviceId = null;
        _failedConnectionDeviceId = device.deviceId;
        _connectionErrors[device.deviceId] = 'Cannot connect to this device';
        _statusText = 'Connection failed. Please try again.';
      });

      await showBottomPopup(
        context,
        message: 'Connection failed: $e',
        isError: true,
      );
    }
  }

  // Disconnect the active device.
  Future<void> _disconnectCurrentDevice() async {
    final device = _connectedDevice;
    if (device == null) return;

    await BleService.instance.clearConnectedDevice(disconnect: true);

    if (!mounted) return;

    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _statusText = 'Device disconnected.';
    });

    await showBottomPopup(
      context,
      message: 'Disconnected from ${_deviceTitle(device)}.',
    );
  }

  // Get a safe device name.
  String _deviceTitle(ble.BleDevice device) {
    final String name = (device.name ?? '').trim();
    return name.isNotEmpty ? name : 'Unnamed BLE Device';
  }

  Widget _deviceTile({
    required ble.BleDevice device,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
    required Color activeColor,
    required bool isPairedSection,
  }) {
    final bool isThisDeviceConnecting =
        _isConnecting && _connectingDeviceId == device.deviceId;

    final bool isThisDeviceConnected =
        _isConnected && _connectedDevice?.deviceId == device.deviceId;
    final bool hasConnectionError =
        _failedConnectionDeviceId == device.deviceId;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isThisDeviceConnected
              ? Icons.bluetooth_connected_rounded
              : Icons.bluetooth_rounded,
          color: isThisDeviceConnected ? activeColor : mutedTextColor,
        ),
        title: Text(
          _deviceTitle(device),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isThisDeviceConnected ? activeColor : textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isThisDeviceConnected
              ? 'Connected'
              : hasConnectionError
              ? 'Cannot connect to this device'
              : isPairedSection
              ? 'Tap to reconnect'
              : device.deviceId,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isThisDeviceConnected
                ? activeColor
                : hasConnectionError
                ? const Color(0xFFCF222E)
                : mutedTextColor,
            fontSize: 12,
            fontWeight: isThisDeviceConnected || hasConnectionError
                ? FontWeight.w500
                : FontWeight.normal,
          ),
        ),
        trailing: isThisDeviceConnecting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: activeColor,
                ),
              )
            : isThisDeviceConnected
            ? Icon(Icons.check_circle_rounded, color: activeColor, size: 20)
            : Icon(
                Icons.chevron_right_rounded,
                color: mutedTextColor,
                size: 22,
              ),
        onTap: isThisDeviceConnected
            ? _disconnectCurrentDevice
            : (_isConnecting ? null : () => _connectToDevice(device)),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 18),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyState({
    required String text,
    required Color cardColor,
    required Color borderColor,
    required Color mutedTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: mutedTextColor, fontSize: 13),
      ),
    );
  }

  Widget _deviceListCard({
    required List<ble.BleDevice> devices,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
    required Color activeColor,
    required bool isPairedSection,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: devices
            .map(
              (device) => _deviceTile(
                device: device,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                mutedTextColor: mutedTextColor,
                activeColor: activeColor,
                isPairedSection: isPairedSection,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF6F8FA);
    final Color cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);
    final Color textColor = isDark ? Colors.white : const Color(0xFF24292F);
    final Color mutedTextColor = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);

    final Color onColor = _isConnected
        ? const Color(0xFF2DA44E)
        : const Color(0xFF0A66C2);
    final Color offCardColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFE5E7EB);
    final Color offBorderColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFCBD5E1);

    final List<ble.BleDevice> pairedDevices = _pairedDevices.values.toList();
    final List<ble.BleDevice> availableDevices = _availableDevices.values
        .where((device) => !_isPairedDevice(device))
        .toList();
    availableDevices.sort((a, b) {
      final String an = (a.name ?? '').trim().toUpperCase();
      final String bn = (b.name ?? '').trim().toUpperCase();
      final bool aStarts = an.startsWith(_preferredNameKeyword);
      final bool bStarts = bn.startsWith(_preferredNameKeyword);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      final bool aJdy = an.startsWith(_secondaryPrefix);
      final bool bJdy = bn.startsWith(_secondaryPrefix);
      if (aJdy != bJdy) return aJdy ? -1 : 1;
      return an.compareTo(bn);
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('BLE Settings'),
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
              actions: [_scanActionButton()],
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.showAppBar) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'BLE Device',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _scanActionButton(),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: _bleUiEnabled ? cardColor : offCardColor,
                      border: Border.all(
                        color: _bleUiEnabled ? borderColor : offBorderColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SwitchListTile(
                      value: _bleUiEnabled,
                      onChanged: _toggleBleUi,
                      activeColor: Colors.white,
                      activeTrackColor: onColor,
                      inactiveThumbColor: mutedTextColor,
                      inactiveTrackColor: offBorderColor,
                      secondary: Icon(
                        _isConnected
                            ? Icons.bluetooth_connected_rounded
                            : Icons.bluetooth_rounded,
                        color: _bleUiEnabled ? onColor : mutedTextColor,
                      ),
                      title: Text(
                        _bleUiEnabled ? 'On' : 'Off',
                        style: TextStyle(
                          color: _bleUiEnabled ? textColor : mutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _bleUiEnabled
                            ? _statusText
                            : 'BLE is off. Device sections are hidden.',
                        style: TextStyle(color: mutedTextColor, fontSize: 12),
                      ),
                    ),
                  ),

                  if (_bleUiEnabled) ...[
                    _sectionTitle('Paired devices', mutedTextColor),
                    if (pairedDevices.isEmpty)
                      _emptyState(
                        text: 'No paired device in this app session.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        mutedTextColor: mutedTextColor,
                      )
                    else
                      _deviceListCard(
                        devices: pairedDevices,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedTextColor: mutedTextColor,
                        activeColor: onColor,
                        isPairedSection: true,
                      ),

                    _sectionTitle('Available devices', mutedTextColor),
                    if (availableDevices.isEmpty)
                      _emptyState(
                        text: _isScanning
                            ? 'Scanning for named BLE devices...'
                            : 'Tap Scan to find nearby BLE devices.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        mutedTextColor: mutedTextColor,
                      )
                    else
                      _deviceListCard(
                        devices: availableDevices,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedTextColor: mutedTextColor,
                        activeColor: onColor,
                        isPairedSection: false,
                      ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
