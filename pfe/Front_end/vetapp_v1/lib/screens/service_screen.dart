import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/service.dart';
import '../services/service_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  _ServiceScreenState createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  Future<Map<String, dynamic>>? _servicesFuture;

  @override
  void initState() {
    super.initState();
    _refreshServices();
  }

  void _refreshServices() {
    setState(() {
      _servicesFuture = ServiceService.getAllServices();
    });
  }

  Future<bool> _requestPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
    } else {
      status = await Permission.photos.request();
    }
    if (status.isGranted) {
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission to access photos is required')),
      );
      return false;
    }
  }

  void _showServiceDialog({Service? service}) {
    final isEdit = service != null;
    final nameController = TextEditingController(text: service?.name ?? '');
    final descriptionController = TextEditingController(text: service?.description ?? '');
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Service' : 'Add Service', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (!await _requestPermission()) return;

                        final picker = ImagePicker();
                        try {
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            final file = File(pickedFile.path);
                            if (await file.exists()) {
                              setDialogState(() {
                                selectedImage = file;
                                print('Selected image: ${selectedImage!.path}');
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Image selected successfully')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selected image is invalid or inaccessible')),
                              );
                            }
                          }
                        } catch (e) {
                          print('Error picking image: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to pick image: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800080),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(selectedImage == null ? 'Pick Image' : 'Image Selected', style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                if (name.isEmpty || description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and description are required')),
                  );
                  return;
                }

                Map<String, dynamic> result;
                try {
                  if (isEdit) {
                    result = await ServiceService.updateService(
                      id: service!.id,
                      name: name,
                      description: description,
                      image: selectedImage,
                    );
                  } else {
                    result = await ServiceService.createService(
                      name: name,
                      description: description,
                      image: selectedImage,
                    );
                  }
                } catch (e) {
                  print('Error performing service operation: $e');
                  result = {
                    'success': false,
                    'message': 'Operation failed: $e',
                  };
                }

                Navigator.pop(context);
                if (result['success']) {
                  _refreshServices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Service updated' : 'Service created'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Operation failed'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800080),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isEdit ? 'Update' : 'Create', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteService(String id) async {
    final result = await ServiceService.deleteService(id);
    if (result['success']) {
      _refreshServices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Service deleted'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to delete service'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
    }
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
                    Expanded(
                      child: Text(
                        'Manage Services',
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
              // Content Section
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
                  child: _servicesFuture == null
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF800080)))
                      : FutureBuilder<Map<String, dynamic>>(
                    future: _servicesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF800080)));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.red)));
                      }
                      if (!snapshot.hasData || !snapshot.data!['success']) {
                        return Center(child: Text(snapshot.data?['message'] ?? 'Failed to load services', style: GoogleFonts.poppins()));
                      }

                      final services = snapshot.data!['services'] as List<Service>;
                      if (services.isEmpty) {
                        return const Center(child: Text('No services available', style: TextStyle(fontSize: 16)));
                      }

                      return RefreshIndicator(
                        color: const Color(0xFF800080),
                        onRefresh: () async {
                          _refreshServices();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(0),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final imageUrl = service.image != null && service.image!.isNotEmpty
                                ? service.image!.replaceAll('http://localhost:3000', 'http://192.168.100.7:3000')
                                : null;

                            return Card(
                              elevation: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: imageUrl != null
                                    ? Image.network(
                                  imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Color(0xFF800080)),
                                )
                                    : const Icon(Icons.image_not_supported, color: Color(0xFF800080)),
                                title: Text(service.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF800080))),
                                subtitle: Text(service.description ?? '', style: GoogleFonts.poppins()),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF800080)),
                                      onPressed: () => _showServiceDialog(service: service),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Color(0xFF800080)),
                                      onPressed: () => _deleteService(service.id),
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
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: InkWell(
        onTap: () => _showServiceDialog(),
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