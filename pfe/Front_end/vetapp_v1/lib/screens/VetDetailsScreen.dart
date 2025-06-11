import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/screens/posts_screen.dart';
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
import 'package:url_launcher/url_launcher.dart';

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
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour démarrer une conversation')),
      );
      return;
    }

    setState(() => _isStartingChat = true);

    try {
      // Ensure WebSocket connection
      if (!_chatService.isConnected()) {
        await _chatService.connect(_userId!, _userRole!.toUpperCase());
        print('WebSocket connected for user $_userId with role: $_userRole');
      }

      // Determine the role
      final role = _userRole!.toLowerCase();
      String targetId;
      String recipientName;

      if (role == 'veterinaire') {
        // ❗ This part assumes you have a `client` object or selection logic
        throw Exception("Vétérinaire: client cible manquant pour démarrer la conversation.");
      } else {
        // Client or other user starting the conversation with the veterinarian
        targetId = widget.vet.id;
        recipientName = 'Dr. ${widget.vet.firstName} ${widget.vet.lastName}'.trim();
        print('Utilisateur (${_userRole}) démarrant une conversation avec le vétérinaire: $recipientName');
      }

      // Get or create the conversation
      final conversation = await _chatService.getOrCreateConversation(
        userId: _userId!,
        targetId: targetId,
      );

      final chatId = conversation['chatId'] as String;
      final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);

      print('Conversation trouvée/créée: Chat ID: $chatId, Participants: ${participants.length}');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ChatScreen(
              chatId: chatId,
              veterinaireId: role == 'veterinaire' ? _userId! : widget.vet.id,
              participants: participants,
              recipientId: targetId,
              recipientName: recipientName,
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du démarrage de la conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de démarrer la conversation: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingChat = false);
      }
    }
  }

  Future<void> _openMapsLocation() async {
    final url = widget.vet.mapsLocation;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open map location')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map location available')),
      );
    }
  }

  Widget _buildWorkingHoursDisplay() {
    final workingHours = _parseWorkingHours(widget.vet.workingHours);

    if (workingHours.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Working hours not available',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: workingHours.map((daySchedule) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      daySchedule['day'] ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildTimeSchedule(daySchedule),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeSchedule(Map<String, dynamic> daySchedule) {
    final start = daySchedule['start'] as String?;
    final end = daySchedule['end'] as String?;
    final pauseStart = daySchedule['pauseStart'] as String?;
    final pauseEnd = daySchedule['pauseEnd'] as String?;

    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Text(
          'Closed',
          style: GoogleFonts.poppins(
            color: Colors.red[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Row(
      children: [
        _buildTimeChip('$start - ${pauseStart ?? end}', Colors.purple),
        if (pauseStart != null && pauseEnd != null && pauseEnd.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildBreakChip(),
          const SizedBox(width: 8),
          _buildTimeChip('$pauseEnd - $end', Colors.purple),
        ],
      ],
    );
  }

  Widget _buildTimeChip(String time, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[100]!),
      ),
      child: Text(
        time,
        style: GoogleFonts.poppins(
          color: color[700],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline, size: 14, color: Colors.red[600]),
          const SizedBox(width: 4),
          Text(
            'Break',
            style: GoogleFonts.poppins(
              color: Colors.red[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseWorkingHours(dynamic workingHours) {
    if (workingHours == null || (workingHours is String && workingHours.isEmpty)) {
      return [];
    }

    try {
      if (workingHours is List<Map<String, dynamic>>) {
        return workingHours;
      }
      if (workingHours is Map<String, dynamic>) {
        return [workingHours];
      }

      if (workingHours is String) {
        String sanitized = workingHours.trim();
        sanitized = _fixMalformedJson(sanitized);

        try {
          final parsed = jsonDecode(sanitized);
          if (parsed is List) {
            return parsed.cast<Map<String, dynamic>>();
          } else if (parsed is Map) {
            return [parsed.cast<String, dynamic>()];
          }
        } catch (e) {
          print('Error parsing sanitized working hours: $e\nSanitized: $sanitized');
          return [];
        }
      }

      return [];
    } catch (e) {
      print('Error parsing working hours: $e');
      return [];
    }
  }

  String _fixMalformedJson(String input) {
    String result = input.trim();

    if (!result.startsWith('[') && result.contains('}, {')) {
      result = '[${result}]';
    }

    result = result.replaceAllMapped(
      RegExp(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9]*)(\s*:)'),
          (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
    );

    result = result.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z][a-zA-Z0-9]*)(\s*[,}])'),
          (match) => ': "${match.group(1)}"${match.group(2)}',
    );

    result = result.replaceAllMapped(
      RegExp(r':\s*(\d{2}:\d{2})'),
          (match) => ': "${match.group(1)}"',
    );

    result = result.replaceAllMapped(
      RegExp(r'"(\d{2})":"(\d{2})"'),
          (match) => '"${match.group(1)}:${match.group(2)}"',
    ).replaceAllMapped(
      RegExp(r'"(\d{2})":(\d{2})'),
          (match) => '"${match.group(1)}:${match.group(2)}"',
    );

    result = result.replaceAll(RegExp(r':\s*"null"'), ': null');

    result = result.replaceAllMapped(
      RegExp(r'"_id":\s*("[^"]*"|[a-fA-F0-9]+)(,\s*|\s*})'),
          (match) => '${match.group(2)}',
    );

    result = result.replaceAll(RegExp(r',\s*}'), '}').replaceAll(RegExp(r',\s*]'), ']');

    return result;
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
                          _infoStat(Icons.people, '100+', 'Patients'),
                          _infoStat(Icons.history, '10+', 'Clients'),
                          _infoStat(Icons.star, averageRating.toStringAsFixed(1), 'Rating'),
                          GestureDetector(
                            onTap: navigateToReviews,
                            child: _infoStat(Icons.comment, '$reviewCount', 'Reviews'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16), // Increased spacing for better visual hierarchy
                    GestureDetector(
                      onTap: _openMapsLocation,
                      child: Card(
                        elevation: 3, // Subtle shadow for depth
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50], // Light blue background for a soft look
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!, width: 1), // Subtle border
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: Colors.blue[800], // Deep blue for contrast
                              ),
                              const SizedBox(width: 8), // Space between icon and text
                              Text(
                                'View Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600, // Bolder for emphasis
                                  color: Colors.blue[800], // Matching deep blue
                                ),
                              ),
                              const Spacer(), // Push arrow to the right
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Colors.blue[800], // Match icon color
                              ),
                            ],
                          ),
                        ),
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
                    const SizedBox(height: 12),
                    _buildWorkingHoursDisplay(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_userRole == 'client') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => PostsScreen(
                                  vetId: widget.vet.id,
                                ),
                              ),
                            );
                          },
                          backgroundColor: const Color(0xFF4A90E2),
                          icon: Icons.article_outlined,
                          label: 'Posts',
                          isLoading: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledButton(
                          onPressed: _isLoading || _isStartingChat ? null : _startConversation,
                          backgroundColor: const Color(0xFF00C9A7),
                          icon: Icons.chat_bubble_outline,
                          label: 'Chat',
                          isLoading: _isStartingChat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _buildStyledButton(
                      onPressed: _isLoading || _isStartingChat
                          ? null
                          : () {
                        List<Map<String, dynamic>> workingHours = [];
                        if (widget.vet.workingHours != null) {
                          try {
                            String hoursString = widget.vet.workingHours is String
                                ? widget.vet.workingHours as String
                                : jsonEncode(widget.vet.workingHours);

                            hoursString = _fixMalformedJson(hoursString);

                            final parsed = jsonDecode(hoursString);
                            if (parsed is List) {
                              workingHours = parsed.cast<Map<String, dynamic>>();
                            } else if (parsed is Map) {
                              workingHours = [parsed.cast<String, dynamic>()];
                            }
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
                      backgroundColor: const Color(0xFF7B68EE),
                      icon: Icons.calendar_today_outlined,
                      label: 'Book Appointment',
                      isLoading: false,
                    ),
                  ),
                ],
                if (_userRole == 'admin')
                  SizedBox(
                    width: double.infinity,
                    child: _buildStyledButton(
                      onPressed: _isLoading ? null : _deleteVeterinarian,
                      backgroundColor: const Color(0xFFE74C3C),
                      icon: Icons.delete_outline,
                      label: 'Delete Veterinarian',
                      isLoading: _isLoading,
                      isDestructive: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledButton({
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required IconData icon,
    required String label,
    required bool isLoading,
    bool isDestructive = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: backgroundColor.withOpacity(0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
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