import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/appointment_screen.dart';
import 'package:vetapp_v1/screens/message_screen.dart';
import 'package:vetapp_v1/screens/profile_screen.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/services/vet_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeContent(), // The content of the home screen
    AppointmentScreen(),
    MessageScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  // Custom Bottom Navigation Bar
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
          backgroundColor: Colors.white, // Base color
          selectedItemColor: Colors.deepPurple, // Active item color
          unselectedItemColor: Colors.grey, // Inactive item color
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          elevation: 0, // Remove default elevation
          selectedFontSize: 12,
          unselectedFontSize: 10,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message, size: 28),
              label: 'Message',
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

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // Variables to manage pagination
  int currentPage = 1;
  String? ratingFilter;
  String? locationFilter;
  int limit = 10;
  String sort = "desc";
  late Future<Map<String, dynamic>> veterinariansFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future with default values
    veterinariansFuture = VetService.fetchVeterinarians(
      rating: ratingFilter,
      location: locationFilter,
      page: currentPage,
      limit: limit,
      sort: sort,
    );
  }

  // Method to refresh the future when navigating pages
  void _refreshVeterinarians(int newPage) {
    setState(() {
      currentPage = newPage;
      veterinariansFuture = VetService.fetchVeterinarians(
        rating: ratingFilter,
        location: locationFilter,
        page: currentPage,
        limit: limit,
        sort: sort,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Welcome,", style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Poppins')),
                    Text("Wade Warren", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  ],
                ),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.search), onPressed: () {}),
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
            FutureBuilder<Map<String, dynamic>>(
              future: veterinariansFuture,
              builder: (context, snapshot) {
                // Check if the data is still loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Handle errors during the API call
                if (snapshot.hasError) {
                  print('API Error: ${snapshot.error}'); // Log the error for debugging
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                // Extract the data from the snapshot
                final Map<String, dynamic>? responseData = snapshot.data;
                // Handle empty or null data
                if (responseData == null ||
                    responseData['veterinarians'] == null ||
                    responseData['veterinarians'].isEmpty) {
                  return const Center(
                    child: Text(
                      'No veterinarians found.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                // Extract the list of veterinarians and pagination details
                final List<dynamic> veterinariansData = responseData['veterinarians'];
                final int totalPages = responseData['totalPages'] ?? 1;
                // Convert the list into a list of Veterinarian objects
                final List<Veterinarian> veterinarians =
                veterinariansData.map((json) => Veterinarian.fromJson(json)).toList();
                // Display the list of veterinarians
                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: veterinarians.length,
                      itemBuilder: (context, index) {
                        final vet = veterinarians[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Hero(
                            tag: vet.id,
                            child: CircleAvatar(
                              radius: 30,
                              backgroundImage: vet.profilePicture != null
                                  ? NetworkImage(vet.profilePicture!)
                                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                              child: vet.profilePicture == null ? const Icon(Icons.person) : null,
                            ),
                          ),
                          title: Text(
                            '${vet.firstName} ${vet.lastName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${vet.rating}/5',
                                    style: const TextStyle(fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      vet.workingHours ?? 'N/A',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VetDetailsScreen(vet: vet),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Pagination Controls
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: currentPage > 1
                                ? () {
                              _refreshVeterinarians(currentPage - 1);
                            }
                                : null,
                          ),
                          Text(
                            'Page $currentPage of $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: currentPage < totalPages
                                ? () {
                              _refreshVeterinarians(currentPage + 1);
                            }
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        const Text('See All', style: TextStyle(color: Colors.blue, fontFamily: 'Poppins')),
      ],
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
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
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
                  Text(_carouselItems[_currentPage]['title']!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(_carouselItems[_currentPage]['subtitle']!,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.white)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple),
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