import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';
import '../models/token_storage.dart';

class ReviewService {
  static const String baseUrl = 'http://192.168.1.18:3000/api';
  static final Dio dio = Dio();

  // Fetch the stored token from TokenStorage
  static Future<String?> _getToken() async {
    final token = await TokenStorage.getToken();
    print('Token retrieved: ${token != null ? "valid" : "null"}');
    return token;
  }

  // Fetch the stored user ID from SharedPreferences
  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    print('User ID retrieved: $userId');
    return userId;
  }

  // Check if vetId is valid
  static Future<Map<String, dynamic>> checkVetId(String vetId) async {
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId format: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }

    try {
      // Try GET /api/ratings/:vetId as a proxy for vetId validation
      print('Checking vetId with GET to $baseUrl/ratings/$vetId');
      final response = await dio.get('$baseUrl/ratings/$vetId');
      print('Check VetId Response: ${response.data}');
      return {'success': true};
    } on DioException catch (e) {
      print('Check VetId Error: Status ${e.response?.statusCode}, Data: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        return {
          'success': false,
          'message': 'Veterinarian not found: Please select a valid veterinarian',
        };
      }
      return {
        'success': false,
        'message': 'Error verifying veterinarian: ${e.message ?? "Unknown error"}',
      };
    }
  }

  // Add a new rating
  static Future<Map<String, dynamic>> addRating(String vetId, double rating) async {
    final token = await _getToken();
    final clientId = await _getUserId();
    if (token == null || clientId == null) {
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (rating < 1 || rating > 5) {
      print('Error: Invalid rating: $rating');
      return {'success': false, 'message': 'Rating must be between 1 and 5'};
    }

    try {
      print('Sending POST to $baseUrl/ratings/$vetId with data: {rating: $rating, clientId: $clientId}');
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
      print('Add Rating Response: ${response.data}');
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
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewText.trim().isEmpty) {
      print('Error: Empty review text');
      return {'success': false, 'message': 'Review text cannot be empty'};
    }

    try {
      print('Sending POST to $baseUrl/reviews/$vetId with data: {review: $reviewText, clientId: $clientId}');
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
      print('Add Review Response: ${response.data}');
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
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (ratingId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(ratingId)) {
      print('Error: Invalid ratingId: $ratingId');
      return {'success': false, 'message': 'Invalid rating ID'};
    }
    if (rating < 1 || rating > 5) {
      print('Error: Invalid rating: $rating');
      return {'success': false, 'message': 'Rating must be between 1 and 5'};
    }

    try {
      print('Sending PUT to $baseUrl/ratings/$vetId/$ratingId with data: {rating: $rating, clientId: $clientId}');
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
      print('Update Rating Response: ${response.data}');
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
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(reviewId)) {
      print('Error: Invalid reviewId: $reviewId');
      return {'success': false, 'message': 'Invalid review ID'};
    }
    if (reviewText.trim().isEmpty) {
      print('Error: Empty review text');
      return {'success': false, 'message': 'Review text cannot be empty'};
    }

    try {
      print('Sending PUT to $baseUrl/reviews/$vetId/$reviewId with data: {review: $reviewText, clientId: $clientId}');
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
      print('Update Review Response: ${response.data}');
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
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (ratingId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(ratingId)) {
      print('Error: Invalid ratingId: $ratingId');
      return {'success': false, 'message': 'Invalid rating ID'};
    }

    try {
      print('Sending DELETE to $baseUrl/ratings/$vetId/$ratingId with data: {clientId: $clientId}');
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
      print('Delete Rating Response: ${response.data}');
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
      print('Error: No token or client ID found');
      return {'success': false, 'message': 'No token or client ID found. Please login.'};
    }
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }
    if (reviewId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(reviewId)) {
      print('Error: Invalid reviewId: $vetId');
      return {'success': false, 'message': 'Invalid review ID'};
    }

    try {
      print('Sending DELETE to $baseUrl/reviews/$vetId/$reviewId with data: {clientId: $clientId}');
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
      print('Delete Review Response: ${response.data}');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // Get ratings and reviews for a specific vet
  static Future<Map<String, dynamic>> getReviews(String vetId) async {
    if (vetId.isEmpty || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vetId)) {
      print('Error: Invalid vetId: $vetId');
      return {'success': false, 'message': 'Invalid veterinarian ID format'};
    }

    try {
      print('Sending GET to $baseUrl/ratings/$vetId and $baseUrl/reviews/$vetId');
      final ratingsResponse = await dio.get('$baseUrl/ratings/$vetId');
      final reviewsResponse = await dio.get('$baseUrl/reviews/$vetId');

      print('Get Ratings Response: ${ratingsResponse.data}');
      print('Get Reviews Response: ${reviewsResponse.data}');

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
      return _handleError(e);
    } catch (e, stackTrace) {
      print('Parsing error: $e\nStackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to parse ratings/reviews: ${e.toString()}'
      };
    }
  }

  // Handle errors during HTTP requests
  static Map<String, dynamic> _handleError(DioException e) {
    print('DioException: ${e.message}');
    print('Response Status Code: ${e.response?.statusCode}');
    print('Response Data: ${e.response?.data}');

    String message;
    if (e.response?.statusCode == 404) {
      // Handle 404 errors specifically
      if (e.response?.data is String && (e.response?.data as String).contains('Cannot')) {
        message = 'Veterinarian not found: Please select a valid veterinarian';
      } else {
        message = 'Veterinarian not found: Please verify the veterinarian ID';
      }
    } else if (e.response?.data is Map<String, dynamic>) {
      message = e.response?.data['message']?.toString() ?? 'Error occurred';
    } else if (e.response?.data is String) {
      // Handle HTML or plain text responses
      final data = e.response?.data as String;
      if (data.contains('<!DOCTYPE html')) {
        message = 'Unexpected server response: Please try again later';
      } else {
        message = data;
      }
    } else {
      message = 'Error occurred: ${e.message ?? "Unknown error"}';
    }

    print('Processed Error Message: $message');
    return {'success': false, 'message': message};
  }
}