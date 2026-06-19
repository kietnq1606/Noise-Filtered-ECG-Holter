import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/bottom_popup.dart';
import '../services/auth_service.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  // Global key to manage and trigger form text field validation states
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Text controllers to capture and manage input data from users
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Instance of the authentication class built in previous steps
  final AuthService _authService = AuthService();

  // UI state flags for loading indicator and password visibility masking
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Firebase error messages shown under username/email fields
  String? _usernameFirebaseError;
  String? _emailFirebaseError;

  // Main background process execution when the signup form is submitted
  Future<void> _createAccount() async {
    // Clear old Firebase errors before submitting again
    setState(() {
      _usernameFirebaseError = null;
      _emailFirebaseError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create temporary Firebase Auth user and send verification email.
      // Firestore data will be saved later after email verification.
      await _authService.createAccountWithEmailPassword(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Keep current Firebase user signed in temporarily.
      // VerifyEmailPage needs currentUser to check emailVerified.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/verify-email',
        (_) => false,
        arguments: {
          'username': _usernameController.text.trim(),
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Username already exists.
      // This error is thrown manually from AuthService.
      if (e.code == 'username-already-used') {
        setState(() {
          _usernameFirebaseError =
              e.message ?? 'This username is already used.';
        });
        return;
      }

      // Email already exists.
      // This error is thrown by Firebase Auth.
      if (e.code == 'email-already-in-use') {
        setState(() {
          _emailFirebaseError = 'This email is already registered.';
        });
        return;
      }

      await showBottomPopup(
        context,
        message: e.message ?? 'Create account failed.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      await showBottomPopup(
        context,
        message: 'Create account failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Release memory slots occupied by controllers to mitigate performance memory leaks
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Unified theme decoration scheme constructor mapping fields into standard GitHub style
  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

    final Color inputColor = isDark ? const Color(0xFF0D1117) : Colors.white;

    return InputDecoration(
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: inputColor,
      // Fixed error text wrapping constraints inside the form view package
      errorMaxLines: 3,
      errorStyle: const TextStyle(
        fontSize: 12,
        height: 1.2,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFF0969DA),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Evaluates local application platform system brightness configurations
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
                  // Core platform structural identification logo
                  Center(
                    child: Icon(
                      Icons.monitor_heart_rounded,
                      size: 48,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Brand structural headline typography
                  Text(
                    'Create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Central wrapped user interactive account management layout block
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- USERNAME FORM FIELD GROUP ---
                          Text(
                            'Username',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_usernameFirebaseError != null) {
                                setState(() {
                                  _usernameFirebaseError = null;
                                });
                              }
                            },
                            style: TextStyle(fontSize: 14, color: textColor),
                            decoration: _inputDecoration(
                              hintText: 'Your username on the app',
                            ),
                            validator: (value) {
                              final username = value?.trim() ?? '';

                              if (username.isEmpty) {
                                return 'Username is required';
                              }
                              if (username.length < 5) {
                                return 'Username must be at least 5 characters';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                  .hasMatch(username)) {
                                return 'Only letters, numbers and underscore are allowed';
                              }

                              return null;
                            },
                          ),

                          if (_usernameFirebaseError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _usernameFirebaseError!,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: Color(0xFFCF222E),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // --- EMAIL FORM FIELD GROUP ---
                          Text(
                            'Email address',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_emailFirebaseError != null) {
                                setState(() {
                                  _emailFirebaseError = null;
                                });
                              }
                            },
                            style: TextStyle(fontSize: 14, color: textColor),
                            decoration: _inputDecoration(
                              hintText: 'yourname@gmail.com',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Email is required';
                              }

                              if (!email.contains('@')) {
                                return 'Please enter a valid email';
                              }

                              return null;
                            },
                          ),

                          if (_emailFirebaseError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _emailFirebaseError!,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: Color(0xFFCF222E),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // --- PASSWORD FORM FIELD GROUP ---
                          Text(
                            'Password',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(fontSize: 14, color: textColor),
                            decoration: _inputDecoration(
                              hintText: 'At least 8 characters',
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 17,
                                  color: mutedTextColor,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';

                              if (password.isEmpty) {
                                return 'Password is required';
                              }

                              if (password.length < 8) {
                                return 'Password must be at least 8 characters';
                              }

                              final passwordRegExp = RegExp(
                                r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[-_!@#\$%^&*(),.?":{}|<>]).+$',
                              );

                              if (!passwordRegExp.hasMatch(password)) {
                                return 'Requires uppercase, lowercase, number & special symbol';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // --- PASSWORD VALIDATION ASSURANCE GROUP ---
                          Text(
                            'Confirm password',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _createAccount(),
                            style: TextStyle(fontSize: 14, color: textColor),
                            decoration: _inputDecoration(
                              hintText: 'Confirm your password',
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 17,
                                  color: mutedTextColor,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }

                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // --- PLATFORM STANDARD PRIMARY ELEVATED CALL TO ACTION BUTTON ---
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createAccount,
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
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'A verification email will be sent to your Gmail address.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- SECONDARY CALLOUT REGISTRATION NAVIGATION INTERFACE BLOCK ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Already have an account?',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                    '/login',
                                    (_) => false,
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: githubBlue,
                          ),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
