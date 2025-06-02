import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/pet_service.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
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
  final List<String> appointmentTypes = ['domicile', 'cabinet'];
  final List<String> services = ['Consultation', 'Vaccination', 'Surgery', 'Grooming'];

  bool _isLoading = false;
  bool _isSubmitting = false;
  late final AppointmentService _appointmentService;
  late final PetService _petService;
  String? _errorMessage;
  final _scrollController = ScrollController();
  late Map<int, Map<String, String>> parsedWorkingHours;

  @override
  void initState() {
    super.initState();
    debugPrint('initState: Initializing AppointmentsScreen, vetId: ${widget.vet.id}');

    final dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.100.7:3000/api',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _appointmentService = AppointmentService(dio: dio);
    _petService = PetService(dio: dio);

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
      debugPrint('Fetched accepted appointment times response: $acceptedTimesResponse');

      if (acceptedTimesResponse['success'] == true) {
        acceptedAppointmentTimes = List<DateTime>.from(acceptedTimesResponse['data']);
        debugPrint('Accepted appointment times: $acceptedAppointmentTimes');
      } else {
        debugPrint('Failed to fetch accepted appointment times: ${acceptedTimesResponse['message']}');
      }

      setState(() {
        pets = fetchedPets;
        _isLoading = false;
        debugPrint('setState: Pets loaded, isLoading: false, acceptedAppointmentTimes: $acceptedAppointmentTimes');
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
        current = current.add(const Duration(minutes: 15));
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
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
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
                        color: isValid ? Colors.grey : Colors.red,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        time.format(context),
                        style: TextStyle(
                          color: isValid ? Colors.black : Colors.red,
                          fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
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
              child: const Text('Cancel'),
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
      // Check working hours
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

      // Check pause time
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

      // Check for conflicts with accepted appointments
      bool hasConflict = acceptedAppointmentTimes.any((apptTime) {
        final apptEnd = apptTime.add(const Duration(minutes: 20));
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
          final start = entry['start']?.toString();
          final end = entry['end']?.toString();
          final pauseStart = entry['pauseStart']?.toString();
          final pauseEnd = entry['pauseEnd']?.toString();

          if (day != null && start != null && end != null) {
            final weekday = daysMapping[day];
            if (weekday != null) {
              final timeFormat = RegExp(r'^\d{1,2}:\d{2}$');
              if (timeFormat.hasMatch(start) && timeFormat.hasMatch(end)) {
                final normalizedStart = start.padLeft(5, '0');
                final normalizedEnd = end.padLeft(5, '0');
                result[weekday] = {
                  'start': normalizedStart,
                  'end': normalizedEnd,
                  'pauseStart': pauseStart ?? '',
                  'pauseEnd': pauseEnd ?? '',
                };
              } else {
                debugPrint('Invalid time format for day $day: start=$start, end=$end');
              }
            } else {
              debugPrint('Invalid day: $day');
            }
          } else {
            debugPrint('Missing fields in entry: $entry');
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

      final DateTime fullStart = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        startTime.hour,
        startTime.minute,
      );

      final DateTime fullEnd = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        endTime.hour,
        endTime.minute,
      );

      final isWithinHours = (selectedDateTime.isAfter(fullStart) || selectedDateTime.isAtSameMomentAs(fullStart)) &&
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
        final apptEnd = apptTime.add(const Duration(minutes: 20));
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
        selectedService == null) {
      debugPrint('Validation failed: Missing required fields');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
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
        final apptEnd = apptTime.add(const Duration(minutes: 20));
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
        // Refresh accepted appointment times
        await _initializeUserAndPets();
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Appointment Booked'),
              content: const Text('Your appointment has been booked. It is pending veterinarian approval.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
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
        SnackBar(content: Text('Error: ${e.toString()}')),
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
      appBar: AppBar(title: const Text('Book Appointment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildAppointmentForm(),
    );
  }

  Widget _buildAppointmentForm() {
    final localizations = MaterialLocalizations.of(context);
    debugPrint('Building appointment form, isSubmitting: $_isSubmitting');
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('1. Select Your Pet'),
          const SizedBox(height: 8),
          pets.isEmpty
              ? const Text('No pets found. Please add a pet first.', style: TextStyle(color: Colors.red))
              : _buildPetSelector(),
          const SizedBox(height: 24),
          _sectionTitle('2. Select Date & Time'),
          const SizedBox(height: 8),
          _buildWorkingHours(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectDate,
                  child: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectTime,
                  child: Text(
                    selectedTime == null
                        ? 'Select Time'
                        : localizations.formatTimeOfDay(selectedTime!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('3. Appointment Type'),
          const SizedBox(height: 8),
          _buildDropdown(
            hint: 'Select type',
            value: selectedAppointmentType,
            items: appointmentTypes,
            onChanged: (value) => setState(() => selectedAppointmentType = value),
          ),
          const SizedBox(height: 24),
          _sectionTitle('4. Service Needed'),
          const SizedBox(height: 8),
          _buildDropdown(
            hint: 'Select service',
            value: selectedService,
            items: services,
            onChanged: (value) => setState(() => selectedService = value),
          ),
          const SizedBox(height: 24),
          _sectionTitle('5. Case Description (Optional)'),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your pet\'s condition...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => caseDescription = value,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              onPressed: _isSubmitting ? null : _createAppointment,
              child: _isSubmitting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
                  : const Text(
                'BOOK APPOINTMENT',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPetSelector() {
    return SizedBox(
      height: 115,
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
              ? 'http://192.168.100.7:3000/api/uploads/animals/$imagePath'
              : imagePath;

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: petId != null ? () => setState(() => selectedPetId = petId) : null,
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
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
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

    final hoursText = sortedHours.map((entry) {
      final day = daysMapping[entry.key] ?? 'Day ${entry.key}';
      final start = entry.value['start'] ?? 'N/A';
      final end = entry.value['end'] ?? 'N/A';
      final pauseStart = entry.value['pauseStart'] ?? '';
      final pauseEnd = entry.value['pauseEnd'] ?? '';
      String formatted = '$day: $start → $end';
      if (pauseStart.isNotEmpty && pauseEnd.isNotEmpty) {
        formatted += ' (Break: $pauseStart → $pauseEnd)';
      }
      return formatted;
    }).join(', ');

    return Text(
      'Working Hours: $hoursText',
      style: const TextStyle(fontSize: 14, color: Colors.black87),
    );
  }
}