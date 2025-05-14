import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'package:vetapp_v1/screens/EditAppointmentScreen.dart';

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
              ));
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

  List<dynamic> get _filteredAppointments {
    final now = DateTime.now();
    return _appointments.where((appt) {
      final date = _parseDate(appt['date']);
      return _currentTabIndex == 0 ? date.isAfter(now) : date.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAppointments,
            ),
          ],
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTabIndex = index),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAppointments,
                child: const Text('Retry'),
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
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          displacement: 40,
          edgeOffset: 20,
          color: Theme.of(context).primaryColor,
          onRefresh: _loadAppointments,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredAppointments.length,
            itemBuilder: (context, index) {
              return _AppointmentCard(
                appointment: _filteredAppointments[index],
                onCancel: _cancelAppointment,
                isPast: _currentTabIndex == 1,
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
  final Function(String) onCancel;
  final bool isPast;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.isPast,
  });

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
    final petName = pet != null
        ? pet['name'] ?? 'Unknown Pet'
        : 'Unknown Pet';

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
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {}, // Add tap effect
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'with $vetName',
                          style: theme.textTheme.bodyMedium?.copyWith(
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
                  Icon(Icons.calendar_today, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text('$formattedDate', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(formattedTime, style: theme.textTheme.bodyMedium),
                ],
              ),
              if (appointment['type'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Type: ${appointment['type']}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
              if (appointment['services'] != null && appointment['services'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_services, size: 16, color: theme.primaryColor),
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
                        Icon(Icons.description, size: 16, color: theme.primaryColor),
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
                        onPressed: () => onCancel(appointment['_id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('CANCEL'),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('EDIT'),
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

  DateTime _parseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }
}