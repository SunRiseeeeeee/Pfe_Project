
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/service.dart';
import '../services/service_service.dart';

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
          title: Text(isEdit ? 'Edit Service' : 'Add Service'),
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
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
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
                      child: Text(selectedImage == null ? 'Pick Image' : 'Image Selected'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
                    SnackBar(content: Text(isEdit ? 'Service updated' : 'Service created')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Operation failed')),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
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
        const SnackBar(content: Text('Service deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to delete service')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!['success']) {
            return Center(child: Text(snapshot.data?['message'] ?? 'Failed to load services'));
          }

          final services = snapshot.data!['services'] as List<Service>;
          if (services.isEmpty) {
            return const Center(child: Text('No services available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final imageUrl = service.image != null && service.image!.isNotEmpty
                  ? service.image!.replaceAll('http://localhost:3000', 'http://192.168.1.18:3000')
                  : null;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: imageUrl != null
                      ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                  )
                      : const Icon(Icons.image_not_supported),
                  title: Text(service.name),
                  subtitle: Text(service.description ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showServiceDialog(service: service),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteService(service.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
