import 'package:dio/dio.dart';

class PetService {
  final Dio dio;

  PetService({required this.dio});

  // Method to fetch pets based on userId
  Future<List<String>> getUserPets(String userId) async {
    try {
      // Make the API call to fetch the user's pets
      final response = await dio.get('/animals/$userId/animals');

      // Assuming the response is an array of pets with each having an `id` and `name` field
      if (response.statusCode == 200) {
        // Extracting the pet names (or you can adjust based on your API response structure)
        final pets = List<String>.from(response.data.map((pet) => pet['name']));

        // Return the list of pet names
        return pets;
      } else {
        throw Exception('Failed to load pets');
      }
    } catch (e) {
      // Handle errors (e.g., no internet, server issues)
      print('Error fetching pets: $e');
      throw Exception('Failed to fetch pets. Please try again later.');
    }
  }
}
