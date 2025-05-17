
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/token_storage.dart';
import '../services/client_service.dart'; // Import for Animal

// Sub-models
class Vaccination {
  final String name;
  final DateTime date;
  final DateTime? nextDueDate;
  final String? notes;

  Vaccination({
    required this.name,
    required this.date,
    this.nextDueDate,
    this.notes,
  });

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      name: json['name']?.toString() ?? '',
      date: DateTime.parse(json['date']?.toString() ?? DateTime.now().toIso8601String()),
      nextDueDate: json['nextDueDate'] != null ? DateTime.tryParse(json['nextDueDate'].toString()) : null,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'date': date.toIso8601String(),
      'nextDueDate': nextDueDate?.toIso8601String(),
      'notes': notes,
    };
  }
}

class Treatment {
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? dosage;
  final String? frequency;
  final String? notes;

  Treatment({
    required this.name,
    required this.startDate,
    this.endDate,
    this.dosage,
    this.frequency,
    this.notes,
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      name: json['name']?.toString() ?? '',
      startDate: DateTime.parse(json['startDate']?.toString() ?? DateTime.now().toIso8601String()),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      dosage: json['dosage']?.toString(),
      frequency: json['frequency']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
    };
  }
}

class Examination {
  final DateTime date;
  final String type;
  final String? results;
  final String? notes;

  Examination({
    required this.date,
    required this.type,
    this.results,
    this.notes,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    return Examination(
      date: DateTime.parse(json['date']?.toString() ?? DateTime.now().toIso8601String()),
      type: json['type']?.toString() ?? '',
      results: json['results']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type,
      'results': results,
      'notes': notes,
    };
  }
}

class AppointmentRecord {
  final DateTime appointmentDate;
  final String? diagnosis;

  AppointmentRecord({
    required this.appointmentDate,
    this.diagnosis,
  });

  factory AppointmentRecord.fromJson(Map<String, dynamic> json) {
    return AppointmentRecord(
      appointmentDate: DateTime.parse(json['appointmentDate']?.toString() ?? DateTime.now().toIso8601String()),
      diagnosis: json['diagnosis']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointmentDate': appointmentDate.toIso8601String(),
      'diagnosis': diagnosis,
    };
  }
}

class AnimalFiche {
  final String id;
  final String animalId;
  final String veterinarianId;
  final String clientId;
  final DateTime creationDate;
  final DateTime lastUpdate;
  final double? weight;
  final double? height;
  final double? temperature;
  final List<Vaccination>? vaccinations;
  final List<Treatment>? treatments;
  final List<Examination>? examinations;
  final List<AppointmentRecord>? appointments;
  final List<String>? allergies;
  final String? diet;
  final String? behaviorNotes;
  final String? medicalHistory;
  final DateTime? recommendedNextVisit;
  final String? generalNotes;

  AnimalFiche({
    required this.id,
    required this.animalId,
    required this.veterinarianId,
    required this.clientId,
    required this.creationDate,
    required this.lastUpdate,
    this.weight,
    this.height,
    this.temperature,
    this.vaccinations,
    this.treatments,
    this.examinations,
    this.appointments,
    this.allergies,
    this.diet,
    this.behaviorNotes,
    this.medicalHistory,
    this.recommendedNextVisit,
    this.generalNotes,
  });

  factory AnimalFiche.fromJson(Map<String, dynamic> json) {
    return AnimalFiche(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      animalId: json['animal'] is Map ? json['animal']['_id']?.toString() ?? '' : json['animal']?.toString() ?? '',
      veterinarianId: json['veterinarian'] is Map ? json['veterinarian']['_id']?.toString() ?? '' : json['veterinarian']?.toString() ?? '',
      clientId: json['client'] is Map ? json['client']['_id']?.toString() ?? '' : json['client']?.toString() ?? '',
      creationDate: DateTime.parse(json['creationDate']?.toString() ?? DateTime.now().toIso8601String()),
      lastUpdate: DateTime.parse(json['lastUpdate']?.toString() ?? DateTime.now().toIso8601String()),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      vaccinations: (json['vaccinations'] as List<dynamic>?)?.map((v) => Vaccination.fromJson(v)).toList(),
      treatments: (json['treatments'] as List<dynamic>?)?.map((t) => Treatment.fromJson(t)).toList(),
      examinations: (json['examinations'] as List<dynamic>?)?.map((e) => Examination.fromJson(e)).toList(),
      appointments: (json['appointments'] as List<dynamic>?)?.map((a) => AppointmentRecord.fromJson(a)).toList(),
      allergies: (json['allergies'] as List<dynamic>?)?.cast<String>(),
      diet: json['diet']?.toString(),
      behaviorNotes: json['behaviorNotes']?.toString(),
      medicalHistory: json['medicalHistory']?.toString(),
      recommendedNextVisit: json['recommendedNextVisit'] != null ? DateTime.tryParse(json['recommendedNextVisit'].toString()) : null,
      generalNotes: json['generalNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'animal': animalId,
      'veterinarian': veterinarianId,
      'client': clientId,
      'creationDate': creationDate.toIso8601String(),
      'lastUpdate': lastUpdate.toIso8601String(),
      'weight': weight,
      'height': height,
      'temperature': temperature,
      'vaccinations': vaccinations?.map((v) => v.toJson()).toList(),
      'treatments': treatments?.map((t) => t.toJson()).toList(),
      'examinations': examinations?.map((e) => e.toJson()).toList(),
      'appointments': appointments?.map((a) => a.toJson()).toList(),
      'allergies': allergies,
      'diet': diet,
      'behaviorNotes': behaviorNotes,
      'medicalHistory': medicalHistory,
      'recommendedNextVisit': recommendedNextVisit?.toIso8601String(),
      'generalNotes': generalNotes,
    };
  }
}

class PetFileService {
  final Dio _dio;
  static const String _baseUrl = 'http://192.168.1.18:3000/api/animal-fiche';

  PetFileService({required Dio dio}) : _dio = dio;

  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetches an AnimalFiche by animal ID.
  Future<AnimalFiche?> fetchFicheByAnimalId(String animalId) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Fetching fiche for animalId: $animalId');
      final response = await _dio.get(
        '$_baseUrl/animal/$animalId/fiche',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('fetchFicheByAnimalId response: ${response.data}');
        return AnimalFiche.fromJson(response.data);
      }
      debugPrint('fetchFicheByAnimalId failed: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      debugPrint('DioException in fetchFicheByAnimalId: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        debugPrint('No fiche found for animalId: $animalId');
        return null; // No fiche found
      }
      throw Exception('Error fetching fiche by animalId: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error in fetchFicheByAnimalId: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Fetches an AnimalFiche by fiche ID.
  Future<AnimalFiche?> fetchFicheById(String ficheId) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Fetching fiche for ficheId: $ficheId');
      final response = await _dio.get(
        '$_baseUrl/$ficheId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('fetchFicheById response: ${response.data}');
        return AnimalFiche.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('DioException in fetchFicheById: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        return null; // No fiche found
      }
      throw Exception('Error fetching fiche: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error in fetchFicheById: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Creates a new AnimalFiche.
  Future<AnimalFiche> createFiche({
    required String animalId,
    required String veterinarianId,
    required String clientId,
    double? weight,
    double? height,
    double? temperature,
    List<Vaccination>? vaccinations,
    List<Treatment>? treatments,
    List<Examination>? examinations,
    List<AppointmentRecord>? appointments,
    List<String>? allergies,
    String? diet,
    String? behaviorNotes,
    String? medicalHistory,
    DateTime? recommendedNextVisit,
    String? generalNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Creating fiche with animalId: $animalId');
      final response = await _dio.post(
        _baseUrl,
        data: {
          'animal': animalId,
          'veterinarian': veterinarianId,
          'client': clientId,
          'weight': weight,
          'height': height,
          'temperature': temperature,
          'vaccinations': vaccinations?.map((v) => v.toJson()).toList(),
          'treatments': treatments?.map((t) => t.toJson()).toList(),
          'examinations': examinations?.map((e) => e.toJson()).toList(),
          'appointments': appointments?.map((a) => a.toJson()).toList(),
          'allergies': allergies,
          'diet': diet,
          'behaviorNotes': behaviorNotes,
          'medicalHistory': medicalHistory,
          'recommendedNextVisit': recommendedNextVisit?.toIso8601String(),
          'generalNotes': generalNotes,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 201) {
        debugPrint('createFiche response: ${response.data}');
        if (response.data is Map<String, dynamic>) {
          return AnimalFiche.fromJson(response.data);
        } else {
          throw Exception('Unexpected response format: ${response.data.runtimeType}');
        }
      }
      throw Exception('Failed to create fiche: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException in createFiche: ${e.response?.data}');
      final errorMessage = e.response?.data is Map
          ? e.response?.data['message'] ?? e.message
          : e.response?.data?.toString() ?? e.message;
      throw Exception('Error creating fiche: $errorMessage');
    } catch (e) {
      debugPrint('Unexpected error in createFiche: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Updates an existing AnimalFiche.
  Future<AnimalFiche> updateFiche({
    required String ficheId,
    double? weight,
    double? height,
    double? temperature,
    List<Vaccination>? vaccinations,
    List<Treatment>? treatments,
    List<Examination>? examinations,
    List<AppointmentRecord>? appointments,
    List<String>? allergies,
    String? diet,
    String? behaviorNotes,
    String? medicalHistory,
    DateTime? recommendedNextVisit,
    String? generalNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Updating fiche with ficheId: $ficheId');
      final response = await _dio.put(
        '$_baseUrl/$ficheId',
        data: {
          'weight': weight,
          'height': height,
          'temperature': temperature,
          'vaccinations': vaccinations?.map((v) => v.toJson()).toList(),
          'treatments': treatments?.map((t) => t.toJson()).toList(),
          'examinations': examinations?.map((e) => e.toJson()).toList(),
          'appointments': appointments?.map((a) => a.toJson()).toList(),
          'allergies': allergies,
          'diet': diet,
          'behaviorNotes': behaviorNotes,
          'medicalHistory': medicalHistory,
          'recommendedNextVisit': recommendedNextVisit?.toIso8601String(),
          'generalNotes': generalNotes,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('updateFiche response: ${response.data}');
        if (response.data is Map<String, dynamic>) {
          return AnimalFiche.fromJson(response.data);
        } else {
          throw Exception('Unexpected response format: ${response.data.runtimeType}');
        }
      }
      throw Exception('Failed to update fiche: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException in updateFiche: ${e.response?.data}');
      final errorMessage = e.response?.data is Map
          ? e.response?.data['message'] ?? e.message
          : e.response?.data?.toString() ?? e.message;
      throw Exception('Error updating fiche: $errorMessage');
    } catch (e) {
      debugPrint('Unexpected error in updateFiche: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Deletes an AnimalFiche by fiche ID.
  Future<void> deleteFiche(String ficheId) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Deleting fiche with ficheId: $ficheId');
      final response = await _dio.delete(
        '$_baseUrl/$ficheId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('deleteFiche response: ${response.data}');
        return;
      }
      throw Exception('Failed to delete fiche: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException in deleteFiche: ${e.response?.data}');
      final errorMessage = e.response?.data is Map
          ? e.response?.data['message'] ?? e.message
          : e.response?.data?.toString() ?? e.message;
      throw Exception('Error deleting fiche: $errorMessage');
    } catch (e) {
      debugPrint('Unexpected error in deleteFiche: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Adds an appointment to an AnimalFiche.
  Future<AnimalFiche> addAppointment({
    required String ficheId,
    required DateTime appointmentDate,
    String? diagnosis,
  }) async {
    try {
      final headers = await _getHeaders();
      debugPrint('Adding appointment to ficheId: $ficheId');
      final response = await _dio.post(
        '$_baseUrl/$ficheId/appointments',
        data: {
          'appointmentDate': appointmentDate.toIso8601String(),
          'diagnosis': diagnosis,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('addAppointment response: ${response.data}');
        if (response.data is Map<String, dynamic>) {
          return AnimalFiche.fromJson(response.data);
        } else {
          throw Exception('Unexpected response format: ${response.data.runtimeType}');
        }
      }
      throw Exception('Failed to add appointment: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException in addAppointment: ${e.response?.data}');
      final errorMessage = e.response?.data is Map
          ? e.response?.data['message'] ?? e.message
          : e.response?.data?.toString() ?? e.message;
      throw Exception('Error adding appointment: $errorMessage');
    } catch (e) {
      debugPrint('Unexpected error in addAppointment: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}
