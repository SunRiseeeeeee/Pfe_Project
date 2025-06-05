import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';
import '../models/token_storage.dart';

class ReviewService {
  static const String baseUrl = 'http://192.168.1.16:3000/api/reviews';
  static final Dio dio = Dio();

  // Fetch the stored token from TokenStorage
  static Future<String?> _getToken() async {
    return await TokenStorage.getToken();
  }

  // Fetch the stored user ID from SharedPreferences
  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Check if vetId is valid
  static Future<Map<String, dynamic>> checkVetId(String vetId) async {
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }

    try {
      // Assuming a hypothetical endpoint to check if the veterinarian exists
      // Replace with actual endpoint if available, e.g., '/users/:vetId'
      final response = await dio.get('$baseUrl/ratings/$vetId');
      return {'success': true};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {
          'success': false,
          'message': 'Veterinarian not found: Please select a valid veterinarian',
        };
      }
      return {
        'success': false , 'message': 'Error verifying veterinarian: ${e.message ?? "Unknown error"}',
      };
    }
  }

  // Add a new rating
  static Future<Map<String, dynamic>> addRating(String vetId, double rating) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (rating < 1 || rating > 5) {
      return {'success': false, 'message': 'Rating must be between 1 and 5'};
    }

    try {
      final response = await dio.post(
        '$baseUrl/ratings/$vetId',
        data: {
          'rating': rating,
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Add a new review
  static Future<Map<String, dynamic>> addReview(String vetId, String reviewText) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewText.trim().isEmpty) {
      return {'success': false, 'message': 'Review text cannot be empty'};
    }
    if (reviewText.length < 10 || reviewText.length > 500) {
      return {'success': false, 'message': 'Review must be between 10 and 500 characters'};
    }

    try {
      final response = await dio.post(
        '$baseUrl/reviews/$vetId',
        data: {
          'review': reviewText,
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Update an existing rating
  static Future<Map<String, dynamic>> updateRating(String vetId, String ratingId, double rating) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (ratingId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(ratingId)) {
      return {'success': false, 'message': 'Invalid rating ID'};
    }
    if (rating < 1 || rating > 5) {
      return {'success': false, 'message': 'Rating must be between 1 and 5'};
    }

    try {
      final response = await dio.put(
        '$baseUrl/ratings/$vetId/$ratingId',
        data: {
          'rating': rating,
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Update an existing review
  static Future<Map<String, dynamic>> updateReview(String vetId, String reviewId, String reviewText) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(reviewId)) {
      return {'success': false, 'message': 'Invalid review ID'};
    }
    if (reviewText.trim().isEmpty) {
      return {'success': false, 'message': 'Review text cannot be empty'};
    }
    if (reviewText.length < 10 || reviewText.length > 500) {
      return {'success': false, 'message': 'Review must be between 10 and 500 characters'};
    }

    try {
      final response = await dio.put(
        '$baseUrl/reviews/$vetId/$reviewId',
        data: {
          'review': reviewText,
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Delete a rating
  static Future<Map<String, dynamic>> deleteRating(String vetId, String ratingId) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (ratingId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(ratingId)) {
      return {'success': false, 'message': 'Invalid rating ID'};
    }

    try {
      final response = await dio.delete(
        '$baseUrl/ratings/$vetId/$ratingId',
        data: {
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Delete a review
  static Future<Map<String, dynamic>> deleteReview(String vetId, String reviewId) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(reviewId)) {
      return {'success': false, 'message': 'Invalid review ID'};
    }

    try {
      final response = await dio.delete(
        '$baseUrl/reviews/$vetId/$reviewId',
        data: {
          'clientId': clientId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Get ratings and reviews for a specific vet
  static Future<Map<String, dynamic>> getReviews(String vetId) async {
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }

    try {
      final ratingsResponse = await dio.get('$baseUrl/ratings/$vetId');
      final reviewsResponse = await dio.get('$baseUrl/reviews/$vetId');

      // Validate response structure
      if (ratingsResponse.data is! Map<String, dynamic> || reviewsResponse.data is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Invalid response format from server',
        };
      }

      final ratingsData = ratingsResponse.data as Map<String, dynamic>;
      final reviewsData = reviewsResponse.data as Map<String, dynamic>;

      // Validate data fields
      if (ratingsData['data'] is! List || reviewsData['data'] is! List) {
        return {
          'success': false,
          'message': 'Invalid data structure in response',
        };
      }

      final ratingsList = ratingsData['data'] as List;
      final reviewsList = reviewsData['data'] as List;

      final reviews = reviewsList.map((reviewJson) {
        if (reviewJson is! Map<String, dynamic>) {
          throw FormatException('Invalid review JSON format');
        }
        return Review.fromJson(reviewJson);
      }).toList();

      return {
        'success': true,
        'reviews': reviews,
        'ratings': ratingsList,
        'averageRating': (ratingsData['averageRating'] is num ? ratingsData['averageRating'].toDouble() : 0.0),
        'ratingCount': (ratingsData['count'] is int ? ratingsData['count'] : 0),
      };
    } on DioException catch (e) {
      // Allow empty reviews/ratings for valid veterinarians
      if (e.response?.statusCode == 404) {
        return {
          'success': true,
          'reviews': <Review>[],
          'ratings': <dynamic>[],
          'averageRating': 0.0,
          'ratingCount': 0,
        };
      }
      return _handleError(e);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to parse ratings/reviews: ${e.toString()}'
      };
    }
  }

  // Handle errors during HTTP requests
  static Map<String, dynamic> _handleError(DioException e) {
    String message;
    if (e.response?.statusCode == 404) {
      message = e.response?.data['message']?.toString() ?? 'Resource not found';
    } else if (e.response?.data is Map<String, dynamic>) {
      message = e.response?.data['message']?.toString() ?? 'Error occurred';
    } else {
      message = 'Error occurred: ${e.message ?? "Unknown error"}';
    }

    return {'success': false, 'message': message};
  }
}