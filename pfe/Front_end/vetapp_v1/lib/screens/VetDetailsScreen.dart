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
import '../services/chat_service.dart';
import './chat_screen.dart';

class VetDetailsScreen extends StatefulWidget {
  final Veterinarian vet;

  const VetDetailsScreen({Key? key, required this.vet}) : super(key: key);

  @override
  _VetDetailsScreenState createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends State<VetDetailsScreen> {
  final ChatService _chatService = ChatService();
  bool isFavorite = false;
  int reviewCount = 0;
  double averageRating = 0.0;
  String? _userRole;
  String? _userId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final role = await TokenStorage.getUserRoleFromToken();

      if (userId != null && role != null) {
        setState(() {
          _userId = userId;
          _userRole = role;
        });
        await _chatService.connect(userId, role.toUpperCase());
        debugPrint('WebSocket connected for user $userId with role $role');
      } else {
        debugPrint('User ID or role not found');
      }

      await fetchReviewData();
    } catch (e) {
      debugPrint('Initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchReviewData() async {
    try {
      final response = await ReviewService.getReviews(widget.vet.id);
      if (response['success']) {
        setState(() {
          reviewCount = response['ratingCount'] ?? 0;
          averageRating = response['averageRating']?.toDouble() ?? 0.0;
        });
      } else {
        debugPrint('Failed to load reviews: ${response['message']}');
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    }
  }

  void navigateToReviews() async {
    try {
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
        debugPrint('User ID not found in SharedPreferences');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view reviews')),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to reviews: $e');
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
              try {
                final result = await VetService.deleteVeterinarian(widget.vet.id);
                Navigator.pop(context);
                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting veterinarian: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _startConversation() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final conversation = await _chatService.getOrCreateConversation(
        userId: _userId!,
        vetId: widget.vet.id,
      );

      final chatId = conversation['chatId'] as String;
      final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);

      // Standardize participant keys to match ChatScreen and ConversationsScreen
      final standardizedParticipants = participants.map((p) {
        return {
          'id': p['id'] as String? ?? '',
          'firstName': p['firstName'] as String? ?? 'Unknown',
          'lastName': p['lastName'] as String? ?? '',
          'profilePicture': p['profilePicture'] as String?,
        };
      }).toList();

      // Add client if missing
      if (!standardizedParticipants.any((p) => p['id'] == _userId)) {
        standardizedParticipants.add({
          'id': _userId!,
          'firstName': 'You',
          'lastName': '',
          'profilePicture': null,
        });
      }

      // Add vet if missing
      if (!standardizedParticipants.any((p) => p['id'] == widget.vet.id)) {
        standardizedParticipants.add({
          'id': widget.vet.id,
          'firstName': widget.vet.firstName,
          'lastName': widget.vet.lastName,
          'profilePicture': widget.vet.profilePicture,
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              veterinaireId: widget.vet.id,
              participants: standardizedParticipants,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> parseWorkingHours(String workingHoursString) {
    debugPrint('Raw working hours input: $workingHoursString');
    if (workingHoursString.isEmpty) {
      return {'formatted': 'Not available', 'parsed': []};
    }

    try {
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
    } catch (e) {
      debugPrint('Error parsing working hours: $e');
      return {'formatted': 'Not available', 'parsed': []};
    }
  }

  String formatWorkingHoursFromString(String workingHoursString) {
    final result = parseWorkingHours(workingHoursString);
    return result['formatted'];
  }

  @override
  Widget build(BuildContext context) {
    String? profileUrl = widget.vet.profilePicture;
    if (profileUrl != null && profileUrl.contains('localhost')) {
      profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.16');
    }
    debugPrint('Vet profile picture: $profileUrl');

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
            if (_userRole == 'client')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
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
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.deepPurple),
                    onPressed: _isLoading ? null : _startConversation,
                    tooltip: 'Start Chat',
                  ),
                ],
              ),
            if (_userRole == 'admin')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _deleteVeterinarian,
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

  @override
  void dispose() {
    _chatService.disconnect();
    super.dispose();
  }
}