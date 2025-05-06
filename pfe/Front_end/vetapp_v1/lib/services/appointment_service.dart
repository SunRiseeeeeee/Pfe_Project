import 'package:dio/dio.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class AppointmentService {
  final Dio _dio;

  AppointmentService({required Dio dio}) : _dio = dio;

  /// Helper to get Authorization header
  Future<Map<String, String>> _authHeader() async {
    final token = await TokenStorage.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Handles Dio errors in a consistent way
  Map<String, dynamic> _handleError(DioException e) {
    final data = e.response?.data;
    final message = data is Map<String, dynamic>
        ? data['message'] ?? data['error']
        : e.message;

    return {
      'success': false,
      'message': message ?? 'An error occurred. Please try again.',
      'statusCode': e.response?.statusCode,
    };
  }

  /// Create a new appointment
  Future<Map<String, dynamic>> createAppointment({
    String? veterinaireId,
    required DateTime date,
    required String animalId,
    required String type,
    List<String>? services,
    String? caseDescription,
  }) async {
    print('Creating appointment with Veterinarian ID: $veterinaireId'); // Debug line
    try {
      final response = await _dio.post(
        '/appointments',
        data: {
          if (veterinaireId != null) 'veterinaireId': veterinaireId,
          'date': date.toUtc().toIso8601String(),
          'animalId': animalId,
          'type': type.toLowerCase(),
          'services': services ?? [],
          if (caseDescription != null) 'caseDescription': caseDescription,
        },
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointment'] ?? response.data,
        'message': response.data['message'] ?? 'Appointment created successfully',
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Get a single appointment by ID
  Future<Map<String, dynamic>> getAppointment(String id) async {
    try {
      final response = await _dio.get(
        '/appointments/$id',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointment'] ?? response.data,
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Get appointments for a specific client
  Future<Map<String, dynamic>> getAppointmentsByClient(String clientId) async {
    try {
      final response = await _dio.get(
        '/appointments/client/history/$clientId',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointments'] ?? response.data,
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Get appointments for a specific veterinarian
  Future<Map<String, dynamic>> getAppointmentsByVeterinaire(String vetId) async {
    try {
      final response = await _dio.get(
        '/appointments/veterinaire/$vetId',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointments'] ?? response.data,
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Update appointment with allowed fields only
  Future<Map<String, dynamic>> updateAppointment(
      String id,
      Map<String, dynamic> updateData,
      ) async {
    try {
      // Filter out non-updatable fields
      final filteredData = Map<String, dynamic>.from(updateData)
        ..removeWhere((key, _) => [
          'clientId',
          'veterinaireId',
          'createdAt',
          'updatedAt',
          '_id',
          '__v',
        ].contains(key));

      final token = await TokenStorage.getToken();  // Get token from SharedPreferences
      if (token == null) {
        throw Exception("Token is missing. User might not be logged in.");
      }

      final response = await _dio.put(
        '/appointments/$id',  // Make sure this matches your backend route
        data: filteredData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return {
        'success': true,
        'data': response.data,
        'message': response.data['message'] ?? 'Appointment updated successfully',
      };
    } on DioException catch (e) {
      return _handleError(e);  // You already have this to handle Dio errors
    }
  }



  /// Delete appointment
  Future<Map<String, dynamic>> deleteAppointment(String id) async {
    try {
      final response = await _dio.delete(
        '/appointments/$id',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Appointment deleted successfully',
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Accept appointment
  Future<Map<String, dynamic>> acceptAppointment(String id) async {
    try {
      final response = await _dio.put(
        '/appointments/$id/accept',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointment'] ?? response.data,
        'message': response.data['message'] ?? 'Appointment accepted',
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Reject appointment
  Future<Map<String, dynamic>> rejectAppointment(String id) async {
    try {
      final response = await _dio.put(
        '/appointments/$id/reject',
        options: Options(headers: await _authHeader()),
      );

      return {
        'success': true,
        'data': response.data['appointment'] ?? response.data,
        'message': response.data['message'] ?? 'Appointment rejected',
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
}
