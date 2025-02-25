import 'package:flutter/material.dart';
import 'screens/login.dart'; // Import the LoginScreen
import 'screens/home_screen.dart';  // Import the HomeScreen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login', // Start with the login screen
      routes: {
        '/login': (context) => LoginScreen(), // Route for the login screen
        '/home': (context) => HomeScreen(),  // Route for the home screen
      },
    );
  }
}