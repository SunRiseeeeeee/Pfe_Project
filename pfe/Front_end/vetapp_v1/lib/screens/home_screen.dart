import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/appointment_screen.dart';
import 'package:vetapp_v1/screens/fypscreen.dart';
import 'package:vetapp_v1/screens/profile_screen.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/screens/MyPetsScreen.dart';
import 'package:vetapp_v1/screens/client_screen.dart';
import '../models/token_storage.dart';
import 'package:dio/dio.dart';

class VetService {
  static const String baseUrl = "http://192.168.1.18:3000/api/users/veterinarians";
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> fetchVeterinarians({
    String? location,
    String? specialty,
    List<String>? services,
    int page = 1,
    int limit = 10,
    String sort = "desc",
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (location != null && location.isNotEmpty) 'location': location.trim(),
        if (specialty != null && specialty.isNotEmpty) 'specialty': specialty.trim(),
        if (services != null && services.isNotEmpty) 'services': services.join(","),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };

      final url = Uri.parse(baseUrl).replace(queryParameters: queryParams).toString();
      print('Request URL: $url');
      print('Query Parameters: $queryParams');

      final response = await _dio.get(baseUrl, queryParameters: queryParams);
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load veterinarians. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching veterinarians: $e');
      rethrow;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final rawRole = await TokenStorage.getUserRoleFromToken();
      print('Raw role from TokenStorage: $rawRole');
      final normalizedRole = rawRole?.toLowerCase().trim();
      setState(() {
        userRole = normalizedRole ?? 'pet_owner';
        if (normalizedRole == 'vet' || normalizedRole == 'veterinaire') {
          userRole = 'veterinarian';
        }
        print('Final userRole: $userRole');
      });
    } catch (e) {
      print('Error fetching user role: $e');
      setState(() {
        userRole = 'pet_owner';
        print('Final userRole (error): $userRole');
      });
    }
  }

  // Screens based on user role
  List<Widget> get _screens {
    if (userRole == 'veterinarian' || userRole == 'secretary') {
      return const [
        HomeContent(),           // 0 - Home
        AppointmentScreen(),     // 1 - Appointment
        ClientScreen(),         // 2 - Client
        FypScreen(),            // 3 - Fyp
        ProfileScreen(),        // 4 - Profile
      ];
    } else {
      return const [
        HomeContent(),           // 0 - Home
        AppointmentScreen(),     // 1 - Appointment
        PetsScreen(),           // 2 - Pets
        FypScreen(),            // 3 - Fyp
        ProfileScreen(),        // 4 - Profile
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: userRole == null
          ? const Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: userRole == 'veterinarian' || userRole == 'secretary'
              ? [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(
              icon: _CustomNavIcon(
                icon: Icons.people,
                isSelected: _selectedIndex == 2,
              ),
              label: 'Client',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stacked_bar_chart, size: 28),
              label: 'Fyp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ]
              : [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(
              icon: _CustomNavIcon(
                icon: Icons.pets,
                isSelected: _selectedIndex == 2,
              ),
              label: 'Pets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stacked_bar_chart, size: 28),
              label: 'Fyp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _CustomNavIcon({
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          icon,
          size: 36,
          color: isSelected ? Colors.deepPurple : Colors.grey,
        ),
      ],
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int currentPage = 1;
  String? locationFilter;
  String? specialtyFilter;
  String? nameFilter;
  int limit = 10;
  String sort = "desc";
  late Future<Map<String, dynamic>> veterinariansFuture;
  String? username;
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
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final fetchedUsername = await TokenStorage.getUsernameFromToken();
      setState(() {
        username = fetchedUsername ?? "User";
      });
    } catch (e) {
      print("Error fetching username: $e");
      setState(() {
        username = "Error";
      });
    }
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

  void _showSearchDialog() {
    String? tempNameFilter = nameFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search Veterinarians'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Search by Name'),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter first or last name (e.g., Pierre)',
                        border: OutlineInputBorder(),
                      ),
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
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome,",
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Poppins'),
                    ),
                    Text(
                      username ?? 'Loading...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _showSearchDialog,
                    ),
                    IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AutoSlidingPageView(),
            const SizedBox(height: 20),
            _buildSectionHeader('Services'),
            const SizedBox(height: 12),
            _buildServicesSection(),
            const SizedBox(height: 20),
            _buildSectionHeader('Our best veterinarians'),
            const SizedBox(height: 12),
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
                        label: Text('Name: $nameFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
                        label: Text('Location: $locationFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
                        label: Text('Specialty: $specialtyFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
            FutureBuilder<Map<String, dynamic>>(
              future: veterinariansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('FutureBuilder error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _refreshVeterinarians(currentPage),
                          child: const Text('Retry'),
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
                  return Center(child: Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)));
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
                  return Center(child: Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)));
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
                                    child: vet.profilePicture != null
                                        ? Image.network(
                                      vet.profilePicture!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Image.asset('assets/images/default_avatar.png',
                                            width: double.infinity, fit: BoxFit.cover);
                                      },
                                    )
                                        : Image.asset('assets/images/default_avatar.png',
                                        width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${vet.firstName} ${vet.lastName}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 14),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        vet.location,
                                        style: const TextStyle(
                                            fontSize: 12, fontFamily: 'Poppins', color: Colors.grey),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (specialization != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          specialization,
                                          style: const TextStyle(
                                              fontSize: 12, fontFamily: 'Poppins', color: Colors.grey),
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
                                            style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
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
                              icon: const Icon(Icons.arrow_back),
                              onPressed: currentPage > 1 ? () => _refreshVeterinarians(currentPage - 1) : null,
                            ),
                            Text('Page $currentPage of ${responseData['totalPages']}'),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: currentPage < responseData['totalPages']
                                  ? () => _refreshVeterinarians(currentPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.blue),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  void _showFilterDialog() {
    String? tempLocationFilter = locationFilter ?? '';
    String? tempSpecialtyFilter = specialtyFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Veterinarians'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filter by Location'),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter location (e.g., Lyon)',
                        border: OutlineInputBorder(),
                      ),
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
                    const Text('Filter by Specialty'),
                    DropdownButton<String>(
                      value: tempSpecialtyFilter,
                      hint: const Text('Select specialty'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any'),
                        ),
                        ...specialties.map((String specialty) {
                          return DropdownMenuItem<String>(
                            value: specialty,
                            child: Text(specialty),
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
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Apply Filters'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesSection() {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(flex: 6, child: _buildServiceCard('Vaccinations', 'assets/images/vac.jpg')),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _buildServiceCard('Grooming', 'assets/images/grooming.jpg')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildServiceCard('Walking', 'assets/images/walking.jpg')),
              const SizedBox(width: 10),
              Expanded(flex: 6, child: _buildServiceCard('Training', 'assets/images/training.jpg')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(String title, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(imageUrl, fit: BoxFit.cover),
          Container(
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AutoSlidingPageView extends StatefulWidget {
  const AutoSlidingPageView({super.key});

  @override
  State<AutoSlidingPageView> createState() => _AutoSlidingPageViewState();
}

class _AutoSlidingPageViewState extends State<AutoSlidingPageView> {
  final List<Map<String, String>> _carouselItems = [
    {'image': 'assets/images/discover.jpg', 'title': 'Discover Top Vets', 'subtitle': 'Find the best vets.'},
    {'image': 'assets/images/vet2.jpg', 'title': 'Explore Our Services', 'subtitle': 'We offer vaccinations.'},
    {'image': 'assets/images/discover2.jpg', 'title': 'Book Appointments', 'subtitle': 'Schedule visits with ease.'},
  ];
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _carouselItems.length * 100);
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index % _carouselItems.length;
              });
            },
            itemCount: _carouselItems.length * 1000,
            itemBuilder: (context, index) {
              final itemIndex = index % _carouselItems.length;
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(_carouselItems[itemIndex]['image']!, fit: BoxFit.cover),
              );
            },
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _carouselItems[_currentPage]['title']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _carouselItems[_currentPage]['subtitle']!,
                    style: const TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple),
                    child: const Text('Discover', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _carouselItems.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.white : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}