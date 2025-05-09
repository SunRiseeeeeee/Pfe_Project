import 'package:dio/dio.dart';
import '../models/token_storage.dart';

class UserService {
  final Dio _dio = Dio();
  final String _baseUrl = 'http://192.168.1.18:3000/api/users';

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
  Future<void> updateUser({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? profilePicture,
    Map<String, dynamic>? address, // Location as address
  }) async {
    final token = await TokenStorage.getToken();
    final userId = await _getUserId();

    if (token == null || userId == null) {
      throw Exception('User ID or Token not found');
    }

    final updatedData = {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      if (address != null) 'address': address, // Add address
      if (profilePicture != null) 'profilePicture': profilePicture,
    };

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
}
