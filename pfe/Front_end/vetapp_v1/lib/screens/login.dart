import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp_v1/screens/signup.dart';
import 'package:vetapp_v1/services/auth_service.dart'; // Import your AuthService
import 'home_screen.dart'; // Import your HomeScreen

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for input fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Authentication service instance
  final AuthService _authService = AuthService();

  // Error message to display
  String _errorMessage = '';

  // Function to handle login
  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    // Validate input
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Username and password are required";
      });
      return;
    }

    try {
      // Call the login function with username and password
      Map<String, dynamic> response = await _authService.login(username, password);

      if (response["success"]) {
        // Extract user details from the response
        final userId = response["data"]["userId"];
        final email = response["data"]["email"];
        final accessToken = response["data"]["accessToken"];
        final refreshToken = response["data"]["refreshToken"];

        // Save user data locally
        await _saveUserData(userId, email, accessToken, refreshToken);

        // Navigate to the HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(), // No parameters passed here
          ),
        );
      } else {
        // Show an error message if login fails
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

  // Save user data locally using SharedPreferences
  Future<void> _saveUserData(String userId, String email, String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('email', email);
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
              'Login',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),

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
            SizedBox(height: 20),

            // Login Button
            Container(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('Login', style: TextStyle(fontSize: 18)),
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

            // Sign Up Link
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              child: Text(
                "Don't have an account? Sign Up",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}