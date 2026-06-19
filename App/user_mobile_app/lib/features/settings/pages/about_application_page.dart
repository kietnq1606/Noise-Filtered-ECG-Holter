import 'package:flutter/material.dart';

class AboutApplicationPage extends StatelessWidget {
  const AboutApplicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final Color cardColor =
        isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
    final Color textColor = isDark ? Colors.white : const Color(0xFF24292F);
    final Color mutedTextColor =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('About Application'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.monitor_heart_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Holter ECG Application',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: mutedTextColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'This application supports account management, BLE connection to a Holter ECG device, ECG data receiving controls, status notifications, and future report management. Doctor information and clinical documents will be expanded when official data is available.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/policy');
                    },
                    icon: const Icon(Icons.policy_outlined, size: 18),
                    label: const Text('Policy and User Guide'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
