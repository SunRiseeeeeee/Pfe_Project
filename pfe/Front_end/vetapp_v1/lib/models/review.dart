class Review {
  final String id;
  final Map<String, dynamic> client;
  final String veterinarian;
  final String review;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.client,
    required this.veterinarian,
    required this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      client: json['client'] as Map<String, dynamic>,
      veterinarian: json['veterinarian'] as String,
      review: json['review'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}