import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.1.18:3000/api/auth",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Login method for the secretary
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      Response response = await _dio.post(
        "/login/secretaire",
        data: {"username": username, "password": password},
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        return {
          "success": true,
          "message": response.data['message'],
          "token": response.data['token'],
        };
      } else {
        return {"success": false, "message": "Unexpected response from server"};
      }
    } on DioException catch (e) {
      print("Login Error: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Login failed",
      };
    }
  }

  /// Signup method for the client
  Future<Map<String, dynamic>> signUpClient({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? profilePicture,
    String? location,
  }) async {
    try {
      Response response = await _dio.post(
        "/signup/client",
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "username": username,
          "email": email,
          "password": password,
          "phoneNumber": phoneNumber,
          "profilePicture": profilePicture,
          "location": location,
        },
      );

      if (response.statusCode == 201 && response.data['user'] != null) {
        return {"success": true, "message": response.data['message']};
      } else {
        return {"success": false, "message": "Unexpected response from server"};
      }
    } on DioException catch (e) {
      print("Client Signup Error: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Client signup failed",
      };
    }
  }

  /// Signup method for the veterinarian
  Future<Map<String, dynamic>> signUpVeterinaire({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    required String specialty,
    required String workingHours,
    String? profilePicture,
    String? location,
  }) async {
    try {
      Response response = await _dio.post(
        "/signup/veterinaire",
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "username": username,
          "email": email,
          "password": password,
          "phoneNumber": phoneNumber,
          "specialty": specialty,
          "workingHours": workingHours,
          "profilePicture": profilePicture,
          "location": location,
        },
      );

      if (response.statusCode == 201 && response.data['user'] != null) {
        return {"success": true, "message": response.data['message']};
      } else {
        return {"success": false, "message": "Unexpected response from server"};
      }
    } on DioException catch (e) {
      print("Veterinarian Signup Error: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Veterinarian signup failed",
      };
    }
  }

  /// Signup method for the secretary
  Future<Map<String, dynamic>> signUpSecretaire({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    required String workingHours,
    String? profilePicture,
  }) async {
    try {
      Response response = await _dio.post(
        "/signup/secretaire",
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "username": username,
          "email": email,
          "password": password,
          "phoneNumber": phoneNumber,
          "workingHours": workingHours,
          "profilePicture": profilePicture,
        },
      );

      if (response.statusCode == 201 && response.data['user'] != null) {
        return {"success": true, "message": response.data['message']};
      } else {
        return {"success": false, "message": "Unexpected response from server"};
      }
    } on DioException catch (e) {
      print("Secretary Signup Error: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Secretary signup failed",
      };
    }
  }

  /// Signup method for the admin
  Future<Map<String, dynamic>> signUpAdmin({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    try {
      Response response = await _dio.post(
        "/signup/admin",
        data: {
          "firstName": firstName,
          "lastName": lastName,
          "username": username,
          "email": email,
          "password": password,
          "phoneNumber": phoneNumber,
        },
      );

      if (response.statusCode == 201 && response.data['user'] != null) {
        return {"success": true, "message": response.data['message']};
      } else {
        return {"success": false, "message": "Unexpected response from server"};
      }
    } on DioException catch (e) {
      print("Admin Signup Error: ${e.message}");
      return {
        "success": false,
        "message": e.response?.data["message"] ?? "Admin signup failed",
      };
    }
  }
}