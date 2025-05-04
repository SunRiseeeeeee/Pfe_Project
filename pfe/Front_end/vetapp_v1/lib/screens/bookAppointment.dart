import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
import 'package:dio/dio.dart';

class AppointmentsScreen extends StatefulWidget {
  final Veterinarian vet;
  const AppointmentsScreen({Key? key, required this.vet}) : super(key: key);

  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String? selectedPetType;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedVetType;
  String? selectedService;

  final List<String> petTypes = ['Dog', 'Cat', 'Bird', 'Fish'];
  final List<String> vetTypes = ['domicile', 'cabinet'];
  final List<String> services = ['Consultation', 'Vaccination'];

  bool _isLoading = false;
  late final AppointmentService _appointmentService;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService(
      dio: Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')),
    );
  }

  void _resetForm() {
    setState(() {
      selectedPetType = null;
      selectedDate = null;
      selectedTime = null;
      selectedVetType = null;
      selectedService = null;
    });
  }

  Future<void> _createAppointment() async {
    if (selectedPetType == null ||
        selectedDate == null ||
        selectedTime == null ||
        selectedVetType == null ||
        selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appointmentDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      final result = await _appointmentService.createAppointment(
        veterinaireId: widget.vet.id, // Ensure this is a valid ObjectId string
        date: appointmentDateTime,
        animalType: selectedPetType!,
        type: selectedVetType!,
        services: [selectedService!],
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment created successfully!")),
        );
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Error creating appointment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred. Please try again.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Appointments'),
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Choose your pet'),
              const SizedBox(height: 12),
              _buildPetSelector(),

              const SizedBox(height: 20),
              _buildSectionTitle('Select appointment type'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedVetType,
                items: vetTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type[0] + type.substring(1).toLowerCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedVetType = value),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Type',
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionTitle('Select service'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedService,
                items: services.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedService = value),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Service',
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionTitle('Select date and time'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(selectedDate == null
                          ? 'Pick date'
                          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'),
                      onPressed: _pickDate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(selectedTime == null
                          ? 'Pick time'
                          : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'),
                      onPressed: _pickTime,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Book Appointment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildPetSelector() {
    final petImageMap = {
      'Dog': 'assets/images/pet2.jpg',
      'Cat': 'assets/images/pet3.jpg',
      'Bird': 'assets/images/pet4.jpg',
      'Fish': 'assets/images/pet5.jpg',
    };

    return SizedBox(
      height: 55,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: petTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final pet = petTypes[index];
          final isSelected = pet == selectedPetType;
          final petImage = petImageMap[pet];

          return GestureDetector(
            onTap: () => setState(() => selectedPetType = pet),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (petImage != null)
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: AssetImage(petImage),
                      backgroundColor: Colors.transparent,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    pet,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.deepPurple : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
