import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/secretary_service.dart';
import '../models/token_storage.dart';
import './secretary_details_screen.dart';

class SecretaryScreen extends StatefulWidget {
  const SecretaryScreen({Key? key}) : super(key: key);

  @override
  _SecretaryScreenState createState() => _SecretaryScreenState();
}

class _SecretaryScreenState extends State<SecretaryScreen> {
  List<Secretary> secretaries = [];
  bool isLoading = true;
  String? errorMessage;
  String? veterinaireId;

  @override
  void initState() {
    super.initState();
    _initializeVeterinaireIdAndFetchSecretaries();
  }

  Future<void> _initializeVeterinaireIdAndFetchSecretaries() async {
    try {
      veterinaireId = await TokenStorage.getUserId();
      if (veterinaireId == null) {
        setState(() {
          errorMessage = 'User ID not found';
          isLoading = false;
        });
        return;
      }
      final fetchedSecretaries = await SecretaryService().getSecretariesByVeterinaireId(veterinaireId!);
      setState(() {
        secretaries = fetchedSecretaries;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching secretaries: $e';
        isLoading = false;
      });
    }
  }

  void _showAddSecretaryDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add New Secretary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (pickedFile != null) {
                          final extension = pickedFile.path.split('.').last.toLowerCase();
                          if (!['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an image file (jpg, jpeg, png, gif)')),
                            );
                            return;
                          }
                          final file = File(pickedFile.path);
                          final exists = await file.exists();
                          final length = exists ? await file.length() : 0;
                          setDialogState(() {
                            selectedImage = file;
                            debugPrint('Selected image: ${pickedFile.path}, Extension: $extension, Exists: $exists, Size: $length bytes');
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                        child: selectedImage != null
                            ? ClipOval(child: Image.file(selectedImage!, fit: BoxFit.cover))
                            : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select an image')),
                              );
                              return;
                            }
                            try {
                              final secretaryData = {
                                'firstName': firstNameController.text.trim(),
                                'lastName': lastNameController.text.trim(),
                                'email': emailController.text.trim(),
                                'phoneNumber': phoneController.text.trim(),
                                'username': usernameController.text.trim(),
                                'password': passwordController.text.trim(),
                              };
                              final newSecretary = await SecretaryService().createSecretary(
                                veterinaireId!,
                                secretaryData,
                                selectedImage,
                              );
                              setState(() {
                                secretaries.add(newSecretary);
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Secretary added successfully')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _deleteSecretary(String secretaryId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
            'Are you sure?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          const Text(
            'This action cannot be undone',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await SecretaryService().deleteSecretary(secretaryId);
                    setState(() {
                      secretaries.removeWhere((s) => s.id == secretaryId);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Secretary deleted successfully')),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ]),
      ),
    ),

    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Secretary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSecretaryDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Secretary',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
          : secretaries.isEmpty
          ? const Center(child: Text('No secretaries found', style: TextStyle(fontSize: 18)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: secretaries.length,
        itemBuilder: (context, index) {
          final secretary = secretaries[index];
          String? profileUrl = secretary.profilePicture;
          if (profileUrl != null && profileUrl.contains('localhost')) {
            profileUrl = profileUrl.replaceFirst('localhost', '192.168.1.18');
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SecretaryDetailsScreen(secretaryId: secretary.id),
                  ),
                );
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: profileUrl != null && profileUrl.isNotEmpty
                    ? profileUrl.startsWith('http')
                    ? Image.network(
                  profileUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Secretary network image error: $error');
                    return Image.asset(
                      'assets/images/default_avatar.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Secretary asset error: $error');
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        );
                      },
                    );
                  },
                )
                    : Image.file(
                  File(profileUrl),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Secretary file image error: $error');
                    return Image.asset(
                      'assets/images/default_avatar.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Secretary asset error: $error');
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        );
                      },
                    );
                  },
                )
                    : Image.asset(
                  'assets/images/default_avatar.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Secretary asset error: $error');
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    );
                  },
                ),
              ),
              title: Text('${secretary.firstName} ${secretary.lastName}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (secretary.email != null) Text(secretary.email!),
                  if (secretary.phoneNumber != null) Text(secretary.phoneNumber!),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteSecretary(secretary.id),
              ),
            ),
          );
        },
      ),
    );
  }
}