class Review {
  final String id;
  final Map<String, dynamic>? client; // Made nullable to handle cases where client data is missing
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
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      client: json['client'] as Map<String, dynamic>?, // Handle nullable client
      veterinarian: json['veterinarian']?.toString() ?? '',
      review: json['review']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
    );
  }
}