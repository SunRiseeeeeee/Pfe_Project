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

    // Handle specific backend conflict error
    if (e.response?.statusCode == 400 && message.contains('sorry you need to wait 20 minutes to take another appointment')) {
      return {
        'success': false,
        'message': message,
        'statusCode': 400,
      };
    }

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
    print('Creating appointment with Veterinarian ID: $veterinaireId');
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
        '/appointments/veterinaire/history/$vetId',
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

  /// Get the times of accepted appointments for a specific veterinarian
  Future<Map<String, dynamic>> getAcceptedAppointmentTimes(String vetId) async {
    try {
      final response = await _dio.get(
        '/appointments/veterinaire/history/$vetId',
        options: Options(headers: await _authHeader()),
      );

      // Extract appointments
      final appointments = List<Map<String, dynamic>>.from(response.data['appointments'] ?? []);

      // Filter for accepted appointments and extract dates
      final acceptedTimes = appointments
          .where((appt) => appt['status']?.toLowerCase() == 'accepted')
          .map((appt) {
        try {
          return DateTime.parse(appt['date']).toLocal();
        } catch (e) {
          print('Error parsing date for appointment ${appt['_id']}: $e');
          return null;
        }
      })
          .where((date) => date != null)
          .cast<DateTime>()
          .toList();

      return {
        'success': true,
        'data': acceptedTimes,
        'message': acceptedTimes.isEmpty
            ? 'No accepted appointments found'
            : 'Accepted appointment times retrieved successfully',
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
      final filteredData = Map<String, dynamic>.from(updateData)
        ..removeWhere((key, _) => [
          'clientId',
          'veterinaireId',
          'createdAt',
          'updatedAt',
          '_id',
          '__v',
        ].contains(key));

      final response = await _dio.put(
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