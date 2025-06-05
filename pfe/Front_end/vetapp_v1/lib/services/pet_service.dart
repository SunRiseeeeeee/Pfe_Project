import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class PetService {
  final Dio dio;
  static const String baseUrl = 'http://192.168.1.16:3000';

  PetService({required this.dio});

  Future<String?> _getToken() async => await TokenStorage.getToken();

  String _getUserId(String token) {
    try {
      final decoded = JwtDecoder.decode(token);
      final userId = decoded['id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID missing in token');
      }
      return userId;
    } catch (e) {
      print('Token decode error: $e');
      throw Exception('Invalid token');
    }
  }

  String _normalizeImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    String cleaned = imagePath.replaceAll(
      RegExp(r'http://(localhost|192\.168\.1\.18):3000'),
      baseUrl,
    );
    if (cleaned.contains('/uploads/animals/')) {
      cleaned = cleaned.replaceAll(RegExp(r'/uploads/animals/animals/'), '/uploads/animals/');
    } else {
      cleaned = cleaned.replaceAll('/uploads/', '/uploads/animals/');
    }
    print('Normalized image URL: $cleaned');
    return cleaned;
  }

  Future<List<Map<String, dynamic>>> getUserPets() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      print('No token found');
      throw Exception('Token missing');
    }

    final userId = _getUserId(token);
    print('Fetching pets for userId: $userId');

    try {
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
          pet['imageUrl'] = _normalizeImageUrl(imagePath);
          if (pet['imageUrl'].isEmpty) {
            print('No picture for pet ${pet['name']}');
          }
        }
        return pets;
      } else {
        print('getUserPets failed: ${response.statusCode}, ${response.data}');
        throw Exception('Failed to load pets: ${response.statusCode} - ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      print('getUserPets error: $e');
      if (e is DioException) {
        final errorMessage = e.response?.data['message'] ?? 'Network error: ${e.message}';
        print('Dio error details: status=${e.response?.statusCode}, data=${e.response?.data}');
        throw Exception(errorMessage);
      }
      rethrow;
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
    if (token == null || token.isEmpty) {
      print('No token found');
      throw Exception('Token missing');
    }

    final userId = _getUserId(token);

    final Map<String, dynamic> formDataMap = {
      'name': name.trim(),
      'species': species.trim(),
      'breed': breed.trim(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
    };

    if (imageFile != null) {
      print('Image file: ${imageFile.path}, size: ${imageFile.lengthSync() / 1024 / 1024} MB');
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Only JPEG or PNG images are allowed');
      }
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: 'pet-${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType: MediaType.parse(mimeType),
      );
      formDataMap['image'] = multipartFile;
    } else {
      print('No image file provided');
    }

    final formData = FormData.fromMap(formDataMap);

    print('Creating pet with data: $formDataMap');

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
        pet['imageUrl'] = _normalizeImageUrl(imagePath);
        return pet;
      } else {
        print('createPet failed: ${response.statusCode}, ${response.data}');
        throw Exception('Failed to create pet: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      print('createPet error: $e');
      if (e is DioException && e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to create pet';
        print('Dio error details: status=${e.response?.statusCode}, data=${e.response?.data}');
        throw Exception(errorMessage);
      }
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
    if (token == null || token.isEmpty) {
      print('No token found');
      throw Exception('Token missing');
    }

    final userId = _getUserId(token);

    final Map<String, dynamic> formDataMap = {
      'name': name.trim(),
      'species': species.trim(),
      'breed': breed.trim(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
    };

    if (imageFile != null) {
      print('Image file: ${imageFile.path}, size: ${imageFile.lengthSync() / 1024 / 1024} MB');
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Only JPEG or PNG images are allowed');
      }
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: 'pet-${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType: MediaType.parse(mimeType),
      );
      formDataMap['image'] = multipartFile;
    }

    final formData = FormData.fromMap(formDataMap);

    print('Updating pet with data: $formDataMap');

    try {
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

      print('updatePet response: ${response.data}');

      if (response.statusCode == 200) {
        final pet = Map<String, dynamic>.from(response.data);
        final imagePath = pet['picture'];
        print('Pet ${pet['name']}: picture=$imagePath');
        pet['imageUrl'] = _normalizeImageUrl(imagePath);
        return pet;
      } else {
        print('updatePet failed: ${response.statusCode}, ${response.data}');
        throw Exception('Failed to update pet: ${response.data['message'] ?? response.data}');
      }
    } catch (e) {
      print('updatePet error: $e');
      if (e is DioException && e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 'Failed to update pet';
        print('Dio error details: status=${e.response?.statusCode}, data=${e.response?.data}');
        throw Exception(errorMessage);
      }
      rethrow;
    }
  }

  Future<void> deletePet(String petId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      print('No token found');
      throw Exception('Token missing');
    }

    final userId = _getUserId(token);

    try {
      final response = await dio.delete(
        '/animals/$userId/animals/$petId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('deletePet response: ${response.statusCode}, ${response.data}');

      if (response.statusCode != 200) {
        print('deletePet failed: ${response.data}');
        throw Exception('Failed to delete pet: ${response.data}');
      }
    } catch (e) {
      print('deletePet error: $e');
      rethrow;
    }
  }
}