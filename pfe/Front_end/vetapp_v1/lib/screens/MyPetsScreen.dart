
import 'package:flutter/material.dart';

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
      ),
      body: const Center(
        child: Text('Pets Screen Content'),
      ),
    );
  }
}