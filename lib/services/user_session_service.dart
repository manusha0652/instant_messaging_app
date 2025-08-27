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
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('last_authenticated_user');
    await prefs.remove('login_timestamp');
  }

  // Legacy method name for compatibility
  Future<void> logout() async {
    await clearSession();
  }

  // Check if this is user's first time setup
  Future<bool> isFirstTimeUser(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey('setup_completed_$phoneNumber');
  }

  // Mark user setup as completed
  Future<void> markSetupCompleted(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_completed_$phoneNumber', true);
  }

  // Check if user has logged in before (legacy method name for compatibility)
  Future<bool> hasLoggedInBefore() async {
    final currentUser = await getCurrentUser();
    return currentUser != null;
  }
}
