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
  String? selectedPetType;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedVetType;
  String? selectedService;
  List<String> petTypes = [];  // This will hold the fetched pet names

  bool _isLoading = false;
  late final AppointmentService _appointmentService;
  late final PetService _petService;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService(
      dio: Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')),
    );
    _petService = PetService(dio: Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')));

    // Fetch the pets for the user
    _fetchPets();
  }

  Future<void> _fetchPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = "USER_ID_HERE";  // Get the actual userId from your authentication system
      final pets = await _petService.getUserPets(userId);

      setState(() {
        petTypes = pets;
      });
    } catch (e) {
      print('Error fetching pets: $e');
      setState(() {
        petTypes = []; // Empty list if there was an error
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAppointment() async {
    if (selectedPetType == null || selectedDate == null || selectedTime == null || selectedVetType == null || selectedService == null) {
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
        veterinaireId: widget.vet.id,  // Make sure the veterinarian ID is correct
        date: appointmentDateTime,
        animalType: selectedPetType!,
        type: selectedVetType!,
        services: [selectedService!],
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment created successfully!")),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Pet Selector
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : petTypes.isEmpty
                  ? const Center(child: Text('No pets found'))
                  : _buildPetSelector(),
            ],
          ),
        ),
      ),
    );
  }

  // This widget will allow the user to choose from the fetched pets
  Widget _buildPetSelector() {
    return Column(
      children: petTypes.map((pet) {
        final isSelected = pet == selectedPetType;
        return GestureDetector(
          onTap: () => setState(() => selectedPetType = pet),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.deepPurple : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey),
            ),
            child: Text(
              pet,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
