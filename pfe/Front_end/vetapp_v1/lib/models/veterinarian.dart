import 'package:flutter/cupertino.dart';

class Veterinarian {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final double rating;
  final String? workingHours;
  final String? location;
  final String? description;

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

  factory Veterinarian.fromJson(Map<String, dynamic> json) {
    // Enhanced ID parser with better error handling
    String parseId(dynamic idValue) {
      try {
        if (idValue == null) {
          throw FormatException('Veterinarian ID is null');
        }

        if (idValue is String) {
          if (idValue.isEmpty) {
            throw FormatException('Veterinarian ID is empty');
          }
          return idValue;
        }

        if (idValue is Map) {
          if (idValue.containsKey('\$oid')) {
            final oid = idValue['\$oid'];
            if (oid is String && oid.isNotEmpty) {
              return oid;
            }
            throw FormatException('Invalid ObjectId format');
          }
          // Try other common ID map formats
          if (idValue.containsKey('id')) return parseId(idValue['id']);
          if (idValue.containsKey('_id')) return parseId(idValue['_id']);
        }

        // Try common alternative ID fields if primary fails
        if (json.containsKey('id')) return parseId(json['id']);
        if (json.containsKey('vetId')) return parseId(json['vetId']);

        throw FormatException('No valid ID found in veterinarian data');
      } catch (e) {
        debugPrint('Error parsing veterinarian ID: $e');
        rethrow;
      }
    }

    // Enhanced safe string converter
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

    // Enhanced working hours parser
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

    return Veterinarian(
      id: parseId(json['_id'] ?? json['id']),
      firstName: safeString(json['firstName'], fieldName: 'firstName'),
      lastName: safeString(json['lastName'], fieldName: 'lastName'),
      profilePicture: json['profilePicture'] is String ? json['profilePicture'] : null,
      rating: (json['rating'] is num ? json['rating'].toDouble() : 0.0),
      workingHours: safeWorkingHours(json['details'] ?? json['workingHours']),
      location: json['location'] is String ? json['location'] : null,
      description: json['description'] is String ? json['description'] : null,
    );
  }
}
