import 'dart:io';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class PetService {
  final Dio dio;
  static const String baseUrl = 'http://192.168.1.16:3000'; // Backend IP

  PetService({required this.dio});

  Future<String?> _getToken() async => await TokenStorage.getToken();

  String _getUserId(String token) {
    final decoded = JwtDecoder.decode(token);
    final userId = decoded['id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('User ID missing in token');
    }
    return userId;
  }

  Future<List<Map<String, dynamic>>> getUserPets() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = _getUserId(token);
    final response = await dio.get(
      '/animals/$userId/animals',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    print('getUserPets response: ${response.data}');

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(response.data);
      for (var pet in pets) {
        final imagePath = pet['picture'];
        print('Processing pet ${pet['name']}: picture=$imagePath');
        if (imagePath != null && imagePath.toString().isNotEmpty) {
          pet['imageUrl'] = imagePath.toString().replaceAll(
            RegExp(r'http://(localhost|192\.168\.1\.18):3000'),
            baseUrl,
          );
        } else {
          pet['imageUrl'] = null;
          print('No picture for pet ${pet['name']}');
        }
      }
      return pets;
    } else {
      throw Exception('Failed to load pets: ${response.statusCode}');
    }
  }

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

    final userId = _getUserId(token);

    final Map<String, dynamic> formDataMap = {
      'name': name,
      'species': species,
      'breed': breed,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate,
    };

    if (imageFile != null) {
      print('Image file: ${imageFile.path}, size: ${imageFile.lengthSync() / 1024 / 1024} MB');
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      );
      formDataMap['image'] = multipartFile;
    } else {
      print('No image file provided');
    }

    final formData = FormData.fromMap(formDataMap);

    print('Creating pet with data: name=$name, species=$species, breed=$breed, imageFile=${imageFile?.path}');

    try {
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

      print('createPet response: ${response.data}');

      if (response.statusCode == 201) {
        final pet = Map<String, dynamic>.from(response.data);
        final imagePath = pet['picture'];
        print('Pet ${pet['name']}: picture=$imagePath');
        if (imagePath != null && imagePath.toString().isNotEmpty) {
          pet['imageUrl'] = imagePath.toString().replaceAll(
            RegExp(r'http://(localhost|192\.168\.1\.18):3000'),
            baseUrl,
          );
        } else {
          pet['imageUrl'] = null;
          print('No picture returned for pet ${pet['name']}');
        }
        return pet;
      } else {
        print('Failed response: ${response.data}');
        throw Exception('Failed to create pet: ${response.data}');
      }
    } catch (e) {
      print('createPet error: $e');
      rethrow;
    }
  }

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

    final userId = _getUserId(token);

    final Map<String, dynamic> formDataMap = {
      'name': name,
      'species': species,
      'breed': breed,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate,
    };

    if (imageFile != null) {
      print('Image file: ${imageFile.path}, size: ${imageFile.lengthSync() / 1024 / 1024} MB');
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      );
      formDataMap['image'] = multipartFile;
    }

    final formData = FormData.fromMap(formDataMap);

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
      final pet = Map<String, dynamic>.from(response.data);
      final imagePath = pet['picture'];
      print('Pet ${pet['name']}: picture=$imagePath');
      if (imagePath != null && imagePath.toString().isNotEmpty) {
        pet['imageUrl'] = imagePath.toString().replaceAll(
          RegExp(r'http://(localhost|192\.168\.1\.18):3000'),
          baseUrl,
        );
      } else {
        pet['imageUrl'] = null;
        print('No picture returned for pet ${pet['name']}');
      }
      return pet;
    } else {
      print('Failed response: ${response.data}');
      throw Exception('Failed to update pet: ${response.data}');
    }
  }

  Future<void> deletePet(String petId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) throw Exception('Token missing');

    final userId = _getUserId(token);

    final response = await dio.delete(
      '/animals/$userId/animals/$petId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete pet: ${response.data}');
    }
  }
}