import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Import the JWT decoder

class TokenStorage {
  // Retrieve access token from SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');  // Returns null if not found
  }

  // Retrieve user ID from SharedPreferences
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');  // Returns null if not found
  }

  // Retrieve username (first name + last name) from SharedPreferences
  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName');
    final lastName = prefs.getString('lastName');
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';  // Combine first and last name
    }
    return null;  // Return null if either first or last name is not found
  }

  // Decode JWT to get username
  static Future<String?> getUsernameFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);

        // Check if token has expired
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          return null; // Token has expired
        }

        return decodedToken['username'];  // Assuming 'username' is in the payload
      } catch (e) {
        return null;  // Return null if the token is invalid or can't be decoded
      }
    }
    return null;  // Return null if no token is found
  }

  static Future<String?> getUserLocationFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) return null;
        return decodedToken['location'];
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Decode JWT to get user role
  static Future<String?> getUserRoleFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);

        // Check if token has expired
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          return null; // Token has expired
        }

        return decodedToken['role'];  // Assuming 'role' is in the payload
      } catch (e) {
        return null;  // Return null if the token is invalid or can't be decoded
      }
    }
    return null;  // Return null if no token is found
  }

  // Save token, user ID, first name, last name, and username in SharedPreferences
  static Future<void> setToken(String token, String userId, String firstName, String lastName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
    await prefs.setString('userId', userId);
    await prefs.setString('firstName', firstName);  // Save first name
    await prefs.setString('lastName', lastName);    // Save last name
    final username = JwtDecoder.decode(token)['username']; // Extract username from token
    await prefs.setString('username', username);    // Save username
  }

  // Clear all stored tokens, user info, and first/last names
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('userId');  // Clear user ID when logging out
    await prefs.remove('firstName');  // Clear first name when logging out
    await prefs.remove('lastName');   // Clear last name when logging out
    await prefs.remove('username');   // Clear username when logging out
  }
}