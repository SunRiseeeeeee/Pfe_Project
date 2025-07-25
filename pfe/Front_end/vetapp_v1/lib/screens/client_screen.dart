import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/client_service.dart';
import '../services/chat_service.dart';
import '../models/token_storage.dart';
import 'AnimalFicheScreen.dart';

import 'chat_screen.dart';

class VetClientScreen extends StatefulWidget {
  const VetClientScreen({super.key});

  @override
  State<VetClientScreen> createState() => _VetClientScreenState();
}

class _VetClientScreenState extends State<VetClientScreen> {
  late final ClientService _clientService;
  List<Client> _clients = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _vetId;

  @override
  void initState() {
    super.initState();
    final dio = Provider.of<Dio>(context, listen: false);
    _clientService = ClientService(dio: dio);
    _loadVetIdAndClients();
  }

  Future<void> _loadVetIdAndClients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      setState(() {
        _vetId = userId;
      });

      final clients = await _clientService.fetchClientsForVeterinarian(userId);
      debugPrint('Fetched clients: ${clients.length}');
      setState(() {
        _clients = clients;
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Clients',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
            onPressed: _loadVetIdAndClients,
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
              onPressed: _loadVetIdAndClients,
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
          : _clients.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 48,
              color: theme.colorScheme.onBackground.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No clients found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadVetIdAndClients,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _clients.length,
          itemBuilder: (context, index) {
            final client = _clients[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientDetailsScreen(
                      client: client,
                      vetId: _vetId ?? '',
                    ),
                  ),
                );
              },
              child: _ClientCard(client: client),
            );
          },
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;

  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clientName = '${client.firstName} ${client.lastName}'.trim();
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: client.profilePicture.isNotEmpty
                  ? client.profilePicture.startsWith('http')
                  ? Image.network(
                client.profilePicture,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Client network image error: $error');
                  return Image.asset(
                    'assets/images/default_avatar.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Client asset error: $error');
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      );
                    },
                  );
                },
              )
                  : Image.file(
                File(client.profilePicture),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Client file image error: $error');
                  return Image.asset(
                    'assets/images/default_avatar.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Client asset error: $error');
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      );
                    },
                  );
                },
              )
                  : Image.asset(
                'assets/images/default_avatar.png',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Client asset error: $error');
                  return Container(
                    width: 50,
                    height: 50,
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
                  const SizedBox(height: 4),
                  Text(
                    client.email ?? 'N/A',
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
      ),
    );
  }
}

class ClientDetailsScreen extends StatefulWidget {
  final Client client;
  final String vetId;

  const ClientDetailsScreen({super.key, required this.client, required this.vetId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  late final ClientService _clientService;
  final ChatService _chatService = ChatService();
  List<Animal> _animals = [];
  bool _isLoadingAnimals = true;
  bool _isStartingChat = false;
  String _animalErrorMessage = '';
  String? _userId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    final dio = Provider.of<Dio>(context, listen: false);
    _clientService = ClientService(dio: dio);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoadingAnimals = true;
      _animalErrorMessage = '';
    });

    try {
      // Fetch user ID and role
      _userId = await TokenStorage.getUserId();
      _userRole = await TokenStorage.getUserRoleFromToken();
      debugPrint('User ID: $_userId, Role: $_userRole');

      if (_userId != null && _userRole != null) {
        // Connect to ChatService
        await _chatService.connect(_userId!, _userRole!.toUpperCase());
        debugPrint('WebSocket connected for user $_userId with role: $_userRole');
      } else {
        debugPrint('User ID or role not found');
      }

      // Load client animals
      await _loadAnimals();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingAnimals = false);
    }
  }

  Future<void> _loadAnimals() async {
    try {
      final animals = await _clientService.fetchClientAnimals(widget.vetId, widget.client.id);
      debugPrint('Fetched animals for client ${widget.client.id}: ${animals.length}');
      setState(() {
        _animals = animals;
        _animalErrorMessage = '';
      });
    } catch (e) {
      debugPrint('Error loading animals: $e');
      setState(() {
        _animalErrorMessage = 'Error loading pets: $e';
      });
    }
  }

  Future<void> _startConversation() async {
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a conversation')),
      );
      return;
    }

    if (!['veterinaire', 'secretaire'].contains(_userRole!.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only veterinarians or secretaries can start conversations')),
      );
      return;
    }

    setState(() => _isStartingChat = true);

    try {
      // Ensure WebSocket connection
      if (!_chatService.isConnected()) {
        await _chatService.connect(_userId!, _userRole!.toUpperCase());
        debugPrint('WebSocket reconnected for user $_userId with role: $_userRole');
      }

      // Start conversation with client
      final targetId = widget.client.id;
      final recipientName = '${widget.client.firstName} ${widget.client.lastName}'.trim();
      debugPrint('Starting conversation with client: $recipientName (ID: $targetId})');

      // Get or create conversation
      final conversation = await _chatService.getOrCreateConversation(
        userId: _userId!,
        targetId: targetId,
      );

      final chatId = conversation['chatId'] as String;
      final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);

      debugPrint('Conversation found/created: Chat ID: $chatId, Participants: ${participants.length}');

      // Determine veterinaireId based on role
      String? veterinaireId;
      String? vetId;
      if (_userRole!.toLowerCase() == 'veterinaire') {
        veterinaireId = _userId;
        vetId = _userId;
      } else if (_userRole!.toLowerCase() == 'secretaire') {
        veterinaireId = await TokenStorage.getVeterinaireId() ?? widget.vetId;
        vetId = veterinaireId;
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              veterinaireId: veterinaireId,
              participants: participants,
              vetId: vetId,
              recipientId: targetId,
              recipientName: recipientName,
            ),
          ),
        );

        // Refresh conversations if message was sent
        if (result == true) {
          debugPrint('Message sent, refreshing conversations');
          // Optionally notify parent screen to refresh conversations
        }
      }
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingChat = false);
      }
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required IconData icon,
    required String label,
    required bool isLoading,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: backgroundColor.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clientName = '${widget.client.firstName} ${widget.client.lastName}'.trim();
    final clientAddress = widget.client.address != null
        ? [
      widget.client.address!.street ?? '',
      widget.client.address!.city ?? '',
      widget.client.address!.state ?? '',
      widget.client.address!.country ?? '',
      widget.client.address!.postalCode ?? '',
    ].where((e) => e.isNotEmpty).join(', ')
        : 'N/A';

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Client Details',
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
                          child: widget.client.profilePicture.isNotEmpty
                              ? widget.client.profilePicture.startsWith('http')
                              ? Image.network(
                            widget.client.profilePicture,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Client network image error: $error');
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
                              : Image.file(
                            File(widget.client.profilePicture),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Client file image error: $error');
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
                              const SizedBox(height: 8),
                              if (['veterinaire', 'secretaire'].contains(_userRole?.toLowerCase()))
                                _buildStyledButton(
                                  onPressed: _isStartingChat ? null : _startConversation,
                                  backgroundColor: const Color(0xF5914ABB),
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Start Conversation',
                                  isLoading: _isStartingChat,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, 'Email', widget.client.email ?? 'N/A', context),
                    _buildInfoRow(Icons.phone, 'Phone', widget.client.phoneNumber ?? 'N/A', context),
                    _buildInfoRow(Icons.location_on, 'Location', clientAddress, context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pets',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingAnimals
                        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                        : _animalErrorMessage.isNotEmpty
                        ? Center(
                      child: Text(
                        _animalErrorMessage,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                        : _animals.isEmpty
                        ? Center(
                      child: Text(
                        'No pets found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _animals.length,
                      itemBuilder: (context, index) {
                        final animal = _animals[index];
                        debugPrint('Rendering pet: ${animal.name}, picture: ${animal.picture}');
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AnimalFicheScreen(
                                  animal: animal,
                                  vetId: widget.vetId,
                                  clientId: widget.client.id,
                                ),
                              ),
                            );
                          },
                          child: _PetCard(animal: animal),
                        );
                      },
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
    _chatService.dispose();
    super.dispose();
  }
}

class _PetCard extends StatelessWidget {
  final Animal animal;

  const _PetCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthdate = animal.birthdate != null
        ? DateFormat.yMMMd().format(animal.birthdate!.toLocal())
        : 'N/A';
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: animal.picture != null && animal.picture!.isNotEmpty
                  ? Image.network(
                animal.picture!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Pet image error: $error');
                  return Image.asset(
                    'assets/images/default_avatar.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Pet asset error: $error');
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey,
                        child: const Icon(Icons.pets, color: Colors.white),
                      );
                    },
                  );
                },
              )
                  : Image.asset(
                'assets/images/default_avatar.png',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Pet asset error: $error');
                  return Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey,
                    child: const Icon(Icons.pets, color: Colors.white),
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
                    animal.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Species: ${animal.species}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Breed: ${animal.breed ?? 'N/A'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Gender: ${animal.gender ?? 'N/A'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Birthdate: $birthdate',
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
      ),
    );
  }
}