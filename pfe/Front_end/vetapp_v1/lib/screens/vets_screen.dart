import 'dart:async';
import 'dart:io'; // Added for File
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/services/vet_service.dart';
import 'package:google_fonts/google_fonts.dart';

class VetsScreen extends StatefulWidget {
  const VetsScreen({super.key});

  @override
  _VetsScreenState createState() => _VetsScreenState();
}

class _VetsScreenState extends State<VetsScreen> {
  int currentPage = 1;
  String? locationFilter;
  String? specialtyFilter;
  String? nameFilter;
  int limit = 10;
  String sort = "desc";
  late Future<Map<String, dynamic>> veterinariansFuture;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  final List<String> specialties = [
    'General Practice',
    'Surgery',
    'Dentistry',
    'Dermatology',
    'Cardiology',
    'Oncology',
    'Chirurgie canine',
    'Urgences vétérinaires & NAC',
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = locationFilter ?? '';
    _searchController.text = nameFilter ?? '';
    veterinariansFuture = VetService.fetchVeterinarians(
      location: locationFilter,
      specialty: specialtyFilter,
      page: currentPage,
      limit: limit,
      sort: sort,
    );
  }

  void _refreshVeterinarians(int newPage) {
    setState(() {
      currentPage = newPage;
      veterinariansFuture = VetService.fetchVeterinarians(
        location: locationFilter,
        specialty: specialtyFilter,
        page: currentPage,
        limit: limit,
        sort: sort,
      );
      debugPrint('Refreshing veterinarians with: page=$currentPage, location=$locationFilter, specialty=$specialtyFilter, name=$nameFilter, limit=$limit, sort=$sort');
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _showFilterDialog() {
    String? tempLocationFilter = locationFilter ?? '';
    String? tempSpecialtyFilter = specialtyFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter Veterinarians', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Filter by Location', style: GoogleFonts.poppins()),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter location (e.g., Lyon)',
                        border: OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                          setDialogState(() {
                            tempLocationFilter = value;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Filter by Specialty', style: GoogleFonts.poppins()),
                    DropdownButton<String>(
                      value: tempSpecialtyFilter,
                      hint: Text('Select specialty', style: GoogleFonts.poppins()),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any', style: GoogleFonts.poppins()),
                        ),
                        ...specialties.map((String specialty) {
                          return DropdownMenuItem<String>(
                            value: specialty,
                            child: Text(specialty, style: GoogleFonts.poppins()),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        setDialogState(() {
                          tempSpecialtyFilter = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  locationFilter = null;
                  specialtyFilter = null;
                  _locationController.text = '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  locationFilter = tempLocationFilter != null && tempLocationFilter!.isNotEmpty
                      ? tempLocationFilter?.trim()
                      : null;
                  specialtyFilter = tempSpecialtyFilter;
                  _locationController.text = locationFilter ?? '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800080),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Apply Filters', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSearchDialog() {
    String? tempNameFilter = nameFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Search Veterinarians', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Search by Name', style: GoogleFonts.poppins()),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter first or last name (e.g., Pierre)',
                        border: OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                          setDialogState(() {
                            tempNameFilter = value;
                          });
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  nameFilter = null;
                  _searchController.text = '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  nameFilter = tempNameFilter != null && tempNameFilter!.isNotEmpty ? tempNameFilter?.trim() : null;
                  _searchController.text = nameFilter ?? '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800080),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Search', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF800080),
              Color(0xFF4B0082),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header with Back Arrow and Action Icons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Veterinarians',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _showSearchDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onPressed: _showFilterDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((locationFilter != null && locationFilter!.isNotEmpty) ||
                            specialtyFilter != null ||
                            (nameFilter != null && nameFilter!.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                if (nameFilter != null && nameFilter!.isNotEmpty)
                                  Chip(
                                    label: Text('Name: $nameFilter', style: GoogleFonts.poppins()),
                                    deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF800080)),
                                    backgroundColor: const Color(0xFF800080).withOpacity(0.1),
                                    onDeleted: () {
                                      setState(() {
                                        nameFilter = null;
                                        _searchController.text = '';
                                        _refreshVeterinarians(1);
                                      });
                                    },
                                  ),
                                if (locationFilter != null && locationFilter!.isNotEmpty)
                                  Chip(
                                    label: Text('Location: $locationFilter', style: GoogleFonts.poppins()),
                                    deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF800080)),
                                    backgroundColor: const Color(0xFF800080).withOpacity(0.1),
                                    onDeleted: () {
                                      setState(() {
                                        locationFilter = null;
                                        _locationController.text = '';
                                        _refreshVeterinarians(1);
                                      });
                                    },
                                  ),
                                if (specialtyFilter != null)
                                  Chip(
                                    label: Text('Specialty: $specialtyFilter', style: GoogleFonts.poppins()),
                                    deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF800080)),
                                    backgroundColor: const Color(0xFF800080).withOpacity(0.1),
                                    onDeleted: () {
                                      setState(() {
                                        specialtyFilter = null;
                                        _refreshVeterinarians(1);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        VeterinarianList(
                          veterinariansFuture: veterinariansFuture,
                          currentPage: currentPage,
                          locationFilter: locationFilter,
                          specialtyFilter: specialtyFilter,
                          nameFilter: nameFilter,
                          onPageChange: _refreshVeterinarians,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VeterinarianList extends StatelessWidget {
  final Future<Map<String, dynamic>> veterinariansFuture;
  final int currentPage;
  final String? locationFilter;
  final String? specialtyFilter;
  final String? nameFilter;
  final Function(int) onPageChange;

  const VeterinarianList({
    super.key,
    required this.veterinariansFuture,
    required this.currentPage,
    this.locationFilter,
    this.specialtyFilter,
    this.nameFilter,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
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
                Text('Error: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => onPageChange(currentPage),
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
          String message = 'No veterinarians found.';
          if (nameFilter != null && nameFilter!.isNotEmpty) {
            message = 'No veterinarians found with name $nameFilter.';
          }
          if (locationFilter != null && locationFilter!.isNotEmpty) {
            message = 'No veterinarians found in $locationFilter.';
          }
          if (specialtyFilter != null) {
            message += ' with specialty $specialtyFilter.';
          }
          return Center(child: Text(message, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)));
        }
        List<dynamic> veterinariansData = responseData['veterinarians'];
        List<Veterinarian> veterinarians = [];
        List<String?> specializations = [];

        for (var json in veterinariansData) {
          veterinarians.add(Veterinarian.fromJson(json));
          final details = json['details'] as Map<String, dynamic>?;
          final specialty = details != null ? details['specialty']?.toString() : null;
          specializations.add(specialty);
        }

        if (nameFilter != null && nameFilter!.isNotEmpty) {
          final lowerCaseNameFilter = nameFilter!.toLowerCase();
          veterinarians = veterinarians.asMap().entries.where((entry) {
            final vet = entry.value;
            final firstName = vet.firstName.toLowerCase();
            final lastName = vet.lastName.toLowerCase();
            return firstName.contains(lowerCaseNameFilter) || lastName.contains(lowerCaseNameFilter);
          }).map((entry) => entry.value).toList();
          specializations = veterinarians.asMap().entries.where((entry) {
            final vet = entry.value;
            final firstName = vet.firstName.toLowerCase();
            final lastName = vet.lastName.toLowerCase();
            return firstName.contains(lowerCaseNameFilter) || lastName.contains(lowerCaseNameFilter);
          }).map((entry) => specializations[entry.key]).toList();
        }
        if (locationFilter != null && locationFilter!.isNotEmpty) {
          veterinarians = veterinarians.asMap().entries.where((entry) {
            final vet = entry.value;
            final location = vet.location.toLowerCase();
            return location.contains(locationFilter!.toLowerCase());
          }).map((entry) => entry.value).toList();
          specializations = veterinarians.asMap().entries.where((entry) {
            final vet = entry.value;
            final location = vet.location.toLowerCase();
            return location.contains(locationFilter!.toLowerCase());
          }).map((entry) => specializations[entry.key]).toList();
        }
        if (specialtyFilter != null && specialtyFilter!.isNotEmpty) {
          final filtered = veterinarians.asMap().entries.where((entry) {
            final index = entry.key;
            final specialization = specializations[index];
            return specialization != null && specialization.toLowerCase() == specialtyFilter!.toLowerCase();
          }).toList();
          veterinarians = filtered.map((entry) => entry.value).toList();
          specializations = filtered.map((entry) => specializations[entry.key]).toList();
        }

        if (veterinarians.isEmpty) {
          String message = 'No veterinarians found.';
          if (nameFilter != null && nameFilter!.isNotEmpty) {
            message = 'No veterinarians found with name $nameFilter.';
          }
          if (locationFilter != null && locationFilter!.isNotEmpty) {
            message = 'No veterinarians found in $locationFilter.';
          }
          if (specialtyFilter != null) {
            message += ' with specialty $specialtyFilter.';
          }
          return Center(child: Text(message, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)));
        }

        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3 / 4,
              ),
              itemCount: veterinarians.length,
              itemBuilder: (context, index) {
                final vet = veterinarians[index];
                final specialization = specializations[index];
                String? profileUrl = vet.profilePicture;
                // Replace localhost with IP for network URLs
                if (profileUrl != null && profileUrl.contains('localhost')) {
                  profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.18');
                }
                debugPrint('Vet profile picture: $profileUrl');
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
                            child: profileUrl != null && profileUrl.isNotEmpty
                                ? profileUrl.startsWith('http')
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
                                vet.location,
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
            ),
            if (responseData['totalPages'] != null && responseData['totalPages'] > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF800080)),
                      onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
                    ),
                    Text('Page $currentPage of ${responseData['totalPages']}', style: GoogleFonts.poppins()),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Color(0xFF800080)),
                      onPressed: currentPage < responseData['totalPages']
                          ? () => onPageChange(currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}