import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'EditProfileScreen.dart';
import 'login.dart';
import 'secretary_screen.dart';
import 'add_admin_screen.dart';
import 'add_veterinary_screen.dart';
import '../models/token_storage.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;
  bool isVeterinarian = false;
  bool isAdmin = false;

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
      print("Fetched user data: $data");

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

  Future<void> _initializeVeterinarianStatus() async {
    try {
      final role = await TokenStorage.getUserRoleFromToken();
      print('ProfileScreen: User role: $role');
      setState(() {
        isVeterinarian = role != null && ['veterinaire', 'veterinarian'].contains(role.toLowerCase());
      });
    } catch (e) {
      print('ProfileScreen: Error fetching role: $e');
    }
  }

  Future<void> _initializeAdminStatus() async {
    try {
      final role = await TokenStorage.getUserRoleFromToken();
      print('ProfileScreen: User role: $role');
      setState(() {
        isAdmin = role != null && role.toLowerCase() == 'admin';
      });
    } catch (e) {
      print('ProfileScreen: Error fetching admin role: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final userId = await _getUserIdFromPrefs();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found")));
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

  Future<void> _changePassword() async {
    String? email = await TokenStorage.getEmailFromToken();
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to retrieve email. Please log in again.")));
      return;
    }

    bool isCodeInput = false;
    String dialogErrorMessage = '';
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(isCodeInput ? 'Enter Verification Code' : 'Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isCodeInput
                      ? 'Enter the verification code sent to $email.'
                      : 'A verification code will be sent to $email.'),
                  const SizedBox(height: 16),
                  if (isCodeInput)
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        hintText: 'Verification Code',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                        errorText: dialogErrorMessage.isNotEmpty ? dialogErrorMessage : null,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() {
                      dialogErrorMessage = '';
                    });

                    if (!isCodeInput) {
                      try {
                        final response = await _authService.forgetPassword(email);
                        if (response['success']) {
                          setDialogState(() {
                            isCodeInput = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response['message'])),
                          );
                        } else {
                          setDialogState(() {
                            dialogErrorMessage = response['message'];
                          });
                        }
                      } catch (error) {
                        setDialogState(() {
                          dialogErrorMessage = 'An error occurred. Please try again.';
                        });
                      }
                    } else {
                      String code = codeController.text.trim();
                      if (code.isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage = 'Code is required';
                        });
                        return;
                      }

                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordPage(email: email, code: code),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isCodeInput ? 'Verify Code' : 'Send Code', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Function to launch Google Maps with the mapsLocation
  Future<void> _launchMaps(String? mapsLocation) async {
    if (mapsLocation == null || mapsLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No location data available")),
      );
      return;
    }

    String mapsUrl;
    // Check if mapsLocation is a Google Maps URL
    if (mapsLocation.startsWith('http')) {
      mapsUrl = mapsLocation;
    } else {
      // Assume it's coordinates (e.g., "40.7128,-74.0060")
      final coords = mapsLocation.split(',');
      if (coords.length == 2) {
        final lat = coords[0].trim();
        final lng = coords[1].trim();
        mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid location format")),
        );
        return;
      }
    }

    final uri = Uri.parse(mapsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Google Maps")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Google Maps: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    _initializeVeterinarianStatus();
    _initializeAdminStatus();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

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
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileHeader(context),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (errorMessage != null)
                        Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
                      else ...[
                          _buildSectionTitle('Personal Information', context),
                          _buildInfoRow(Icons.person, 'Full Name', '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}', context),
                          _buildInfoRow(Icons.email, 'Email', userData?['email'] ?? '', context),
                          _buildInfoRow(Icons.phone, 'Phone', userData?['phoneNumber'] ?? '', context),
                          _buildInfoRow(
                            Icons.location_on,
                            'Location',
                            _formatAddress(userData?['address']), // Display formatted address
                            context,
                            onTap: () => _launchMaps(userData?['mapsLocation']), // Launch mapsLocation on tap
                          ),
                          if (isVeterinarian) ...[
                            const SizedBox(height: 24),
                            _buildVeterinarianSection(context),
                          ],
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
                          if (isVeterinarian)
                            _buildActionButton(Icons.person_add, 'My Secretary', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SecretaryScreen()),
                              );
                            }, context),
                          if (isAdmin)
                            _buildActionButton(Icons.admin_panel_settings, 'Add New Admin', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddAdminScreen()),
                              );
                            }, context),
                          if (isAdmin)
                            _buildActionButton(Icons.medical_services, 'Add Veterinary', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddVeterinaryScreen()),
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
                                const SnackBar(content: Text("Logged out successfully")),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logout failed: $e')),
                              );
                            }
                          }, context),
                          _buildActionButton(Icons.lock, 'Change Password', _changePassword, context),
                          _buildActionButton(Icons.delete, 'Delete Your Account', deleteAccount, context),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Format address for display
  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Not specified';
    final parts = [
      address['street'] ?? '',
      address['city'] ?? '',
      address['state'] ?? '',
      address['country'] ?? '',
      address['postalCode'] ?? '',
    ].where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Not specified';
  }

  Widget _buildProfileHeader(BuildContext context) {
    String? profileUrl = userData?['profilePicture'];
    if (profileUrl != null && profileUrl.contains('localhost')) {
      profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.16');
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                ? FileImage(File(profileUrl))
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Color(0xFF800080)),
              onPressed: () {
                // Add logic to change profile picture
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVeterinarianSection(BuildContext context) {
    final details = userData?['details'] ?? {};
    final specialization = details['specialization'] ?? 'Not specified';
    final services = (details['services'] as List<dynamic>?)?.join(', ') ?? 'Not specified';
    final workingHours = List<Map<String, dynamic>>.from(details['workingHours'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Veterinarian Details', context),
        const Divider(color: Colors.grey, thickness: 0.5),
        _buildInfoRow(Icons.medical_services, 'Specialization', specialization, context),
        _buildInfoRow(Icons.list, 'Services', services, context),
        const SizedBox(height: 12),
        _buildSectionTitle('Working Hours', context),
        const Divider(color: Colors.grey, thickness: 0.5),
        if (workingHours.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No working hours specified',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        else
          ...workingHours.map((workingHour) {
            final day = workingHour['day'] ?? 'Unknown';
            final start = workingHour['start'] ?? 'N/A';
            final end = workingHour['end'] ?? 'N/A';
            final pauseStart = workingHour['pauseStart'];
            final pauseEnd = workingHour['pauseEnd'];
            final pause = (pauseStart != null && pauseEnd != null) ? 'Pause: $pauseStart - $pauseEnd' : 'No pause';
            final hoursText = '$day: $start - $end, $pause';

            return _buildInfoRow(Icons.access_time, 'Hours', hoursText, context);
          }).toList(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0xFF800080).withOpacity(0.2),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF800080), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isNotEmpty ? value : 'Not specified',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceRow(IconData icon, String label, bool isEnabled, Function(bool)? onChanged, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF800080), size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ],
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: const Color(0xFF800080),
            activeTrackColor: const Color(0xFF800080).withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0xFF800080).withOpacity(0.2),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF800080), Color(0xFF4B0082)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}