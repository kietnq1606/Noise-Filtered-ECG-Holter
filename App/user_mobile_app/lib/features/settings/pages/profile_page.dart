  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import '../../../shared/widgets/bottom_popup.dart';

  class ProfilePage extends StatefulWidget {
    const ProfilePage({super.key});

    @override
    State<ProfilePage> createState() => _ProfilePageState();
  }

  class _ProfilePageState extends State<ProfilePage> {
    // Store profile loading future
    late Future<Map<String, dynamic>?> _profileFuture;

    // Loading state when saving display name
    bool _isSavingDisplayName = false;
    bool _isSavingPhoto = false;

    // Local display name after editing
    String? _localDisplayName;
    String? _localPhotoUrl;
    String? _localAvatarIcon;

    final List<Map<String, dynamic>> _defaultAvatarIcons = const [
      {'name': 'person', 'icon': Icons.person_rounded},
      {'name': 'account', 'icon': Icons.account_circle},
      {'name': 'face', 'icon': Icons.face_rounded},
      {'name': 'person_outline', 'icon': Icons.person_outline},
      {'name': 'supervised_user', 'icon': Icons.supervised_user_circle},
      {'name': 'badge', 'icon': Icons.badge_rounded},
    ];

    // Get current Firebase user
    User? get _user => FirebaseAuth.instance.currentUser;

    @override
    void initState() {
      super.initState();
      _profileFuture = _loadUserProfile();
    }

    // Load user profile from Firestore
    Future<Map<String, dynamic>?> _loadUserProfile() async {
      final user = _user;
      if (user == null) return null;

      // Reload Auth user to get latest data
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return null;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid);

      final doc = await userRef.get();
      final data = doc.data();

      // Use Auth data if Firestore data does not exist
      if (data == null) {
        return {
          'uid': refreshedUser.uid,
          'email': refreshedUser.email,
          'username': 'Not set',
          'displayName': refreshedUser.displayName ?? 'No display name',
          'photoURL': refreshedUser.photoURL,
          'emailVerified': refreshedUser.emailVerified,
        };
      }

      return data;
    }

    // Update display name in Firebase Auth and Firestore
    Future<void> _updateDisplayName(String newDisplayName) async {
      final user = _user;
      final displayName = newDisplayName.trim();

      if (user == null) {
        await showBottomPopup(
          context,
          message: 'No current user is signed in.',
          isError: true,
        );
        return;
      }

      if (displayName.isEmpty) {
        await showBottomPopup(
          context,
          message: 'Display name cannot be empty.',
          isError: true,
        );
        return;
      }

      setState(() {
        _isSavingDisplayName = true;
      });

      try {
        // Update Firebase Authentication profile
        await user.updateDisplayName(displayName);

        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userRef.get();

        if (doc.exists) {
          // Update only displayName, keep username unchanged
          await userRef.set({
            'displayName': displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // Create user document if it does not exist
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'username': 'Not set',
            'displayName': displayName,
            'photoURL': user.photoURL,
            'provider': user.providerData.map((p) => p.providerId).toList(),
            'emailVerified': user.emailVerified,
            'profileCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Reload user after updating Auth data
        await user.reload();

        if (!mounted) return;

        // Update only display name area, do not reload whole page
        setState(() {
          _isSavingDisplayName = false;
          _localDisplayName = displayName;
        });

        await showBottomPopup(
          context,
          message: 'Display name updated successfully.',
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        setState(() {
          _isSavingDisplayName = false;
        });

        await showBottomPopup(
          context,
          message: e.message ?? 'Cannot update display name.',
          isError: true,
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isSavingDisplayName = false;
        });

        await showBottomPopup(
          context,
          message: 'Cannot update display name: $e',
          isError: true,
        );
      }
    }

    Future<void> _updatePhotoUrl(String photoUrl) async {
      final user = _user;

      if (user == null) {
        await showBottomPopup(
          context,
          message: 'No current user is signed in.',
          isError: true,
        );
        return;
      }

      setState(() {
        _isSavingPhoto = true;
      });

      try {
        final String? newPhotoUrl = photoUrl.trim().isEmpty ? null : photoUrl.trim();

        await user.updatePhotoURL(newPhotoUrl);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'photoURL': newPhotoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await user.reload();

        if (!mounted) return;

        setState(() {
          _isSavingPhoto = false;
          _localPhotoUrl = newPhotoUrl ?? '';
        });

        await showBottomPopup(
          context,
          message: 'Profile image updated successfully.',
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        setState(() {
          _isSavingPhoto = false;
        });

        await showBottomPopup(
          context,
          message: e.message ?? 'Cannot update profile image.',
          isError: true,
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isSavingPhoto = false;
        });

        await showBottomPopup(
          context,
          message: 'Cannot update profile image: $e',
          isError: true,
        );
      }
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

    Future<void> _updateDefaultAvatarIcon(String iconName) async {
      final user = _user;
      if (user == null) return;

      setState(() {
        _isSavingPhoto = true;
      });

      try {
        await user.updatePhotoURL(null);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'photoURL': null,
          'avatarIcon': iconName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await user.reload();

        if (!mounted) return;

        setState(() {
          _isSavingPhoto = false;
          _localPhotoUrl = '';
          _localAvatarIcon = iconName;
        });

        await showBottomPopup(
          context,
          message: 'Default avatar updated successfully.',
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isSavingPhoto = false;
        });

        await showBottomPopup(
          context,
          message: 'Cannot update default avatar: $e',
          isError: true,
        );
      }
    }

    Future<void> _showDefaultAvatarPicker() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (pickerContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: _defaultAvatarIcons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final item = _defaultAvatarIcons[index];
                  final String name = item['name'] as String;
                  final IconData icon = item['icon'] as IconData;

                  return OutlinedButton(
                    onPressed: () async {
                      Navigator.of(pickerContext).pop();
                      await _updateDefaultAvatarIcon(name);
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Icon(icon, size: 30),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    String _getGooglePhotoUrl(User? user) {
      if (user == null) return '';

      for (final provider in user.providerData) {
        if (provider.providerId == 'google.com') {
          return provider.photoURL?.trim() ?? '';
        }
      }

      return user.photoURL?.trim() ?? '';
    }

    Future<void> _showPhotoOptions(String currentPhotoUrl) async {
      final String googlePhotoUrl = _getGooglePhotoUrl(_user);

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        googlePhotoUrl.isNotEmpty ? NetworkImage(googlePhotoUrl) : null,
                    child: googlePhotoUrl.isEmpty
                        ? const Icon(Icons.account_circle_outlined)
                        : null,
                  ),
                  title: const Text('Use Google account image'),
                  subtitle: Text(
                    googlePhotoUrl.isEmpty
                        ? 'No Google image is available for this account'
                        : 'Apply the image from your Google profile',
                  ),
                  enabled: googlePhotoUrl.isNotEmpty,
                  onTap: googlePhotoUrl.isEmpty
                      ? null
                      : () async {
                          Navigator.of(bottomSheetContext).pop();
                          await _updatePhotoUrl(googlePhotoUrl);
                        },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_rounded),
                  ),
                  title: const Text('Use default app icon'),
                  subtitle: const Text('Choose from built-in default avatar icons'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _showDefaultAvatarPicker();
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Show dialog to edit display name
    Future<void> _showEditDisplayNameDialog(String currentDisplayName) async {
      final TextEditingController controller = TextEditingController(
        text: currentDisplayName == 'No display name' ? '' : currentDisplayName,
      );

      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      void closeDialog(BuildContext dialogContext, [String? value]) {
        // Hide keyboard before closing dialog
        FocusScope.of(dialogContext).unfocus();

        // Close dialog after current input frame finishes
        Future.microtask(() {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(value);
          }
        });
      }

      final String? result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit display name'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Display name cannot be empty';
                  }

                  if (name.length < 2) {
                    return 'Display name must be at least 2 characters';
                  }

                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    final name = controller.text.trim();
                    closeDialog(dialogContext, name);
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  closeDialog(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name = controller.text.trim();
                    closeDialog(dialogContext, name);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Dispose after dialog and keyboard fully close
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        controller.dispose();
      });

      if (result != null && result.trim().isNotEmpty) {
        await _updateDisplayName(result);
      }
    }

    // Profile information tile
    Widget _infoTile({
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
            Icon(icon, size: 22, color: mutedTextColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Display name row under avatar
    Widget _displayNameArea({
      required String displayName,
      required Color textColor,
      required Color githubBlue,
    }) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // This text is always centered with the avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            // This button does not affect the center position of the text
            Positioned(
              right: 0,
              child: _isSavingDisplayName
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Edit display name',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: githubBlue,
                      onPressed: () {
                        _showEditDisplayNameDialog(displayName);
                      },
                    ),
            ),
          ],
        ),
      );
    }

    Widget _profileAvatar({
      required String photoUrl,
      required String avatarIcon,
      required Color githubBlue,
    }) {
      final IconData selectedIcon = _getAvatarIcon(avatarIcon);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: githubBlue.withOpacity(0.15),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Icon(
                    selectedIcon,
                    color: githubBlue,
                    size: 42,
                  )
                : null,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: githubBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSavingPhoto ? null : () => _showPhotoOptions(photoUrl),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: _isSavingPhoto
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Get sign-in provider text
    String _getProviderText(User? user) {
      if (user == null) return 'Unknown';

      final providers = user.providerData.map((e) => e.providerId).toList();

      if (providers.contains('google.com')) {
        return 'Google Sign-In';
      }

      if (providers.contains('password')) {
        return 'Email and password';
      }

      return providers.isEmpty ? 'Unknown' : providers.join(', ');
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

      final Color textColor =
          isDark ? Colors.white : const Color(0xFF24292F);

      final Color mutedTextColor =
          isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);

      const Color githubBlue = Color(0xFF0969DA);

      final user = _user;

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
        ),
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final String email = data?['email'] ?? user?.email ?? 'No email';

              final String firestoreUsername =
                  (data?['username'] ?? '').toString().trim();

              final String firestoreDisplayName =
                  (data?['displayName'] ?? '').toString().trim();

              final String authDisplayName =
                  user?.displayName?.trim() ?? '';

              final String username =
                  firestoreUsername.isNotEmpty ? firestoreUsername : 'Not set';

              final String localDisplayName = _localDisplayName?.trim() ?? '';

              final String displayName = localDisplayName.isNotEmpty
                  ? localDisplayName
                  : firestoreDisplayName.isNotEmpty
                      ? firestoreDisplayName
                      : authDisplayName.isNotEmpty
                          ? authDisplayName
                          : firestoreUsername.isNotEmpty
                              ? firestoreUsername
                              : 'No display name';

              final String provider = _getProviderText(user);
              final String firestorePhotoUrl =
                  (data?['photoURL'] ?? '').toString().trim();
              final String firestoreAvatarIcon =
                  (data?['avatarIcon'] ?? '').toString().trim();
              final String authPhotoUrl = user?.photoURL?.trim() ?? '';
              final String? localPhotoUrl = _localPhotoUrl?.trim();
              final String localAvatarIcon = _localAvatarIcon?.trim() ?? '';
              final String photoUrl = localPhotoUrl != null
                  ? localPhotoUrl
                  : firestorePhotoUrl.isNotEmpty
                      ? firestorePhotoUrl
                      : authPhotoUrl;
              final String avatarIcon = localAvatarIcon.isNotEmpty
                  ? localAvatarIcon
                  : firestoreAvatarIcon.isNotEmpty
                      ? firestoreAvatarIcon
                      : 'person';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top profile card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _profileAvatar(
                                photoUrl: photoUrl,
                                avatarIcon: avatarIcon,
                                githubBlue: githubBlue,
                              ),
                              const SizedBox(height: 14),

                              // Display name is always centered
                              _displayNameArea(
                                displayName: displayName,
                                textColor: textColor,
                                githubBlue: githubBlue,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Account detail card
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _infoTile(
                                icon: Icons.alternate_email_rounded,
                                title: 'Username',
                                value: username,
                                borderColor: borderColor,
                                textColor: textColor,
                                mutedTextColor: mutedTextColor,
                              ),
                              _infoTile(
                                icon: Icons.email_outlined,
                                title: 'Email',
                                value: email,
                                borderColor: borderColor,
                                textColor: textColor,
                                mutedTextColor: mutedTextColor,
                              ),
                              _infoTile(
                                icon: Icons.login_rounded,
                                title: 'Sign-in method',
                                value: provider,
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
            },
          ),
        ),
      );
    }
  }
