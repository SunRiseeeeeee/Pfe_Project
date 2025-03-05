import 'package:flutter/material.dart';
import 'package:vetapp_v1/screens/home_screen.dart';
import 'package:vetapp_v1/services/auth_service.dart';

// String Extension for Capitalize
extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedRole = "client";
  String _errorMessage = '';
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Role Selection Dropdown
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items: ["client", "veterinaire", "secrétaire", "admin"]
                  .map((role) => DropdownMenuItem(
                value: role,
                child: Text(role.capitalize()),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Role'),
            ),
            SizedBox(height: 10),

            // Common Fields
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            SizedBox(height: 10),

            // Role-Specific Fields
            if (_selectedRole == "veterinaire" ||
                _selectedRole == "secrétaire" ||
                _selectedRole == "client" ||
                _selectedRole == "admin")
              TextField(
                controller: _phoneNumberController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            if (_selectedRole == "veterinaire")
              TextField(
                controller: _specialtyController,
                decoration: InputDecoration(labelText: 'Specialty'),
              ),
            if (_selectedRole == "veterinaire" || _selectedRole == "secrétaire")
              TextField(
                controller: _workingHoursController,
                decoration: InputDecoration(labelText: 'Working Hours'),
              ),
            if (_selectedRole == "client")
              TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Location'),
              ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signUp,
              child: Text('Sign Up'),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Function to handle signup
  Future<void> _signUp() async {
    String firstName = _firstNameController.text;
    String lastName = _lastNameController.text;
    String username = _usernameController.text;
    String email = _emailController.text;
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;
    String phoneNumber = _phoneNumberController.text;
    String specialty = _specialtyController.text;
    String workingHours = _workingHoursController.text;
    String location = _locationController.text;

    // Basic validation
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = "All common fields are required";
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = "Passwords do not match";
      });
      return;
    }

    // Role-specific validation
    if (_selectedRole == "veterinaire" || _selectedRole == "secrétaire" || _selectedRole == "client" || _selectedRole == "admin") {
      if (phoneNumber.isEmpty) {
        setState(() {
          _errorMessage = "Phone number is required for this role";
        });
        return;
      }
    }

    if (_selectedRole == "veterinaire" || _selectedRole == "secrétaire") {
      if (workingHours.isEmpty) {
        setState(() {
          _errorMessage = "Working hours are required for this role";
        });
        return;
      }
    }

    if (_selectedRole == "veterinaire" && specialty.isEmpty) {
      setState(() {
        _errorMessage = "Specialty is required for veterinarians";
      });
      return;
    }

    if (_selectedRole == "client" && location.isEmpty) {
      setState(() {
        _errorMessage = "Location is required for clients";
      });
      return;
    }

    // Call the appropriate signup method in AuthService
    Map<String, dynamic> response;
    switch (_selectedRole) {
      case "client":
        response = await _authService.signUpClient(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          phoneNumber: phoneNumber,
          location: location,
        );
        break;
      case "veterinaire":
        response = await _authService.signUpVeterinaire(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          phoneNumber: phoneNumber,
          specialty: specialty,
          workingHours: workingHours,
        );
        break;
      case "secrétaire":
        response = await _authService.signUpSecretaire(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          phoneNumber: phoneNumber,
          workingHours: workingHours,
        );
        break;
      case "admin":
        response = await _authService.signUpAdmin(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          phoneNumber: phoneNumber,
        );
        break;
      default:
        setState(() {
          _errorMessage = "Invalid role selected";
        });
        return;
    }

    if (response["success"]) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      // Show an error message if signup fails
      setState(() {
        _errorMessage = response["message"] ?? "Signup failed";
      });
    }
  }
}