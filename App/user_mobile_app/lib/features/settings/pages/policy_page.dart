import 'package:flutter/material.dart';

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

  Widget _section({
    required String title,
    required String body,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockHeader({
    required String label,
    required IconData icon,
    required Color textColor,
    required Color mutedTextColor,
    required Color borderColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: mutedTextColor,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);

    final Color cardColor = isDark ? const Color(0xFF161B22) : Colors.white;

    final Color borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

    final Color textColor = isDark ? Colors.white : const Color(0xFF24292F);

    final Color mutedTextColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Policy and User Guide'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _blockHeader(
                      label: 'POLICY',
                      icon: Icons.policy_outlined,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(
                            title: 'Purpose',
                            body:
                                'This app is designed for Holter ECG device connectivity, ECG data receiving, and monitoring support. It is not a replacement for professional diagnosis.',
                            textColor: textColor,
                            mutedTextColor: mutedTextColor,
                          ),
                          _section(
                            title: 'Device Use',
                            body:
                                'Connect only trusted Holter ECG devices. Start ECG receiving after the BLE device is connected and stop receiving when monitoring is complete.',
                            textColor: textColor,
                            mutedTextColor: mutedTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _blockHeader(
                      label: 'USER GUIDE',
                      icon: Icons.menu_book_outlined,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(
                            title: 'Data Notice',
                            body:
                                'Account, profile, BLE status, and ECG-related data may be used by the app to provide monitoring features. Detailed storage and sharing rules will be updated when official project documents are available.',
                            textColor: textColor,
                            mutedTextColor: mutedTextColor,
                          ),
                          _section(
                            title: 'User Guide',
                            body:
                                'Sign in, connect the Holter device from Settings, return to Dashboard, prepare the ECG channel, then start or stop ECG receiving as needed.',
                            textColor: textColor,
                            mutedTextColor: mutedTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}