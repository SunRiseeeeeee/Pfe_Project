import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/secretary_service.dart';

class EditSecretaryScreen extends StatefulWidget {
  final Secretary secretary;

  const EditSecretaryScreen({Key? key, required this.secretary}) : super(key: key);

  @override
  _EditSecretaryScreenState createState() => _EditSecretaryScreenState();
}

class _EditSecretaryScreenState extends State<EditSecretaryScreen> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController usernameController; // Read-only
  late TextEditingController passwordController;
  File? selectedImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current secretary data
    firstNameController = TextEditingController(text: widget.secretary.firstName);
    lastNameController = TextEditingController(text: widget.secretary.lastName);
    emailController = TextEditingController(text: widget.secretary.email ?? '');
    phoneController = TextEditingController(text: widget.secretary.phoneNumber ?? '');
    usernameController = TextEditingController(text: widget.secretary.username ?? '');
    passwordController = TextEditingController(); // Empty for security
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final extension = pickedFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an image file (jpg, jpeg, png, gif)', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final file = File(pickedFile.path);
      final exists = await file.exists();
      final length = exists ? await file.length() : 0;

      setState(() {
        selectedImage = file;
      });

      debugPrint('Selected image: ${pickedFile.path}, Extension: $extension, Exists: $exists, Size: $length bytes');
    }
  }

  Future<void> _updateSecretary() async {
    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final secretaryData = <String, dynamic>{
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'phoneNumber': phoneController.text.trim(),
        // Note: username is intentionally excluded from updates
      };

      // Only include password if it's not empty
      if (passwordController.text.trim().isNotEmpty) {
        secretaryData['password'] = passwordController.text.trim();
      }

      final updatedSecretary = await SecretaryService().updateSecretary(
        widget.secretary.id,
        secretaryData,
        selectedImage,
      );

      Navigator.pop(context, updatedSecretary);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Secretary updated successfully', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating secretary: $e', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildProfileImage() {
    String? profileUrl = widget.secretary.profilePicture;
    if (profileUrl != null && profileUrl.contains('localhost')) {
      profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.16');
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF800080), width: 2),
        ),
        child: ClipOval(
          child: selectedImage != null
              ? Image.file(selectedImage!, fit: BoxFit.cover)
              : profileUrl != null && profileUrl.isNotEmpty
              ? profileUrl.startsWith('http')
              ? Image.network(
            profileUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF800080)),
              );
            },
          )
              : Image.file(
            File(profileUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF800080)),
              );
            },
          )
              : Container(
            color: Colors.grey[200],
            child: const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF800080)),
          ),
        ),
      ),
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
              // Custom Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Edit Secretary',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                child: Container(
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile Image
                        _buildProfileImage(),
                        const SizedBox(height: 24),

                        // First Name Field
                        TextField(
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF800080)),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 16),

                        // Last Name Field
                        TextField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF800080)),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 16),

                        // Email Field (Editable)
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF800080)),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Phone Number Field
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF800080)),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Username Field (Read-only)
                        TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username (Cannot be changed)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[100],
                            suffixIcon: const Icon(Icons.lock, color: Colors.grey),
                          ),
                          style: GoogleFonts.poppins(color: Colors.grey),
                          enabled: false, // Makes the field read-only
                        ),
                        const SizedBox(height: 16),

                        // Password Field (Editable)
                        TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'New Password (Leave empty to keep current)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: GoogleFonts.poppins(),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF800080)),
                            ),
                            suffixIcon: const Icon(Icons.lock_outline),
                          ),
                          style: GoogleFonts.poppins(),
                          obscureText: true,
                        ),
                        const SizedBox(height: 32),

                        // Update Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF800080), Color(0xFF4B0082)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _updateSecretary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'Update Secretary',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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