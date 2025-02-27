import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.1.18:3000/api/auth", // Use machine's IP
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Login method for the secretary
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // Send a POST request to the specific endpoint for secretary login
      Response response = await _dio.post(
        "/login/secretaire", // Adjusted endpoint for secretary login
        data: {
          "username": username,
          "password": password,
        },
      );

      // Print debug information
      print("Response status: ${response.statusCode}");
      print("Response data: ${response.data}");

      // Check if the response contains a token
      if (response.statusCode == 200 && response.data['token'] != null) {
        return {
          "success": true,
          "message": response.data['message'],
          "token": response.data['token'], // Return the JWT token
        };
      } else {
        return {
          "success": false,
          "message": "Unexpected response from server",
        };
      }
    } on DioException catch (e) {
      // Handle errors (e.g., invalid credentials, network issues)
      print("Error occurred: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Login failed",
      };
    }
  }
}