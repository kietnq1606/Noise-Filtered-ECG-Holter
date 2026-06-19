import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/bottom_popup.dart';
import '../../auth/services/auth_service.dart';

// Pages
import 'profile_page.dart';
import 'security_page.dart';

class SettingsPage extends StatefulWidget {
  final bool showAppBar;

  const SettingsPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _isLoggingOut = false;

  // Khai báo Future để lưu trữ dữ liệu profile tránh load đi load lại
  late Future<Map<String, dynamic>?> _profileFuture;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadUserProfile();
  }

  // Hàm đọc dữ liệu từ Firestore giống y như ProfilePage
  Future<Map<String, dynamic>?> _loadUserProfile() async {
    final user = _user;
    if (user == null) return null;

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser == null) return null;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid);

    final doc = await userRef.get();
    return doc.data();
  }

  // Hàm refresh lại dữ liệu khi người dùng quay lại từ trang Profile
  Future<void> _refreshSettingsData() async {
    setState(() {
      _profileFuture = _loadUserProfile();
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      await showBottomPopup(
        context,
        message: 'Logout failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _confirmLogout() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _logout();
    }
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

  Widget _settingsCard({
    required List<Widget> children,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }

  Widget _divider(Color borderColor) {
    return Divider(height: 1, thickness: 1, color: borderColor);
  }

  IconData _getAvatarIcon(String? iconName) {
    switch (iconName) {
      case 'account':
        return Icons.account_circle;
      case 'face':
        return Icons.face_rounded;
      case 'person_outline':
        return Icons.person_outline;
      case 'supervised_user':
        return Icons.supervised_user_circle;
      case 'badge':
        return Icons.badge_rounded;
      case 'person':
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final Color cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
    final Color textColor = isDark ? Colors.white : const Color(0xFF24292F);
    final Color mutedTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);

    const Color githubBlue = Color(0xFF0969DA);
    const Color dangerRed = Color(0xFFCF222E);

    final user = _user;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Settings'),
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        // Bọc toàn bộ Body bằng FutureBuilder để hứng dữ liệu từ Firestore lên giống hệt ProfilePage
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;

            // Xử lý logic hiển thị tên đồng bộ 100% với ProfilePage
            final String firestoreUsername = (data?['username'] ?? '').toString().trim();
            final String firestoreDisplayName = (data?['displayName'] ?? '').toString().trim();
            final String authDisplayName = user?.displayName?.trim() ?? '';

            // Thứ tự ưu tiên: Firestore Tên > Firestore Mã số (Username) > Auth Tên gốc > Mặc định
            final String displayName = firestoreDisplayName.isNotEmpty
                ? firestoreDisplayName
                : firestoreUsername.isNotEmpty && firestoreUsername != 'Not set'
                    ? firestoreUsername
                    : authDisplayName.isNotEmpty
                        ? authDisplayName
                        : 'Holter ECG User';
            final String photoUrl =
                (data?['photoURL'] ?? user?.photoURL ?? '').toString().trim();
            final String avatarIconName =
                (data?['avatarIcon'] ?? 'person').toString().trim();
            final IconData avatarIcon = _getAvatarIcon(avatarIconName);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // HEADER SECTION: Hiển thị avatar và tên đã đồng bộ hóa dữ liệu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: githubBlue.withOpacity(0.15),
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Icon(
                                    avatarIcon,
                                    color: githubBlue,
                                    size: 26,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              displayName, // Đã lấy đúng chuẩn theo Database Firestore của bạn
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ACCOUNT SECTION
                    _sectionTitle('Account', mutedTextColor),
                    _settingsCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _settingsTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Profile',
                          //subtitle: 'Display name, email and account identity',
                          iconColor: githubBlue,
                          titleColor: textColor,
                          onTap: () async {
                            // Dùng lệnh await để khi người dùng nhấn "Back" từ ProfilePage về, 
                            // SettingsPage sẽ tự động gọi hàm cập nhật lại tên mới ngay lập tức.
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfilePage()),
                            );
                            _refreshSettingsData();
                          },
                        ),
                        _divider(borderColor),
                        _settingsTile(
                          icon: Icons.security_rounded,
                          title: 'Security',
                          //subtitle: 'Username, password reset and sign-in method',
                          iconColor: githubBlue,
                          titleColor: textColor,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SecurityPage()),
                            );
                          },
                        ),
                      ],
                    ),

                    // DEVICE SECTION
                    _sectionTitle('Device', mutedTextColor),
                    _settingsCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _settingsTile(
                          icon: Icons.bluetooth_connected_rounded,
                          title: 'BLE Connection',
                          // subtitle: 'Scan, connect or disconnect the Holter device',
                          iconColor: githubBlue,
                          titleColor: textColor,
                          onTap: () {
                            Navigator.of(context).pushNamed('/ble-connect');
                          },
                        ),
                      ],
                    ),

                    // APP SECTION
                    _sectionTitle('Information', mutedTextColor),
                    _settingsCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _settingsTile(
                          icon: Icons.info_outline_rounded,
                          title: 'About Application',
                          // subtitle: 'Introduction, version and user guide policy',
                          iconColor: githubBlue,
                          titleColor: textColor,
                          onTap: () {
                            Navigator.of(context).pushNamed('/about-application');
                          },
                        ),
                      ],
                    ),

                    // DANGER ZONE SECTION
                    _sectionTitle('Danger zone', mutedTextColor),
                    _settingsCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _settingsTile(
                          icon: Icons.logout_rounded,
                          title: _isLoggingOut ? 'Logging out...' : 'Logout',
                          // subtitle: 'Sign out from this account',
                          iconColor: dangerRed,
                          titleColor: dangerRed,
                          trailing: _isLoggingOut
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: dangerRed,
                                ),
                          onTap: _isLoggingOut ? null : _confirmLogout,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
