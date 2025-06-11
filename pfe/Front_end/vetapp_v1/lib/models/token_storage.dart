import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenStorage {
  // Existing methods (unchanged)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName');
    final lastName = prefs.getString('lastName');
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return null;
  }

  static Future<String?> getUsernameFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          print('TokenStorage: Token is expired');
          return null;
        }
        print('TokenStorage: Decoded username: ${decodedToken['username']}');
        return decodedToken['username'];
      } catch (e) {
        print('TokenStorage: Error decoding username: $e');
        return null;
      }
    }
    print('TokenStorage: No token found for username');
    return null;
  }

  static Future<String?> getUserLocationFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          print('TokenStorage: Token is expired');
          return null;
        }
        print('TokenStorage: Decoded location: ${decodedToken['location']}');
        return decodedToken['location'];
      } catch (e) {
        print('TokenStorage: Error decoding location: $e');
        return null;
      }
    }
    print('TokenStorage: No token found for location');
    return null;
  }

  static Future<String?> getUserRoleFromToken() async {
    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          print('TokenStorage: Token is expired');
          return null;
        }
        print('TokenStorage: Decoded role: ${decodedToken['role']}');
        return decodedToken['role'];
      } catch (e) {
        print('TokenStorage: Error decoding role: $e');
        return null;
      }
    }
    print('TokenStorage: No token found for role');
    return null;
  }

  static Future<String?> getEmailFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email != null) {
      print('TokenStorage: Email from SharedPreferences: $email');
      return email;
    }
    print('TokenStorage: No email found in SharedPreferences');

    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          print('TokenStorage: Token is expired');
          return null;
        }
        print('TokenStorage: Decoded token payload: $decodedToken');
        if (decodedToken['email'] == null) {
          print('TokenStorage: Email field missing in JWT payload');
        }
        return decodedToken['email'];
      } catch (e) {
        print('TokenStorage: Error decoding email: $e');
        return null;
      }
    }
    print('TokenStorage: No token found for email');
    return null;
  }

  static Future<void> setToken(String token, String userId, String firstName, String lastName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
    await prefs.setString('userId', userId);
    await prefs.setString('firstName', firstName);
    await prefs.setString('lastName', lastName);
    try {
      final decodedToken = JwtDecoder.decode(token);
      final username = decodedToken['username'];
      if (username != null) {
        await prefs.setString('username', username);
      }
      // Store veterinaireId for secretaries
      final veterinaireId = decodedToken['veterinaireId'];
      if (veterinaireId != null) {
        await prefs.setString('veterinaireId', veterinaireId);
      }
    } catch (e) {
      print('TokenStorage: Error saving username or veterinaireId from token: $e');
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('userId');
    await prefs.remove('firstName');
    await prefs.remove('lastName');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('veterinaireId');
  }

  // New method to get veterinaireId for secretaries
  static Future<String?> getVeterinaireId() async {
    final prefs = await SharedPreferences.getInstance();
    final veterinaireId = prefs.getString('veterinaireId');
    if (veterinaireId != null) {
      print('TokenStorage: Veterinaire ID from SharedPreferences: $veterinaireId');
      return veterinaireId;
    }

    final token = await getToken();
    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        bool hasExpired = JwtDecoder.isExpired(token);
        if (hasExpired) {
          print('TokenStorage: Token is expired');
          return null;
        }
        final vetId = decodedToken['veterinaireId'];
        if (vetId != null) {
          print('TokenStorage: Decoded veterinaireId: $vetId');
          await prefs.setString('veterinaireId', vetId); // Cache for future use
          return vetId;
        }
        print('TokenStorage: No veterinaireId found in token');
        return null;
      } catch (e) {
        print('TokenStorage: Error decoding veterinaireId: $e');
        return null;
      }
    }
    print('TokenStorage: No token found for veterinaireId');
    return null;
  }

  static storeTokens(accessToken, refreshToken) {
    // Placeholder for storing refresh token if needed
    print('TokenStorage: storeTokens called with accessToken and refreshToken');
  }
}