import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:vetapp_v1/services/pet_service.dart';

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _otherBreedController = TextEditingController(); // New controller for other breed
  String? _selectedSpecies;
  String? _selectedBreed;
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  File? _imageFile;
  late final PetService _petService;
  bool _isLoading = false;

  final List<String> speciesList = ['Dog', 'Cat', 'Rabbit', 'Bird', 'Hamster', 'Ferret', 'Guinea Pig', 'Fish'];

  final Map<String, List<String>> breedMap = {
    'Dog': ['Labrador', 'Poodle', 'Bulldog', 'Beagle', 'German Shepherd', 'Golden Retriever', 'Chihuahua', 'Rottweiler', 'Dachshund', 'Boxer', 'Other'],
    'Cat': ['Persian', 'Maine Coon', 'Siamese', 'Sphynx', 'Ragdoll', 'Bengal', 'British Shorthair', 'Scottish Fold', 'Abyssinian', 'American Shorthair', 'Other'],
    'Rabbit': ['Holland Lop', 'Mini Rex', 'Lionhead', 'Netherland Dwarf', 'Flemish Giant', 'Mini Lop', 'Rex', 'English Angora', 'Harlequin', 'Dutch', 'Other'],
    'Bird': ['Budgerigar', 'Cockatiel', 'Lovebird', 'Canary', 'Finch', 'Parrotlet', 'Conure', 'Amazon', 'African Grey', 'Macaw', 'Other'],
    'Hamster': ['Syrian', 'Dwarf Campbell', 'Winter White', 'Roborovski', 'Chinese', 'Teddy Bear', 'Russian Dwarf', 'Albino', 'Long-haired', 'Short-haired', 'Other'],
    'Ferret': ['Standard', 'Angora', 'Black-footed', 'Blaze', 'Sable', 'Albino', 'Champagne', 'Chocolate', 'Cinnamon', 'Panda', 'Other'],
    'Guinea Pig': ['Abyssinian', 'Peruvian', 'Silkie', 'American', 'Teddy', 'Texel', 'Coronet', 'White Crested', 'Rex', 'Baldwin', 'Other'],
    'Fish': ['Betta', 'Goldfish', 'Guppy', 'Neon Tetra', 'Angelfish', 'Discus', 'Molly', 'Platy', 'Corydoras', 'Zebra Danio', 'Other'],
  };

  @override
  void initState() {
    super.initState();
    Dio dio = Dio(BaseOptions(baseUrl: PetService.baseUrl + '/api'));
    _petService = PetService(dio: dio);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final file = File(image.path);
      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected image is invalid')),
        );
        return;
      }
      final sizeInMB = file.lengthSync() / 1024 / 1024;
      if (sizeInMB > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image size must be less than 5 MB')),
        );
        return;
      }
      final extension = image.path.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a JPEG or PNG image')),
        );
        return;
      }
      setState(() {
        _imageFile = file;
        print('Selected image: ${image.path}, size: $sizeInMB MB');
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      try {
        print('Starting pet creation...');
        print('Image file: ${_imageFile?.path}');
        if (_imageFile != null) {
          print('Image file exists: ${_imageFile!.existsSync()}');
          print('Image file size: ${_imageFile!.lengthSync() / 1024 / 1024} MB');
        }

        // Determine the breed to send
        String breedToSend = '';
        if (_selectedBreed == 'Other') {
          breedToSend = _otherBreedController.text.trim();
        } else if (_selectedBreed != null) {
          breedToSend = _selectedBreed!;
        }

        final response = await _petService.createPet(
          name: _nameController.text,
          species: _selectedSpecies!,
          breed: breedToSend,
          gender: _selectedGender,
          birthDate: _selectedBirthDate != null
              ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
              : null,
          imageFile: _imageFile,
        );

        print('AddPetScreen response: $response');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet added successfully!')),
        );

        Navigator.pop(context, response);
      } catch (e) {
        print('AddPetScreen error: $e');
        String errorMessage = 'Failed to add pet';
        if (e.toString().contains('DioException')) {
          errorMessage = e.toString().split('Exception: ').last;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF800080)),
      ),
      prefixIconColor: const Color(0xFF800080),
      suffixIconColor: const Color(0xFF800080),
    );

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
                        'Add New Pet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              _buildImagePickerSection(),
              Expanded(
                child: Container(
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
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Pet Name',
                                    prefixIcon: const Icon(Icons.pets),
                                  ),
                                  validator: (value) => value == null || value.trim().isEmpty
                                      ? 'Please enter a name'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  value: _selectedSpecies,
                                  items: speciesList.map((species) {
                                    return DropdownMenuItem<String>(
                                      value: species,
                                      child: Text(species),
                                    );
                                  }).toList(),
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Species',
                                    prefixIcon: const Icon(Icons.category),
                                  ),
                                  onChanged: (value) => setState(() {
                                    _selectedSpecies = value;
                                    _selectedBreed = null; // Reset breed when species changes
                                    _otherBreedController.clear(); // Clear other breed field
                                  }),
                                  validator: (value) => value == null ? 'Please select a species' : null,
                                ),
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  value: _selectedBreed,
                                  items: (_selectedSpecies != null ? breedMap[_selectedSpecies] ?? [] : [])
                                      .map((breed) {
                                    return DropdownMenuItem<String>(
                                      value: breed,
                                      child: Text(breed),
                                    );
                                  }).toList(),
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Breed (Optional)',
                                    prefixIcon: const Icon(Icons.pets),
                                  ),
                                  onChanged: _selectedSpecies != null
                                      ? (value) => setState(() {
                                    _selectedBreed = value;
                                    if (value != 'Other') {
                                      _otherBreedController.clear(); // Clear other breed field if not "Other"
                                    }
                                  })
                                      : null,
                                  validator: null, // Remove validation to make breed optional
                                ),
                                // Show other breed text field when "Other" is selected
                                if (_selectedBreed == 'Other') ...[
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _otherBreedController,
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Specify Other Breed',
                                      prefixIcon: const Icon(Icons.edit),
                                    ),
                                    validator: (value) => value == null || value.trim().isEmpty
                                        ? 'Please specify the breed'
                                        : null,
                                  ),
                                ],
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  items: ['Male', 'Female'].map((gender) {
                                    return DropdownMenuItem<String>(
                                      value: gender,
                                      child: Text(gender),
                                    );
                                  }).toList(),
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Gender',
                                    prefixIcon: const Icon(Icons.transgender),
                                  ),
                                  onChanged: (value) => setState(() => _selectedGender = value),
                                ),
                                const SizedBox(height: 24),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Birth Date',
                                      suffixIcon: const Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      _selectedBirthDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
                                          : 'Select birth date',
                                      style: TextStyle(
                                        color: _selectedBirthDate != null
                                            ? Colors.black
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildSubmitButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : const AssetImage('assets/default_pet.png'),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Color(0xFF800080)),
              onPressed: _pickImage,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return InkWell(
      onTap: _isLoading ? null : _submit,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0xFF800080).withOpacity(0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF800080), Color(0xFF4B0082)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
            'ADD PET',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _otherBreedController.dispose(); // Dispose the new controller
    super.dispose();
  }
}