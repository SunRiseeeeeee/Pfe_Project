import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/services/pet_service.dart';
import 'package:vetapp_v1/screens/AddPetScreen.dart';
import 'package:dio/dio.dart';
import 'dart:io' show File;

import 'PetDetailsScreen.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  Future<List<Map<String, dynamic>>>? _petsFuture;
  final PetService _petService = PetService(dio: Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')));

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  void _loadPets() {
    setState(() {
      _petsFuture = _petService.getUserPets();
    });
  }

  Future<void> _refreshPets() async {
    _loadPets();
  }

  void _navigateToAddPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPetScreen()),
    );
    if (result != null) {
      _refreshPets();
    }
  }

  // Method to determine the correct ImageProvider for pet pictures
  ImageProvider getPetPictureProvider(String? picture) {
    debugPrint('Loading pet picture: $picture');
    if (picture == null || picture.isEmpty) {
      return const AssetImage('assets/default_pet.png');
    }
    // Check if the picture is a local file path
    if (picture.startsWith('/data/') || picture.startsWith('file://')) {
      final path = picture.startsWith('file://') ? picture.substring(7) : picture;
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      } else {
        debugPrint('Local pet picture does not exist: $path');
        return const AssetImage('assets/default_pet.png');
      }
    }
    // Use NetworkImage for remote URLs
    return NetworkImage(picture);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: Center(
            child: Text(
              'My Pets',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ),
      ),
      body: _petsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
        future: _petsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no pets.'));
          }

          final pets = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshPets,
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.9,
              ),
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetDetailsScreen(pet: pet),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: getPetPictureProvider(pet['picture']),
                          backgroundColor: Colors.grey[200],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pet['name'] ?? 'Unnamed',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPet,
        backgroundColor: Colors.purple[80],
        child: const Icon(Icons.add),
        tooltip: 'Add Pet',
      ),
    );
  }
}