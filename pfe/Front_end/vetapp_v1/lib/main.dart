import 'package:flutter/material.dart';
import 'screens/login.dart'; // Import the LoginScreen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login', // Set the initial route to '/login'
      routes: {
        '/login': (context) => LoginScreen(), // Define the route for the LoginScreen
      },
    );
  }
}