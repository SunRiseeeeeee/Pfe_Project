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
  final PetService _petService = PetService(dio: Dio(BaseOptions(baseUrl: 'http://192.168.100.7:3000/api')));

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
    setState(() {
      _petsFuture = _petService.getUserPets(); // Ensure this fetches new pets
    });
  }

  void _navigateToAddPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPetScreen()),
    );
    if (result != null) {
      debugPrint('AddPetScreen returned: $result'); // Debug to confirm return
      _refreshPets();
    }
  }

  Widget getPetPictureWidget(String? picture) {
    debugPrint('Loading pet picture: $picture');
    String? pictureUrl = picture;
    // Replace localhost and old IP with current IP for network URLs
    if (pictureUrl != null) {
      if (pictureUrl.contains('localhost')) {
        pictureUrl = pictureUrl.replaceFirst('localhost', '192.168.100.7');
      }
      if (pictureUrl.contains('192.168.1.18')) {
        pictureUrl = pictureUrl.replaceFirst('192.168.1.18', '192.168.100.7');
      }
    }
    return pictureUrl != null && pictureUrl.isNotEmpty
        ? pictureUrl.startsWith('http')
        ? Image.network(
      pictureUrl,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Pet network image error for $pictureUrl: $error');
        return Image.asset(
          'assets/default_pet.png', // Reverted to original asset path
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Pet asset error: $error');
            return Container(
              width: 100,
              height: 100,
              color: Colors.grey,
              child: const Icon(Icons.pets, color: Colors.white),
            );
          },
        );
      },
    )
        : Image.file(
      File(pictureUrl),
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Pet file image error for $pictureUrl: $error');
        return Image.asset(
          'assets/default_pet.png', // Reverted to original asset path
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Pet asset error: $error');
            return Container(
              width: 100,
              height: 100,
              color: Colors.grey,
              child: const Icon(Icons.pets, color: Colors.white),
            );
          },
        );
      },
    )
        : Image.asset(
      'assets/default_pet.png', // Reverted to original asset path
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Pet asset error: $error');
        return Container(
          width: 100,
          height: 100,
          color: Colors.grey,
          child: const Icon(Icons.pets, color: Colors.white),
        );
      },
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Custom Header with Back Arrow
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'My Pets',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Content Section
                Container(
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
                  padding: const EdgeInsets.all(20),
                  child: _petsFuture == null
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
                          padding: const EdgeInsets.all(0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: pets.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
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
                                    ClipOval(
                                      child: getPetPictureWidget(pet['picture']),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      pet['name'] ?? 'Unnamed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF800080),
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
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: InkWell(
        onTap: _navigateToAddPet,
        borderRadius: BorderRadius.circular(28),
        splashColor: const Color(0xFF800080).withOpacity(0.2),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF800080), Color(0xFF4B0082)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}