import 'package:flutter/material.dart';

class DoctorInfo {
  final String name;
  final String avatarLabel;
  final String workArea;
  final String email;
  final String phone;
  final String degree;
  final String details;

  const DoctorInfo({
    required this.name,
    required this.avatarLabel,
    required this.workArea,
    this.email = 'xxxxx',
    this.phone = 'xxxxx',
    this.degree = 'xxxxx',
    this.details = 'xxx',
  });
}

class DoctorInfoPage extends StatelessWidget {
  const DoctorInfoPage({super.key});

  static const List<DoctorInfo> _doctors = [
    DoctorInfo(
      name: 'Doctor 1',
      avatarLabel: 'D1',
      workArea: 'Workplace or department not set',
    ),
    DoctorInfo(
      name: 'Doctor 2',
      avatarLabel: 'D2',
      workArea: 'Workplace or department not set',
    ),
    DoctorInfo(
      name: 'Doctor 3',
      avatarLabel: 'D3',
      workArea: 'Workplace or department not set',
    ),
  ];

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
    const Color accentColor = Color(0xFF0969DA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _doctors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doctor = _doctors[index];

            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.15),
                  child: Text(
                    doctor.avatarLabel,
                    style: const TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  doctor.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  doctor.workArea,
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: mutedTextColor,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DoctorDetailPage(doctor: doctor),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class DoctorDetailPage extends StatelessWidget {
  final DoctorInfo doctor;

  const DoctorDetailPage({
    super.key,
    required this.doctor,
  });

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color borderColor,
    required Color textColor,
    required Color mutedTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(icon, color: mutedTextColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    const Color accentColor = Color(0xFF0969DA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Doctor Detail'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: accentColor.withOpacity(0.15),
                      child: Text(
                        doctor.avatarLabel,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      doctor.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      doctor.workArea,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mutedTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: doctor.email,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _infoRow(
                      icon: Icons.phone_outlined,
                      title: 'Contact phone number',
                      value: doctor.phone,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _infoRow(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Professional degrees',
                      value: doctor.degree,
                      borderColor: borderColor,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                    ),
                    _infoRow(
                      icon: Icons.description_outlined,
                      title: 'Details',
                      value: doctor.details,
                      borderColor: Colors.transparent,
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
    );
  }
}
