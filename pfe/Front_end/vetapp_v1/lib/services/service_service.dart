import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../models/service.dart';
import '../models/token_storage.dart';
import 'auth_service.dart';

class ServiceService {
  static const String baseUrl = 'http://192.168.1.16:3000/api/services';
  static final Dio _dio = Dio();

  static void _initializeDio() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print("REQUEST[${options.method}] => PATH: ${options.path}, DATA: ${options.data}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print("RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}, DATA: ${response.data}");
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print("ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}, MESSAGE: ${e.response?.data['message'] ?? e.message}");
        if (e.response?.statusCode == 401) {
          final authService = AuthService();
          final refreshResult = await authService.refreshToken();
          if (refreshResult["success"]) {
            final newToken = refreshResult["accessToken"];
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final retryResponse = await _dio.request(
                e.requestOptions.path,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                ),
              );
              return handler.resolve(retryResponse);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  // Call initialize in a static constructor
  static void init() {
    _initializeDio();
  }

  // Fetch all service names
  static Future<List<String>> fetchServiceNames() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await _dio.get(
        baseUrl,
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
      print('Fetch service names response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => json['name'].toString()).toList();
      }
      throw Exception('Failed to load service names: ${response.statusCode} - ${response.statusMessage}');
    } catch (e) {
      print('Error fetching service names: $e');
      throw Exception('Error fetching service names: $e');
    }
  }

  // Fetch all services
  static Future<Map<String, dynamic>> getAllServices() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await _dio.get(
        baseUrl,
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
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
        final imageFilename = path.basename(image.path);
        final extension = path.extension(imageFilename).toLowerCase().replaceFirst('.', '');
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          return {
            'success': false,
            'message': 'Only JPG, JPEG, or PNG images are allowed',
          };
        }
        final fileSize = await image.length();
        if (fileSize > 5 * 1024 * 1024) {
          return {
            'success': false,
            'message': 'Image file size must be less than 5MB',
          };
        }
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            image.path,
            filename: imageFilename,
            contentType: DioMediaType('image', extension),
          ),
        ));
        print('Creating service with data: ${formData.fields}, image: ${image.path}, filename: $imageFilename, size: ${fileSize ~/ 1024}KB');
      }

      final response = await _dio.post(
        baseUrl,
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
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
        if (errorMessage.contains('ENOENT') || errorMessage.contains('no such file or directory')) {
          print('Retrying service creation without image due to server directory error');
          // Fallback: Retry without image
          final retryResult = await createService(name: name, description: description);
          if (retryResult['success']) {
            return {
              'success': true,
              'service': retryResult['service'],
              'message': 'Service created without image due to server directory issue. Ensure the backend upload directory exists at: src/services/uploads/services relative to the project root (C:\\Users\\baade\\Documents\\GitHub\\Pfe_Project\\pfe\\Backend\\).',
            };
          }
        }
        return {
          'success': false,
          'message': errorMessage.contains('Seuls les fichiers image sont autorisés')
              ? 'Only image files are allowed by the server'
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
      final token = await TokenStorage.getToken();
      final response = await _dio.get(
        '$baseUrl/$id',
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );
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
        final imageFilename = path.basename(image.path);
        final extension = path.extension(imageFilename).toLowerCase().replaceFirst('.', '');
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          return {
            'success': false,
            'message': 'Only JPG, JPEG, or PNG images are allowed',
          };
        }
        final fileSize = await image.length();
        if (fileSize > 5 * 1024 * 1024) {
          return {
            'success': false,
            'message': 'Image file size must be less than 5MB',
          };
        }
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            image.path,
            filename: imageFilename,
            contentType: DioMediaType('image', extension),
          ),
        ));
        print('Updating service with data: ${formData.fields}, image: ${image.path}, filename: $imageFilename, size: ${fileSize ~/ 1024}KB');
      }

      final response = await _dio.put(
        '$baseUrl/$id',
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
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
        if (errorMessage.contains('ENOENT') || errorMessage.contains('no such file or directory')) {
          print('Retrying service update without image due to server directory error');
          // Fallback: Retry without image
          final retryResult = await updateService(id: id, name: name, description: description);
          if (retryResult['success']) {
            return {
              'success': true,
              'service': retryResult['service'],
              'message': 'Service updated without image due to server directory issue. Ensure the backend upload directory exists at: src/services/uploads/services relative to the project root (C:\\Users\\baade\\Documents\\GitHub\\Pfe_Project\\pfe\\Backend\\).',
            };
          }
        }
        return {
          'success': false,
          'message': errorMessage.contains('Seuls les fichiers image sont autorisés')
              ? 'Only image files are allowed by the server'
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