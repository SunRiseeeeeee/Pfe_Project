import '../services/client_service.dart';

class Client {
  final String id;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String? email;
  final String? phoneNumber;
  final Address? address;
  final String? username;
  final bool? isActive;
  final DateTime? lastLogin;
  final String? role;
  final String? mapsLocation; // Added mapsLocation
  final String? description; // Added description

  Client({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    this.email,
    this.phoneNumber,
    this.address,
    this.username,
    this.isActive,
    this.lastLogin,
    this.role,
    this.mapsLocation,
    this.description,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    String profilePicture = json['profilePicture']?.toString() ?? '';
    // Preserve local file paths; only normalize if it's a relative server path
    if (profilePicture.isNotEmpty && !profilePicture.startsWith('http') && !profilePicture.startsWith('/data/')) {
      profilePicture = 'http://192.168.1.16:3000$profilePicture';
    }
    profilePicture = profilePicture.isEmpty ? '/data/placeholder.png' : profilePicture;

    // Handle isActive as bool or String
    bool? isActive;
    if (json['isActive'] != null) {
      if (json['isActive'] is bool) {
        isActive = json['isActive'] as bool;
      } else if (json['isActive'] is String) {
        isActive = json['isActive'].toLowerCase() == 'true';
      }
    }

    return Client(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'Unknown',
      lastName: json['lastName']?.toString() ?? 'Client',
      profilePicture: profilePicture,
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      username: json['username']?.toString(),
      isActive: isActive,
      lastLogin: json['lastLogin'] != null ? DateTime.tryParse(json['lastLogin'].toString()) : null,
      role: json['role']?.toString(),
      mapsLocation: json['mapsLocation']?.toString(), // Parse mapsLocation
      description: json['description']?.toString(), // Parse description
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address?.toJson(),
      'username': username,
      'isActive': isActive,
      'lastLogin': lastLogin?.toIso8601String(),
      'role': role,
      'mapsLocation': mapsLocation, // Include mapsLocation
      'description': description, // Include description
    };
  }
}