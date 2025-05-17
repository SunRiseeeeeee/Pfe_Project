import 'dart:io';
import 'package:dio/dio.dart';
import '../models/service.dart';
import '../models/token_storage.dart';

class ServiceService {
  static const String baseUrl = 'http://192.168.1.18:3000/api/services';
  static final Dio _dio = Dio();

  // Fetch all services
  static Future<Map<String, dynamic>> getAllServices() async {
    try {
      final response = await _dio.get(baseUrl);
      print('Get all services response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'services': (response.data as List).map((json) => Service.fromJson(json)).toList(),
        };
      }
      return {
        'success': false,
        'message': 'Failed to load services: ${response.statusCode} - ${response.statusMessage}',
      };
    } catch (e) {
      print('Error fetching services: $e');
      return {
        'success': false,
        'message': 'Error fetching services: $e',
      };
    }
  }

  // Create a new service
  static Future<Map<String, dynamic>> createService({
    required String name,
    String? description,
    File? image,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }
      final role = await TokenStorage.getUserRoleFromToken();
      if (role != 'admin') {
        return {
          'success': false,
          'message': 'Admin privileges required to create a service',
        };
      }

      final formData = FormData.fromMap({
        'name': name,
        if (description != null) 'description': description,
      });

      if (image != null && await image.exists()) {
        final imagePath = image.path;
        final imageFilename = imagePath.toLowerCase().endsWith('.png') ? 'images.png' : 'images.jpg';
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            imagePath,
            filename: imageFilename,
          ),
        ));
        print('Creating service with data: ${formData.fields}, image: $imagePath, filename: $imageFilename');
      }

      final response = await _dio.post(
        baseUrl,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('Create service response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 201) {
        return {
          'success': true,
          'service': Service.fromJson(response.data),
          'message': 'Service created successfully',
        };
      }
      return {
        'success': false,
        'message': 'Failed to create service: ${response.statusCode} - ${response.statusMessage}',
      };
    } catch (e) {
      print('Error creating service: $e');
      if (e is DioException && e.response != null) {
        print('Server response: ${e.response?.data}');
        final errorMessage = e.response?.data['message'] ?? 'Failed to create service: Server error';
        return {
          'success': false,
          'message': errorMessage.contains('ENOENT')
              ? 'Failed to save image: Check backend multer configuration in serviceMulterConfig.ts and ensure the server runs under the correct user (e.g., baade)'
              : errorMessage,
        };
      }
      return {
        'success': false,
        'message': 'Failed to create service: $e',
      };
    }
  }

  // Get service by ID
  static Future<Map<String, dynamic>> getServiceById(String id) async {
    try {
      final response = await _dio.get('$baseUrl/$id');
      print('Get service by ID response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'service': Service.fromJson(response.data),
        };
      }
      return {
        'success': false,
        'message': 'Failed to load service: ${response.statusCode} - ${response.statusMessage}',
      };
    } catch (e) {
      print('Error fetching service by ID: $e');
      return {
        'success': false,
        'message': 'Error fetching service: $e',
      };
    }
  }

  // Update a service
  static Future<Map<String, dynamic>> updateService({
    required String id,
    String? name,
    String? description,
    File? image,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }
      final role = await TokenStorage.getUserRoleFromToken();
      if (role != 'admin') {
        return {
          'success': false,
          'message': 'Admin privileges required to update a service',
        };
      }

      if (name == null && description == null && image == null) {
        return {
          'success': false,
          'message': 'At least one field (name, description, or image) must be provided',
        };
      }

      final formData = FormData.fromMap({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      });

      if (image != null && await image.exists()) {
        final imagePath = image.path;
        final imageFilename = imagePath.toLowerCase().endsWith('.png') ? 'images.png' : 'images.jpg';
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            imagePath,
            filename: imageFilename,
          ),
        ));
        print('Updating service with data: ${formData.fields}, image: $imagePath, filename: $imageFilename');
      }

      final response = await _dio.put(
        '$baseUrl/$id',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('Update service response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'service': Service.fromJson(response.data),
          'message': 'Service updated successfully',
        };
      }
      return {
        'success': false,
        'message': 'Failed to update service: ${response.statusCode} - ${response.statusMessage}',
      };
    } catch (e) {
      print('Error updating service: $e');
      if (e is DioException && e.response != null) {
        print('Server response: ${e.response?.data}');
        final errorMessage = e.response?.data['message'] ?? 'Failed to update service: Server error';
        return {
          'success': false,
          'message': errorMessage.contains('ENOENT')
              ? 'Failed to save image: Check backend multer configuration in serviceMulterConfig.ts and ensure the server runs under the correct user (e.g., baade)'
              : errorMessage,
        };
      }
      return {
        'success': false,
        'message': 'Failed to update service: $e',
      };
    }
  }

  // Delete a service
  static Future<Map<String, dynamic>> deleteService(String id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication token not found',
        };
      }
      final role = await TokenStorage.getUserRoleFromToken();
      if (role != 'admin') {
        return {
          'success': false,
          'message': 'Admin privileges required to delete a service',
        };
      }

      final response = await _dio.delete(
        '$baseUrl/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('Delete service response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Service deleted successfully',
        };
      }
      return {
        'success': false,
        'message': 'Failed to delete service: ${response.statusCode} - ${response.statusMessage}',
      };
    } catch (e) {
      print('Error deleting service: $e');
      return {
        'success': false,
        'message': 'Error deleting service: $e',
      };
    }
  }
}