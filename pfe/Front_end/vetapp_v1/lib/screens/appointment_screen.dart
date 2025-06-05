import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'package:vetapp_v1/screens/EditAppointmentScreen.dart';
import 'package:vetapp_v1/screens/client_appointment_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  late final AppointmentService _appointmentService;
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final dio = Provider.of<Dio>(context, listen: false);
    _appointmentService = AppointmentService(dio: dio);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _appointmentService.getAppointmentsByClient(userId);

      if (response['success'] == true) {
        setState(() {
          _appointments = List.from(response['data'] ?? []);
          _appointments.sort((a, b) {
            final dateA = _parseDate(a['date']);
            final dateB = _parseDate(b['date']);
            return dateA.compareTo(dateB);
          });
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load appointments';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _appointmentService.deleteAppointment(appointmentId);
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Appointment cancelled'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _loadAppointments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _acceptAppointment(String appointmentId) async {
    try {
      final response = await _appointmentService.updateAppointment(appointmentId, 'accepted' as Map<String, dynamic>);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment accepted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadAppointments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  List<dynamic> get _filteredAppointments {
    final now = DateTime.now();
    return _appointments.where((appt) {
      final date = _parseDate(appt['date']);
      return _currentTabIndex == 0 ? date.isAfter(now) || date.isAtSameMomentAs(now) : date.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Appointments',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
                    child: Column(
                      children: [
                        TabBar(
                          onTap: (index) => setState(() => _currentTabIndex = index),
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
                          tabs: const [
                            Tab(text: 'Upcoming'),
                            Tab(text: 'Past'),
                          ],
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF800080)))
                              : _errorMessage.isNotEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(_errorMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins()),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAppointments,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF800080),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                              : _filteredAppointments.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No appointments found',
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          )
                              : RefreshIndicator(
                            displacement: 40,
                            edgeOffset: 20,
                            color: const Color(0xFF800080),
                            onRefresh: _loadAppointments,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredAppointments.length,
                              itemBuilder: (context, index) {
                                return _AppointmentCard(
                                  appointment: _filteredAppointments[index],
                                  onCancel: _cancelAppointment,
                                  onAccept: _acceptAppointment,
                                  isPast: _currentTabIndex == 1,
                                );
                              },
                            ),
                          ),
                        ),
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
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Function(String) onCancel;
  final Function(String) onAccept;
  final bool isPast;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onAccept,
    required this.isPast,
  });

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _parseDate(appointment['date']);
    final formattedDate = DateFormat.yMMMd().format(date);
    final formattedTime = DateFormat.jm().format(date);

    final vet = appointment['veterinaireId'];
    final vetName = vet != null
        ? '${vet['firstName'] ?? ''} ${vet['lastName'] ?? ''}'.trim()
        : 'Unknown Vet';

    final pet = appointment['animalId'];
    final petName = pet != null ? pet['name'] ?? 'Unknown Pet' : 'Unknown Pet';

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
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClientAppointmentDetailsScreen(
                appointment: appointment,
                onAccept: onAccept,
                onCancel: onCancel,
                isPast: isPast,
              ),
            ),
          );
        },
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
                          petName,
                          style: GoogleFonts.poppins(
                            fontSize: theme.textTheme.titleMedium?.fontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF800080),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'with $vetName',
                          style: GoogleFonts.poppins(
                            fontSize: theme.textTheme.bodyMedium?.fontSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
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
                  Icon(Icons.calendar_today, size: 16, color: const Color(0xFF800080)),
                  const SizedBox(width: 8),
                  Text('$formattedDate', style: GoogleFonts.poppins(fontSize: theme.textTheme.bodyMedium?.fontSize)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: const Color(0xFF800080)),
                  const SizedBox(width: 8),
                  Text(formattedTime, style: GoogleFonts.poppins(fontSize: theme.textTheme.bodyMedium?.fontSize)),
                ],
              ),
              if (appointment['type'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: const Color(0xFF800080)),
                    const SizedBox(width: 8),
                    Text('Type: ${appointment['type']}', style: GoogleFonts.poppins(fontSize: theme.textTheme.bodyMedium?.fontSize)),
                  ],
                ),
              ],
              if (appointment['services'] != null && appointment['services'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_services, size: 16, color: const Color(0xFF800080)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Services: ${(appointment['services'] as List).join(', ')}',
                        style: GoogleFonts.poppins(fontSize: theme.textTheme.bodyMedium?.fontSize),
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
                        Icon(Icons.description, size: 16, color: const Color(0xFF800080)),
                        const SizedBox(width: 8),
                        Text(
                          'Description:',
                          style: GoogleFonts.poppins(
                            fontSize: theme.textTheme.bodyMedium?.fontSize,
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
                        style: GoogleFonts.poppins(fontSize: theme.textTheme.bodyMedium?.fontSize),
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
                        onPressed: () => onCancel(appointment['_id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('CANCEL', style: GoogleFonts.poppins()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditAppointmentScreen(appointment: appointment),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF800080),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('EDIT', style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}