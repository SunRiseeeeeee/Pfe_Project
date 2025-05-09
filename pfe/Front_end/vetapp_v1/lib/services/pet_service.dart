import 'dart:io';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class PetService {
  final Dio dio;

  PetService({required Dio dio})
      : dio = Dio(
    BaseOptions(baseUrl: 'http://192.168.1.18:3000/api'), // ✅ Correct base URL
  );

  Future<String?> _getToken() async => await TokenStorage.getToken();

  Future<String> _getUserId(String token) {
    final decoded = JwtDecoder.decode(token);
    final userId = decoded['id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('User ID missing in token');
    }
    return Future.value(userId);
  }

  /// 🔹 Get all pets for the user
  Future<List<Map<String, dynamic>>> getUserPets() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = await _getUserId(token);
    final response = await dio.get(
      '/animals/$userId/animals',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    } else {
      throw Exception('Failed to load pets: ${response.statusCode}');
    }
  }

  /// 🔹 Create a new pet
  Future<Map<String, dynamic>> createPet({
    required String name,
    required String species,
    required String breed,
    String? gender,
    String? birthDate,
    File? imageFile,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = await _getUserId(token);

    FormData formData = FormData.fromMap({
      'name': name,
      'species': species,
      'breed': breed,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate,
      if (imageFile != null)
        'image': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
    });

    final response = await dio.post(
      '/animals/$userId/animals',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data);
    } else {
      throw Exception('Failed to create pet: ${response.data}');
    }
  }

  /// 🔹 Update an existing pet
  Future<Map<String, dynamic>> updatePet({
    required String petId,
    required String name,
    required String species,
    required String breed,
    String? gender,
    String? birthDate,
    File? imageFile,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = await _getUserId(token);

    FormData formData = FormData.fromMap({
      'name': name,
      'species': species,
      'breed': breed,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate,
      if (imageFile != null)
        'image': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
    });

    final response = await dio.put(
      '/animals/$userId/animals/$petId',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data);
    } else {
      throw Exception('Failed to update pet: ${response.data}');
    }
  }

  /// 🔹 Delete a pet
  Future<void> deletePet(String petId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = await _getUserId(token);

    final response = await dio.delete(
      '/animals/$userId/animals/$petId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete pet: ${response.data}');
    }
  }
}
