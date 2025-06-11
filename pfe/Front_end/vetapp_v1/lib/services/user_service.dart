import 'package:dio/dio.dart';
import '../models/token_storage.dart';
import 'auth_service.dart';

class UserService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.16:3000/api/users',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final String _authBaseUrl = 'http://192.168.1.16:3000/api/auth';
  final AuthService _authService = AuthService();

  UserService() {
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
          // Attempt to refresh token
          final refreshResult = await _authService.refreshToken();
          if (refreshResult["success"]) {
            // Retry the original request with the new token
            final options = e.requestOptions;
            final newToken = refreshResult["accessToken"];
            options.headers['Authorization'] = 'Bearer $newToken';
            try {
              final retryResponse = await _dio.request(
                options.path,
                data: options.data,
                queryParameters: options.queryParameters,
                options: Options(
                  method: options.method,
                  headers: options.headers,
                ),
              );
              return handler.resolve(retryResponse);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
            // Refresh failed, propagate the error
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?> _getUserId() async {
    return await TokenStorage.getUserId();
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await _dio.get('/$userId');
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch user: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to fetch user: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> updateUser(Map<String, dynamic> updatedData) async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User ID not found');
    }

    try {
      print('Sending update for user $userId with data: $updatedData');
      final response = await _dio.put(
        '/$userId',
        data: updatedData,
        options: Options(headers: {
          'Content-Type': 'application/json',
        }),
      );
      print('Update successful: ${response.data}');
    } on DioException catch (e) {
      print('Update failed: ${e.response?.data}');
      throw Exception('Failed to update user: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> deleteUser() async {
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User ID not found');
    }

    try {
      final response = await _dio.delete('/$userId');
      print('User deleted: ${response.data}');
    } on DioException catch (e) {
      print('Delete failed: ${e.response?.data}');
      throw Exception('Failed to delete user: ${e.response?.data['message'] ?? e.message}');
    }
  }

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