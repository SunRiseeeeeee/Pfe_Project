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

    // Check text fields
    final textFieldsChanged =
        _firstNameController.text != (_userData['firstName'] ?? '') ||
            _lastNameController.text != (_userData['lastName'] ?? '') ||
            _phoneNumberController.text != (_userData['phoneNumber'] ?? '') ||
            _streetController.text != (currentAddress['street'] ?? '') ||
            _cityController.text != (currentAddress['city'] ?? '') ||
            _stateController.text != (currentAddress['state'] ?? '') ||
            _countryController.text != (currentAddress['country'] ?? '') ||
            _postalCodeController.text != (currentAddress['postalCode'] ?? '');

    // Check veterinarian-specific fields
    final vetFieldsChanged = _userData['role'] == 'veterinaire' &&
        (_descriptionController.text != (_userData['description'] ?? '') ||
            _specializationController.text != (currentDetails['specialization'] ?? '') ||
            _servicesController.text != (currentDetails['services'] as List<dynamic>?)?.join(', ') ||
            _workingHours.toString() != (currentDetails['workingHours'] ?? []).toString());

    // Check profile image
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
      'city': _cityController.text,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePictureSection(),
              const SizedBox(height: 24),
              _buildPersonalInfoSection(theme),
              const SizedBox(height: 24),
              _buildAddressSection(theme),
              if (_userData['role'] == 'veterinaire') ...[
                const SizedBox(height: 24),
                _buildVeterinarianSection(theme),
              ],
              const SizedBox(height: 32),
              _buildSaveButton(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : _originalProfileImagePath != null
                  ? NetworkImage(_originalProfileImagePath!)
                  : null,
              child: _profileImage == null && _originalProfileImagePath == null
                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                  : null,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _pickImage,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _pickImage,
          child: const Text('Change Photo'),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information', style: theme.textTheme.titleMedium),
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

  Widget _buildAddressSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address', style: theme.textTheme.titleMedium),
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

  Widget _buildVeterinarianSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Veterinarian Details', style: theme.textTheme.titleMedium),
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
            Text('Working Hours', style: theme.textTheme.titleMedium),
            ..._workingHours.asMap().entries.map((entry) {
              final index = entry.key;
              final workingHour = entry.value;
              return _buildWorkingHourRow(index, workingHour, theme);
            }).toList(),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _addWorkingHour,
              child: const Text('Add Working Hour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHourRow(int index, Map<String, dynamic> workingHour, ThemeData theme) {
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
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: workingHour['day'],
              decoration: InputDecoration(
                labelText: 'Day',
                prefixIcon: const Icon(Icons.calendar_today),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['start'],
                    decoration: InputDecoration(
                      labelText: 'Start Time',
                      prefixIcon: const Icon(Icons.access_time),
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controllers['end'],
                    decoration: InputDecoration(
                      labelText: 'End Time',
                      prefixIcon: const Icon(Icons.access_time),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['pauseStart'],
                    decoration: InputDecoration(
                      labelText: 'Pause Start (optional)',
                      prefixIcon: const Icon(Icons.pause),
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controllers['pauseEnd'],
                    decoration: InputDecoration(
                      labelText: 'Pause End (optional)',
                      prefixIcon: const Icon(Icons.play_arrow),
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
            TextButton(
              onPressed: () {
                setState(() {
                  _workingHours.removeAt(index);
                  _workingHourControllers.removeAt(index);
                });
              },
              child: const Text('Remove'),
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      keyboardType: keyboardType,
      validator: isRequired
          ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      }
          : null,
      onChanged: onChanged,
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _updateProfile,
        child: _isUpdating
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text('SAVE CHANGES', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}