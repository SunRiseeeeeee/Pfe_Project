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
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  File? _imageFile;
  late final PetService _petService;

  @override
  void initState() {
    super.initState();
    Dio dio = Dio(BaseOptions(baseUrl: PetService.baseUrl + '/api'));
    _petService = PetService(dio: dio);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
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
      try {
        print('Starting pet creation...');
        print('Image file: ${_imageFile?.path}');
        if (_imageFile != null) {
          print('Image file exists: ${_imageFile!.existsSync()}');
          print('Image file size: ${_imageFile!.lengthSync() / 1024 / 1024} MB');
        } else {
          print('No image selected');
        }

        final response = await _petService.createPet(
          name: _nameController.text,
          species: _speciesController.text,
          breed: _breedController.text,
          gender: _selectedGender,
          birthDate: _selectedBirthDate?.toIso8601String(),
          imageFile: _imageFile,
        );

        print('AddPetScreen response: $response');
        print('Returned pet picture: ${response['picture']}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet added successfully!')),
        );

        Navigator.pop(context, response);
      } catch (e) {
        print('AddPetScreen error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add pet: $e')),
        );
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
                                  validator: (value) => value == null || value.isEmpty
                                      ? 'Please enter a name'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _speciesController,
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Species',
                                    prefixIcon: const Icon(Icons.category),
                                  ),
                                  validator: (value) => value == null || value.isEmpty
                                      ? 'Please enter the species'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _breedController,
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Breed',
                                    prefixIcon: const Icon(Icons.pets),
                                  ),
                                  validator: (value) => value == null || value.isEmpty
                                      ? 'Please enter the breed'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  items: ['Male', 'Female'].map((gender) {
                                    return DropdownMenuItem(
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
      onTap: _submit,
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
        child: const Center(
          child: Text(
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
    _speciesController.dispose();
    _breedController.dispose();
    super.dispose();
  }
}