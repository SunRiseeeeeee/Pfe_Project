import 'package:dio/dio.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class AppointmentService {
  final Dio _dio;

  AppointmentService({required Dio dio}) : _dio = dio;

  // Helper for authorization header
  Future<Map<String, String>> _authHeader() async {
    final token = await TokenStorage.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // Helper for error handling
  Map<String, dynamic> _handleError(DioException e) {
    return {
      'success': false,
      'message': e.response?.data['message'] ??
          e.response?.data['error'] ??
          e.message ??
          'An error occurred. Please try again.',
      'statusCode': e.response?.statusCode,
    };
  }

  // Create appointment (client only, backend gets client from token)
  Future<Map<String, dynamic>> createAppointment({
    String? veterinaireId,
    required DateTime date,
    required String animalType,
    required String type,
    List<String>? services,
  }) async {
    try {
      final response = await _dio.post(
        '/appointments',
        data: {
          if (veterinaireId != null) 'veterinaireId': veterinaireId,
          'date': date.toUtc().toIso8601String(),
          'animalType': animalType,
          'type': type.toLowerCase(),
          'services': services ?? [],
        },
        options: Options(
          headers: await _authHeader(),
        ),
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


  // Get appointment by ID
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

  // Get all appointments for a client (by clientId)
  Future<Map<String, dynamic>> getAppointmentsByClient(String clientId) async {
    try {
      final response = await _dio.get(
        '/appointments/client/$clientId',
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

  // Get all appointments for a veterinarian (by vetId)
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

  // Update appointment (only allowed fields)
  Future<Map<String, dynamic>> updateAppointment(
      String id,
      Map<String, dynamic> updateData,
      ) async {
    try {
      // Remove protected fields if present
      final filteredData = Map<String, dynamic>.from(updateData)
        ..removeWhere((key, _) =>
            ['clientId', 'veterinaireId', 'createdAt', 'updatedAt'].contains(key));
      final response = await _dio.patch(
        '/appointments/$id',
        data: filteredData,
        options: Options(headers: await _authHeader()),
      );
      return {
        'success': true,
        'data': response.data,
        'message': response.data['message'] ?? 'Appointment updated successfully',
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Delete appointment
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

  // Accept appointment
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

  // Reject appointment
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
