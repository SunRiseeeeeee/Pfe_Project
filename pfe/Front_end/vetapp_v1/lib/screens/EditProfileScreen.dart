import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/user_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _originalProfileImagePath;

  // Form fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _postalCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _specializationController;
  late TextEditingController _servicesController;
  late TextEditingController _mapsLocationController; // Added for mapsLocation
  List<Map<String, dynamic>> _workingHours = [];
  List<Map<String, TextEditingController>> _workingHourControllers = [];

  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _postalCodeController = TextEditingController();
    _descriptionController = TextEditingController();
    _specializationController = TextEditingController();
    _servicesController = TextEditingController();
    _mapsLocationController = TextEditingController(); // Initialize mapsLocation controller
  }

  void _loadUserData() {
    _getUserId().then((userId) {
      if (userId != null) {
        _fetchUserData(userId);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('User ID not found');
      }
    });
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _descriptionController.dispose();
    _specializationController.dispose();
    _servicesController.dispose();
    _mapsLocationController.dispose(); // Dispose mapsLocation controller
    for (var controllers in _workingHourControllers) {
      controllers['day']?.dispose();
      controllers['start']?.dispose();
      controllers['pauseStart']?.dispose();
      controllers['pauseEnd']?.dispose();
      controllers['end']?.dispose();
    }
  }

  Future<void> _fetchUserData(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      if (mounted) {
        setState(() {
          _userData = user;
          _originalProfileImagePath = user['profilePicture'];
          _populateFormFields(user);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to fetch user data: ${e.toString()}');
      }
    }
  }

  void _populateFormFields(Map<String, dynamic> user) {
    _firstNameController.text = user['firstName'] ?? '';
    _lastNameController.text = user['lastName'] ?? '';
    _phoneNumberController.text = user['phoneNumber'] ?? '';
    _mapsLocationController.text = user['mapsLocation'] ?? ''; // Populate mapsLocation

    final address = user['address'] ?? {};
    _streetController.text = address['street'] ?? '';
    _cityController.text = address['city'] ?? '';
    _stateController.text = address['state'] ?? '';
    _countryController.text = address['country'] ?? '';
    _postalCodeController.text = address['postalCode'] ?? '';

    if (user['role'] == 'veterinaire') {
      final details = user['details'] ?? {};
      _descriptionController.text = user['description'] ?? '';
      _specializationController.text = details['specialization'] ?? '';
      _servicesController.text = (details['services'] as List<dynamic>?)?.join(', ') ?? '';
      _workingHours = List<Map<String, dynamic>>.from(details['workingHours'] ?? []);
      _workingHourControllers = _workingHours.map((workingHour) {
        return {
          'day': TextEditingController(text: workingHour['day']),
          'start': TextEditingController(text: workingHour['start']),
          'pauseStart': TextEditingController(text: workingHour['pauseStart']),
          'pauseEnd': TextEditingController(text: workingHour['pauseEnd']),
          'end': TextEditingController(text: workingHour['end']),
        };
      }).toList();
    }
  }

  bool _hasChanges() {
    if (_userData.isEmpty) return false;

    final currentAddress = _userData['address'] ?? {};
    final currentDetails = _userData['details'] ?? {};

    final textFieldsChanged =
        _firstNameController.text != (_userData['firstName'] ?? '') ||
            _lastNameController.text != (_userData['lastName'] ?? '') ||
            _phoneNumberController.text != (_userData['phoneNumber'] ?? '') ||
            _streetController.text != (currentAddress['street'] ?? '') ||
            _cityController.text != (currentAddress['city'] ?? '') ||
            _stateController.text != (currentAddress['state'] ?? '') ||
            _countryController.text != (currentAddress['country'] ?? '') ||
            _postalCodeController.text != (currentAddress['postalCode'] ?? '') ||
            _mapsLocationController.text != (_userData['mapsLocation'] ?? ''); // Check mapsLocation

    final vetFieldsChanged = _userData['role'] == 'veterinaire' &&
        (_descriptionController.text != (_userData['description'] ?? '') ||
            _specializationController.text != (currentDetails['specialization'] ?? '') ||
            _servicesController.text != (currentDetails['services'] as List<dynamic>?)?.join(', ') ||
            _workingHours.toString() != (currentDetails['workingHours'] ?? []).toString());

    final imageChanged =
        (_profileImage != null && _profileImage!.path != _originalProfileImagePath) ||
            (_profileImage == null && _originalProfileImagePath != null);

    return textFieldsChanged || vetFieldsChanged || imageChanged;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasChanges()) {
      _showSnackBar('No changes made');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User ID not found');

      final updatedData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'phoneNumber': _phoneNumberController.text,
        'address': _buildAddressData(),
        'mapsLocation': _mapsLocationController.text.isNotEmpty ? _mapsLocationController.text : null, // Include mapsLocation
        if (_profileImage != null) 'profilePicture': _profileImage!.path,
      };

      if (_userData['role'] == 'veterinaire') {
        updatedData['description'] = _descriptionController.text;
        updatedData['details'] = {
          'specialization': _specializationController.text,
          'services': _servicesController.text.split(',').map((s) => s.trim()).toList(),
          'workingHours': _workingHours,
        };
      }

      await _userService.updateUser(updatedData);

      if (mounted) {
        _showSnackBar('Profile updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Map<String, dynamic> _buildAddressData() {
    return {
      'street': _streetController.text,
      'city': _streetController.text,
      'state': _stateController.text.isNotEmpty ? _stateController.text : null,
      'country': _countryController.text.isNotEmpty ? _countryController.text : null,
      'postalCode': _postalCodeController.text,
    };
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _addWorkingHour() {
    setState(() {
      _workingHours.add({
        'day': 'Monday',
        'start': '08:00',
        'pauseStart': null,
        'pauseEnd': null,
        'end': '18:00',
      });
      _workingHourControllers.add({
        'day': TextEditingController(text: 'Monday'),
        'start': TextEditingController(text: '08:00'),
        'pauseStart': TextEditingController(),
        'pauseEnd': TextEditingController(),
        'end': TextEditingController(text: '18:00'),
      });
    });
  }

  void _updateWorkingHour(int index, String key, String? value) {
    setState(() {
      _workingHours[index][key] = value;
    });
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
                // Custom Header with Back Arrow on the Side
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back arrow on the left
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      // Centered title
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Placeholder to balance the layout (empty space on the right)
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Profile Picture Section
                _buildProfilePictureSection(),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 24),
                        _buildAddressSection(),
                        const SizedBox(height: 24),
                        _buildMapsLocationSection(), // Added mapsLocation section
                        if (_userData['role'] == 'veterinaire') ...[
                          const SizedBox(height: 24),
                          _buildVeterinarianSection(),
                        ],
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
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
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : _originalProfileImagePath != null
                ? NetworkImage(_originalProfileImagePath!) as ImageProvider
                : null,
            child: _profileImage == null && _originalProfileImagePath == null
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
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

  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _phoneNumberController,
              label: 'Phone Number',
              icon: Icons.phone,
              isRequired: true,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _streetController,
              label: 'Street',
              icon: Icons.home,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _stateController,
                    label: 'State/Province',
                    icon: Icons.map,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    icon: Icons.markunread_mailbox,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _countryController,
              label: 'Country',
              icon: Icons.public,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapsLocationSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Maps Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _mapsLocationController,
              label: 'Maps Location (e.g., Google Maps URL)',
              icon: Icons.location_on,
              validator: (value) {
                if (value == null || value.isEmpty) return null; // Optional field
                if (!Uri.parse(value).isAbsolute) {
                  return 'Enter a valid URL';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVeterinarianSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veterinarian Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _specializationController,
              label: 'Specialization',
              icon: Icons.medical_services,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              controller: _servicesController,
              label: 'Services (comma-separated)',
              icon: Icons.list,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Working Hours',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            ..._workingHours.asMap().entries.map((entry) {
              final index = entry.key;
              final workingHour = entry.value;
              return _buildWorkingHourRow(index, workingHour);
            }).toList(),
            const SizedBox(height: 12),
            InkWell(
              onTap: _addWorkingHour,
              borderRadius: BorderRadius.circular(12),
              splashColor: const Color(0xFF800080).withOpacity(0.2),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Add Working Hour',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHourRow(int index, Map<String, dynamic> workingHour) {
    final controllers = _workingHourControllers[index];
    final List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: workingHour['day'],
              decoration: InputDecoration(
                labelText: 'Day',
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF800080)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: days.map((day) {
                return DropdownMenuItem<String>(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateWorkingHour(index, 'day', value);
                  controllers['day']!.text = value;
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a day';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['start'],
                    decoration: InputDecoration(
                      labelText: 'Start Time',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.access_time, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter start time';
                      }
                      if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
                        return 'Enter valid time (HH:MM)';
                      }
                      return null;
                    },
                    onChanged: (value) => _updateWorkingHour(index, 'start', value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers['end'],
                    decoration: InputDecoration(
                      labelText: 'End Time',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.access_time, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter end time';
                      }
                      if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
                        return 'Enter valid time (HH:MM)';
                      }
                      return null;
                    },
                    onChanged: (value) => _updateWorkingHour(index, 'end', value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['pauseStart'],
                    decoration: InputDecoration(
                      labelText: 'Pause Start (optional)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.pause, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
                        return 'Enter valid time (HH:MM)';
                      }
                      return null;
                    },
                    onChanged: (value) => _updateWorkingHour(index, 'pauseStart', value.isEmpty ? null : value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers['pauseEnd'],
                    decoration: InputDecoration(
                      labelText: 'Pause End (optional)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.play_arrow, color: Color(0xFF800080)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
                        return 'Enter valid time (HH:MM)';
                      }
                      return null;
                    },
                    onChanged: (value) => _updateWorkingHour(index, 'pauseEnd', value.isEmpty ? null : value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _workingHours.removeAt(index);
                  _workingHourControllers.removeAt(index);
                });
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: const Color(0xFF800080).withOpacity(0.2),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: const Color(0xFF800080)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF800080)),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator ??
          (isRequired
              ? (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          }
              : null),
      onChanged: onChanged,
    );
  }

  Widget _buildSaveButton() {
    return InkWell(
      onTap: _updateProfile,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0xFF800080).withOpacity(0.2),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
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
          child: _isUpdating
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
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