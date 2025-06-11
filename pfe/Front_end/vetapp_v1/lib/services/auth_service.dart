import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token_storage.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://192.168.1.16:3000/api/auth",
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 100),
  ));

  AuthService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print("REQUEST[${options.method}] => PATH: ${options.path}, DATA: ${options.data}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print("RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}, DATA: ${response.data}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print("ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}, MESSAGE: ${e.response?.data['message'] ?? e.message}");
        return handler.next(e);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print("Starting login process...");
      final response = await _dio.post(
        "/login",
        data: {
          "username": username.trim().toLowerCase(),
          "password": password.trim(),
        },
      );

      if (response.statusCode == 200) {
        final userId = response.data["user"]["id"];
        final email = response.data["user"]["email"];
        final accessToken = response.data["tokens"]["accessToken"];
        final refreshToken = response.data["tokens"]["refreshToken"];
        print("Access Token: $accessToken");
        print("Refresh Token: $refreshToken");
        print("User ID: $userId");

        await TokenStorage.storeTokens(accessToken, refreshToken);
        await TokenStorage.setToken(
          accessToken,
          userId,
          response.data["user"]["firstName"],
          response.data["user"]["lastName"],
        );

        return {
          "success": true,
          "message": "Login successful",
          "data": {
            "userId": userId,
            "email": email,
            "accessToken": accessToken,
            "refreshToken": refreshToken,
          },
        };
      } else {
        return {
          "success": false,
          "message": response.data["message"] ?? "Login failed",
        };
      }
    } on DioException catch (e) {
      print("Login error: ${e.response?.data}, Status: ${e.response?.statusCode}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    Map<String, String>? address,
    String? mapsLocation,
    String? description,
    String? profilePicture,
  }) async {
    try {
      final response = await _dio.post(
        "/signup/client",
        data: {
          "firstName": firstName.trim(),
          "lastName": lastName.trim(),
          "username": username.trim().toLowerCase(),
          "email": email.trim().toLowerCase(),
          "password": password.trim(),
          "phoneNumber": phoneNumber.trim(),
          if (address != null && address.values.any((v) => v.isNotEmpty)) "address": address,
          if (mapsLocation != null && mapsLocation.isNotEmpty) "mapsLocation": mapsLocation,
          if (description != null && description.isNotEmpty) "description": description,
          if (profilePicture != null && profilePicture.isNotEmpty) "profilePicture": profilePicture,
        },
      );

      if (response.statusCode == 201) {
        final userId = response.data["user"]["id"];
        final accessToken = response.data["tokens"]["accessToken"];
        final refreshToken = response.data["tokens"]["refreshToken"];

        await TokenStorage.storeTokens(accessToken, refreshToken);
        await TokenStorage.setToken(accessToken, userId, firstName, lastName);

        return {
          "success": true,
          "message": response.data["message"],
          "user": response.data["user"],
          "tokens": response.data["tokens"],
        };
      } else {
        return {
          "success": false,
          "message": response.data["message"] ?? "Registration failed",
        };
      }
    } on DioException catch (e) {
      print("Register error: ${e.response?.data}, Status: ${e.response?.statusCode}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }

      final response = await _dio.post(
        "/refresh-token",
        data: {
          "refreshToken": refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final accessToken = response.data["tokens"]["accessToken"];
        final newRefreshToken = response.data["tokens"]["refreshToken"];
        final userId = response.data["user"]["id"];
        final firstName = response.data["user"]["firstName"];
        final lastName = response.data["user"]["lastName"];

        await TokenStorage.storeTokens(accessToken, newRefreshToken);
        await TokenStorage.setToken(
          accessToken,
          userId,
          firstName,
          lastName,
          newRefreshToken,
        );


        return {
          "success": true,
          "accessToken": accessToken,
          "refreshToken": newRefreshToken,
        };
      } else {
        return {
          "success": false,
          "message": response.data["message"] ?? "Failed to refresh token",
        };
      }
    } on DioException catch (e) {
      print("Refresh token error: ${e.response?.data}, Status: ${e.response?.statusCode}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Failed to refresh token",
      };
    }
  }

  Future<void> logout() async {
    try {
      await TokenStorage.clear();
    } catch (e) {
      throw Exception("Logout failed: $e");
    }
  }

  Future<Map<String, dynamic>> forgetPassword(String email) async {
    try {
      print("Sending forgetPassword request for email: $email");
      final response = await _dio.post(
        "/forget-password",
        data: {
          "email": email.trim().toLowerCase(),
        },
      );

      print("forgetPassword response: ${response.data}");
      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": response.data["message"] ?? "Verification code sent successfully",
        };
      } else {
        return {
          "success": false,
          "message": response.data["message"] ?? "Failed to send verification code",
        };
      }
    } on DioException catch (e) {
      print("forgetPassword error: ${e.response?.data}, Status: ${e.response?.statusCode}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    try {
      print("Sending resetPassword request for email: $email, code: $code");
      final response = await _dio.post(
        "/reset-password",
        data: {
          "email": email.trim().toLowerCase(),
          "code": code.trim(),
          "newPassword": newPassword.trim(),
        },
      );

      print("resetPassword response: ${response.data}");
      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": response.data["message"] ?? "Password reset successfully",
        };
      } else {
        return {
          "success": false,
          "message": response.data["message"] ?? "Failed to reset password",
        };
      }
    } on DioException catch (e) {
      print("resetPassword error: ${e.response?.data}, Status: ${e.response?.statusCode}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again.",
      };
    }
  }
}