import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:vetapp_v1/services/auth_service.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // User data fetched from the API
  Map<String, dynamic>? userData;
  bool isLoading = true; // Loading state for the API call
  String? errorMessage; // Error message if the API call fails

  // Fetch user details from the API using the stored userId
  Future<void> fetchUserDetails(String userId) async {
    final url = Uri.parse('http://192.168.1.18:3000/api/users/$userId');
    try {
      final response = await Dio().get(url.toString());

      if (response.statusCode == 200) {
        // Parse the JSON response
        setState(() {
          userData = response.data;
          isLoading = false;
        });
      } else {
        // Handle HTTP errors
        setState(() {
          errorMessage = 'Failed to load user details. Status Code: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle exceptions (e.g., network errors)
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }

  // Retrieve the userId from SharedPreferences
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  @override
  void initState() {
    super.initState();
    // Fetch the userId and then fetch user details
    getUserId().then((userId) {
      if (userId != null) {
        fetchUserDetails(userId);
      } else {
        setState(() {
          errorMessage = 'User ID not found. Please log in again.';
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background color
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple, // Match the app's primary color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              )
            else ...[
                // Profile Header Section
                _buildProfileHeader(),
                const SizedBox(height: 24),

                // Personal Information Section
                _buildSectionTitle('Personal Information'),
                _buildInfoRow(Icons.person, 'Full Name', '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'),
                _buildInfoRow(Icons.email, 'Email', userData?['email'] ?? ''),
                _buildInfoRow(Icons.phone, 'Phone', userData?['phoneNumber'] ?? ''),
                const SizedBox(height: 24),

                // Preferences Section
                _buildSectionTitle('Preferences'),
                _buildPreferenceRow(Icons.notifications, 'Notifications', userData?['notificationsEnabled'] ?? false),
                _buildPreferenceRow(Icons.dark_mode, 'Dark Mode', userData?['darkModeEnabled'] ?? false),
                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButton(Icons.edit, 'Edit Profile', () {
                  // Navigate to Edit Profile Screen
                  print('Edit Profile Button Pressed');
                }),
                _buildActionButton(Icons.logout, 'Log Out', () async {
                  try {
                    final authService = AuthService(); // Create an instance of AuthService

                    // Call the logout method
                    await authService.logout();

                    // Navigate to the LoginPage and clear the stack
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false, // Remove all previous routes
                    );

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Logged out successfully")),
                    );
                  } catch (e) {
                    // Show an error message if logout fails
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }),
              ],
          ],
        ),
      ),
    );
  }

  // Profile Header Widget
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: userData?['profilePicture'] != null
                ? NetworkImage(userData!['profilePicture'])
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
          ),
          const SizedBox(height: 12),
          Text(
            '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            userData?['email'] ?? '',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
    );
  }

  // Info Row Widget
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Preference Row Widget
  Widget _buildPreferenceRow(IconData icon, String label, bool isEnabled) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Switch(
            value: isEnabled,
            onChanged: (value) {
              // Handle preference toggle
              print('$label toggled to $value');
            },
            activeColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  // Action Button Widget
  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}