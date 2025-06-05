import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/services/pet_service.dart';
import 'package:dio/dio.dart';
import 'AddPetScreen.dart';
import 'PetDetailsScreen.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  Future<List<Map<String, dynamic>>>? _petsFuture;
  final PetService _petService = PetService(dio: Dio(BaseOptions(baseUrl: PetService.baseUrl + '/api')));

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
      _petsFuture = _petService.getUserPets();
    });
  }

  void _navigateToAddPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPetScreen()),
    );
    if (result != null) {
      debugPrint('AddPetScreen returned: $result');
      _refreshPets();
    }
  }

  Widget getPetPictureWidget(String? imageUrl) {
    debugPrint('Loading pet picture from URL: $imageUrl');

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.pets, color: Colors.grey, size: 40),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 80,
        height: 80,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Pet image error: $error, URL: $imageUrl');
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Colors.grey, size: 40),
            );
          },
        ),
      ),
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
                        debugPrint('Fetch error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: ${snapshot.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPets,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
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
                            childAspectRatio: 0.85,
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
                                    getPetPictureWidget(pet['imageUrl']),
                                    const SizedBox(height: 12),
                                    Text(
                                      pet['name'] ?? 'Unnamed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF800080),
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPet,
        backgroundColor: const Color(0xFF800080),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}