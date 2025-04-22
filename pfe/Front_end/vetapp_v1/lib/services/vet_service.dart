import 'package:dio/dio.dart';
import 'package:vetapp_v1/models/veterinarian.dart';

class VetService {
  static const String baseUrl = "http://192.168.1.18:3000/api/users/veterinarians";
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> fetchVeterinarians({
    String? rating,
    String? location,
    int page = 1,
    int limit = 10,
    String sort = "desc",
  }) async {
    try {
      final queryParams = {
        if (rating != null && rating.trim().isNotEmpty) 'rating': rating.trim(),
        if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };

      final response = await _dio.get(baseUrl, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final jsonData = response.data;
        final veterinariansData = jsonData['veterinarians'];
        final int currentPage = jsonData['currentPage'] ?? 1;
        final int totalPages = jsonData['totalPages'] ?? 1;
        final int totalCount = jsonData['totalCount'] ?? 0;

        final List<Veterinarian> veterinarians =
        veterinariansData.map<Veterinarian>((json) => Veterinarian.fromJson(json)).toList();

        return {
          'currentPage': currentPage,
          'totalPages': totalPages,
          'totalCount': totalCount,
          'veterinarians': veterinarians,
        };
      } else {
        throw Exception('Failed to load veterinarians. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching veterinarians: $e');
      throw Exception('Error: $e');
    }
  }
}
