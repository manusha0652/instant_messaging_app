// App Configuration
class AppConstants {
  static const String appName = 'ChatLink';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'chatlink.db';
  static const int databaseVersion = 1;

  // Session
  static const int sessionExpiryDays = 7;
  static const int qrCodeExpiryMinutes = 5;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double defaultBorderRadius = 8.0;
  static const double cardBorderRadius = 12.0;
  static const double messageBubbleRadius = 16.0;

  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // Message Types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeFile = 'file';

  // QR Code
  static const double qrCodeSize = 200.0;
  static const String qrCodeType = 'chatlink';
  static const String qrCodeVersion = '1.0';

  // Validation
  static const int minPinLength = 4;
  static const int maxPinLength = 6;
  static const int maxNameLength = 50;
  static const int maxMessageLength = 1000;

  // File Sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
}

// Shared Preferences Keys
class PreferenceKeys {
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String lastLogin = 'last_login';
  static const String biometricEnabled = 'biometric_enabled';
  static const String themeMode = 'theme_mode';
  static const String firstLaunch = 'first_launch';
}

// Secure Storage Keys
class SecureStorageKeys {
  static const String sessionId = 'session_id';
  static const String pinHash = 'pin_hash';
  static const String encryptionKey = 'encryption_key';
}

// Route Names
class RouteNames {
  static const String splash = '/';
  static const String profileSetup = '/profile-setup';
  static const String login = '/login';
  static const String main = '/main';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
}
