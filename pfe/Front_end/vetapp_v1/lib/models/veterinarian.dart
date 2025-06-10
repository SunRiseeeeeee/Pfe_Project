import 'package:flutter/cupertino.dart';

class Veterinarian {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final double rating;
  final double averageRating;
  final String? workingHours;
  final String? description;
  final Map<String, dynamic>? address;
  final String? mapsLocation; // ✅ NEW: Added mapsLocation field for the URL

  Veterinarian({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    required this.rating,
    required this.averageRating,
    this.workingHours,
    this.description,
    this.address,
    this.mapsLocation, // ✅ NEW: Included in constructor
  });

  factory Veterinarian.fromJson(Map<String, dynamic> json) {
    String parseId(dynamic idValue) {
      try {
        if (idValue == null) throw FormatException('Veterinarian ID is null');
        if (idValue is String && idValue.isNotEmpty) return idValue;
        if (idValue is Map) {
          if (idValue.containsKey('\$oid')) return idValue['\$oid'];
          if (idValue.containsKey('id')) return parseId(idValue['id']);
          if (idValue.containsKey('_id')) return parseId(idValue['_id']);
        }
        if (json.containsKey('id')) return parseId(json['id']);
        if (json.containsKey('vetId')) return parseId(json['vetId']);
        throw FormatException('No valid ID found in veterinarian data');
      } catch (e) {
        debugPrint('Error parsing veterinarian ID: $e');
        rethrow;
      }
    }

    String safeString(dynamic value, {String fieldName = 'field'}) {
      try {
        if (value == null) return 'Unknown';
        if (value is String) return value;
        if (value is List) return value.isNotEmpty ? value.first.toString() : 'Unknown';
        return value.toString();
      } catch (e) {
        debugPrint('Error parsing $fieldName: $e');
        return 'Unknown';
      }
    }

    String? safeWorkingHours(dynamic details) {
      try {
        if (details is Map) {
          final hours = details['workingHours'] ?? details['hours'];
          if (hours is String) return hours;
          if (hours is List) return hours.isNotEmpty ? hours.join(', ') : null;
        }
        return null;
      } catch (e) {
        debugPrint('Error parsing working hours: $e');
        return null;
      }
    }

    String? safeMapsLocation(dynamic value) { // ✅ NEW: Helper to parse mapsLocation
      try {
        if (value == null) return null;
        if (value is String && value.isNotEmpty) return value;
        return null;
      } catch (e) {
        debugPrint('Error parsing mapsLocation: $e');
        return null;
      }
    }

    return Veterinarian(
      id: parseId(json['_id'] ?? json['id']),
      firstName: safeString(json['firstName'], fieldName: 'firstName'),
      lastName: safeString(json['lastName'], fieldName: 'lastName'),
      profilePicture: json['profilePicture'] is String ? json['profilePicture'] : null,
      rating: (json['rating'] is num ? json['rating'].toDouble() : 0.0),
      averageRating: (json['averageRating'] is num ? json['averageRating'].toDouble() : 0.0),
      workingHours: safeWorkingHours(json['details'] ?? json['workingHours']),
      description: json['description'] is String ? json['description'] : null,
      address: json['address'] is Map<String, dynamic> ? json['address'] : null,
      mapsLocation: safeMapsLocation(json['mapsLocation']), // ✅ NEW: Parse mapsLocation
    );
  }

  String get location {
    if (address == null) return 'Unknown Location';

    final street = address!['street'];
    final city = address!['city'];
    final country = address!['country'];

    return [street, city, country]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');
  }
}