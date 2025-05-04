import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/token_storage.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://192.168.1.18:3000/api/auth",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  AuthService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print("REQUEST[\${options.method}] => PATH: \${options.path}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print("RESPONSE[\${response.statusCode}] => PATH: \${response.requestOptions.path}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print("ERROR[\${e.response?.statusCode}] => PATH: \${e.requestOptions.path}");
        return handler.next(e);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', accessToken);
        await prefs.setString('refreshToken', refreshToken);

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
          "message": response.data["message"] ?? "Login failed"
        };
      }
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again."
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
    String? profilePicture,
    String? mapsLocation,
    List<String>? services,
    List<Map<String, String>>? workingHours,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        "/signup",
        data: {
          "firstName": firstName.trim(),
          "lastName": lastName.trim(),
          "username": username.trim().toLowerCase(),
          "email": email.trim().toLowerCase(),
          "password": password.trim(),
          "phoneNumber": phoneNumber.trim(),
          "profilePicture": profilePicture,
          "mapsLocation": mapsLocation,
          "details": {
            "services": services,
            "workingHours": workingHours,
          },
          "role": role,
        },
      );

      if (response.statusCode == 201) {
        return {"success": true, "message": response.data["message"]};
      } else {
        return {"success": false, "message": response.data["message"] ?? "Registration failed"};
      }
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "An error occurred. Please try again."
      };
    }
  }

  Future<void> logout() async {
    try {
      // Clear tokens from SharedPreferences
      await TokenStorage.clear();

      // Optionally, you can send a logout request to your backend if needed
      // final response = await _dio.post(
      //   "/logout",
      //   data: {"refreshToken": refreshToken},
      //   options: Options(
      //     headers: {"Authorization": "Bearer $accessToken"},
      //   ),
      // );

      // If everything is successful, you may want to navigate or show a message
    } catch (e) {
      throw Exception("Logout failed: $e");
    }
  }


}