import 'package:dio/dio.dart';
import '../models/token_storage.dart';

class UserService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.16:3000/api/users',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30), // Match AuthService
  ));
  final String _authBaseUrl = 'http://192.168.1.16:3000/api/auth';

  UserService() {
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

  // Retrieve the user ID using the TokenStorage class
  Future<String?> _getUserId() async {
    return await TokenStorage.getUserId();
  }

  // Fetch user details by ID using TokenStorage for the token
  Future<Map<String, dynamic>> getUserById(String userId) async {
    final token = await TokenStorage.getToken();

    if (token == null) {
      throw Exception('Token not found');
    }

    try {
      final response = await _dio.get(
        '/$userId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch user: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to fetch user: ${e.response?.data['message'] ?? e.message}');
    }
  }

  // Update user (allowed fields only)
  Future<void> updateUser(Map<String, dynamic> updatedData) async {
    final token = await TokenStorage.getToken();
    final userId = await _getUserId();

    if (token == null || userId == null) {
      throw Exception('User ID or Token not found');
    }

    try {
      print('Sending update for user $userId with data: $updatedData');
      final response = await _dio.put(
        '/$userId',
        data: updatedData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      print('Update successful: ${response.data}');
    } on DioException catch (e) {
      print('Update failed: ${e.response?.data}');
      throw Exception('Failed to update user: ${e.response?.data['message'] ?? e.message}');
    }
  }

  // Delete user
  Future<void> deleteUser() async {
    final token = await TokenStorage.getToken();
    final userId = await _getUserId();

    if (token == null || userId == null) {
      throw Exception('User ID or Token not found');
    }

    try {
      final response = await _dio.delete(
        '/$userId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      print('User deleted: ${response.data}');
    } on DioException catch (e) {
      print('Delete failed: ${e.response?.data}');
      throw Exception('Failed to delete user: ${e.response?.data['message'] ?? e.message}');
    }
  }

  // Create a new admin user
  Future<Map<String, dynamic>> createAdmin({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? profilePicture,
    String? mapsLocation,
    String? description,
    Map<String, dynamic>? address,
  }) async {
    final data = {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      if (profilePicture != null) 'profilePicture': profilePicture,
      if (mapsLocation != null) 'mapsLocation': mapsLocation,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
    };

    try {
      final response = await _dio.post(
        '$_authBaseUrl/signup/admin',
        data: data,
        options: Options(headers: {
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 201) {
        return response.data['user'];
      } else {
        throw Exception('Failed to create admin: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Create admin failed: ${e.response?.data}');
      throw Exception('Failed to create admin: ${e.response?.data['message'] ?? e.message}');
    }
  }

  // Create a new veterinarian user
  Future<Map<String, dynamic>> createVeterinary({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? profilePicture,
    String? mapsLocation,
    String? description,
    Map<String, dynamic>? address,
    required List<String> services,
    required List<Map<String, dynamic>> workingHours,
    required String specialization,
    int? experienceYears,
  }) async {
    final data = {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      if (profilePicture != null) 'profilePicture': profilePicture,
      if (mapsLocation != null) 'mapsLocation': mapsLocation,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      'details': {
        'services': services,
        'workingHours': workingHours,
        'specialization': specialization,
        if (experienceYears != null) 'experienceYears': experienceYears,
      },
    };

    try {
      final response = await _dio.post(
        '$_authBaseUrl/signup/veterinaire',
        data: data,
        options: Options(headers: {
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 201) {
        return response.data['user'];
      }
      throw Exception('Failed to create veterinarian: ${response.statusCode}');
    } on DioException catch (e) {
      print('Create veterinarian failed: ${e.response?.data}');
      throw Exception('Failed to create veterinarian: ${e.response?.data['message'] ?? e.message}');
    }
  }
}