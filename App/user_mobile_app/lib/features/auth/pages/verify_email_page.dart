import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/bottom_popup.dart';
import '../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  // Timer for checking email verification status.
  Timer? _verifyTimer;

  // Timer for resend email cooldown.
  Timer? _resendCooldownTimer;

  final AuthService _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;

  int _resendSecondsLeft = 60;

  String? _username;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
    void initState() {
      super.initState();

      // Check verification status quietly every 3 seconds, ONLY if not manually checking
      _verifyTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) {
          if (!_isChecking) { 
            _checkEmailVerified(silent: true);
          }
        },
      );

      // Start cooldown because the first email was already sent.
      _startResendCooldown();
    }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get username from CreateAccountPage.
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map && args['username'] is String) {
      _username = args['username'] as String;
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();

    setState(() {
      _resendSecondsLeft = 60;
    });

    _resendCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        if (_resendSecondsLeft <= 1) {
          timer.cancel();

          setState(() {
            _resendSecondsLeft = 0;
          });
        } else {
          setState(() {
            _resendSecondsLeft--;
          });
        }
      },
    );
  }

  Future<void> _checkEmailVerified({bool silent = false}) async {
      // If user clicked the button manually and it is loading, stop here
      if (!silent && _isChecking) return;

      // Show loading spinner ONLY for manual clicks
      if (!silent) {
        setState(() {
          _isChecking = true;
        });
      }

      try {
        // Refresh user data from Firebase
        await _user?.reload();

        final refreshedUser = FirebaseAuth.instance.currentUser;

        // If email is verified successfully
        if (refreshedUser != null && refreshedUser.emailVerified) {
          _verifyTimer?.cancel();
          _resendCooldownTimer?.cancel();

          if (_username == null || _username!.trim().isEmpty) {
            throw FirebaseAuthException(
              code: 'missing-username',
              message: 'Missing username. Please create your account again.',
            );
          }

          // Save user to database
          await _authService.saveVerifiedEmailPasswordAccount(
            username: _username!,
          );

          // Sign out so user can log in normally
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          await showBottomPopup(
            context,
            message: 'Email verified successfully. Please sign in.',
          );

          // Go to login page
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (_) => false,
          );
        } else {
          // Show error message ONLY for manual clicks
          if (!silent && mounted) {
            await showBottomPopup(
              context,
              message: 'Email is not verified yet. Please check Gmail.',
              isError: true,
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        if (!silent && mounted) {
          await showBottomPopup(
            context,
            message: e.message ?? 'Email verification failed.',
            isError: true,
          );
        }
      } catch (e) {
        if (!silent && mounted) {
          await showBottomPopup(
            context,
            message: 'Email verification failed: $e',
            isError: true,
          );
        }
      } finally {
        // Hide loading spinner ONLY for manual clicks
        if (!silent && mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    }

  Future<void> _resendVerificationEmail() async {
    // Prevent too many resend requests.
    if (_isResending || _resendSecondsLeft > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _user?.sendEmailVerification();

      if (!mounted) return;

      await showBottomPopup(
        context,
        message: 'Verification email has been resent.',
      );

      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      await showBottomPopup(
        context,
        message: e.message ?? 'Cannot resend verification email.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _backToSignUp() async {
    _verifyTimer?.cancel();
    _resendCooldownTimer?.cancel();

    // Delete temporary Auth user if email is not verified.
    await _authService.deleteUnverifiedCurrentUser();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/create-account',
      (_) => false,
    );
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _resendCooldownTimer?.cancel();
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

    final String email = _user?.email ?? 'your email';

    final bool canResend = !_isResending && _resendSecondsLeft == 0;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 52,
                    color: textColor,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Verify your email',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'A verification link has been sent to:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: mutedTextColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Please open your email and click the verification link. '
                          'After verification, return to this app. '
                          'This page will automatically check your email status.',
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
                          child: ElevatedButton(
                            onPressed: _isChecking
                                ? null
                                : () => _checkEmailVerified(silent: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: githubGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: _isChecking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'I have verified my email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed:
                                canResend ? _resendVerificationEmail : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: githubBlue,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _resendSecondsLeft > 0
                                        ? 'Resend email in ${_resendSecondsLeft}s'
                                        : 'Resend verification email',
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
                      onPressed: _backToSignUp,
                      style: TextButton.styleFrom(
                        foregroundColor: githubBlue,
                      ),
                      child: const Text(
                        'Back to sign up',
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
