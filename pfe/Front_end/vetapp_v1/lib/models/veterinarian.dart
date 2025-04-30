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
    // Helper function to safely extract String from dynamic
    String safeString(dynamic value) {
      if (value is String) return value;
      if (value is List) return value.isNotEmpty ? value.first.toString() : 'Unknown';
      return value?.toString() ?? 'Unknown';
    }

    // Helper function to safely extract working hours
    String? safeWorkingHours(dynamic details) {
      if (details is Map) {
        final hours = details['workingHours'];
        if (hours is String) return hours;
        if (hours is List) return hours.isNotEmpty ? hours.first.toString() : null;
      }
      return null;
    }

    return Veterinarian(
      id: safeString(json['_id']),
      firstName: safeString(json['firstName']),
      lastName: safeString(json['lastName']),
      profilePicture: json['profilePicture'] is String ? json['profilePicture'] : null,
      rating: (json['rating'] is num ? json['rating'].toDouble() : 0.0),
      workingHours: safeWorkingHours(json['details']),
      location: json['location'] is String ? json['location'] : null,
      description: json['description'] is String ? json['description'] : null,
    );
  }
}