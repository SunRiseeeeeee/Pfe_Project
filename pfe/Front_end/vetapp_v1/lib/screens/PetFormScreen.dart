import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:vetapp_v1/services/pet_service.dart';

class PetFormScreen extends StatefulWidget {
  final Map<String, dynamic> existingPet;
  final bool isEditing;

  const PetFormScreen({super.key, required this.existingPet, required this.isEditing});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PetService _petService = PetService(dio: Dio(BaseOptions(baseUrl: PetService.baseUrl + '/api')));

  late TextEditingController _nameController;
  late TextEditingController _speciesController;
  late TextEditingController _breedController;
  late TextEditingController _genderController;
  late TextEditingController _birthDateController;

  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingPet['name']?.toString());
    _speciesController = TextEditingController(text: widget.existingPet['species']?.toString());
    _breedController = TextEditingController(text: widget.existingPet['breed']?.toString());
    _genderController = TextEditingController(text: widget.existingPet['gender']?.toString());
    _birthDateController = TextEditingController(
      text: widget.existingPet['birthDate'] != null
          ? widget.existingPet['birthDate'].toString().split('T')[0]
          : '',
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final extension = picked.path.split('.').last.toLowerCase();
      final sizeMB = file.lengthSync() / 1024 / 1024;
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a JPEG or PNG image')),
        );
        return;
      }
      if (sizeMB > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image size must be less than 5 MB')),
        );
        return;
      }
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        final birthDate = _birthDateController.text.isNotEmpty ? _birthDateController.text : null;
        await _petService.updatePet(
          petId: widget.existingPet['id'].toString(),
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          breed: _breedController.text.trim(),
          gender: _genderController.text.isNotEmpty ? _genderController.text.trim() : null,
          birthDate: birthDate,
          imageFile: _selectedImage,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet updated successfully')),
          );
          Navigator.pop(context, true); // Return true to trigger refresh in PetsScreen
        }
      } catch (e) {
        String errorMessage = 'Failed to update pet';
        if (e is DioException && e.response != null) {
          errorMessage = e.response?.data['message'] ?? 'Network error';
          debugPrint('Dio error: status=${e.response?.statusCode}, data=${e.response?.data}');
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          debugPrint('Update error: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
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
                        'Edit Pet',
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
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Name',
                                  icon: Icons.pets,
                                  validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  controller: _speciesController,
                                  label: 'Species',
                                  icon: Icons.category,
                                  validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter a species' : null,
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  controller: _breedController,
                                  label: 'Breed',
                                  icon: Icons.pets,
                                  validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter a breed' : null,
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  controller: _genderController,
                                  label: 'Gender',
                                  icon: Icons.transgender,
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  controller: _birthDateController,
                                  label: 'Birth Date',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return null;
                                    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                                    if (!regex.hasMatch(value)) {
                                      return 'Please enter a valid date (YYYY-MM-DD)';
                                    }
                                    final date = DateTime.tryParse(value);
                                    if (date == null || date.isAfter(DateTime.now())) {
                                      return 'Please enter a valid past date';
                                    }
                                    return null;
                                  },
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
          margin: const EdgeInsets.symmetric(vertical: 10),
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
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : widget.existingPet['imageUrl'] != null && widget.existingPet['imageUrl'].isNotEmpty
                ? NetworkImage(widget.existingPet['imageUrl'])
                : const AssetImage('assets/default_pet.png'),
            onBackgroundImageError: (error, stackTrace) {
              debugPrint('Image load error: $error, URL: ${widget.existingPet['imageUrl']}');
            },
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF800080)),
        ),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF800080)) : null,
        prefixIconColor: const Color(0xFF800080),
        labelText: label,
        hintText: hint,
      ),
      validator: validator ??
              (value) => value == null || value.trim().isEmpty ? 'Please enter $label' : null,
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
            'SAVE CHANGES',
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
}