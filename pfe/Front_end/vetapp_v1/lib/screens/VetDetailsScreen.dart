import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import '../models/veterinarian.dart';
import '../models/token_storage.dart';
import '../services/chat_service.dart';
import '../services/review_service.dart';
import '../services/vet_service.dart';
import '../screens/reviews_screen.dart';
import '../screens/bookAppointment.dart';
import './chat_screen.dart';

class VetDetailsScreen extends StatefulWidget {
  final Veterinarian vet;

  const VetDetailsScreen({super.key, required this.vet});

  @override
  State<VetDetailsScreen> createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends State<VetDetailsScreen> {
  final ChatService _chatService = ChatService();
  bool isFavorite = false;
  int reviewCount = 0;
  double averageRating = 0.0;
  String? _userRole;
  String? _userId;
  bool _isLoading = false;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      _userId = await TokenStorage.getUserId();
      _userRole = await TokenStorage.getUserRoleFromToken();
      print('User ID: $_userId, Role: $_userRole');

      if (_userId != null && _userRole != null) {
        await _chatService.connect(_userId!, _userRole!.toUpperCase());
        print('WebSocket connected for user $_userId with role: $_userRole');
      } else {
        print('User ID or role not found');
      }

      await fetchReviewData();
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
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
          averageRating = (response['averageRating'] as num?)?.toDouble() ?? 0.0;
        });
      } else {
        print('Failed to load reviews: ${response['message']}');
      }
    } catch (e) {
      print('Error fetching reviews: $e');
    }
  }

  void navigateToReviews() async {
    try {
      _userId ??= await TokenStorage.getUserId();
      if (_userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewsScreen(
              vetId: widget.vet.id,
              currentUserId: _userId!,
            ),
          ),
        );
      } else {
        print('User ID not found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view reviews')),
        );
      }
    } catch (e) {
      print('Error navigating to reviews: $e');
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
        const SnackBar(content: Text('Please log in to start a chat')),
      );
      return;
    }

    setState(() => _isStartingChat = true);
    try {
      final conversation = await _chatService
          .getOrCreateConversation(
        userId: _userId!,
        vetId: widget.vet.id,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Conversation creation timed out'),
      );

      final chatId = conversation['chatId'] as String;
      final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);
      print('Navigating to ChatScreen with chatId: $chatId, participants: $participants');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ChatScreen(
              chatId: chatId,
              veterinaireId: widget.vet.id,
              participants: participants,
              vetId: '',
              recipientId: null,
              recipientName: '',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingChat = false);
      }
    }
  }

  String formatWorkingHours(dynamic workingHours) {
    if (workingHours == null || (workingHours is String && workingHours.isEmpty)) {
      return 'Not available';
    }

    try {
      // If it's already a properly formatted list/Map, use it directly
      if (workingHours is List<Map<String, dynamic>>) {
        return _formatHoursList(workingHours);
      }
      if (workingHours is Map<String, dynamic>) {
        return _formatHoursList([workingHours]);
      }

      // Handle string input
      if (workingHours is String) {
        String sanitized = workingHours.trim();

        // Convert the malformed JSON to proper JSON
        sanitized = _fixMalformedJson(sanitized);

        try {
          final parsed = jsonDecode(sanitized);
          if (parsed is List) {
            return _formatHoursList(parsed.cast<Map<String, dynamic>>());
          } else if (parsed is Map) {
            return _formatHoursList([parsed.cast<String, dynamic>()]);
          }
        } catch (e) {
          print('Error parsing sanitized working hours: $e\nSanitized: $sanitized');
          return 'Invalid format';
        }
      }

      return 'Not available';
    } catch (e) {
      print('Error parsing working hours: $e');
      return 'Not available';
    }
  }

  String _fixMalformedJson(String input) {
    String result = input.trim();

    // Step 1: If it's not an array and contains multiple objects, wrap in []
    if (!result.startsWith('[') && result.contains('}, {')) {
      result = '[${result}]';
    }

    // Step 2: Quote property names (convert day: to "day":)
    result = result.replaceAllMapped(
      RegExp(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9]*)(\s*:)'),
          (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
    );

    // Step 3: Quote string values (convert Monday to "Monday")
    result = result.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z][a-zA-Z0-9]*)(\s*[,}])'),
          (match) => ': "${match.group(1)}"${match.group(2)}',
    );

    // Step 4: Ensure time values are quoted (09:00 -> "09:00")
    result = result.replaceAllMapped(
      RegExp(r':\s*(\d{2}:\d{2})'),
          (match) => ': "${match.group(1)}"',
    );

    // Step 5: Handle malformed times ("08":"00" -> "08:00" or "08":00)
    result = result.replaceAllMapped(
      RegExp(r'"(\d{2})":"(\d{2})"'),
          (match) => '"${match.group(1)}:${match.group(2)}"',
    ).replaceAllMapped(
      RegExp(r'"(\d{2})":(\d{2})'),
          (match) => '"${match.group(1)}:${match.group(2)}"',
    );

    // Step 6: Convert string "null" to null
    result = result.replaceAll(RegExp(r':\s*"null"'), ': null');

    // Step 7: Remove _id fields
    result = result.replaceAllMapped(
      RegExp(r'"_id":\s*("[^"]*"|[a-fA-F0-9]+)(,\s*|\s*})'),
          (match) => '${match.group(2)}',
    );

    // Step 8: Clean up trailing commas
    result = result.replaceAll(RegExp(r',\s*}'), '}').replaceAll(RegExp(r',\s*]'), ']');

    return result;
  }

  String _formatHoursList(List<Map<String, dynamic>> hours) {
    return hours.map((e) {
      // Create a copy without _id
      final cleaned = Map<String, dynamic>.from(e)..remove('_id');
      final day = cleaned['day'] as String? ?? 'Unknown day';
      final start = cleaned['start']?.toString() ?? '?';
      final end = cleaned['end']?.toString() ?? '?';
      final pauseStart = cleaned['pauseStart'] == 'null' ? null : cleaned['pauseStart']?.toString();
      final pauseEnd = cleaned['pauseEnd'] == 'null' ? null : cleaned['pauseEnd']?.toString();

      if (pauseStart != null && pauseEnd != null) {
        return '$day: $start - $pauseStart (Break) $pauseEnd - $end';
      }
      return '$day: $start - $end';
    }).join('\n');
  }
  @override
  Widget build(BuildContext context) {
    String? profilePicture = widget.vet.profilePicture;
    if (profilePicture != null && profilePicture.contains('localhost')) {
      profilePicture = profilePicture.replaceAll('localhost', '192.168.1.16');
    }
    print('Profile picture URL: $profilePicture');

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Doctor Details',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          onPressed: () {
                            setState(() {
                              isFavorite = !isFavorite;
                            });
                            print('Favorite toggled: $isFavorite');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Hero(
                      tag: widget.vet.id,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: profilePicture != null && profilePicture.isNotEmpty
                            ? profilePicture.startsWith('http')
                            ? Image.network(
                          profilePicture,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, __) {
                            print('Error loading image: $error');
                            return Image.asset(
                              'assets/images/default_avatar.png',
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                            : Image.file(
                          File(profilePicture),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, __) {
                            print('Error loading file: $error');
                            return Image.asset(
                              'assets/images/default_avatar.png',
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                            : Image.asset(
                          'assets/images/default_avatar.png',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dr. ${widget.vet.firstName} ${widget.vet.lastName}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.vet.location,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
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
                          _infoStat(Icons.people, '4,500+', 'Patients'),
                          _infoStat(Icons.history, '10+', 'Clients'),
                          _infoStat(Icons.star, averageRating.toStringAsFixed(1), 'Rating'),
                          GestureDetector(
                            onTap: navigateToReviews,
                            child: _infoStat(Icons.comment, '$reviewCount', 'Reviews'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'About',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.vet.description ?? 'No description available.',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Working Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatWorkingHours(widget.vet.workingHours),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
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
                      onPressed: _isLoading || _isStartingChat
                          ? null
                          : () {
                        List<Map<String, dynamic>> workingHours = [];
                        if (widget.vet.workingHours != null) {
                          try {
                            String hoursString = widget.vet.workingHours is String
                                ? widget.vet.workingHours as String
                                : jsonEncode(widget.vet.workingHours);

                            // Fix malformed JSON
                            hoursString = _fixMalformedJson(hoursString);

                            final parsed = jsonDecode(hoursString);
                            if (parsed is List) {
                              workingHours = parsed.cast<Map<String, dynamic>>();
                            } else if (parsed is Map) {
                              workingHours = [parsed.cast<String, dynamic>()];
                            }
                            // Remove _id and handle "null" strings
                            workingHours = workingHours
                                .map((e) => Map<String, dynamic>.from(e)
                              ..remove('_id')
                              ..updateAll((key, value) => value == 'null' ? null : value))
                                .toList();
                          } catch (e) {
                            print('Error parsing working hours for appointment: $e');
                          }
                        }

                        final workingHoursJson = jsonEncode(
                          workingHours.map((e) {
                            final day = e['day'] as String? ?? '';
                            final start = e['start'] as String? ?? '';
                            final end = e['end'] as String? ?? '';
                            final pauseStart = e['pauseStart'] as String?;
                            final pauseEnd = e['pauseEnd'] as String?;
                            final hours = pauseStart != null && pauseEnd != null
                                ? '$start -> $pauseStart (Break) -> $pauseEnd -> $end'
                                : '$start -> $end';
                            return {'day': day, 'hours': hours};
                          }).toList(),
                        );
                        print('Navigating to BookAppointment with working hours: $workingHoursJson');
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
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
                  _isStartingChat
                      ? const CircularProgressIndicator(color: Colors.deepPurple)
                      : IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green),
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
                    'Delete Veterinarian',
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}