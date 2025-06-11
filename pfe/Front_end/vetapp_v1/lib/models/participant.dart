class Participant {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String role; // Add role field

  Participant({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    required this.role,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? 'Inconnu',
      lastName: json['lastName'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
      role: json['role'] as String? ?? 'unknown', // Default to 'unknown' if missing
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'role': role,
    };
  }
}