import 'package:flutter/material.dart';
import 'package:vetapp_v1/screens/home_screen.dart';
import 'package:vetapp_v1/screens/signup.dart';

import 'package:vetapp_v1/services/auth_service.dart'; // Import your AuthService class

void main() {
  runApp(LoginScreen());
}

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Login Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _errorMessage = ''; // To display error messages

  // Updated login function
  Future<void> _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    // Call the login function with username and password only
    Map<String, dynamic> response = await _authService.login(username, password);

    if (response["success"]) {
      // Navigate to the HomePage on successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      // Show an error message if login fails
      setState(() {
        _errorMessage = response["message"] ?? "Login failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
            SizedBox(height: 20), // Add spacing before the Sign Up link
            TextButton(
              onPressed: () {
                // Navigate to the SignUpPage when the link is tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              child: Text(
                "Don't have an account? Sign Up",
                style: TextStyle(
                  color: Colors.blue, // Link color
                  decoration: TextDecoration.underline, // Underline for link appearance
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}