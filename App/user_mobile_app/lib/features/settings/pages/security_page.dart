import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../shared/widgets/bottom_popup.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // Loading state for username updates
  bool _isSavingUsername = false;

  // Loading state for password reset email
  bool _isSendingPasswordReset = false;

  bool _isGoogleUser(User? user) {
    if (user == null) return false;

    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  bool _isPasswordUser(User? user) {
    if (user == null) return false;

    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  Future<void> _showSnackBar(String message, {bool isError = false}) async {
    if (!mounted) return;
    await showBottomPopup(
      context,
      message: message,
      isError: isError,
    );
  }

  // Show popup dialog with close X button
  Future<void> _showMessageDialog({
    required String title,
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = const Color(0xFF0969DA),
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final bool isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;

        final Color textColor =
            isDark ? Colors.white : const Color(0xFF24292F);

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 18, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: textColor,
              height: 1.35,
            ),
          ),
        );
      },
    );
  }

  // Send password reset email
  Future<void> _sendPasswordResetEmail() async {
    final user = _user;

    if (user == null) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message: 'No current user is signed in.',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
      return;
    }

    final bool isGoogleUser = _isGoogleUser(user);
    final bool isPasswordUser = _isPasswordUser(user);

    // Google-only account cannot change password in this app
    if (isGoogleUser && !isPasswordUser) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message:
            'You are signed in with a Google account, so you cannot change your password here.',
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFF0969DA),
      );
      return;
    }

    if (!isPasswordUser) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message: 'This account does not use email/password sign-in.',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
      return;
    }

    final email = user.email?.trim() ?? '';

    if (email.isEmpty) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message: 'This account does not have an email address.',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
      return;
    }

    setState(() {
      _isSendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      await _showMessageDialog(
        title: 'Check your email',
        message:
            'A password reset link has been sent to $email. After resetting your password, you will need to sign in again with your new password.',
        icon: Icons.mark_email_read_outlined,
        iconColor: const Color(0xFF0969DA),
      );
    } on FirebaseAuthException catch (e) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message: e.message ?? 'Cannot send password reset email.',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
    } catch (e) {
      await _showMessageDialog(
        title: 'Cannot change password',
        message: 'Cannot send password reset email: $e',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingPasswordReset = false;
        });
      }
    }
  }

  // Ask email/password user to enter current password before updating username
  Future<String?> _showPasswordConfirmDialog() async {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    void closeDialog(BuildContext dialogContext, [String? value]) {
      FocusScope.of(dialogContext).unfocus();

      Future.microtask(() {
        if (Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop(value);
        }
      });
    }

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: const Text('Confirm password'),
              content: SizedBox(
                width: 320,
                child: Form(
                  key: formKey,
                  child: TextFormField(
                    controller: controller,
                    autofocus: true,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      border: const OutlineInputBorder(),
                      errorMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';

                      if (password.isEmpty) {
                        return 'Password cannot be empty';
                      }

                      if (password.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (formKey.currentState!.validate()) {
                        closeDialog(dialogContext, controller.text);
                      }
                    },
                  ),
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
                      closeDialog(dialogContext, controller.text);
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });

    return result;
  }

  // Re-authenticate email/password account
  Future<void> _reauthenticateWithPassword(User user) async {
    final email = user.email?.trim() ?? '';

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'This account does not have an email address.',
      );
    }

    final password = await _showPasswordConfirmDialog();

    if (password == null || password.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'reauth-cancelled',
        message: 'Password confirmation was cancelled.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Re-authenticate Google account before updating username
  Future<void> _reauthenticateWithGoogle(User user) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      // Required in google_sign_in v7
      await googleSignIn.initialize();

      // Start Google authentication flow
      final GoogleSignInAccount googleUser =
          await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Cannot get Google ID token.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'google-reauth-cancelled',
        message: 'Google authentication was cancelled or failed.',
      );
    }
  }

  // Update username in users and usernames collections together
  Future<void> _updateUsernameInFirestore({
    required User user,
    required String username,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final userRef = firestore.collection('users').doc(user.uid);
    final newUsernameRef = firestore.collection('usernames').doc(username);

    // Find old username index documents of this user
    final oldUsernameDocs = await firestore
        .collection('usernames')
        .where('uid', isEqualTo: user.uid)
        .get();

    await firestore.runTransaction((transaction) async {
      final newUsernameSnapshot = await transaction.get(newUsernameRef);

      // Do not allow username if it belongs to another user
      if (newUsernameSnapshot.exists) {
        final data = newUsernameSnapshot.data();
        final existingUid = (data?['uid'] ?? '').toString();

        if (existingUid.isNotEmpty && existingUid != user.uid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-already-exists',
            message: 'This username is already taken.',
          );
        }
      }

      // Update username in users/{uid}
      transaction.set(
        userRef,
        {
          'username': username,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Create or update usernames/{username}
      transaction.set(
        newUsernameRef,
        {
          'uid': user.uid,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Delete old username index documents of this user
      for (final doc in oldUsernameDocs.docs) {
        if (doc.id != username) {
          transaction.delete(doc.reference);
        }
      }
    });
  }

  // Update username with provider-based re-authentication
  Future<void> _updateUsername(String newUsername) async {
    final username = newUsername.trim();

    if (username.isEmpty) {
      await _showSnackBar('Username cannot be empty.', isError: true);
      return;
    }

    if (username.length < 5) {
      await _showSnackBar(
        'Username must be at least 5 characters.',
        isError: true,
      );
      return;
    }

    final currentUser = _user;

    if (currentUser == null) {
      await _showMessageDialog(
        title: 'Cannot update username',
        message: 'No current user is signed in.',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
      return;
    }

    setState(() {
      _isSavingUsername = true;
    });

    try {
      await currentUser.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No current user is signed in.',
        );
      }

      final bool isGoogleUser = _isGoogleUser(refreshedUser);
      final bool isPasswordUser = _isPasswordUser(refreshedUser);

      if (isGoogleUser) {
        await _reauthenticateWithGoogle(refreshedUser);
      } else if (isPasswordUser) {
        await _reauthenticateWithPassword(refreshedUser);
      } else {
        throw FirebaseAuthException(
          code: 'unsupported-provider',
          message:
              'This sign-in method does not support username changes in this app.',
        );
      }

      final latestUser = FirebaseAuth.instance.currentUser;

      if (latestUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No current user is signed in.',
        );
      }

      await _updateUsernameInFirestore(
        user: latestUser,
        username: username,
      );

      await _showSnackBar('Username updated successfully.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'reauth-cancelled' ||
          e.code == 'google-reauth-cancelled') {
        await _showMessageDialog(
          title: 'Username was not updated',
          message:
              'Authentication was cancelled, so your username was not changed.',
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF0969DA),
        );
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-mismatch') {
        await _showMessageDialog(
          title: 'Authentication failed',
          message:
              'The authentication step failed. Please check your account and try again.',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFCF222E),
        );
      } else {
        await _showMessageDialog(
          title: 'Cannot update username',
          message: e.message ?? 'Cannot update username.',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFCF222E),
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'username-already-exists') {
        await _showMessageDialog(
          title: 'Username not available',
          message: 'This username is already taken. Please choose another one.',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFCF222E),
        );
      } else {
        await _showMessageDialog(
          title: 'Cannot update username',
          message: e.message ?? 'Cannot update username.',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFCF222E),
        );
      }
    } catch (e) {
      await _showMessageDialog(
        title: 'Cannot update username',
        message: 'Cannot update username: $e',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFCF222E),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUsername = false;
        });
      }
    }
  }

  // Open dialog to edit username
  Future<void> _showEditUsernameDialog() async {
    final TextEditingController controller = TextEditingController();
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          title: const Text('Edit username'),
          content: SizedBox(
            width: 320,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),

                  // Allow validation text to wrap instead of being clipped
                  errorMaxLines: 2,
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Username cannot be empty';
                  }

                  if (name.length < 5) {
                    return 'Username must be at least 5 characters';
                  }

                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    final username = controller.text.trim();
                    closeDialog(dialogContext, username);
                  }
                },
              ),
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
                  final username = controller.text.trim();
                  closeDialog(dialogContext, username);
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
      await _updateUsername(result);
    }
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: cardColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.lock_reset_rounded,
                    color: githubBlue,
                  ),
                  title: Text(
                    'Change password',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Send a password reset link to your email',
                    style: TextStyle(color: mutedTextColor),
                  ),
                  trailing: _isSendingPasswordReset
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _isSendingPasswordReset
                      ? null
                      : _sendPasswordResetEmail,
                ),

                Divider(height: 1, color: borderColor),

                ListTile(
                  leading: const Icon(
                    Icons.alternate_email_rounded,
                    color: githubBlue,
                  ),
                  title: Text(
                    'Change username',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Requires authentication before updating',
                    style: TextStyle(color: mutedTextColor),
                  ),
                  trailing: _isSavingUsername
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _isSavingUsername ? null : _showEditUsernameDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
