import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://192.168.1.18:3000/api/auth", // Base URL for authentication endpoints
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Constructor to add interceptors (optional)
  AuthService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print("REQUEST[${options.method}] => PATH: ${options.path}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print("RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print("ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}");
        return handler.next(e);
      },
    ));
  }

  // Login function
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        "/login",
        data: {
          "username": username,
          "password": password,
        },
      );

      if (response.statusCode == 200) {
        // Extract the user details from the response
        final userId = response.data["user"]["id"];
        final email = response.data["user"]["email"];
        final accessToken = response.data["accessToken"];
        final refreshToken = response.data["refreshToken"];

        // Return the extracted details
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

  // Register function
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? profilePicture,
    String? MapsLocation,
    String? services,
    String? workingHours,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        "/signup", // Endpoint for user registration
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "username": username,
          "email": email,
          "password": password,
          "phoneNumber": phoneNumber,
          "profilePicture": profilePicture,
          "MapsLocation": MapsLocation,
          "services": services,
          "workingHours": workingHours,
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
}