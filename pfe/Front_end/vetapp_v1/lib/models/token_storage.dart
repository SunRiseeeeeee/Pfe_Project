import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');  // Add this new method
  }

  static Future<void> setToken(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
    await prefs.setString('userId', userId);  // Store user ID when setting token
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');  // Clear user ID when logging out
  }
}