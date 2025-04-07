import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/auth_service.dart'; // Import your AuthService
import 'login.dart'; // Import your LoginPage

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers for input fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();

  // Authentication service instance
  final AuthService _authService = AuthService();

  // Error message to display
  String _errorMessage = '';

  // Function to handle sign-up
  Future<void> _signUp() async {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String phoneNumber = _phoneNumberController.text.trim();
    String location = _locationController.text.trim();
    String specialty = _specialtyController.text.trim();
    String workingHours = _workingHoursController.text.trim();

    // Validate input
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = "All fields are required";
      });
      return;
    }

    try {
      // Call the register function with user details
      Map<String, dynamic> response = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        username: username,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        profilePicture: "", // Optional field
        location: location,
        specialty: specialty.isNotEmpty ? specialty : null,
        workingHours: workingHours.isNotEmpty ? workingHours : null,
        role: "CLIENT", // Default role, or you can make this dynamic
      );

      if (response["success"]) {
        // Show success message and navigate to login page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"])),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        // Show an error message if registration fails
        setState(() {
          _errorMessage = response["message"];
        });
      }
    } catch (error) {
      // Handle unexpected errors
      setState(() {
        _errorMessage = "An error occurred. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Title
              Text(
                'VetApp',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // First Name Field
              TextField(
                controller: _firstNameController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'First Name',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Last Name Field
              TextField(
                controller: _lastNameController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Last Name',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Username Field
              TextField(
                controller: _usernameController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Username',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Email Field
              TextField(
                controller: _emailController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Email',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Phone Number Field
              TextField(
                controller: _phoneNumberController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Phone Number',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Location Field
              TextField(
                controller: _locationController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Location',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Specialty Field (Optional)
              TextField(
                controller: _specialtyController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Specialty (Optional)',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Working Hours Field (Optional)
              TextField(
                controller: _workingHoursController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Working Hours (Optional)',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.purple),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sign Up Button
              Container(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text('Sign Up', style: TextStyle(fontSize: 18)),
                ),
              ),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(fontSize: 16, color: Colors.red[200]),
                  ),
                ),

              SizedBox(height: 20),

              // Login Link
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: Text(
                  "Already have an account? Log In",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
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