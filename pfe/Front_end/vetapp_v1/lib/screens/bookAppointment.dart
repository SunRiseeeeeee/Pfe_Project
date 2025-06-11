import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/pet_service.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
import 'package:vetapp_v1/services/user_service.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'dart:convert';

class AppointmentsScreen extends StatefulWidget {
  final Veterinarian vet;
  final String workingHours;

  const AppointmentsScreen({
    Key? key,
    required this.vet,
    required this.workingHours,
  }) : super(key: key);

  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String? selectedPetId;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedAppointmentType;
  String? selectedService;
  String? caseDescription;

  List<Map<String, dynamic>> pets = [];
  List<DateTime> acceptedAppointmentTimes = [];
  final List<String> appointmentTypes = ['household', 'clinic'];
  List<String> services = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  late final AppointmentService _appointmentService;
  late final PetService _petService;
  late final UserService _userService;
  String? _errorMessage;
  final _scrollController = ScrollController();
  late Map<int, Map<String, String>> parsedWorkingHours;

  @override
  void initState() {
    super.initState();
    debugPrint('initState: Initializing AppointmentsScreen, vetId: ${widget.vet.id}');

    final dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.1.16:3000/api',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _appointmentService = AppointmentService(dio: dio);
    _petService = PetService(dio: dio);
    _userService = UserService();

    parsedWorkingHours = _parseWorkingHours(widget.workingHours);
    debugPrint('Parsed working hours: $parsedWorkingHours');

    _initializeUserAndPets();
  }

  Future<void> _initializeUserAndPets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      debugPrint('setState: Initializing user and pets, isLoading: true');
    });

    try {
      final fetchedPets = await _petService.getUserPets();
      final acceptedTimesResponse = await _appointmentService.getAcceptedAppointmentTimes(widget.vet.id!);
      final vetDetails = await _userService.getUserById(widget.vet.id!);
      final fetchedServices = List<String>.from(vetDetails['details']?['services'] ?? []);

      debugPrint('Fetched vet details: $vetDetails');
      debugPrint('Fetched services: $fetchedServices');
      debugPrint('Fetched accepted appointment times response: $acceptedTimesResponse');

      if (acceptedTimesResponse['success'] == true) {
        acceptedAppointmentTimes = List<DateTime>.from(acceptedTimesResponse['data']);
        debugPrint('Accepted appointment times: $acceptedAppointmentTimes');
      } else {
        debugPrint('Failed to fetch accepted appointment times: ${acceptedTimesResponse['message']}');
      }

      setState(() {
        pets = fetchedPets;
        services = fetchedServices.isNotEmpty ? fetchedServices : ['No services available'];
        _isLoading = false;
        debugPrint('setState: Pets and services loaded, isLoading: false, acceptedAppointmentTimes: $acceptedAppointmentTimes');
      });
    } catch (e) {
      debugPrint('Error initializing data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
        debugPrint('setState: Error loading data, isLoading: false');
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
        debugPrint('setState: Selected date: $picked');
      });
    }
  }

  Future<void> _selectTime() async {
    await _showCustomTimePicker();
  }

  Future<void> _showCustomTimePicker() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    final int dayOfWeek = selectedDate!.weekday;
    final dayHours = parsedWorkingHours[dayOfWeek];

    if (dayHours == null || dayHours['start'] == null || dayHours['end'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No working hours available for the selected day')),
      );
      return;
    }

    final DateFormat timeFormat = DateFormat('HH:mm');
    TimeOfDay? selected;

    final List<TimeOfDay> timeSlots = [];
    try {
      final startTime = timeFormat.parse(dayHours['start']!);
      final endTime = timeFormat.parse(dayHours['end']!);

      DateTime current = startTime;
      while (current.isBefore(endTime) || current.isAtSameMomentAs(endTime)) {
        final hour = current.hour;
        final minute = current.minute;
        timeSlots.add(TimeOfDay(hour: hour, minute: minute));
        current = current.add(const Duration(minutes: 30));
      }
    } catch (e) {
      debugPrint('Error generating time slots: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading time slots')),
      );
      return;
    }

    await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Time'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: timeSlots.length,
              itemBuilder: (context, index) {
                final time = timeSlots[index];
                final isValid = _isTimeSlotValid(time, dayHours);

                return GestureDetector(
                  onTap: isValid
                      ? () {
                    selected = time;
                    Navigator.pop(context, time);
                  }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isValid ? Colors.white : Colors.red.withOpacity(0.1),
                      border: Border.all(
                        color: isValid ? Theme.of(context).primaryColor : Colors.red,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        time.format(context).replaceAll(RegExp(r'\s+'), ' '),
                        style: TextStyle(
                          color: isValid ? Theme.of(context).primaryColor : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() {
          selectedTime = value;
          debugPrint('setState: Selected time: ${value.format(context)}');
        });
      }
    });
  }

  bool _isTimeSlotValid(TimeOfDay time, Map<String, String> dayHours) {
    final DateFormat dateFormat = DateFormat('HH:mm');
    final selectedDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      time.hour,
      time.minute,
    );

    try {
      final startTime = dateFormat.parse(dayHours['start']!);
      final endTime = dateFormat.parse(dayHours['end']!);
      final fullStart = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        startTime.hour,
        startTime.minute,
      );
      final fullEnd = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        endTime.hour,
        endTime.minute,
      );

      final isWithinHours = (selectedDateTime.isAfter(fullStart) || selectedDateTime.isAtSameMomentAs(fullStart)) &&
          (selectedDateTime.isBefore(fullEnd) || selectedDateTime.isAtSameMomentAs(fullEnd));

      bool isDuringPause = false;
      if (dayHours['pauseStart'] != null && dayHours['pauseEnd'] != null) {
        final timeFormat = RegExp(r'^\d{2}:\d{2}$');
        if (!timeFormat.hasMatch(dayHours['pauseStart']!) || !timeFormat.hasMatch(dayHours['pauseEnd']!)) {
          debugPrint('Invalid pause time format: pauseStart=${dayHours['pauseStart']}, pauseEnd=${dayHours['pauseEnd']}');
          return isWithinHours;
        }

        final pauseStartTime = dateFormat.parse(dayHours['pauseStart']!);
        final pauseEndTime = dateFormat.parse(dayHours['pauseEnd']!);
        final fullPauseStart = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          pauseStartTime.hour,
          pauseStartTime.minute,
        );
        final fullPauseEnd = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          pauseEndTime.hour,
          pauseEndTime.minute,
        );

        isDuringPause = selectedDateTime.isAtSameMomentAs(fullPauseStart) ||
            (selectedDateTime.isAfter(fullPauseStart) && selectedDateTime.isBefore(fullPauseEnd));
      }

      bool hasConflict = acceptedAppointmentTimes.any((apptTime) {
        final apptEnd = apptTime.add(const Duration(minutes: 30));
        return selectedDateTime.isAfter(apptTime.subtract(const Duration(minutes: 1))) &&
            selectedDateTime.isBefore(apptEnd);
      });

      debugPrint(
          'Validating time: ${time.format(context)}, isWithinHours: $isWithinHours, isDuringPause: $isDuringPause, hasConflict: $hasConflict');
      return isWithinHours && !isDuringPause && !hasConflict;
    } catch (e) {
      debugPrint('Error validating time slot: $e');
      return false;
    }
  }

  Map<int, Map<String, String>> _parseWorkingHours(String? workingHoursJson) {
    final daysMapping = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };

    final Map<int, Map<String, String>> result = {};

    if (workingHoursJson == null || workingHoursJson.isEmpty) {
      debugPrint('Working hours JSON is null or empty');
      setState(() => _errorMessage = 'Working hours data is missing');
      return result;
    }

    debugPrint('Received working hours JSON: $workingHoursJson');

    try {
      final List<dynamic> entries = jsonDecode(workingHoursJson);
      debugPrint('Parsed JSON entries: $entries');

      for (var entry in entries) {
        if (entry is Map<String, dynamic>) {
          final day = entry['day']?.toString().toLowerCase();
          if (day == null || !daysMapping.containsKey(day)) {
            debugPrint('Invalid or missing day: $day');
            continue;
          }

          final weekday = daysMapping[day]!;
          final timeFormat = RegExp(r'^\d{1,2}:\d{2}$');

          if (entry.containsKey('start') && entry.containsKey('end')) {
            final start = entry['start']?.toString();
            final end = entry['end']?.toString();
            final pauseStart = entry['pauseStart']?.toString();
            final pauseEnd = entry['pauseEnd']?.toString();

            if (start != null && end != null && timeFormat.hasMatch(start) && timeFormat.hasMatch(end)) {
              final normalizedStart = start.padLeft(5, '0');
              final normalizedEnd = end.padLeft(5, '0');
              result[weekday] = {
                'start': normalizedStart,
                'end': normalizedEnd,
                'pauseStart': pauseStart != null && timeFormat.hasMatch(pauseStart) ? pauseStart.padLeft(5, '0') : '',
                'pauseEnd': pauseEnd != null && timeFormat.hasMatch(pauseEnd) ? pauseEnd.padLeft(5, '0') : '',
              };
              debugPrint('Parsed entry for $day: start=$normalizedStart, end=$normalizedEnd, pauseStart=$pauseStart, pauseEnd=$pauseEnd');
            } else {
              debugPrint('Invalid time format for day $day: start=$start, end=$end');
            }
          } else if (entry.containsKey('hours')) {
            final hours = entry['hours']?.toString();
            if (hours == null || hours.isEmpty) {
              debugPrint('Empty hours field for day $day');
              continue;
            }

            final hoursPattern = RegExp(r'(\d{2}:\d{2})\s*->\s*(\d{2}:\d{2})\s*\(Break\)\s*->\s*(\d{2}:\d{2})\s*->\s*(\d{2}:\d{2})');
            final simplePattern = RegExp(r'(\d{2}:\d{2})\s*->\s*(\d{2}:\d{2})');

            if (hoursPattern.hasMatch(hours)) {
              final match = hoursPattern.firstMatch(hours)!;
              final start = match.group(1);
              final pauseStart = match.group(2);
              final pauseEnd = match.group(3);
              final end = match.group(4);

              if (start != null && pauseStart != null && pauseEnd != null && end != null &&
                  timeFormat.hasMatch(start) && timeFormat.hasMatch(pauseStart) &&
                  timeFormat.hasMatch(pauseEnd) && timeFormat.hasMatch(end)) {
                result[weekday] = {
                  'start': start.padLeft(5, '0'),
                  'pauseStart': pauseStart.padLeft(5, '0'),
                  'pauseEnd': pauseEnd.padLeft(5, '0'),
                  'end': end.padLeft(5, '0'),
                };
                debugPrint('Parsed hours for $day: start=$start, pauseStart=$pauseStart, pauseEnd=$pauseEnd, end=$end');
              } else {
                debugPrint('Invalid time format in hours for day $day: $hours');
              }
            } else if (simplePattern.hasMatch(hours)) {
              final match = simplePattern.firstMatch(hours)!;
              final start = match.group(1);
              final end = match.group(2);

              if (start != null && end != null && timeFormat.hasMatch(start) && timeFormat.hasMatch(end)) {
                result[weekday] = {
                  'start': start.padLeft(5, '0'),
                  'end': end.padLeft(5, '0'),
                  'pauseStart': '',
                  'pauseEnd': '',
                };
                debugPrint('Parsed simple hours for $day: start=$start, end=$end');
              } else {
                debugPrint('Invalid time format in simple hours for day $day: $hours');
              }
            } else {
              debugPrint('Unrecognized hours format for day $day: $hours');
            }
          } else {
            debugPrint('Missing required fields in entry: $entry');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing working hours: $e');
      setState(() => _errorMessage = 'Error parsing working hours');
    }

    if (result.isEmpty) {
      setState(() => _errorMessage = 'No valid working hours found');
    }

    return result;
  }

  bool _isTimeWithinWorkingHours() {
    if (selectedDate == null || selectedTime == null) {
      debugPrint('Selected date or time is null');
      return false;
    }

    final int dayOfWeek = selectedDate!.weekday;
    debugPrint('Selected date: $selectedDate, weekday: $dayOfWeek');
    debugPrint('Selected time: ${selectedTime!.hour}:${selectedTime!.minute}');

    final dayHours = parsedWorkingHours[dayOfWeek];
    if (dayHours == null) {
      debugPrint('No working hours for weekday $dayOfWeek');
      return false;
    }

    final String startTimeStr = dayHours['start'] ?? '';
    final String endTimeStr = dayHours['end'] ?? '';
    final String pauseStartStr = dayHours['pauseStart'] ?? '';
    final String pauseEndStr = dayHours['pauseEnd'] ?? '';
    debugPrint('Working hours for day $dayOfWeek: start=$startTimeStr, end=$endTimeStr, pause=$pauseStartStr-$pauseEndStr');

    if (startTimeStr.isEmpty || endTimeStr.isEmpty) {
      debugPrint('Start or end time is empty');
      return false;
    }

    final DateFormat dateFormat = DateFormat('HH:mm');

    try {
      final DateTime startTime = dateFormat.parse(startTimeStr);
      final DateTime endTime = dateFormat.parse(endTimeStr);

      final DateTime selectedDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      final DateTime? fullStart = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        startTime.hour,
        startTime.minute,
      );

      final fullEnd = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        endTime.hour,
        endTime.minute,
      );

      final isWithinHours = (selectedDateTime.isAfter(fullStart!) || selectedDateTime.isAtSameMomentAs(fullStart)) &&
          (selectedDateTime.isBefore(fullEnd) || selectedDateTime.isAtSameMomentAs(fullEnd));

      bool isDuringPause = false;
      if (pauseStartStr.isNotEmpty && pauseEndStr.isNotEmpty) {
        final timeFormat = RegExp(r'^\d{2}:\d{2}$');
        if (!timeFormat.hasMatch(pauseStartStr) || !timeFormat.hasMatch(pauseEndStr)) {
          debugPrint('Invalid pause time format: pauseStart=$pauseStartStr, pauseEnd=$pauseEndStr');
          return isWithinHours;
        }

        final pauseStartTime = dateFormat.parse(pauseStartStr);
        final pauseEndTime = dateFormat.parse(pauseEndStr);

        final fullPauseStart = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          pauseStartTime.hour,
          pauseStartTime.minute,
        );

        final fullPauseEnd = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          pauseEndTime.hour,
          pauseEndTime.minute,
        );

        isDuringPause = selectedDateTime.isAtSameMomentAs(fullPauseStart) ||
            (selectedDateTime.isAfter(fullPauseStart) && selectedDateTime.isBefore(fullPauseEnd));
      }

      bool hasConflict = acceptedAppointmentTimes.any((apptTime) {
        final apptEnd = apptTime.add(const Duration(minutes: 30));
        return selectedDateTime.isAfter(apptTime.subtract(const Duration(minutes: 1))) &&
            selectedDateTime.isBefore(apptEnd);
      });

      debugPrint('Selected: $selectedDateTime, Start: $fullStart, End: $fullEnd, Pause: $isDuringPause, Conflict: $hasConflict');
      return isWithinHours && !isDuringPause && !hasConflict;
    } catch (e) {
      debugPrint('Error parsing times: $e');
      return false;
    }
  }

  Future<void> _createAppointment() async {
    debugPrint('Attempting to create appointment');
    if (selectedPetId == null ||
        selectedDate == null ||
        selectedTime == null ||
        selectedAppointmentType == null ||
        selectedService == null ||
        services.contains('No services available')) {
      debugPrint('Validation failed: Missing required fields or no services available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields or check veterinarian services')),
      );
      return;
    }

    if (!_isTimeWithinWorkingHours()) {
      final dayHours = parsedWorkingHours[selectedDate!.weekday];
      final pauseStartStr = dayHours?['pauseStart'] ?? '';
      final pauseEndStr = dayHours?['pauseEnd'] ?? '';
      final isDuringBreak = pauseStartStr.isNotEmpty &&
          pauseEndStr.isNotEmpty &&
          selectedTime != null &&
          DateFormat('HH:mm').parse(pauseStartStr).hour <= selectedTime!.hour &&
          selectedTime!.hour <= DateFormat('HH:mm').parse(pauseEndStr).hour;

      bool hasConflict = acceptedAppointmentTimes.any((apptTime) {
        final apptEnd = apptTime.add(const Duration(minutes: 30));
        final selectedDateTime = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          selectedTime!.hour,
          selectedTime!.minute,
        );
        return selectedDateTime.isAfter(apptTime.subtract(const Duration(minutes: 1))) &&
            selectedDateTime.isBefore(apptEnd);
      });

      debugPrint('Time validation failed: isDuringBreak=$isDuringBreak, hasConflict=$hasConflict');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasConflict
                ? 'The selected time conflicts with an existing appointment.'
                : isDuringBreak
                ? 'The selected time falls during the veterinarian\'s break period ($pauseStartStr–$pauseEndStr).'
                : 'The selected time is outside the veterinarian\'s working hours.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      debugPrint('setState: Starting appointment creation, isSubmitting: true');
    });

    try {
      final appointmentDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      debugPrint('Creating appointment with Veterinarian ID: ${widget.vet.id}, date: $appointmentDateTime, petId: $selectedPetId, type: $selectedAppointmentType, service: $selectedService');
      final result = await _appointmentService.createAppointment(
        veterinaireId: widget.vet.id!,
        date: appointmentDateTime,
        animalId: selectedPetId!,
        type: selectedAppointmentType!,
        services: [selectedService!],
        caseDescription: caseDescription,
      );
      debugPrint('Create appointment response: $result');

      if (result['success'] == true) {
        debugPrint('Appointment created successfully');
        setState(() {
          _isSubmitting = false;
          selectedPetId = null;
          selectedDate = null;
          selectedTime = null;
          selectedAppointmentType = null;
          selectedService = null;
          caseDescription = null;
          debugPrint('setState: isSubmitting: false, form reset');
        });
        await _initializeUserAndPets();
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Appointment Booked'),
              content: const Text('Your appointment has been booked. It is pending veterinarian approval.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment created successfully!')),
          );
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        debugPrint('Failed to create appointment: ${result['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Error creating appointment')),
        );
        setState(() {
          _isSubmitting = false;
          debugPrint('setState: isSubmitting: false (error case)');
        });
      }
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating appointment: ${e.toString()}')),
      );
      setState(() {
        _isSubmitting = false;
        debugPrint('setState: isSubmitting: false (exception case)');
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    debugPrint('Disposing AppointmentsScreen');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building AppointmentsScreen, acceptedAppointmentTimes: $acceptedAppointmentTimes');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
          : _buildAppointmentForm(),
    );
  }

  Widget _buildAppointmentForm() {
    final localizations = MaterialLocalizations.of(context);
    debugPrint('Building appointment form, isSubmitting: $_isSubmitting');
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('1. Select Your Pet'),
          const SizedBox(height: 12),
          pets.isEmpty
              ? const Text('No pets found. Please add a pet first.', style: TextStyle(color: Colors.red, fontSize: 14))
              : _buildPetSelector(),
          const SizedBox(height: 24),
          _sectionTitle('2. Select Date & Time'),
          const SizedBox(height: 12),
          _buildWorkingHours(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectTime,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    selectedTime == null
                        ? 'Select Time'
                        : localizations.formatTimeOfDay(selectedTime!).replaceAll(RegExp(r'\s+'), ' '),
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('3. Appointment Type'),
          const SizedBox(height: 12),
          _buildDropdown(
            hint: 'Select type',
            value: selectedAppointmentType,
            items: appointmentTypes,
            onChanged: (value) => setState(() => selectedAppointmentType = value),
          ),
          const SizedBox(height: 24),
          _sectionTitle('4. Service Needed'),
          const SizedBox(height: 12),
          _buildDropdown(
            hint: services.contains('No services available') ? 'No services available' : 'Select service',
            value: selectedService,
            items: services,
            onChanged: services.contains('No services available')
                ? null
                : (value) => setState(() => selectedService = value),
          ),
          const SizedBox(height: 24),
          _sectionTitle('5. Case Description (Optional)'),
          const SizedBox(height: 12),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe your pet\'s condition...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) => caseDescription = value,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              onPressed: (_isSubmitting || services.contains('No services available')) ? null : _createAppointment,
              child: _isSubmitting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
                  : const Text(
                'BOOK APPOINTMENT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
    );
  }

  Widget _buildPetSelector() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        itemBuilder: (context, index) {
          final pet = pets[index];
          final petId = pet['_id']?.toString();
          final isSelected = petId == selectedPetId;
          final String name = pet['name']?.toString() ?? 'Unnamed';
          final String? imagePath = pet['picture'];
          final String? imageUrl = imagePath != null && !imagePath.startsWith('http')
              ? 'http://192.168.1.16:3000/api/uploads/animals/$imagePath'
              : imagePath;

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              elevation: 2,
              child: InkWell(
                onTap: petId != null ? () => setState(() => selectedPetId = petId) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: imageUrl != null
                            ? NetworkImage(imageUrl)
                            : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                        onBackgroundImageError: (_, __) {},
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkingHours() {
    if (parsedWorkingHours.isEmpty) {
      return const Text(
        'Working hours not available. Please contact the veterinarian for scheduling.',
        style: TextStyle(color: Colors.red, fontSize: 14),
      );
    }

    final daysMapping = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    final sortedHours = parsedWorkingHours.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedHours.map((entry) {
            final day = daysMapping[entry.key] ?? 'Day ${entry.key}';
            final start = entry.value['start'] ?? 'N/A';
            final end = entry.value['end'] ?? 'N/A';
            final pauseStart = entry.value['pauseStart']?.isNotEmpty == true ? entry.value['pauseStart'] : null;
            final pauseEnd = entry.value['pauseEnd']?.isNotEmpty == true ? entry.value['pauseEnd'] : null;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day name
                  SizedBox(
                    width: 100,
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Time schedule
                  Row(
                    children: [
                      _buildTimeChip('$start - ${pauseStart ?? end}', Colors.purple),
                      if (pauseStart != null && pauseEnd != null) ...[
                        const SizedBox(width: 8),
                        _buildBreakChip(),
                        const SizedBox(width: 8),
                        _buildTimeChip('$pauseEnd - $end', Colors.purple),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[100]!),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: color[700],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline, size: 14, color: Colors.red[600]),
          const SizedBox(width: 4),
          Text(
            'Break',
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}