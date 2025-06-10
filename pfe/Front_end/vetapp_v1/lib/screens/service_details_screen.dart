import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/service.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/services/vet_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final Service service;

  const ServiceDetailsScreen({
    super.key,
    required this.service,
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  late Future<Map<String, dynamic>> veterinariansFuture;

  @override
  void initState() {
    super.initState();
    veterinariansFuture = VetService.fetchVeterinarians(
      services: [widget.service.name.toLowerCase()], // Pass as single-item list
      limit: 50,
    );
    debugPrint('Fetching veterinarians for service: ${widget.service.name}');
  }

  void _refreshVeterinarians() {
    setState(() {
      veterinariansFuture = VetService.fetchVeterinarians(
        services: [widget.service.name.toLowerCase()], // Pass as single-item list
        limit: 50,
      );
      debugPrint('Refreshing veterinarians for service: ${widget.service.name}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.service.image != null && widget.service.image!.isNotEmpty
        ? widget.service.image!.replaceAll('http://localhost:3000', 'http://192.168.1.16:3000')
        : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.service.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Service image error for $imageUrl: $error');
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.medical_services,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                      : Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.medical_services,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: const Color(0xFF800080),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFF800080),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'About This Service',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.service.description ??
                                'Professional veterinary service provided by qualified veterinarians.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        color: const Color(0xFF800080),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vets Providing This Service',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVeterinariansList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVeterinariansList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: veterinariansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF800080)));
        }
        if (snapshot.hasError) {
          debugPrint('FutureBuilder error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _refreshVeterinarians,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800080),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        final Map<String, dynamic>? responseData = snapshot.data;
        debugPrint('API response: $responseData');
        if (responseData == null || responseData['veterinarians'] == null || responseData['veterinarians'].isEmpty) {
          return Center(
            child: Text(
              'No veterinarians found for "${widget.service.name}".',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          );
        }
        List<dynamic> veterinariansData = responseData['veterinarians'];
        List<Veterinarian> veterinarians = veterinariansData.map((json) => Veterinarian.fromJson(json)).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: 3 / 4,
          ),
          itemCount: veterinarians.length,
          itemBuilder: (context, index) {
            final vet = veterinarians[index];
            final details = (veterinariansData[index]['details'] as Map<String, dynamic>?);
            final specialization = details != null ? details['specialization']?.toString() : null;
            String? profileUrl = vet.profilePicture;
            if (profileUrl != null && profileUrl.contains('localhost')) {
              profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.16');
            }
            final isValidImageUrl = profileUrl != null &&
                (profileUrl.startsWith('http') ||
                    (profileUrl.startsWith('/') && File(profileUrl).existsSync()));
            debugPrint('Vet $index profile picture: $profileUrl, valid: $isValidImageUrl');
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VetDetailsScreen(vet: vet)),
                );
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: isValidImageUrl
                            ? profileUrl!.startsWith('http')
                            ? Image.network(
                          profileUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Vet network image error for $profileUrl: $error');
                            return Image.asset(
                              'assets/images/default_avatar.png',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Vet asset error: $error');
                                return Container(
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
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Vet file image error for $profileUrl: $error');
                            return Image.asset(
                              'assets/images/default_avatar.png',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Vet asset error: $error');
                                return Container(
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
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Vet asset error: $error');
                            return Container(
                              width: double.infinity,
                              color: Colors.grey,
                              child: const Icon(Icons.person, color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Column(
                        children: [
                          Text(
                            '${vet.firstName} ${vet.lastName}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vet.location ?? 'Unknown location',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (specialization != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              specialization,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${vet.averageRating.toStringAsFixed(1)}/5',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}