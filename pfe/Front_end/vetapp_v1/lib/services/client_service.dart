import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../models/token_storage.dart';

// Models
class Address {
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  Address({
    this.street,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      postalCode: json['postalCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
    };
  }
}

class Client {
  final String id;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String? email;
  final String? phoneNumber;
  final Address? address;
  final String? username;
  final bool? isActive;
  final DateTime? lastLogin;
  final String? role;

  Client({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    this.email,
    this.phoneNumber,
    this.address,
    this.username,
    this.isActive,
    this.lastLogin,
    this.role,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    String profilePicture = json['profilePicture']?.toString() ?? '';
    // Preserve local file paths; only normalize if it's a relative server path
    if (profilePicture.isNotEmpty && !profilePicture.startsWith('http') && !profilePicture.startsWith('/data/')) {
      profilePicture = 'http://192.168.1.18:3000$profilePicture';
    }
    profilePicture = profilePicture.isEmpty ? '/data/placeholder.png' : profilePicture;

    // Handle isActive as bool or String
    bool? isActive;
    if (json['isActive'] != null) {
      if (json['isActive'] is bool) {
        isActive = json['isActive'] as bool;
      } else if (json['isActive'] is String) {
        isActive = json['isActive'].toLowerCase() == 'true';
      }
    }

    return Client(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'Unknown',
      lastName: json['lastName']?.toString() ?? 'Client',
      profilePicture: profilePicture,
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      username: json['username']?.toString(),
      isActive: isActive,
      lastLogin: json['lastLogin'] != null ? DateTime.tryParse(json['lastLogin'].toString()) : null,
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address?.toJson(),
      'username': username,
      'isActive': isActive,
      'lastLogin': lastLogin?.toIso8601String(),
      'role': role,
    };
  }
}

class Animal {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final String? picture;
  final String? gender;
  final DateTime? birthdate;

  Animal({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.picture,
    this.gender,
    this.birthdate,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    String? picture = json['picture']?.toString() ?? json['profilePicture']?.toString();
    if (picture != null && !picture.startsWith('http')) {
      picture = 'http://192.168.1.18:3000$picture';
    }
    return Animal(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Pet',
      species: json['species']?.toString() ?? 'N/A',
      breed: json['breed']?.toString(),
      picture: picture,
      gender: json['gender']?.toString(),
      birthdate: json['birthDate'] != null ? DateTime.tryParse(json['birthDate'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'picture': picture,
      'gender': gender,
      'birthDate': birthdate?.toIso8601String(),
    };
  }
}

class Appointment {
  final String id;
  final Client client;
  final Veterinarian veterinarian;
  final Animal animal;
  final DateTime date;
  final String type;
  final String status;
  final List<String>? services;
  final String? caseDescription;

  Appointment({
    required this.id,
    required this.client,
    required this.veterinarian,
    required this.animal,
    required this.date,
    required this.type,
    required this.status,
    this.services,
    this.caseDescription,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      client: Client.fromJson(json['clientId'] ?? json['client'] ?? {}),
      veterinarian: Veterinarian.fromJson(
        json['veterinaire'] ?? (json['veterinaireId'] is Map ? json['veterinaireId'] : {'id': json['veterinaireId']}),
      ),
      animal: Animal.fromJson(json['animalId'] ?? {}),
      date: DateTime.parse(json['date']?.toString() ?? DateTime.now().toIso8601String()),
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      services: (json['services'] as List<dynamic>?)?.cast<String>(),
      caseDescription: json['caseDescription']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'client': client.toJson(),
      'veterinaire': veterinarian.toJson(),
      'animal': animal.toJson(),
      'date': date.toIso8601String(),
      'type': type,
      'status': status,
      'services': services,
      'caseDescription': caseDescription,
    };
  }
}

class Veterinarian {
  final String id;
  final String firstName;
  final String lastName;

  Veterinarian({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  factory Veterinarian.fromJson(Map<String, dynamic> json) {
    return Veterinarian(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'Unknown',
      lastName: json['lastName']?.toString() ?? 'Vet',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

class ClientService {
  final Dio _dio;
  static const String _baseUrl = 'http://192.168.1.18:3000/api/appointments';

  ClientService({required Dio dio}) : _dio = dio;

  // Helper to add Authorization header
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Fetches all clients associated with a veterinarian by their ID.
  Future<List<Client>> fetchClientsForVeterinarian(String vetId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/veterinaire/history/$vetId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> appointments = data['appointments'] ?? [];
        final Map<String, Client> uniqueClients = {};
        for (var appt in appointments) {
          final clientJson = appt['clientId'] as Map<String, dynamic>? ?? appt['client'];
          if (clientJson != null) {
            final client = Client.fromJson(clientJson);
            uniqueClients[client.id] = client;
          }
        }
        return uniqueClients.values.toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data['message'] == 'client non trouvé') {
        return [];
      }
      throw Exception('Error fetching clients: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Fetches clients with accepted appointments for a veterinarian by their ID.
  Future<List<Client>> fetchClientsWithAcceptedAppointments(String vetId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/veterinaire/$vetId/clients',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final List<dynamic> clientsJson = response.data;
        return clientsJson.map((json) => Client.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data['message'] == 'client non trouvé') {
        return [];
      }
      throw Exception('Error fetching clients: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Fetches animals of a client for a veterinarian by their IDs.
  Future<List<Animal>> fetchClientAnimals(String vetId, String clientId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/veterinaire/$vetId/client/$clientId/animals',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('fetchClientAnimals response: ${response.data}');
        List<dynamic> animalsJson;
        if (response.data is List) {
          animalsJson = response.data;
        } else if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          animalsJson = data['animals'] ?? data['data'] ?? [];
        } else {
          animalsJson = [];
        }
        return animalsJson.map((json) => Animal.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      debugPrint('DioException in fetchClientAnimals: ${e.response?.data}');
      if (e.response?.statusCode == 404 && e.response?.data['message'] == 'client non trouvé') {
        return [];
      }
      throw Exception('Error fetching animals: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error in fetchClientAnimals: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Fetches all appointments for a veterinarian by their ID.
  Future<List<Appointment>> fetchAppointmentsForVeterinarian(String vetId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/veterinaire/history/$vetId',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> appointmentsJson = data['appointments'] ?? [];
        return appointmentsJson.map((json) => Appointment.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && e.response?.data['message'] == 'client non trouvé') {
        return [];
      }
      throw Exception('Error fetching appointments: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Deletes an appointment by its ID.
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.delete(
        '$_baseUrl/$appointmentId',
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete appointment: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error deleting appointment: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Accepts an appointment by its ID.
  Future<void> acceptAppointment(String appointmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.put(
        '$_baseUrl/$appointmentId/accept',
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept appointment: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error accepting appointment: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Rejects an appointment by its ID.
  Future<void> rejectAppointment(String appointmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.put(
        '$_baseUrl/$appointmentId/reject',
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to reject appointment: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error rejecting appointment: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}