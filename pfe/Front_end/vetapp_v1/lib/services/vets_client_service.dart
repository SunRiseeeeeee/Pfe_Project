import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  final String? profilePicture;
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
    this.profilePicture,
    this.email,
    this.phoneNumber,
    this.address,
    this.username,
    this.isActive,
    this.lastLogin,
    this.role,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    String? profilePicture = json['profilePicture']?.toString();
    if (profilePicture != null) {
      if (profilePicture.startsWith('/data/') || profilePicture.contains('/cache/')) {
        profilePicture = null; // Skip local cache paths
      } else if (!profilePicture.startsWith('http')) {
        profilePicture = 'http://192.168.100.7:3000$profilePicture';
      }
    }
    profilePicture = profilePicture?.isEmpty == true ? null : profilePicture;

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
    debugPrint('Parsing animal: $json');
    String? picture = json['picture']?.toString() ?? json['profilePicture']?.toString();
    if (picture != null && !picture.startsWith('http')) {
      picture = 'http://192.168.1.18:3000$picture';
    }
    picture = picture?.isEmpty == true ? null : picture;

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

class VetsClientService {
  final Dio _dio;
  static const String _baseUrl = 'http://192.168.100.7:3000/api';

  VetsClientService({required Dio dio}) : _dio = dio;

  // Helper to add Authorization header
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Fetches clients with accepted appointments for a veterinarian by their ID.
  Future<List<Client>> fetchClientsForVet(String vetId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/appointments/veterinaire/$vetId/clients',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('Clients fetched: $data');
        final List<dynamic> clientsJson = data['clients'] ?? [];
        return clientsJson.map((json) => Client.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        debugPrint('No clients with accepted appointments found for vet $vetId');
        return [];
      } else {
        debugPrint('Failed to fetch clients: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      debugPrint('Dio error fetching clients: ${e.response?.data['message'] ?? e.message}');
      if (e.response?.statusCode == 404) {
        debugPrint('No clients with accepted appointments found for vet $vetId');
        return [];
      }
      throw Exception('Error fetching clients: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching clients: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Fetches animals with accepted appointments for a client and veterinarian.
  Future<List<Animal>> fetchPetsForClient(String vetId, String clientId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$_baseUrl/appointments/veterinaire/$vetId/client/$clientId/animals',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('Raw animals response: $data');
        final List<dynamic> animalsJson = data['animals'] ?? [];
        debugPrint('Animals fetched for client $clientId and vet $vetId: $animalsJson');
        return animalsJson.map((json) => Animal.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        debugPrint('No animals with accepted appointments found for client $clientId and vet $vetId');
        return [];
      } else {
        debugPrint('Failed to fetch animals: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      debugPrint('Dio error fetching animals: ${e.response?.data['message'] ?? e.message}');
      if (e.response?.statusCode == 404) {
        debugPrint('No animals with accepted appointments found for client $clientId and vet $vetId');
        return [];
      }
      throw Exception('Error fetching animals: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching animals: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}