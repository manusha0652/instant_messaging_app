import 'package:shared_preferences/shared_preferences.dart';

class UserSessionService {
  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  // Check if user is already logged in
  Future<String?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user');
  }

  // Check if user has biometric enabled
  Future<bool> isBiometricEnabled(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled_$phoneNumber') ?? false;
  }

  // Get last authenticated user
  Future<String?> getLastAuthenticatedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_authenticated_user');
  }

  // Save current user session
  Future<void> saveUserSession(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', phoneNumber);
    await prefs.setString('last_authenticated_user', phoneNumber);
    await prefs.setInt(
      'login_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Check if user session is valid (optional - for auto-logout after certain time)
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final loginTimestamp = prefs.getInt('login_timestamp');

    if (loginTimestamp == null) return false;

    final sessionDuration =
        DateTime.now().millisecondsSinceEpoch - loginTimestamp;
    const maxSessionDuration =
        7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

    return sessionDuration < maxSessionDuration;
  }

  // Clear user session (logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('login_timestamp');
  }

  // Clear all session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Check if user has ever logged in before
  Future<bool> hasLoggedInBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_authenticated_user') != null;
  }

  // Enable/disable biometric authentication
  Future<void> setBiometricEnabled(String phoneNumber, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled_$phoneNumber', enabled);
  }
}
