import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/first_time_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/fingerprint_authentication.dart';
import 'services/database_service.dart';
import 'services/user_session_service.dart';
import 'services/real_time_messaging_service.dart'; // Keep existing import

void main() {
  runApp(const ChatLinkApp());
}

class ChatLinkApp extends StatelessWidget {
  const ChatLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatLink',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final RealTimeMessagingService _messagingService = RealTimeMessagingService(); // Initialize messaging service

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize database
      await _databaseService.database;

      // Initialize local messaging service
      await _messagingService.initialize();

      // Check if there are any users in the database
      final bool hasUsers = await _databaseService.hasAnyUsers();

      if (!hasUsers) {
        // First time setup - no users exist
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FirstTimeSetupScreen()),
          );
        }
        return;
      }

      // Check if user has logged in before
      final bool hasLoggedInBefore = await _sessionService.hasLoggedInBefore();

      if (!hasLoggedInBefore) {
        // User exists but not logged in - go to first time setup
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FirstTimeSetupScreen()),
          );
        }
        return;
      }

      // Get the last authenticated user
      final String? lastUser = await _sessionService.getLastAuthenticatedUser();

      if (lastUser != null) {
        // Check if biometric is enabled for this user
        final bool biometricEnabled = await _sessionService.isBiometricEnabled(lastUser);

        if (biometricEnabled) {
          // User has biometric enabled - go to fingerprint authentication
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FingerprintAuthScreen(
                  phoneNumber: lastUser,
                  isSetup: false, // This is login mode for existing users
                ),
              ),
            );
          }
        } else {
          // User doesn't have biometric - go directly to home
          await _sessionService.saveUserSession(lastUser);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else {
        // No last user found - go to first time setup
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FirstTimeSetupScreen()),
          );
        }
      }
    } catch (e) {
      print('Error initializing app: $e');
      // On error, go to first time setup
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FirstTimeSetupScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }

  @override
  void dispose() {
    // Clean up messaging service when app is disposed
    _messagingService.dispose();
    super.dispose();
  }
}
