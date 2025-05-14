import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/pet_file_service.dart';
import '../services/client_service.dart';

class AnimalFicheScreen extends StatefulWidget {
  final Animal animal;
  final String vetId;
  final String clientId;
  final String? ficheId;

  const AnimalFicheScreen({
    super.key,
    required this.animal,
    required this.vetId,
    required this.clientId,
    this.ficheId,
  });

  @override
  State<AnimalFicheScreen> createState() => _AnimalFicheScreenState();
}

class _AnimalFicheScreenState extends State<AnimalFicheScreen> {
  late final PetFileService _petFileService;
  AnimalFiche? _fiche;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isEditing = false;

  // Form controllers for simple fields
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _dietController = TextEditingController();
  final _behaviorNotesController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _generalNotesController = TextEditingController();
  final _allergiesController = TextEditingController();

  // Lists for complex fields
  List<Vaccination> _vaccinations = [];
  List<Treatment> _treatments = [];
  List<Examination> _examinations = [];
  List<AppointmentRecord> _appointments = [];
  List<String> _allergies = [];
  DateTime? _recommendedNextVisit;

  @override
  void initState() {
    super.initState();
    final dio = Provider.of<Dio>(context, listen: false);
    _petFileService = PetFileService(dio: dio);
    _loadFiche();
  }

  Future<void> _loadFiche() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      AnimalFiche? fiche;
      if (widget.ficheId != null && widget.ficheId!.isNotEmpty) {
        debugPrint('Loading fiche with ficheId: ${widget.ficheId}');
        fiche = await _petFileService.fetchFicheById(widget.ficheId!);
      } else {
        debugPrint('No ficheId provided, attempting to fetch by animalId: ${widget.animal.id}');
        fiche = await _petFileService.fetchFicheByAnimalId(widget.animal.id);
        if (fiche == null) {
          debugPrint('No fiche found for animalId: ${widget.animal.id}. Prompting to create a new fiche.');
        }
      }

      setState(() {
        _fiche = fiche;
        if (fiche != null) {
          debugPrint('Fiche loaded successfully: ${fiche.id}');
          _weightController.text = fiche.weight?.toString() ?? '';
          _heightController.text = fiche.height?.toString() ?? '';
          _temperatureController.text = fiche.temperature?.toString() ?? '';
          _dietController.text = fiche.diet ?? '';
          _behaviorNotesController.text = fiche.behaviorNotes ?? '';
          _medicalHistoryController.text = fiche.medicalHistory ?? '';
          _generalNotesController.text = fiche.generalNotes ?? '';
          _vaccinations = fiche.vaccinations ?? [];
          _treatments = fiche.treatments ?? [];
          _examinations = fiche.examinations ?? [];
          _appointments = fiche.appointments ?? [];
          _allergies = fiche.allergies ?? [];
          _recommendedNextVisit = fiche.recommendedNextVisit;
        } else {
          _errorMessage = 'No fiche found. Please create a new fiche.';
        }
      });
    } catch (e) {
      debugPrint('Error loading fiche: $e');
      setState(() {
        _errorMessage = e.toString().contains('404')
            ? 'Fiche not found for the provided ID. Please create a new fiche.'
            : 'Failed to load fiche: $e. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (_weightController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _temperatureController.text.isEmpty ||
        _dietController.text.trim().isEmpty ||
        _behaviorNotesController.text.trim().isEmpty ||
        _medicalHistoryController.text.trim().isEmpty ||
        _generalNotesController.text.trim().isEmpty ||
        _recommendedNextVisit == null) {
      setState(() {
        _errorMessage = 'Please fill all required fields.';
      });
      return false;
    }
    if (double.tryParse(_weightController.text) == null ||
        double.tryParse(_heightController.text) == null ||
        double.tryParse(_temperatureController.text) == null) {
      setState(() {
        _errorMessage = 'Weight, height, and temperature must be valid numbers.';
      });
      return false;
    }
    return true;
  }

  Future<void> _createOrUpdateFiche() async {
    if (_isEditing && !_validateForm()) return;

    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final temperature = double.tryParse(_temperatureController.text);
    final diet = _dietController.text.trim();
    final behaviorNotes = _behaviorNotesController.text.trim();
    final medicalHistory = _medicalHistoryController.text.trim();
    final generalNotes = _generalNotesController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      AnimalFiche updatedFiche;
      if (_fiche == null) {
        updatedFiche = await _petFileService.createFiche(
          animalId: widget.animal.id,
          veterinarianId: widget.vetId,
          clientId: widget.clientId,
          weight: weight,
          height: height,
          temperature: temperature,
          vaccinations: _vaccinations.isNotEmpty ? _vaccinations : null,
          treatments: _treatments.isNotEmpty ? _treatments : null,
          examinations: _examinations.isNotEmpty ? _examinations : null,
          appointments: _appointments.isNotEmpty ? _appointments : null,
          allergies: _allergies.isNotEmpty ? _allergies : null,
          diet: diet.isNotEmpty ? diet : null,
          behaviorNotes: behaviorNotes.isNotEmpty ? behaviorNotes : null,
          medicalHistory: medicalHistory.isNotEmpty ? medicalHistory : null,
          recommendedNextVisit: _recommendedNextVisit,
          generalNotes: generalNotes.isNotEmpty ? generalNotes : null,
        );
        debugPrint('Created fiche with ID: ${updatedFiche.id}');
      } else {
        updatedFiche = await _petFileService.updateFiche(
          ficheId: _fiche!.id,
          weight: weight,
          height: height,
          temperature: temperature,
          vaccinations: _vaccinations.isNotEmpty ? _vaccinations : null,
          treatments: _treatments.isNotEmpty ? _treatments : null,
          examinations: _examinations.isNotEmpty ? _examinations : null,
          appointments: _appointments.isNotEmpty ? _appointments : null,
          allergies: _allergies.isNotEmpty ? _allergies : null,
          diet: diet.isNotEmpty ? diet : null,
          behaviorNotes: behaviorNotes.isNotEmpty ? behaviorNotes : null,
          medicalHistory: medicalHistory.isNotEmpty ? medicalHistory : null,
          recommendedNextVisit: _recommendedNextVisit,
          generalNotes: generalNotes.isNotEmpty ? generalNotes : null,
        );
        debugPrint('Updated fiche with ID: ${updatedFiche.id}');
      }
      setState(() {
        _fiche = updatedFiche;
        _isEditing = false;
      });
    } catch (e) {
      debugPrint('Error saving fiche: $e');
      setState(() {
        _errorMessage = e.toString().contains('Cannot POST')
            ? 'Failed to create fiche. The server is not accepting requests.'
            : 'Failed to save fiche: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addVaccination() async {
    final nameController = TextEditingController();
    DateTime? date = DateTime.now();
    DateTime? nextDueDate;
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vaccination'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Date: ${DateFormat.yMMMd().format(date!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) date = picked;
                },
              ),
              ListTile(
                title: Text(nextDueDate == null ? 'Next Due Date' : 'Next Due: ${DateFormat.yMMMd().format(nextDueDate!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) nextDueDate = picked;
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vaccination name is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _vaccinations.add(Vaccination(
          name: nameController.text.trim(),
          date: date!,
          nextDueDate: nextDueDate,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        ));
      });
    }
  }

  Future<void> _addTreatment() async {
    final nameController = TextEditingController();
    DateTime? startDate = DateTime.now();
    DateTime? endDate;
    final dosageController = TextEditingController();
    final freqencyController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Treatment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Start Date: ${DateFormat.yMMMd().format(startDate!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) startDate = picked;
                },
              ),
              ListTile(
                title: Text(endDate == null ? 'End Date' : 'End Date: ${DateFormat.yMMMd().format(endDate!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) endDate = picked;
                },
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
              TextField(
                controller: freqencyController,
                decoration: const InputDecoration(labelText: 'Frequency'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Treatment name is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _treatments.add(Treatment(
          name: nameController.text.trim(),
          startDate: startDate!,
          endDate: endDate,
          dosage: dosageController.text.trim().isNotEmpty ? dosageController.text.trim() : null,
          frequency: freqencyController.text.trim().isNotEmpty ? freqencyController.text.trim() : null,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        ));
      });
    }
  }

  Future<void> _addExamination() async {
    final typeController = TextEditingController();
    DateTime? date = DateTime.now();
    final resultsController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Examination'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Date: ${DateFormat.yMMMd().format(date!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) date = picked;
                },
              ),
              TextField(
                controller: resultsController,
                decoration: const InputDecoration(labelText: 'Results'),
                maxLines: 2,
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (typeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Examination type is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _examinations.add(Examination(
          type: typeController.text.trim(),
          date: date!,
          results: resultsController.text.trim().isNotEmpty ? resultsController.text.trim() : null,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        ));
      });
    }
  }

  Future<void> _addAppointment() async {
    DateTime? appointmentDate = DateTime.now();
    final diagnosisController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Appointment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Date: ${DateFormat.yMMMd().format(appointmentDate!)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: appointmentDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) appointmentDate = picked;
                },
              ),
              TextField(
                controller: diagnosisController,
                decoration: const InputDecoration(labelText: 'Diagnosis'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _appointments.add(AppointmentRecord(
          appointmentDate: appointmentDate!,
          diagnosis: diagnosisController.text.trim().isNotEmpty ? diagnosisController.text.trim() : null,
        ));
      });
    }
  }

  void _addAllergy() {
    if (_allergiesController.text.trim().isNotEmpty) {
      setState(() {
        _allergies.add(_allergiesController.text.trim());
        _allergiesController.clear();
      });
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List items, String emptyMessage, Function addFunction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        items.isEmpty
            ? Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map<Widget>((item) {
            String displayText;
            if (item is Vaccination) {
              displayText = '${item.name} (${DateFormat.yMMMd().format(item.date)})';
            } else if (item is Treatment) {
              displayText = '${item.name} (${DateFormat.yMMMd().format(item.startDate)})';
            } else if (item is Examination) {
              displayText = '${item.type} (${DateFormat.yMMMd().format(item.date)})';
            } else if (item is AppointmentRecord) {
              displayText = 'Appointment (${DateFormat.yMMMd().format(item.appointmentDate)})';
            } else {
              displayText = item.toString();
            }
            return Chip(
              label: Text(displayText),
              onDeleted: () {
                setState(() {
                  if (item is Vaccination) _vaccinations.remove(item);
                  if (item is Treatment) _treatments.remove(item);
                  if (item is Examination) _examinations.remove(item);
                  if (item is AppointmentRecord) _appointments.remove(item);
                  if (item is String) _allergies.remove(item);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_isEditing)
          ElevatedButton(
            onPressed: () => addFunction(),
            child: Text('Add $title'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          '${widget.animal.name}’s Medical Fiche',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_fiche != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isEditing ? _createOrUpdateFiche : _loadFiche,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _fiche == null && !_isEditing
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Medical Fiche Found',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create a medical fiche for ${widget.animal.name}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      style: theme.elevatedButtonTheme.style,
                      child: Text(
                        'Create Fiche',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Fiche',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _temperatureController,
                            decoration: const InputDecoration(
                              labelText: 'Temperature (°C)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _dietController,
                            decoration: const InputDecoration(
                              labelText: 'Diet',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _behaviorNotesController,
                            decoration: const InputDecoration(
                              labelText: 'Behavior Notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _medicalHistoryController,
                            decoration: const InputDecoration(
                              labelText: 'Medical History',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _generalNotesController,
                            decoration: const InputDecoration(
                              labelText: 'General Notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _allergiesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Add Allergy',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _addAllergy(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addAllergy,
                              ),
                            ],
                          ),
                          _buildListSection(
                            'Allergies',
                            _allergies,
                            'No allergies added',
                            _addAllergy,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: Text(
                              _recommendedNextVisit == null
                                  ? 'Recommended Next Visit'
                                  : 'Next Visit: ${DateFormat.yMMMd().format(_recommendedNextVisit!)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _recommendedNextVisit = picked;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Vaccinations',
                            _vaccinations,
                            'No vaccinations added',
                            _addVaccination,
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Treatments',
                            _treatments,
                            'No treatments added',
                            _addTreatment,
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Examinations',
                            _examinations,
                            'No examinations added',
                            _addExamination,
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Appointments',
                            _appointments,
                            'No appointments added',
                            _addAppointment,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    if (_fiche == null) {
                                      _weightController.clear();
                                      _heightController.clear();
                                      _temperatureController.clear();
                                      _dietController.clear();
                                      _behaviorNotesController.clear();
                                      _medicalHistoryController.clear();
                                      _generalNotesController.clear();
                                      _allergiesController.clear();
                                      _vaccinations.clear();
                                      _treatments.clear();
                                      _examinations.clear();
                                      _appointments.clear();
                                      _allergies.clear();
                                      _recommendedNextVisit = null;
                                    }
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _createOrUpdateFiche,
                                style: theme.elevatedButtonTheme.style,
                                child: Text(
                                  _fiche == null ? 'Create' : 'Update',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(Icons.fitness_center, 'Weight', _fiche!.weight?.toString() ?? 'N/A'),
                          _buildInfoRow(Icons.height, 'Height', _fiche!.height?.toString() ?? 'N/A'),
                          _buildInfoRow(Icons.thermostat, 'Temperature', _fiche!.temperature?.toString() ?? 'N/A'),
                          _buildInfoRow(Icons.restaurant, 'Diet', _fiche!.diet ?? 'N/A'),
                          _buildInfoRow(Icons.notes, 'Behavior Notes', _fiche!.behaviorNotes ?? 'N/A'),
                          _buildInfoRow(Icons.medical_services, 'Medical History', _fiche!.medicalHistory ?? 'N/A'),
                          _buildInfoRow(Icons.note, 'General Notes', _fiche!.generalNotes ?? 'N/A'),
                          _buildInfoRow(Icons.calendar_today, 'Created', DateFormat.yMMMd().format(_fiche!.creationDate)),
                          _buildInfoRow(Icons.update, 'Last Updated', DateFormat.yMMMd().format(_fiche!.lastUpdate)),
                          _buildInfoRow(
                            Icons.event,
                            'Recommended Next Visit',
                            _fiche!.recommendedNextVisit != null
                                ? DateFormat.yMMMd().format(_fiche!.recommendedNextVisit!)
                                : 'N/A',
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Allergies',
                            _fiche!.allergies ?? [],
                            'No allergies',
                                () {},
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Vaccinations',
                            _fiche!.vaccinations ?? [],
                            'No vaccinations',
                                () {},
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Treatments',
                            _fiche!.treatments ?? [],
                            'No treatments',
                                () {},
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Examinations',
                            _fiche!.examinations ?? [],
                            'No examinations',
                                () {},
                          ),
                          const SizedBox(height: 16),
                          _buildListSection(
                            'Appointments',
                            _fiche!.appointments ?? [],
                            'No appointments',
                                () {},
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _temperatureController.dispose();
    _dietController.dispose();
    _behaviorNotesController.dispose();
    _medicalHistoryController.dispose();
    _generalNotesController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }
}