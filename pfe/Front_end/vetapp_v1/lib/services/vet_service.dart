import 'package:dio/dio.dart';
import '../models/token_storage.dart';

class VetService {
  static const String baseUrl = "http://192.168.1.16:3000/api/users";
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> fetchVeterinarians({
    String? rating,
    String? location,
    String? specialty,
    List<String>? services,
    int page = 1,
    int limit = 10,
    String sort = "desc", String? name,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      final queryParams = {
        if (rating != null && rating.trim().isNotEmpty) 'rating': rating.trim(),
        if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
        if (specialty != null && specialty.trim().isNotEmpty) 'specialty': specialty.trim(),
        if (services != null && services.isNotEmpty) 'services': services.join(","),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };

      final response = await _dio.get(
        '$baseUrl/veterinarians',
        queryParameters: queryParams,
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
      print('Fetch veterinarians response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        return response.data; // Contains 'veterinarians', 'totalPages', 'averageRating'
      } else {
        return {
          'success': false,
          'message': 'Failed to load veterinarians. Status: ${response.statusCode} - ${response.statusMessage}',
        };
      }
    } catch (e) {
      print('Error fetching veterinarians: $e');
      return {
        'success': false,
        'message': 'Error fetching veterinarians: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteVeterinarian(String vetId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        print('Delete veterinarian failed: No authentication token found');
        return {
          'success': false,
          'message': 'Authentication token not found. Please log in again.',
        };
      }

      // Verify admin role
      final role = await TokenStorage.getUserRoleFromToken();
      if (role != 'admin') {
        print('Delete veterinarian failed: User role is $role, admin required');
        return {
          'success': false,
          'message': 'Admin privileges required to delete a veterinarian.',
        };
      }

      print('Attempting to delete veterinarian ID: $vetId with token: $token');
      final response = await _dio.delete(
        '$baseUrl/$vetId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('Delete veterinarian response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Veterinarian deleted successfully',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': 'Invalid veterinarian ID.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Permission denied: Admin access required.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Veterinarian not found.',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete veterinarian: ${response.statusCode} - ${response.statusMessage}',
        };
      }
    } catch (e) {
      print('Error deleting veterinarian ID: $vetId - $e');
      if (e is DioException && e.response != null) {
        print('Dio error details: ${e.response?.statusCode} - ${e.response?.data}');
        return {
          'success': false,
          'message': 'Error deleting veterinarian: ${e.response?.data['message'] ?? e.message}',
        };
      }
      return {
        'success': false,
        'message': 'Error deleting veterinarian: $e',
      };
    }
  }
}