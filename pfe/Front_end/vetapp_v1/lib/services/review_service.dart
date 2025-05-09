import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';
import '../models/token_storage.dart';
// Import the TokenStorage class

class ReviewService {
  static const String baseUrl = 'http://192.168.1.18:3000/api/reviews'; // Update this
  static final Dio dio = Dio();

  // Fetch the stored token from TokenStorage
  static Future<String?> _getToken() async {
    final token = await TokenStorage.getToken(); // Use TokenStorage to retrieve the token
    print('Token retrieved: $token');  // Debug: print token value
    return token;
  }

  // Add a new review
  static Future<Map<String, dynamic>> addReview(String vetId, double rating, String reviewText) async {
    final token = await _getToken();
    if (token == null) {
      print('Error: No token found');
      return {'success': false, 'message': 'No token found. Please login.'};
    }

    try {
      final response = await dio.post(
        '$baseUrl/$vetId',
        data: {
          'rating': rating,
          'review': reviewText,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',  // Add Bearer token to headers
            'Content-Type': 'application/json',
          },
        ),
      );
      print('Add Review Response: ${response.data}');  // Debug: print response
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Update an existing review
  static Future<Map<String, dynamic>> updateReview(String reviewId, double rating, String reviewText) async {
    final token = await _getToken();
    if (token == null) {
      print('Error: No token found');
      return {'success': false, 'message': 'No token found. Please login.'};
    }

    try {
      final response = await dio.put(
        '$baseUrl/$reviewId',
        data: {
          'rating': rating,
          'review': reviewText,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',  // Add Bearer token to headers
            'Content-Type': 'application/json',
          },
        ),
      );
      print('Update Review Response: ${response.data}');  // Debug: print response
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Delete a review
  static Future<Map<String, dynamic>> deleteReview(String reviewId) async {
    final token = await _getToken();
    if (token == null) {
      print('Error: No token found');
      return {'success': false, 'message': 'No token found. Please login.'};
    }

    try {
      final response = await dio.delete(
        '$baseUrl/$reviewId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',  // Add Bearer token to headers
          },
        ),
      );
      print('Delete Review Response: ${response.data}');  // Debug: print response
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Get reviews for a specific vet
  static Future<Map<String, dynamic>> getReviews(String vetId) async {
    try {
      final response = await dio.get('$baseUrl/$vetId');
      print('Get Reviews Response: ${response.data}');

      final responseData = response.data as Map<String, dynamic>;
      final reviewsList = responseData['reviews'] as List;

      final reviews = reviewsList.map((reviewJson) {
        return Review.fromJson(reviewJson as Map<String, dynamic>);
      }).toList();

      return {
        'success': true,
        'reviews': reviews,
        'averageRating': (responseData['averageRating'] as num).toDouble(),
        'ratingCount': responseData['ratingCount'] as int,
      };
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to parse reviews: ${e.toString()}'
      };
    }
  }

  // Handle errors during HTTP requests
  static Map<String, dynamic> _handleError(DioException e) {
    final message = e.response?.data['message'] ?? 'Error occurred';
    print('Error Message: $message');  // Debug: print error message
    return {'success': false, 'message': message};
  }
}
