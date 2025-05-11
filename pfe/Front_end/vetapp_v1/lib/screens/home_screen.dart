import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/appointment_screen.dart';
import 'package:vetapp_v1/screens/message_screen.dart';
import 'package:vetapp_v1/screens/profile_screen.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/services/vet_service.dart';
import 'package:vetapp_v1/screens/MyPetsScreen.dart';

import '../models/token_storage.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeContent(),           // 0 - Home
    AppointmentScreen(),     // 1 - Appointment/
    PetsScreen(),             // 3 - Pets
    MessageScreen(),         // 2 - Message
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
          items: [
            BottomNavigationBarItem(  // 0 - Home
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(  // 1 - Appointment
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(  // 2 - Pets (special)
              icon: _BigPawIcon(isSelected: _selectedIndex == 2),
              label: 'Pets',
            ),
            BottomNavigationBarItem(  // 3 - Message
              icon: Icon(Icons.message, size: 28),
              label: 'Message',
            ),
            BottomNavigationBarItem(  // 4 - Profile
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }



}
class _BigPawIcon extends StatelessWidget {
  final bool isSelected;

  const _BigPawIcon({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle (slightly larger than normal icons)
        Container(
          width: 40,  // Bigger than other icons (28)
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        // Paw icon with fingers extending beyond
        Icon(
          Icons.pets,
          size: 36,  // Larger than other icons
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
  // Variables to manage pagination
  int currentPage = 1;
  String? ratingFilter;
  String? locationFilter;
  int limit = 10;
  String sort = "desc";
  late Future<Map<String, dynamic>> veterinariansFuture;
  String? username; // Variable to store the username

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
    // Fetch the username from TokenStorage
    _loadUsername();
  }

  // Method to load the username from TokenStorage
  Future<void> _loadUsername() async {
    final tokenStorage = TokenStorage();
    setState(() {
      // Optional: Set a temporary state to indicate loading
      username = "";
    });

    try {
      final fetchedUsername = await TokenStorage.getUsernameFromToken(); // Fetching username from SharedPreferences
      if (fetchedUsername != null) {
        setState(() {
          username = fetchedUsername; // Store the username once fetched
        });
      } else {
        setState(() {
          username = "Username not found"; // Handle the case where username is null
        });
      }
    } catch (e) {
      setState(() {
        username = "Error loading username"; // Error handling in case of any issue
      });
      print("Error fetching username: $e");
    }
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
                  children: [
                    const Text(
                      "Welcome,",
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Poppins'),
                    ),
                    // Display the username dynamically here
                    Text(
                      username ?? 'Loading...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('API Error: ${snapshot.error}');
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                final Map<String, dynamic>? responseData = snapshot.data;
                if (responseData == null || responseData['veterinarians'] == null || responseData['veterinarians'].isEmpty) {
                  return const Center(child: Text('No veterinarians found.', style: TextStyle(fontSize: 16, color: Colors.grey)));
                }
                final List<dynamic> veterinariansData = responseData['veterinarians'];
                final List<Veterinarian> veterinarians = veterinariansData.map((json) => Veterinarian.fromJson(json)).toList();

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
                                        ? Image.network(vet.profilePicture!, width: double.infinity, fit: BoxFit.cover)
                                        : Image.asset('assets/images/default_avatar.png', width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${vet.firstName} ${vet.lastName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 14),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${vet.averageRating.toStringAsFixed(1)}/5', // Directly display the averageRating from the API
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

  // Modify the _buildSectionHeader method
  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        // Replace 'See All' with the filter button
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.blue),
          onPressed: () {
            // You can call your filter logic here or navigate to a filter screen
            _showFilterDialog();
          },
        ),
      ],
    );
  }

// Method to show filter options (you can customize this)
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Veterinarians'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Rating'),
              DropdownButton<String>(
                value: ratingFilter,
                items: ['1', '2', '3', '4', '5'].map((String rating) {
                  return DropdownMenuItem<String>(
                    value: rating,
                    child: Text(rating),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    ratingFilter = value;
                    _refreshVeterinarians(1); // Refresh veterinarians with new filter
                  });
                  Navigator.pop(context); // Close dialog after selection
                },
              ),
              const SizedBox(height: 16),
              const Text('Filter by Location'),
              TextField(
                onChanged: (value) {
                  locationFilter = value;
                },
                decoration: const InputDecoration(hintText: 'Enter location'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _refreshVeterinarians(1); // Refresh veterinarians after applying filter
                  });
                  Navigator.pop(context); // Close dialog after applying filter
                },
                child: const Text('Apply Filters'),
              ),
            ],
          ),
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