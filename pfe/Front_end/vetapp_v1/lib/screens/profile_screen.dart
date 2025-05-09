import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'EditProfileScreen.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  Future<String?> _getUserIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<void> fetchUserDetails() async {
    try {
      final userId = await _getUserIdFromPrefs();
      if (userId == null) {
        setState(() {
          errorMessage = 'User ID not found. Please log in again.';
          isLoading = false;
        });
        return;
      }

      final data = await _userService.getUserById(userId);
      print("Fetched user data: $data");  // Print the full response

      setState(() {
        userData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });
    }
  }


  Future<void> deleteAccount() async {
    try {
      final userId = await _getUserIdFromPrefs();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID not found")));
        return;
      }

      await _userService.deleteUser();
      await _authService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deleted successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
            else ...[
                _buildProfileHeader(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Personal Information', context),
                _buildInfoRow(Icons.person, 'Full Name', '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}', context),
                _buildInfoRow(Icons.email, 'Email', userData?['email'] ?? '', context),
                _buildInfoRow(Icons.phone, 'Phone', userData?['phoneNumber'] ?? '', context),
                _buildInfoRow(
                    Icons.location_on,
                    'Location',
                    '${userData?['address']?['street'] ?? ''}, ${userData?['address']?['city'] ?? ''}, ${userData?['address']?['state'] ?? ''}, ${userData?['address']?['country'] ?? ''}, ${userData?['address']?['postalCode'] ?? ''}',
                    context
                ),


                const SizedBox(height: 24),
                _buildSectionTitle('Preferences', context),
                _buildPreferenceRow(Icons.notifications, 'Notifications', userData?['notificationsEnabled'] ?? false, null, context),
                _buildPreferenceRow(
                  Icons.dark_mode,
                  'Dark Mode',
                  isDarkMode,
                      (value) => themeProvider.toggleTheme(value),
                  context,
                ),
                const SizedBox(height: 24),
                _buildActionButton(Icons.edit, 'Edit Profile', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                }, context),
                _buildActionButton(Icons.logout, 'Log Out', () async {
                  try {
                    await _authService.logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Logged out successfully")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')));
                  }
                }, context),
                _buildActionButton(Icons.delete, 'Delete Your Account', deleteAccount, context),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    String? profileUrl = userData?['profilePicture'];
    if (profileUrl != null && profileUrl.contains('localhost')) {
      profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.18');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          profileUrl != null && profileUrl.isNotEmpty
              ? CircleAvatar(
            radius: 50,
            backgroundImage:  FileImage(File(profileUrl)),
          )
              : const CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage('assets/images/default_avatar.png'),
          ),
          const SizedBox(height: 12),
          Text(
            '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            userData?['email'] ?? '',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14),
          ),
          if (profileUrl == null || profileUrl.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Profile picture is missing',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(IconData icon, String label, bool isEnabled, Function(bool)? onChanged, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
