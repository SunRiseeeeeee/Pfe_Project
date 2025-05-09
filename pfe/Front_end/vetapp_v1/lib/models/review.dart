import 'client.dart';

class Review {
  final String id;
  final Client client;
  final String veterinarian;
  final double rating;
  final String review;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.client,
    required this.veterinarian,
    required this.rating,
    required this.review,
    required this.ratingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id'],
      client: Client.fromJson(json['client']),
      veterinarian: json['veterinarian'],
      rating: (json['rating'] as num).toDouble(),
      review: json['review'],
      ratingCount: json['ratingCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}