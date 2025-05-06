import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/pet_service.dart';
import 'package:vetapp_v1/services/appointment_service.dart';
import 'package:dio/dio.dart';
import 'package:vetapp_v1/models/veterinarian.dart';

class AppointmentsScreen extends StatefulWidget {
  final Veterinarian vet;
  const AppointmentsScreen({Key? key, required this.vet}) : super(key: key);

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
  final List<String> appointmentTypes = ['domicile', 'cabinet'];
  final List<String> services = ['Consultation', 'Vaccination', 'Surgery', 'Grooming'];

  bool _isLoading = false;
  bool _isSubmitting = false;
  late final AppointmentService _appointmentService;
  late final PetService _petService;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.1.18:3000/api',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
    _appointmentService = AppointmentService(dio: dio);
    _petService = PetService(dio: dio);
    _initializeUserAndPets();
  }

  Future<void> _initializeUserAndPets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _fetchPets();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPets() async {
    try {
      final fetchedPets = await _petService.getUserPets();
      setState(() => pets = fetchedPets);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load pets: ${e.toString()}');
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
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> _createAppointment() async {
    if (selectedPetId == null ||
        selectedDate == null ||
        selectedTime == null ||
        selectedAppointmentType == null ||
        selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appointmentDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
      print('Veterinaire ID: ${widget.vet.id}');

      final result = await _appointmentService.createAppointment(
        veterinaireId: widget.vet.id,
        date: appointmentDateTime,
        animalId: selectedPetId!,
        type: selectedAppointmentType!,
        services: [selectedService!],
        caseDescription: caseDescription,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment created successfully!")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Error creating appointment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildAppointmentForm(),
    );
  }

  Widget _buildAppointmentForm() {
    final localizations = MaterialLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("1. Select Your Pet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (pets.isEmpty)
            const Text('No pets found. Please add a pet first.', style: TextStyle(color: Colors.red)),
          if (pets.isNotEmpty) _buildPetSelector(),
          const SizedBox(height: 24),

          const Text("2. Select Date & Time", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

          const Text("3. Appointment Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedAppointmentType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select type',
            ),
            items: appointmentTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type[0].toUpperCase() + type.substring(1)),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedAppointmentType = value),
          ),
          const SizedBox(height: 24),

          const Text("4. Service Needed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedService,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select service',
            ),
            items: services.map((service) {
              return DropdownMenuItem(
                value: service,
                child: Text(service),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedService = value),
          ),
          const SizedBox(height: 24),

          const Text("5. Case Description (Optional)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your pet\'s condition...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => caseDescription = value,
          ),
          const SizedBox(height: 32),

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
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
                  : const Text('BOOK APPOINTMENT', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelector() {
    return Column(
      children: pets.map((pet) {
        final isSelected = pet['_id'] == selectedPetId;
        final String name = pet['name']?.toString() ?? 'Unnamed';
        final String type = pet['type']?.toString() ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              Icons.pets,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            title: Text(
              name,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Text(type),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                : null,
            onTap: () => setState(() => selectedPetId = pet['_id']),
          ),
        );
      }).toList(),
    );
  }

}
