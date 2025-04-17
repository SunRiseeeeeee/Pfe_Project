import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:vetapp_v1/models/veterinarian.dart';


/// VetService Class
class VetService {
  static const String baseUrl = "http://192.168.1.18:3000/api/users/veterinarians";

  // Create a Dio instance
  static final Dio _dio = Dio();

  /// Fetch all veterinarians
  static Future<List<Veterinarian>> fetchVeterinarians() async {
    try {
      // Make a GET request to the API
      final response = await _dio.get(baseUrl);

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        // Parse the JSON response
        final Map<String, dynamic> jsonData = response.data;

        // Extract the list of veterinarians from the "veterinarians" key
        final List<dynamic>? veterinariansData = jsonData['veterinarians'];

        // If the "veterinarians" key is null or not a list, return an empty list
        if (veterinariansData == null || veterinariansData.isEmpty) {
          print('No veterinarians found in the API response.');
          return [];
        }

        // Convert the list into a list of Veterinarian objects
        return veterinariansData.map((json) => Veterinarian.fromJson(json)).toList();
      } else {
        // Throw an exception if the response status code is not 200
        throw Exception('Failed to load veterinarians. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle any errors that occur during the request
      print('Error fetching veterinarians: $e');
      throw Exception('Error: $e');
    }
  }
}