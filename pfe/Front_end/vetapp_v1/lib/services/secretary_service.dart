import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import '../models/token_storage.dart';

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
      street: json['street'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'],
    );
  }
}

class Secretary {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? email;
  final String? phoneNumber;
  final String? username;
  final String? veterinaireId;
  final Address? address;
  final List<dynamic>? workingHours;
  final dynamic mapsLocation;
  final String? lastLogin;
  final String? specialization;

  Secretary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.email,
    this.phoneNumber,
    this.username,
    this.veterinaireId,
    this.address,
    this.workingHours,
    this.mapsLocation,
    this.lastLogin,
    this.specialization,
  });

  factory Secretary.fromJson(Map<String, dynamic> json) {
    final data = json['user'] ?? json;
    debugPrint('Parsing secretary, profilePicture: ${data['profilePicture']}');
    return Secretary(
      id: data['id'] ?? data['_id'],
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      profilePicture: data['profilePicture'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      username: data['username'],
      veterinaireId: data['veterinaireId'],
      address: data['address'] != null ? Address.fromJson(data['address']) : null,
      workingHours: data['details']?['workingHours'],
      mapsLocation: data['mapsLocation'],
      lastLogin: data['lastLogin'],
      specialization: data['details']?['specialization'],
    );
  }
}

class SecretaryService {
  static const String baseUrl = 'http://192.168.100.7:3000/api';

  // Fetch secretaries for a veterinarian
  Future<List<Secretary>> getSecretariesByVeterinaireId(String veterinaireId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/users/veterinaire/$veterinaireId/secretariens'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('API response: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded is List
          ? decoded
          : decoded['data'] is List
          ? decoded['data']
          : throw Exception('Unexpected response format: ${response.body}');
      return data.map((json) => Secretary.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch secretaries: ${response.body}');
    }
  }

  // Fetch details of a single secretary
  Future<Secretary> getSecretaryDetails(String secretaryId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/users/$secretaryId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('Secretary details response: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Secretary.fromJson(data);
    } else {
      throw Exception('Failed to fetch secretary details: ${response.body}');
    }
  }

  // Create a new secretary
  Future<Secretary> createSecretary(String veterinaireId, Map<String, dynamic> secretaryData, [File? image]) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/signup/secretaire/$veterinaireId'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    // Add text fields
    secretaryData.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Add image file if provided
    if (image != null) {
      final exists = await image.exists();
      final length = exists ? await image.length() : 0;
      final filename = image.path.split('/').last;
      final extension = filename.split('.').last.toLowerCase();
      debugPrint('Uploading image: ${image.path}, Exists: $exists, Size: $length bytes, Filename: $filename, Extension: $extension');
      if (!exists) {
        throw Exception('Image file does not exist: ${image.path}');
      }
      // Set MIME type based on extension
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'image/jpeg'; // Fallback
      }
      final file = await http.MultipartFile.fromPath(
        'profilePicture',
        image.path,
        contentType: MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
      );
      request.files.add(file);
      debugPrint('Multipart fields: ${request.fields}, Files: ${request.files.length}, MIME: $mimeType');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    debugPrint('Create secretary response: $responseBody');

    if (response.statusCode == 201) {
      final data = jsonDecode(responseBody);
      return Secretary.fromJson(data['user']);
    } else {
      throw Exception('Failed to create secretary: $responseBody');
    }
  }

  // Delete a secretary
  Future<void> deleteSecretary(String secretaryId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/users/$secretaryId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete secretary: ${response.body}');
    }
  }
}