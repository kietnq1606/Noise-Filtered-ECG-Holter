import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/bottom_popup.dart';
import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameOrEmailController =
      TextEditingController();

  final AuthService _authService = AuthService();

  bool _isSending = false;
  bool _hasSentEmail = false;

  String? _resolvedEmail;

  Timer? _cooldownTimer;
  int _cooldownSecondsLeft = 0;

  void _startCooldown() {
    _cooldownTimer?.cancel();

    setState(() {
      _cooldownSecondsLeft = 60;
    });

    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        if (_cooldownSecondsLeft <= 1) {
          timer.cancel();
          setState(() {
            _cooldownSecondsLeft = 0;
          });
        } else {
          setState(() {
            _cooldownSecondsLeft--;
          });
        }
      },
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Resolve username to email if the user enters a username.
      final resolvedEmail = await _authService.getEmailFromUsernameOrEmail(
        _usernameOrEmailController.text,
      );

      // Send Firebase password reset link.
      await _authService.sendPasswordResetEmail(
        _usernameOrEmailController.text,
      );

      if (!mounted) return;

      setState(() {
        _resolvedEmail = resolvedEmail;
        _hasSentEmail = true;
      });

      _startCooldown();

      await showBottomPopup(
        context,
        message: 'Password reset email has been sent.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Cannot send password reset email.';

      if (e.code == 'user-not-found') {
        message = 'Username or email does not exist.';
      } else if (e.message != null) {
        message = e.message!;
      }

      await showBottomPopup(
        context,
        message: message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      await showBottomPopup(
        context,
        message: 'Cannot send password reset email: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _resendPasswordResetEmail() async {
    if (_cooldownSecondsLeft > 0 || _isSending) return;

    await _sendPasswordResetEmail();
  }

  void _backToSignIn() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
      arguments: {
        'authMessage':
            'Password changed successfully. Please sign in with your new password.',
      },
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _usernameOrEmailController.dispose();
    super.dispose();
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

    const Color githubGreen = Color(0xFF2DA44E);
    const Color githubBlue = Color(0xFF0969DA);

    final bool canResend = !_isSending && _cooldownSecondsLeft == 0;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    _hasSentEmail
                        ? 'Check your email'
                        : 'Reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: !_hasSentEmail
                        ? Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Enter your username or email address and we’ll send you a link to reset your password.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: mutedTextColor,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  'Username or email address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                TextFormField(
                                  controller: _usernameOrEmailController,
                                  keyboardType: TextInputType.text,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) =>
                                      _sendPasswordResetEmail(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0D1117)
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: githubBlue,
                                        width: 2,
                                      ),
                                    ),
                                    hintText: 'Enter your username or email',
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Username or email cannot be blank';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: _isSending
                                        ? null
                                        : _sendPasswordResetEmail,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: githubGreen,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          githubGreen.withOpacity(0.6),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Send password reset email',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'We sent a password reset link to:',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: mutedTextColor,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                _resolvedEmail ?? 'your email',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Please open your email and click the password reset link to create a new password.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: mutedTextColor,
                                ),
                              ),

                              const SizedBox(height: 20),

                              SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: canResend
                                      ? _resendPasswordResetEmail
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: githubBlue,
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _cooldownSecondsLeft > 0
                                              ? 'Resend email in ${_cooldownSecondsLeft}s'
                                              : 'Resend password reset email',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextButton(
                      onPressed: _backToSignIn,
                      style: TextButton.styleFrom(
                        foregroundColor: githubBlue,
                      ),
                      child: const Text(
                        'Back to sign in',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
