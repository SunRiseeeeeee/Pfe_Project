import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:vetapp_v1/models/token_storage.dart';

class PetService {
  final Dio dio;

  PetService({required this.dio});

  Future<List<Map<String, dynamic>>> getUserPets() async {
    final String? token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token not found or is empty');
    }

    late String userId;

    try {
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      print('Decoded token: $decodedToken');  // Debug print of the decoded token

      // Check if the 'id' exists in the decoded token
      userId = decodedToken['id']?.toString() ?? '';
      if (userId.isEmpty) {
        throw Exception('User ID is missing or empty in token');
      }
    } catch (e) {
      throw Exception('Token decode error: $e');
    }

    try {
      final response = await dio.get(
        '/animals/$userId/animals', // Construct the correct URL with the userId
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> petsData = response.data;
        return petsData.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      throw Exception('Failed to load pets: $e');
    }
  }
}
