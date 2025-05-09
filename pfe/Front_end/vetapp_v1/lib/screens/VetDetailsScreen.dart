import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/reviews_screen.dart';
import 'package:vetapp_v1/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bookAppointment.dart';

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

  @override
  void initState() {
    super.initState();
    fetchReviewData();
  }

  void fetchReviewData() async {
    final response = await ReviewService.getReviews(widget.vet.id);
    if (response['success']) {
      setState(() {
        reviewCount = response['ratingCount'];
        averageRating = response['averageRating'];
      });
    } else {
      print('Failed to load reviews: ${response['message']}');
    }
  }

  // Method to navigate to the ReviewsScreen
  void navigateToReviews() async {
    // Get the current user ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    if (currentUserId != null) {
      // Navigate to ReviewsScreen passing both vetId and currentUserId
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewsScreen(
            vetId: widget.vet.id,
            currentUserId: currentUserId,  // Pass userId
          ),
        ),
      );
    } else {
      // Handle the case where userId is not found in SharedPreferences
      print("User ID not found in SharedPreferences");
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      print('${widget.vet.firstName} ${widget.vet.lastName} is now ${isFavorite ? "favorited" : "unfavorited"}');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Hero(
                tag: widget.vet.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.vet.profilePicture ?? 'https://via.placeholder.com/300x200',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                      onTap: navigateToReviews,  // Use the updated method to navigate
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
              Text(
                'Fees',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _feeButton('Checkup'),
                  _feeButton('Consultation'),
                  _feeButton('Follow-Ups'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentsScreen(vet: widget.vet),
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
      ),
    );
  }

  String formatWorkingHoursFromString(String workingHoursString) {
    final entries = workingHoursString.split(RegExp(r'\},\s*\{'));

    List<String> formatted = [];

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

      final day = data['day'] ?? '...';
      final start = data['start'] ?? '...';
      final end = data['end'] ?? '...';
      final pauseStart = data['pauseStart'];
      final pauseEnd = data['pauseEnd'];

      String formattedEntry = '$day: $start';

      if (pauseStart != null && pauseEnd != null) {
        formattedEntry += ' → $pauseStart (Break) → $pauseEnd';
      }

      formattedEntry += ' → $end';
      formatted.add(formattedEntry);
    }

    return formatted.join('\n');
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
