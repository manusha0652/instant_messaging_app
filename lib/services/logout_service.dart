import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'user_session_service.dart';

class LogoutService {
  static final LogoutService _instance = LogoutService._internal();
  factory LogoutService() => _instance;
  LogoutService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();

  // 🗑️ Complete logout with database clearing (for development)
  Future<void> logoutAndClearAllData() async {
    try {
      print('🔄 Starting complete logout and data clearing...');

      // 1. Clear current session
      await _sessionService.clearSession();
      print('✅ Session cleared');

      // 2. Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ SharedPreferences cleared');

      // 3. Delete all users from database
      await _databaseService.deleteAllUsers();
      print('✅ All users deleted from database');

      // 4. Clear all settings
      final db = await _databaseService.database;
      await db.delete('settings');
      print('✅ All settings cleared');

      print('🎉 Complete logout successful - app reset to fresh state!');
    } catch (e) {
      print('❌ Error during logout: $e');
      throw Exception('Failed to logout: $e');
    }
  }
}
