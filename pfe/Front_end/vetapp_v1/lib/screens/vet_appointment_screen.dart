import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/client_service.dart';
import '../models/token_storage.dart';
import 'AnimalFicheScreen.dart';

class VetAppointmentScreen extends StatefulWidget {
  const VetAppointmentScreen({super.key});

  @override
  State<VetAppointmentScreen> createState() => _VetAppointmentScreenState();
}

class _VetAppointmentScreenState extends State<VetAppointmentScreen> {
  late final ClientService _clientService;
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final dio = Provider.of<Dio>(context, listen: false);
    _clientService = ClientService(dio: dio);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final vetAppointments = await _clientService.fetchAppointmentsForVeterinarian(userId);
      setState(() {
        _appointments = vetAppointments.map((appt) => appt.toJson()).toList();
      });
    } catch (e) {
      setState(() {
        final errorStr = e.toString();
        _errorMessage = errorStr.contains('client non trouvé')
            ? 'No client appointments found for this veterinarian'
            : 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptAppointment(String appointmentId) async {
    try {
      await _clientService.acceptAppointment(appointmentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment accepted',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green,
        ),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _rejectAppointment(String appointmentId) async {
    try {
      await _clientService.rejectAppointment(appointmentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment rejected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.red,
        ),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  List<dynamic> get _filteredAppointments {
    final now = DateTime.now();
    List<dynamic> filtered = [];

    if (_currentTabIndex == 0) {
      filtered = _appointments
          .where((appt) =>
      (appt['status']?.toString().toLowerCase() ?? 'pending') == 'pending' &&
          !_parseDate(appt['date']).isBefore(now))
          .toList()
        ..sort((a, b) => _parseDate(a['date']).compareTo(_parseDate(b['date'])));
    } else if (_currentTabIndex == 1) {
      filtered = _appointments
          .where((appt) =>
      (appt['status']?.toString().toLowerCase() ?? 'pending') == 'accepted' &&
          !_parseDate(appt['date']).isBefore(now))
          .toList()
        ..sort((a, b) => _parseDate(a['date']).compareTo(_parseDate(b['date'])));
    } else {
      filtered = _appointments
          .where((appt) => _parseDate(appt['date']).isBefore(now))
          .toList()
        ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: Text(
            'Veterinarian Appointments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
              onPressed: _loadAppointments,
            ),
          ],
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTabIndex = index),
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Accepted'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : _errorMessage.isNotEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAppointments,
                style: theme.elevatedButtonTheme.style,
                child: Text(
                  'Retry',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        )
            : _filteredAppointments.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 48,
                color: theme.colorScheme.onBackground.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No appointments found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _loadAppointments,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredAppointments.length,
            itemBuilder: (context, index) {
              final appointment = _filteredAppointments[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentDetailsScreen(
                        appointment: appointment,
                        onAccept: _acceptAppointment,
                        onReject: _rejectAppointment,
                        isPast: _currentTabIndex == 2, appointmentId: '',
                      ),
                    ),
                  );
                },
                child: _AppointmentCard(
                  appointment: appointment,
                  onAccept: _acceptAppointment,
                  onReject: _rejectAppointment,
                  isPast: _currentTabIndex == 2,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Function(String) onAccept;
  final Function(String) onReject;
  final bool isPast;

  const _AppointmentCard({
    required this.appointment,
    required this.onAccept,
    required this.onReject,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _parseDate(appointment['date']);
    final formattedDate = DateFormat.yMMMd().format(date);
    final formattedTime = DateFormat.jm().format(date);

    final client = appointment['client'] ?? {};
    final clientName = client.isNotEmpty
        ? '${client['firstName'] ?? 'Unknown'} ${client['lastName'] ?? 'Client'}'.trim()
        : 'Unknown Client';
    final petName = appointment['animal']?['name']?.toString() ?? 'Unknown Pet';

    final status = appointment['status']?.toString().toLowerCase() ?? 'pending';
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient: $clientName',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pet: $petName',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
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
                Text(formattedDate, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(formattedTime, style: theme.textTheme.bodyMedium),
              ],
            ),
            if (appointment['type'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Type: ${appointment['type']}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (appointment['services'] != null && (appointment['services'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.medical_services, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Services: ${(appointment['services'] as List).join(', ')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (appointment['caseDescription'] != null) ...[
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      appointment['caseDescription'],
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (!isPast && status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => onReject(appointment['_id']),
                      style: theme.outlinedButtonTheme.style?.copyWith(
                        foregroundColor: MaterialStateProperty.all(theme.colorScheme.error),
                        side: MaterialStateProperty.all(
                          BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                      child: Text(
                        'REJECT',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => onAccept(appointment['_id']),
                      style: theme.elevatedButtonTheme.style?.copyWith(
                        backgroundColor: MaterialStateProperty.all(Colors.green),
                      ),
                      child: Text(
                        'ACCEPT',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }
}


class AppointmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final Function(String) onAccept;
  final Function(String) onReject;
  final bool isPast;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
    required this.onAccept,
    required this.onReject,
    required this.isPast, required String appointmentId,
  });

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  String vetId = '';

  @override
  void initState() {
    super.initState();
    _loadVetId();
  }

  Future<void> _loadVetId() async {
    final id = await TokenStorage.getUserId() ??
        widget.appointment['vetId']?.toString() ??
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
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
    debugPrint('Appointment data: ${widget.appointment}');
    final theme = Theme.of(context);
    final date = _parseDate(widget.appointment['date']);
    final formattedDate = DateFormat.yMMMd().format(date);
    final formattedTime = DateFormat.jm().format(date);

    final client = widget.appointment['client'] ?? {};
    debugPrint('Full appointment data: ${widget.appointment}');
    debugPrint('Client data: $client');
    debugPrint('Client fields: ${client.keys.join(', ')}');
    debugPrint('Client mapsLocation (raw): ${client.containsKey('mapsLocation') ? client['mapsLocation']?.toString() : 'key not found'}');
    debugPrint('Client address (raw): ${client.containsKey('address') ? client['address']?.toString() : 'key not found'}');
    try {
      final clientObj = Client.fromJson(client);
      debugPrint('Parsed Client model: ${clientObj.toJson()}');
      debugPrint('Client model has mapsLocation field: ${clientObj.toJson().containsKey('mapsLocation')}');
      debugPrint('Parsed Client mapsLocation: ${clientObj.toJson()['mapsLocation']?.toString() ?? 'null'}');
    } catch (e, stackTrace) {
      debugPrint('Error parsing Client model: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    final clientName = client.isNotEmpty
        ? '${client['firstName'] ?? 'Unknown'} ${client['lastName'] ?? 'Client'}'.trim()
        : 'Unknown Client';
    String? clientPicture = client['profilePicture']?.toString();
    if (clientPicture != null && clientPicture.contains('localhost')) {
      clientPicture = clientPicture.replaceFirst('localhost', '192.168.1.16');
    }
    final clientEmail = client['email']?.toString() ?? 'N/A';
    final clientPhone = client['phoneNumber']?.toString() ?? 'N/A';
    final clientAddress = client.containsKey('address') && client['address'] != null
        ? [
      client['address']['street']?.toString() ?? '',
      client['address']['city']?.toString() ?? '',
      client['address']['state']?.toString() ?? '',
      client['address']['country']?.toString() ?? '',
      client['address']['postalCode']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).join(', ')
        : 'N/A';
    final clientMapsLocation = client.containsKey('mapsLocation') ? client['mapsLocation']?.toString() ?? 'N/A' : 'N/A';
    debugPrint('UI clientMapsLocation: $clientMapsLocation');
    final clientLastLogin = client.containsKey('lastLogin') && client['lastLogin'] != null
        ? DateFormat.yMMMd().add_jm().format(DateTime.parse(client['lastLogin'].toString()).toLocal())
        : 'N/A';

    final animal = widget.appointment['animal'] ?? {};
    debugPrint('Animal data: $animal');
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

    // Construct Animal object
    final animalObj = Animal(
      id: animal['id']?.toString() ?? animal['_id']?.toString() ?? '',
      name: petName,
      species: petSpecies,
      breed: petBreed,
      gender: petGender,
      birthDate: animal['birthDate'] != null ? DateTime.parse(animal['birthDate'].toString()) : null,
      picture: petPicture,
    );

    // Extract clientId
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

    // Debug logs
    debugPrint('animalId: ${animalObj.id}');
    debugPrint('vetId: $vetId');
    debugPrint('clientId: $clientId');
    debugPrint('Button enabled: ${animalObj.id.isNotEmpty && vetId.isNotEmpty && clientId.isNotEmpty}');

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Appointment Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: clientPicture != null && clientPicture.isNotEmpty
                              ? Image.file(
                            File(clientPicture),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Client image error: $error');
                              return Image.asset(
                                'assets/images/default_avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Client asset error: $error');
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
                              debugPrint('Client asset error: $error');
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
                                clientName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                    _buildInfoRow(Icons.email, 'Email', clientEmail, context),
                    _buildInfoRow(Icons.phone, 'Phone', clientPhone, context),
                    _buildInfoRow(Icons.location_on, 'Address', clientAddress, context),
                    _buildInfoRow(Icons.map, 'Map Location', client['mapsLocation']?.toString() ?? 'N/A', context),
                    _buildInfoRow(Icons.access_time, 'Last Login', clientLastLogin, context),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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
                              debugPrint('Pet image error: $error');
                              return Image.asset(
                                'assets/images/default_avatar.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Pet asset error: $error');
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey,
                                    child: const Icon(Icons.pets, color: Colors.white),
                                  );
                                },
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
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Species: $petSpecies',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                'Breed: $petBreed',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                          debugPrint('Navigating to AnimalFicheScreen for animalId: ${animalObj.id}');
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
                        style: theme.elevatedButtonTheme.style?.copyWith(
                          backgroundColor: MaterialStateProperty.all(theme.colorScheme.primary),
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Chip(
                          label: Text(
                            status.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
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
                        Text(formattedDate, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(formattedTime, style: theme.textTheme.bodyMedium),
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
                            style: theme.textTheme.bodyMedium,
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
                              style: theme.textTheme.bodyMedium,
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
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              widget.appointment['caseDescription'],
                              style: theme.textTheme.bodyMedium,
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
                            onPressed: () => widget.onReject(widget.appointment['_id']),
                            style: theme.outlinedButtonTheme.style?.copyWith(
                              foregroundColor: MaterialStateProperty.all(theme.colorScheme.error),
                              side: MaterialStateProperty.all(
                                BorderSide(color: theme.colorScheme.error),
                              ),
                            ),
                            child: Text(
                              'REJECT',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => widget.onAccept(widget.appointment['_id']),
                            style: theme.elevatedButtonTheme.style?.copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.green),
                            ),
                            child: Text(
                              'ACCEPT',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
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