import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthService._init();

  /// Hash a PIN using SHA256
  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate user with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock ChatLink',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Store user session
  Future<void> storeSession(String sessionId) async {
    await _secureStorage.write(key: 'session_id', value: sessionId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_login', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get current user session
  Future<String?> getSession() async {
    return await _secureStorage.read(key: 'session_id');
  }

  /// Clear user session (logout)
  Future<void> clearSession() async {
    await _secureStorage.delete(key: 'session_id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_login');
  }

  /// Check if user session is valid (not expired)
  Future<bool> isSessionValid() async {
    final sessionId = await getSession();
    if (sessionId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt('last_login');
    if (lastLogin == null) return false;

    final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    final difference = now.difference(lastLoginDate);

    // Session expires after 7 days
    return difference.inDays < 7;
  }

  /// Validate PIN
  bool validatePin(String inputPin, String storedHashedPin) {
    final hashedInput = hashPin(inputPin);
    return hashedInput == storedHashedPin;
  }

  /// Generate session ID
  String generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final combined = '$timestamp$random';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
