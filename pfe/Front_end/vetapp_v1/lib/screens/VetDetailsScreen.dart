import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/reviews_screen.dart';
import 'package:vetapp_v1/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp_v1/screens/bookAppointment.dart';
import 'dart:convert';
import 'dart:io';
import '../models/token_storage.dart';
import '../services/vet_service.dart';

class VetDetailsScreen extends StatefulWidget {
  final Veterinarian vet;

  const VetDetailsScreen({Key? key, required this.vet}) : super(key: key);

  @override
  _VetDetailsScreenState createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends State<VetDetailsScreen> {
  bool isFavorite = false;
  int reviewCount = 0;
  double averageRating = 0.0;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    fetchReviewData();
    _loadUserRole();
  }

  void fetchReviewData() async {
    final response = await ReviewService.getReviews(widget.vet.id);
    if (response['success']) {
      setState(() {
        reviewCount = response['ratingCount'];
        averageRating = response['averageRating'];
      });
    } else {
      debugPrint('Failed to load reviews: ${response['message']}');
    }
  }

  void _loadUserRole() async {
    final role = await TokenStorage.getUserRoleFromToken();
    setState(() {
      _userRole = role;
    });
  }

  void navigateToReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewsScreen(
            vetId: widget.vet.id,
            currentUserId: currentUserId,
          ),
        ),
      );
    } else {
      debugPrint("User ID not found in SharedPreferences");
    }
  }

  void _deleteVeterinarian() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Veterinarian'),
        content: Text(
          'Are you sure you want to delete Dr. ${widget.vet.firstName} ${widget.vet.lastName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await VetService.deleteVeterinarian(widget.vet.id);
              Navigator.pop(context); // Close dialog
              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'])),
                );
                Navigator.pop(context); // Pop VetDetailsScreen
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'])),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> parseWorkingHours(String workingHoursString) {
    debugPrint('Raw working hours input: $workingHoursString');
    if (workingHoursString.isEmpty) {
      return {'formatted': 'Not available', 'parsed': []};
    }

    final entries = workingHoursString.split(RegExp(r'\},\s*\{'));
    List<Map<String, String?>> parsedHours = [];

    for (var entry in entries) {
      entry = entry.replaceAll(RegExp(r'[\{\}]'), '');
      final pairs = entry.split(',').map((e) => e.trim()).toList();

      Map<String, String?> data = {};
      for (var pair in pairs) {
        final parts = pair.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          data[key] = value == 'null' ? null : value;
        }
      }

      final day = data['day'];
      final start = data['start'];
      final end = data['end'];

      if (day != null && start != null && end != null) {
        parsedHours.add({
          'day': day,
          'start': start,
          'end': end,
          'pauseStart': data['pauseStart'],
          'pauseEnd': data['pauseEnd'],
        });
      }
    }

    return {
      'formatted': parsedHours.isEmpty
          ? 'Not available'
          : parsedHours
          .map((e) {
        String formattedEntry = '${e['day']}: ${e['start']}';
        if (e['pauseStart'] != null && e['pauseEnd'] != null) {
          formattedEntry += ' → ${e['pauseStart']} (Break) → ${e['pauseEnd']}';
        }
        formattedEntry += ' → ${e['end']}';
        return formattedEntry;
      })
          .join('\n'),
      'parsed': parsedHours,
    };
  }

  String formatWorkingHoursFromString(String workingHoursString) {
    final result = parseWorkingHours(workingHoursString);
    return result['formatted'];
  }

  @override
  Widget build(BuildContext context) {
    String? profileUrl = widget.vet.profilePicture;
    if (profileUrl != null && profileUrl.contains('localhost')) {
      profileUrl = profileUrl.replaceFirst('localhost', '192.168.100.7');
    }
    debugPrint('Vet profile picture: $profileUrl');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Doctor Details',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () {
                      setState(() {
                        isFavorite = !isFavorite;
                      });
                      debugPrint(
                          '${widget.vet.firstName} ${widget.vet.lastName} is now ${isFavorite ? "favorited" : "unfavorited"}');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Hero(
                tag: widget.vet.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: profileUrl != null && profileUrl.isNotEmpty
                      ? profileUrl.startsWith('http')
                      ? Image.network(
                    profileUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Vet network image error for $profileUrl: $error');
                      return Image.asset(
                        'assets/images/default_avatar.png',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Vet asset error: $error');
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey,
                            child: const Icon(Icons.person, color: Colors.white),
                          );
                        },
                      );
                    },
                  )
                      : Image.file(
                    File(profileUrl),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Vet file image error for $profileUrl: $error');
                      return Image.asset(
                        'assets/images/default_avatar.png',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Vet asset error: $error');
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey,
                            child: const Icon(Icons.person, color: Colors.white),
                          );
                        },
                      );
                    },
                  )
                      : Image.asset(
                    'assets/images/default_avatar.png',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Vet asset error: $error');
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dr. ${widget.vet.firstName} ${widget.vet.lastName}',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.vet.location ?? 'Unknown Location',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoStat(Icons.people, "4,500+", "Patients"),
                    _infoStat(Icons.history, "10+", "Years Exp."),
                    _infoStat(Icons.star, averageRating.toStringAsFixed(1), "Rating"),
                    GestureDetector(
                      onTap: navigateToReviews,
                      child: _infoStat(Icons.comment, "$reviewCount", "Review${reviewCount == 1 ? '' : 's'}"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'About',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.vet.description ?? 'No description available for this veterinarian.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Text(
                'Working Hours',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                formatWorkingHoursFromString(widget.vet.workingHours ?? ''),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_userRole == 'client') // Book Appointment button for clients
              ElevatedButton(
                onPressed: () {
                  final workingHoursData = parseWorkingHours(widget.vet.workingHours ?? '');
                  final workingHoursJson = jsonEncode(workingHoursData['parsed']);
                  debugPrint('Passing working hours JSON to AppointmentsScreen: $workingHoursJson');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentsScreen(
                        vet: widget.vet,
                        workingHours: workingHoursJson,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Book Appointment',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            if (_userRole == 'admin') // Delete button for admins
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: _deleteVeterinarian,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _feeButton(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}