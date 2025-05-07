import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart'; // Add this import

void main() {
  runApp(
    Provider<Dio>(
      create: (_) => Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')), // <-- Set your actual API base URL
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
    );
  }
}
