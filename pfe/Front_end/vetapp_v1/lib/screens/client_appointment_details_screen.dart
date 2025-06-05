import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vetapp_v1/models/client.dart' as ClientModel;

import 'package:vetapp_v1/models/token_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/screens/EditAppointmentScreen.dart';
import '../services/client_service.dart';
import 'AnimalFicheScreen.dart';

class ClientAppointmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final Function(String) onAccept;
  final Function(String) onCancel;
  final bool isPast;

  const ClientAppointmentDetailsScreen({
    super.key,
    required this.appointment,
    required this.onAccept,
    required this.onCancel,
    required this.isPast,
  });

  @override
  State<ClientAppointmentDetailsScreen> createState() => _ClientAppointmentDetailsScreenState();
}

class _ClientAppointmentDetailsScreenState extends State<ClientAppointmentDetailsScreen> {
  String vetId = '';
  ClientModel.Client? clientObj;

  @override
  void initState() {
    super.initState();
    _loadVetId();
  }

  Future<void> _loadVetId() async {
    final id = await TokenStorage.getUserId() ??
        widget.appointment['vetId']?.toString() ??
        widget.appointment['veterinaireId']?['_id']?.toString() ??
        widget.appointment['veterinarianId']?.toString() ??
        '';
    setState(() {
      vetId = id;
    });
  }

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return DateTime.now();
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: label == 'Map Location' && value != 'N/A' && value.isNotEmpty
                      ? () async {
                    final url = value.startsWith('http') ? value : 'https://www.google.com/maps/search/?api=1&query=$value';
                    try {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open map')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error opening map: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error opening map: $e')),
                      );
                    }
                  }
                      : null,
                  child: label == 'Map Location' && value != 'N/A' && value.isNotEmpty
                      ? Row(
                    children: [
                      Text(
                        'See Location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ],
                  )
                      : Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _parseDate(widget.appointment['date']);
    final formattedDate = DateFormat.yMMMd().format(date);
    final formattedTime = DateFormat.jm().format(date);

    // Veterinarian data
    final vet = widget.appointment['veterinaireId'] ?? {};
    final vetName = vet.isNotEmpty
        ? '${vet['firstName'] ?? 'Unknown'} ${vet['lastName'] ?? 'Vet'}'.trim()
        : 'Unknown Vet';
    String? vetPicture = vet['profilePicture']?.toString();
    if (vetPicture != null && vetPicture.contains('localhost')) {
      vetPicture = vetPicture.replaceFirst('localhost', '192.168.1.16');
    }
    final vetEmail = vet['email']?.toString() ?? 'N/A';
    final vetPhone = vet['phoneNumber']?.toString() ?? 'N/A';
    final vetSpecialization = vet['details']?['specialization']?.toString() ?? 'N/A';
    final vetAddress = vet.containsKey('address') && vet['address'] != null
        ? [
      vet['address']['street']?.toString() ?? '',
      vet['address']['city']?.toString() ?? '',
      vet['address']['state']?.toString() ?? '',
      vet['address']['country']?.toString() ?? '',
      vet['address']['postalCode']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).join(', ')
        : 'N/A';
    final vetMapsLocation = vet['mapsLocation']?.toString() ??
        vet['address']?['mapsLocation']?.toString() ??
        'N/A';

    // Pet data
    final animal = widget.appointment['animalId'] ?? widget.appointment['animal'] ?? {};
    final petName = animal['name']?.toString() ?? 'Unknown Pet';
    final petSpecies = animal['species']?.toString() ?? 'N/A';
    final petBreed = animal['breed']?.toString() ?? 'N/A';
    final petGender = animal['gender']?.toString() ?? 'N/A';
    final petBirthdate = animal['birthDate'] != null
        ? DateFormat.yMMMd().format(DateTime.parse(animal['birthDate'].toString()).toLocal())
        : 'N/A';
    String? petPicture = animal['picture']?.toString();
    if (petPicture != null && petPicture.contains('localhost')) {
      petPicture = petPicture.replaceFirst('localhost', '192.168.1.16');
    } else {
      petPicture ??= 'http://192.168.1.16:3000/uploads/placeholder.png';
    }

    final animalObj = Animal(
      id: animal['id']?.toString() ?? animal['_id']?.toString() ?? '',
      name: petName,
      species: petSpecies,
      breed: petBreed,
      gender: petGender,
      birthDate: animal['birthDate'] != null ? DateTime.parse(animal['birthDate'].toString()) : null,
      picture: petPicture,
    );

    final client = widget.appointment['client'] ?? {};
    final clientId = client['id']?.toString() ?? client['_id']?.toString() ?? '';

    final status = widget.appointment['status']?.toString().toLowerCase() ?? 'pending';
    Color statusColor;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Appointment Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF800080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veterinarian Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Veterinarian Information',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: vetPicture != null && vetPicture.isNotEmpty
                              ? vetPicture.startsWith('http')
                              ? Image.network(
                            vetPicture,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Vet network image error: $error');
                              return Image.asset(
                                'assets/images/default_avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Vet asset error: $error');
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey,
                                    child: const Icon(Icons.person, color: Colors.white),
                                  );
                                },
                              );
                            },
                          )
                              : Image.file(
                            File(vetPicture),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Vet file image error: $error');
                              return Image.asset(
                                'assets/images/default_avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Vet asset error: $error');
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey,
                                    child: const Icon(Icons.person, color: Colors.white),
                                  );
                                },
                              );
                            },
                          )
                              : Image.asset(
                            'assets/images/default_avatar.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Vet asset error: $error');
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey,
                                child: const Icon(Icons.person, color: Colors.white),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vetName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, 'Email', vetEmail, context),
                    _buildInfoRow(Icons.phone, 'Phone', vetPhone, context),
                    _buildInfoRow(Icons.location_on, 'Address', vetAddress, context),
                    _buildInfoRow(Icons.star, 'Specialization', vetSpecialization, context),
                    _buildInfoRow(Icons.map, 'Map Location', vetMapsLocation, context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pet Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pet Information',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            petPicture,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey,
                                child: const Icon(Icons.pets, color: Colors.white),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                petName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Species: $petSpecies',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                'Breed: $petBreed',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.male, 'Gender', petGender, context),
                    _buildInfoRow(Icons.cake, 'Birthdate', petBirthdate, context),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: animalObj.id.isNotEmpty && vetId.isNotEmpty && clientId.isNotEmpty
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnimalFicheScreen(
                                animal: animalObj,
                                vetId: vetId,
                                clientId: clientId,
                                ficheId: null,
                              ),
                            ),
                          );
                        }
                            : null,
                        icon: const Icon(Icons.description),
                        label: const Text('View Medical Fiche'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Appointment Details Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Appointment Details',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Chip(
                          label: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: statusColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(formattedDate, style: GoogleFonts.poppins(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(formattedTime, style: GoogleFonts.poppins(fontSize: 14)),
                      ],
                    ),
                    if (widget.appointment['type'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Type: ${widget.appointment['type']}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                    if (widget.appointment['services'] != null && (widget.appointment['services'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.medical_services, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Services: ${(widget.appointment['services'] as List).join(', ')}',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.appointment['caseDescription'] != null) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Description:',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              widget.appointment['caseDescription'],
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!widget.isPast && status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => widget.onCancel(widget.appointment['_id']),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditAppointmentScreen(appointment: widget.appointment),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF800080),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'EDIT',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),
                        ],
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