import 'package:flutter/material.dart';

import '../features/ecg/pages/ecg_dashboard_page.dart';
import '../features/settings/pages/doctor_info_page.dart';
import '../features/settings/pages/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    EcgDashboardPage(showAppBar: false),
    DoctorInfoPage(),
    SettingsPage(showAppBar: false),
  ];

  static const List<String> _titles = [
    'ECG Dashboard',
    'Doctors',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final Color borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
    final Color textColor = isDark ? Colors.white : const Color(0xFF24292F);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_services_outlined),
              selectedIcon: Icon(Icons.medical_services_rounded),
              label: 'Doctors',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
