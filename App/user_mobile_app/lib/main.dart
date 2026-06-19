import 'package:flutter/material.dart';

// firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// pages
import 'app/app_shell.dart';
import 'features/auth/pages/create_account_page.dart';
import 'features/auth/pages/forgot_password_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/verify_email_page.dart';
import 'features/ble/pages/ble_connect_page.dart';
import 'features/ecg/pages/ecg_dashboard_page.dart';
import 'features/settings/pages/about_application_page.dart';
import 'features/settings/pages/doctor_info_page.dart';
import 'features/settings/pages/policy_page.dart';
import 'features/settings/pages/profile_page.dart';
import 'features/settings/pages/security_page.dart';
import 'features/settings/pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holter ECG',
      // turn off the debug banner
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0969DA),
        ),

        // Enable Material Design 3 UI style.
        useMaterial3: true,
      ),
      // When app opens, navigate to the login page.
      initialRoute: '/login',
      routes: {
        // Login screen.
        '/login': (_) => const LoginPage(),
        '/verify-email': (_) => const VerifyEmailPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/create-account': (context) => const CreateAccountPage(),
        '/app': (_) => const AppShell(),
        '/dashboard': (_) => const EcgDashboardPage(),
        '/settings': (_) => const SettingsPage(),
        '/security': (_) => const SecurityPage(),
        '/profile': (_) => const ProfilePage(),
        '/ble-connect': (_) => const BleConnectPage(),
        '/doctors': (_) => const DoctorInfoPage(),
        '/about-application': (_) => const AboutApplicationPage(),
        '/policy': (_) => const PolicyPage(),
      },
    );
  }
}
