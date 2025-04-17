import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/services/vet_service.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                      Text(
                        "Welcome,",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Poppins', // Apply Poppins font
                        ),
                      ),
                      Text(
                        "Wade Warren",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins', // Apply Poppins font
                        ),
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
              // Discover Section with background image
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/vet2.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Overlay with content
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Text and Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Discover Top Vets\nin Your Area!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat', // Apply Montserrat font
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                            ),
                            child: Text(
                              'Discover',
                              style: TextStyle(
                                fontFamily: 'Poppins', // Apply Poppins font
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Services Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins', // Apply Poppins font
                    ),
                  ),
                  Text(
                    'See All',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontFamily: 'Poppins', // Apply Poppins font
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Custom Layout for Services Section
              Column(
                children: [
                  // First Row: 60% - 40%
                  SizedBox(
                    height: 150, // Fixed height for the row
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildServiceCard('Vaccinations', 'assets/images/vac.jpg'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildServiceCardWithFixedDimensions(
                            'Grooming',
                            'assets/images/grooming.jpg',
                            height: 150,
                            width: 100,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Second Row: 40% - 60%
                  SizedBox(
                    height: 150, // Fixed height for the row
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildServiceCardWithFixedDimensions(
                            'Walking',
                            'assets/images/walking.jpg',
                            height: 150,
                            width: 100,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: _buildServiceCard('Training', 'assets/images/training.jpg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Best Veterinarian Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Our best veterinarians',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins', // Apply Poppins font
                    ),
                  ),
                  Text(
                    'See All',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontFamily: 'Poppins', // Apply Poppins font
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Fetch and display the list of veterinarians
              FutureBuilder<List<Veterinarian>>(
                future: VetService.fetchVeterinarians(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No veterinarians found.'));
                  } else {
                    final veterinarians = snapshot.data!;
                    return ListView.builder(
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
                              child: vet.profilePicture == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          ),
                          title: Text(
                            '${vet.firstName} ${vet.lastName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins', // Apply Poppins font
                            ),
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
                                    style: TextStyle(
                                      fontFamily: 'Poppins', // Apply Poppins font
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    vet.workingHours ?? 'N/A',
                                    style: TextStyle(
                                      fontFamily: 'Poppins', // Apply Poppins font
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
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey,
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_rounded),
                label: 'Appointments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),

    );
  }

  static Widget _buildServiceCard(String title, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imageUrl,
            fit: BoxFit.cover,
          ),
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins', // Apply Poppins font
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildServiceCardWithFixedDimensions(String title, String imageUrl,
      {double height = 150, double width = 100}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: Image.asset(
              imageUrl,
              fit: BoxFit.cover,
            ),
          ),
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins', // Apply Poppins font
              ),
            ),
          ),
        ],
      ),
    );
  }
}