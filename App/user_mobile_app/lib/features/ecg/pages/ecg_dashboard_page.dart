import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/services/ble_service.dart';
import '../../../shared/widgets/bottom_popup.dart';

class EcgDashboardPage extends StatefulWidget {
  final bool showAppBar;

  const EcgDashboardPage({super.key, this.showAppBar = true});

  @override
  State<EcgDashboardPage> createState() => _EcgDashboardPageState();
}

class _EcgDashboardPageState extends State<EcgDashboardPage> {
  final BleService _bleService = BleService.instance;
  StreamSubscription<String>? _logSubscription;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _bleService.addListener(_handleBleUpdate);

    _logSubscription = _bleService.logStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });

    _refreshConnectionState();
  }

  @override
  void dispose() {
    _bleService.removeListener(_handleBleUpdate);
    _logSubscription?.cancel();
    super.dispose();
  }

  void _handleBleUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshConnectionState() async {
    await _bleService.refreshConnectionState();
  }

  Future<void> _runBleAction(Future<void> Function() action) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      await showBottomPopup(
        context,
        message: 'BLE action failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _startEcg() async {
    await _runBleAction(() async {
      await _bleService.startEcg();
    });
  }

  Future<void> _stopEcg() async {
    await _runBleAction(() async {
      await _bleService.stopEcg();
    });
  }

  String get _deviceName {
    final device = _bleService.connectedDevice;
    if (device == null) return 'No device connected';
    return _bleService.getDeviceName(device);
  }

  String get _connectionText {
    if (!_bleService.isConnected) return 'Disconnected';
    if (!_bleService.isPrepared) return 'Connected, validating ECG device';
    if (_bleService.isStreaming) return 'Receiving ECG data';
    if (_bleService.isPrepared) return 'ECG channel ready';
    return 'Connected';
  }

  Color _statusColor(bool isDark) {
    if (_bleService.isStreaming) return const Color(0xFF2DA44E);
    if (_bleService.isConnected) return const Color(0xFF0969DA);
    return isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _statusTile({
    required String label,
    required String value,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: FilledButton.icon(
          onPressed: _isBusy ? null : onPressed,
          icon: Icon(icon, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataBox({
    required String title,
    required String body,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: 13, height: 1.35),
          ),
        ],
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
    final Color accentColor = _statusColor(isDark);

    final String transmittedPacket =
        _bleService.lastTransmittedPacket ?? 'No packet transmitted yet.';
    final String receivedPacket =
        _bleService.lastReceivedPacket ?? 'No packet received yet.';

    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _metricCard(
                  title: 'Device',
                  value: _deviceName,
                  icon: Icons.bluetooth_connected_rounded,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedTextColor: mutedTextColor,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 12),
                _metricCard(
                  title: 'Status',
                  value: _connectionText,
                  icon: Icons.favorite_rounded,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedTextColor: mutedTextColor,
                  accentColor: accentColor,
                ),
                _sectionTitle('Controls', mutedTextColor),
                Row(
                  children: [
                    _controlButton(
                      label: 'Start',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          _bleService.isPrepared && !_bleService.isStreaming
                          ? _startEcg
                          : null,
                      color: const Color(0xFF2DA44E),
                    ),
                    const SizedBox(width: 8),
                    _controlButton(
                      label: 'Stop',
                      icon: Icons.stop_rounded,
                      onPressed: _bleService.isStreaming ? _stopEcg : null,
                      color: const Color(0xFFCF222E),
                    ),
                  ],
                ),
                _sectionTitle('ECG Data', mutedTextColor),
                _dataBox(
                  title: 'Transmitted packet',
                  body: transmittedPacket,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedTextColor: mutedTextColor,
                ),
                const SizedBox(height: 12),
                _dataBox(
                  title: 'Received packet',
                  body: receivedPacket,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedTextColor: mutedTextColor,
                ),
                _sectionTitle('ACK/NACK Status', mutedTextColor),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    _statusTile(
                      label: 'Last ACK Seq',
                      value: _bleService.lastAckSeq?.toString() ?? '-',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _statusTile(
                      label: 'Last NACK Seq',
                      value: _bleService.lastNackSeq?.toString() ?? '-',
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _statusTile(
                      label: 'ACK Count',
                      value: _bleService.ackCount.toString(),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _statusTile(
                      label: 'NACK Count',
                      value: _bleService.nackCount.toString(),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _statusTile(
                      label: 'Timeout Count',
                      value: _bleService.timeoutCount.toString(),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _statusTile(
                      label: 'Link Status',
                      value: _bleService.linkStatus,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );

    if (!widget.showAppBar) {
      return ColoredBox(color: bgColor, child: body);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('ECG Dashboard'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: body,
    );
  }
}
