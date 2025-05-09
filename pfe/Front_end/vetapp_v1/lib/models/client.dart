class Client {
  final String id;
  final String firstName;
  final String lastName;
  final String profilePicture;

  Client({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      profilePicture: json['profilePicture'] ?? '',
    );
  }
}