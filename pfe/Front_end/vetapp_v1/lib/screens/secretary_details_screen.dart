import 'dart:io';
import 'package:flutter/material.dart';
import '../services/secretary_service.dart';

class SecretaryDetailsScreen extends StatefulWidget {
  final String secretaryId;

  const SecretaryDetailsScreen({Key? key, required this.secretaryId}) : super(key: key);

  @override
  _SecretaryDetailsScreenState createState() => _SecretaryDetailsScreenState();
}

class _SecretaryDetailsScreenState extends State<SecretaryDetailsScreen> {
  Secretary? secretary;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSecretaryDetails();
  }

  Future<void> _fetchSecretaryDetails() async {
    try {
      final fetchedSecretary = await SecretaryService().getSecretaryDetails(widget.secretaryId);
      setState(() {
        secretary = fetchedSecretary;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching secretary details: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Secretary Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
          : secretary == null
          ? const Center(child: Text('No details found', style: TextStyle(fontSize: 18)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: secretary!.profilePicture != null && secretary!.profilePicture!.isNotEmpty
                  ? secretary!.profilePicture!.startsWith('http')
                  ? Image.network(
                secretary!.profilePicture!.replaceFirst('localhost', '192.168.1.18'),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Details network image error: $error');
                  return Image.asset(
                    'assets/images/default_avatar.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Details asset error: $error');
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      );
                    },
                  );
                },
              )
                  : Image.file(
                File(secretary!.profilePicture!),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Details file image error: $error');
                  return Image.asset(
                    'assets/images/default_avatar.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Details asset error: $error');
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      );
                    },
                  );
                },
              )
                  : Image.asset(
                'assets/images/default_avatar.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Details asset error: $error');
                  return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              '${secretary!.firstName} ${secretary!.lastName}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Details Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (secretary!.email != null) ...[
                      Text(
                        'Email: ${secretary!.email}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (secretary!.phoneNumber != null) ...[
                      Text(
                        'Phone: ${secretary!.phoneNumber}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (secretary!.username != null) ...[
                      Text(
                        'Username: ${secretary!.username}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (secretary!.veterinaireId != null) ...[
                      Text(
                        'Veterinarian ID: ${secretary!.veterinaireId}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}