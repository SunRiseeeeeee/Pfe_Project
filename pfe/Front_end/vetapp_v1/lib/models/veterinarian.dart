class Veterinarian {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture; // Nullable because not all veterinarians may have a profile picture
  final double rating;
  final String? workingHours; // Nullable because some veterinarians may not specify working hours
  final String? location; // Nullable because location might not always be available
  final String? description; // Nullable because description might not always be available

  Veterinarian({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    required this.rating,
    this.workingHours,
    this.location,
    this.description,
  });

  // Factory constructor to create a Veterinarian object from JSON
  factory Veterinarian.fromJson(Map<String, dynamic> json) {
    return Veterinarian(
      id: json['_id'], // Assuming '_id' is the unique identifier from the API
      firstName: json['firstName'] ?? 'Unknown', // Default value if firstName is null
      lastName: json['lastName'] ?? 'Unknown',
      profilePicture: json['profilePicture'], // Nullable field
      rating: json['rating']?.toDouble() ?? 0.0, // Default to 0.0 if rating is null
      workingHours: json['details']?['workingHours'], // Nested field in the JSON
      location: json['location'],
      description: json['description'],
    );
  }
}