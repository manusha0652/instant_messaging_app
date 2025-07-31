import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/first_time_setup_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/fingerprint_authentication.dart';
import 'screens/home_screen.dart' as home;
import 'screens/qr_scanner_screen.dart'; // Import the QR scanner screen
import 'services/database_service.dart';
import 'services/user_session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final dbService = DatabaseService();
  await dbService.database; // This will create the database and tables

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatLink',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home:
          const AppInitializer(), // Use initializer instead of direct SplashScreen
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const home.HomeScreen(),
        '/qr_scanner': (context) => const QRScannerScreen(),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final UserSessionService _sessionService = UserSessionService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash screen for minimum duration
    await Future.delayed(const Duration(seconds: 2));

    try {
      // First check if there are any users in the database
      final bool hasAnyUsers = await _databaseService.hasAnyUsers();

      if (!hasAnyUsers) {
        // No users in database - this is a brand new installation
        // Go directly to profile setup for first user
        _navigateToProfileSetup();
        return;
      }

      // There are users in database - check session state
      final bool hasLoggedInBefore = await _sessionService.hasLoggedInBefore();

      if (hasLoggedInBefore) {
        // Check if current session is valid
        final String? currentUser = await _sessionService.getCurrentUser();
        final bool isSessionValid = await _sessionService.isSessionValid();

        if (currentUser != null && isSessionValid) {
          // User is already logged in - go directly to home
          _navigateToHome();
        } else {
          // Session expired or no current user - get last authenticated user
          final String? lastUser = await _sessionService
              .getLastAuthenticatedUser();

          if (lastUser != null) {
            // User exists but needs to re-authenticate - go to fingerprint
            _navigateToFingerprint(lastUser);
          } else {
            // No previous user found - go to login
            _navigateToLogin();
          }
        }
      } else {
        // Has users but no previous login - go to login screen
        _navigateToLogin();
      }
    } catch (e) {
      print('Error initializing app: $e');
      // On error, default to login screen
      _navigateToLogin();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const home.HomeScreen()),
    );
  }

  void _navigateToFingerprint(String phoneNumber) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FingerprintAuthScreen(phoneNumber: phoneNumber, isSetup: false),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigateToProfileSetup() {
    // For first-time users, we'll navigate to a special setup flow
    // that includes phone number collection as well
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const FirstTimeSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Show splash while initializing
  }
}
