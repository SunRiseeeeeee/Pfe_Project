import 'package:dio/dio.dart';
import '../models/token_storage.dart';

class UserService {
  final Dio _dio = Dio();
  final String _baseUrl = 'http://192.168.100.7:3000/api/users';
  final String _authBaseUrl = 'http://192.168.100.7:3000/api/auth';

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

    final response = await _dio.get(
      '$_baseUrl/$userId',
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to fetch user: ${response.statusCode}');
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
        '$_baseUrl/$userId',
        data: updatedData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      print('Update successful: ${response.data}');
    } on DioException catch (e) {
      print('Update failed: ${e.response?.data}');
      throw Exception('Failed to update user: ${e.response?.data}');
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
        '$_baseUrl/$userId',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      print('User deleted: ${response.data}');
    } on DioException catch (e) {
      print('Delete failed: ${e.response?.data}');
      throw Exception('Failed to delete user: ${e.response?.data}');
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
      } else {
        throw Exception('Failed to create veterinarian: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Create veterinarian failed: ${e.response?.data}');
      throw Exception('Failed to create veterinarian: ${e.response?.data['message'] ?? e.message}');
    }
  }
}