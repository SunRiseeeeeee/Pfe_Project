import 'package:flutter/material.dart';
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
  String? selectedReason;

  final List<String> petTypes = ['Dog', 'Cat', 'Bird', 'Fish'];
  final List<String> vetTypes = ['General', 'Emergency'];
  final List<String> services = ['Consultation', 'Vaccination'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[160], // Darker background
      appBar: AppBar(
        title: const Text('Appointments'),
        leading: BackButton(color: Colors.black),
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
              Text(
                'Choose your pet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 55,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: petTypes.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 15),
                  itemBuilder: (context, index) {
                    final pet = petTypes[index];
                    final isSelected = pet == selectedPetType;
                    final petImage = {
                      'Dog': 'assets/images/pet2.jpg',
                      'Cat': 'assets/images/pet3.jpg',
                      'Bird': 'assets/images/pet4.jpg',
                      'Fish': 'assets/images/pet5.jpg',
                    }[pet];

                    return GestureDetector(
                      onTap: () => setState(() => selectedPetType = pet),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white, // White background for all pets
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
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Date'),
                        _buildSelectableBox(
                          text: selectedDate != null
                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                              : 'Select Date',
                          icon: Icons.calendar_today,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(DateTime.now().year + 1),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Time'), // Add "Time" label here
                        _buildSelectableBox(
                          text: selectedTime != null
                              ? selectedTime!.format(context)
                              : 'Select Time',
                          icon: Icons.access_time,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('Veterinary type'),
              _buildDropdownWithPlaceholder(
                vetTypes,
                selectedVetType,
                    (val) => setState(() => selectedVetType = val),
                placeholder: 'Choose Type',
              ),
              const SizedBox(height: 24),
              _buildLabel('Service'),
              _buildDropdownWithPlaceholder(
                services,
                selectedService,
                    (val) => setState(() => selectedService = val),
                placeholder: 'Choose Service',
              ),
              const SizedBox(height: 24),
              _buildLabel('Vet'),
              _buildDropdown(
                ['Dr. ${widget.vet.firstName} ${widget.vet.lastName}'],
                'Dr. ${widget.vet.firstName} ${widget.vet.lastName}',
                null,
              ),
              const SizedBox(height: 24),
              _buildLabel('Reason'),
              _buildReasonField(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle next button logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 50, // Add shadow to the button
                    shadowColor: Colors.black.withOpacity(0.2), // Shadow color
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
  }

  Widget _buildSelectableBox({
    required String text,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white, // White background for the box
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.grey[600]),
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String? value, void Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white, // White background for the dropdown
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
    );
  }

  Widget _buildDropdownWithPlaceholder(
      List<String> items,
      String? value,
      void Function(String?)? onChanged, {
        required String placeholder,
      }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        placeholder,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white, // White background for the dropdown
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text(placeholder)),
        ...items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
      ],
    );
  }

  Widget _buildReasonField() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, // White background for the field
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'e.g. Fever',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: Icon(Icons.edit, color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        onChanged: (val) => setState(() => selectedReason = val),
      ),
    );
  }
}
