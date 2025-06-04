import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/user_service.dart';
import '../services/service_service.dart';

class AddVeterinaryScreen extends StatefulWidget {
  const AddVeterinaryScreen({super.key});

  @override
  _AddVeterinaryScreenState createState() => _AddVeterinaryScreenState();
}

class _AddVeterinaryScreenState extends State<AddVeterinaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _mapsLocationController = TextEditingController();
  String? _selectedSpecialization;
  List<String> _selectedServices = [];
  bool _isLoading = false;
  bool _isServicesLoading = true;
  String? _servicesError;
  List<String> _availableServices = [];
  final UserService _userService = UserService();

  // List of available specialties (fixed typo)
  final List<String> _specialties = [
    'General Practice',
    'Surgery',
    'Dentistry',
    'Dermatology',
    'Cardiology',
    'Oncology',
    'Chirurgie canine',
    'Urgences & NAC',
  ];

  // Static working hours
  final List<Map<String, dynamic>> _workingHours = [
    {'day': 'Monday', 'start': '09:00', 'end': '17:00', 'pauseStart': '12:00', 'pauseEnd': '13:00'},
    {'day': 'Tuesday', 'start': '09:00', 'end': '17:00', 'pauseStart': '12:00', 'pauseEnd': '13:00'},
    {'day': 'Wednesday', 'start': '09:00', 'end': '17:00', 'pauseStart': '12:00', 'pauseEnd': '13:00'},
    {'day': 'Thursday', 'start': '09:00', 'end': '17:00', 'pauseStart': '12:00', 'pauseEnd': '13:00'},
    {'day': 'Friday', 'start': '09:00', 'end': '17:00', 'pauseStart': '12:00', 'pauseEnd': '13:00'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      setState(() => _isServicesLoading = true);
      final services = await ServiceService.fetchServiceNames();
      if (mounted) {
        setState(() {
          _availableServices = services;
          _isServicesLoading = false;
          _servicesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServicesLoading = false;
          _servicesError = 'Failed to load services: $e';
        });
      }
      print('Error in _fetchServices: $e');
    }
  }

  Future<void> _createVeterinarian() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one service', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.createVeterinary(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        services: _selectedServices,
        workingHours: _workingHours,
        specialization: _selectedSpecialization!,
        experienceYears: int.tryParse(_experienceYearsController.text.trim()),
        mapsLocation: _mapsLocationController.text.trim().isNotEmpty
            ? _mapsLocationController.text.trim()
            : null,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veterinarian created successfully', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create veterinarian: $e', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _experienceYearsController.dispose();
    _mapsLocationController.dispose();
    super.dispose();
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
          child: Column(
            children: [
              // Custom Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Add New Veterinarian',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Form Section
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
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a username';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                return 'Username can only contain letters, numbers, and underscores';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneNumberController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a phone number';
                              }
                              if (!RegExp(r'^[0-9]{8,15}$').hasMatch(value)) {
                                return 'Phone number must be 8-15 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSpecialization,
                            decoration: InputDecoration(
                              labelText: 'Specialization',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(color: Colors.black),
                            items: _specialties.map((specialty) {
                              return DropdownMenuItem<String>(
                                value: specialty,
                                child: Text(specialty, style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSpecialization = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a specialization';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _isServicesLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF800080)))
                              : _servicesError != null
                              ? Text(
                            _servicesError!,
                            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                          )
                              : MultiSelectDialogField(
                            items: _availableServices
                                .map((service) => MultiSelectItem<String>(service, service))
                                .toList(),
                            title: Text('Select Services', style: GoogleFonts.poppins()),
                            selectedColor: const Color(0xFF800080),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            buttonText: Text(
                              'Select Services',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            chipDisplay: MultiSelectChipDisplay(
                              chipColor: const Color(0xFF800080).withOpacity(0.1),
                              textStyle: GoogleFonts.poppins(color: const Color(0xFF800080)),
                              onTap: (value) {
                                setState(() {
                                  _selectedServices.remove(value);
                                });
                              },
                            ),
                            onConfirm: (values) {
                              setState(() {
                                _selectedServices = values.cast<String>();
                              });
                            },
                            validator: (values) {
                              if (values == null || values.isEmpty) {
                                return 'Please select at least one service';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _experienceYearsController,
                            decoration: InputDecoration(
                              labelText: 'Experience Years (optional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final years = int.tryParse(value);
                                if (years == null || years < 0 || years > 100) {
                                  return 'Please enter a valid number of years (0-100)';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _mapsLocationController,
                            decoration: InputDecoration(
                              labelText: 'Maps Location (optional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              labelStyle: GoogleFonts.poppins(),
                              hintText: 'e.g., 40.7128,-74.0060 or Google Maps URL',
                              hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            ),
                            style: GoogleFonts.poppins(),
                            validator: (value) {
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF800080), Color(0xFF4B0082)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading || _isServicesLoading ? null : _createVeterinarian,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : Text(
                                'Create Veterinarian',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}