import 'package:flutter/material.dart';

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
                    children: const [
                      Text("Welcome,", style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text("Wade Warren", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: Icon(Icons.search), onPressed: () {}),
                      IconButton(icon: Icon(Icons.notifications_none), onPressed: () {}),
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
                          const Text(
                            'Discover Top Vets\nin Your Area!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                            child: const Text('Discover'),
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
                children: const [
                  Text('Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('See All', style: TextStyle(color: Colors.blue)),
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
                          child: _buildServiceCardWithFixedDimensions('Grooming', 'assets/images/grooming.jpg', height: 150, width: 100),
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
                          child: _buildServiceCardWithFixedDimensions('Walking', 'assets/images/walking.jpg', height: 150, width: 100),
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

              // Best Veterinarian
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Our best veterinarian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('See All', style: TextStyle(color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('assets/images/manage_health.png'),
                ),
                title: const Text('Cameron Williamson', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Veterinary Behavioral'),
              ),
              Row(
                children: const [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text('4.5'),
                  SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 18),
                  SizedBox(width: 4),
                  Text('3 Years'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointment',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Message',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  static Widget _buildServiceCard(String title, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox(
            width: double.infinity, // Ensure the image takes up the available width
            height: 150, // Set a fixed height for the image
            child: Image.asset(imageUrl, fit: BoxFit.cover),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildServiceCardWithFixedDimensions(String title, String imageUrl, {double height = 150, double width = 100}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox(
            width: width, // Explicit width
            height: height, // Explicit height
            child: Image.asset(imageUrl, fit: BoxFit.cover),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}