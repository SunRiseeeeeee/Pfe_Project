import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/veterinarian.dart';
import 'package:vetapp_v1/screens/appointment_screen.dart';
import 'package:vetapp_v1/screens/fypscreen.dart';
import 'package:vetapp_v1/screens/profile_screen.dart';
import 'package:vetapp_v1/screens/VetDetailsScreen.dart';
import 'package:vetapp_v1/screens/MyPetsScreen.dart';
import 'package:vetapp_v1/screens/client_screen.dart';
import 'package:vetapp_v1/screens/vet_appointment_screen.dart';
import 'package:vetapp_v1/screens/vets_screen.dart';
import 'package:vetapp_v1/screens/service_screen.dart';
import 'package:vetapp_v1/screens/chat_screen.dart';
import '../models/token_storage.dart';
import 'package:dio/dio.dart';
import '../models/service.dart';
import '../services/service_service.dart';
import 'all_services_screen.dart';
import 'conversations_screen.dart';
import '../services/chat_service.dart';
import '../services/notif_service.dart' as notif;
import 'notif_screen.dart';
import 'service_details_screen.dart';

class VetService {
  static const String baseUrl = "http://192.168.1.16:3000/api/users/veterinarians";
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> fetchVeterinarians({
    String? location,
    String? specialty,
    List<String>? services,
    int page = 1,
    int limit = 10,
    String sort = "desc",
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (location != null && location.isNotEmpty) 'location': location.trim(),
        if (specialty != null && specialty.isNotEmpty) 'specialty': specialty.trim(),
        if (services != null && services.isNotEmpty) 'services': services.join(","),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };

      final url = Uri.parse(baseUrl).replace(queryParameters: queryParams).toString();
      print('Request URL: $url');
      print('Query Parameters: $queryParams');

      final response = await _dio.get(baseUrl, queryParameters: queryParams);
      print('Response Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load veterinarians. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching veterinarians: $e');
      rethrow;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? userRole;
  String? userId;
  final ChatService _chatService = ChatService();
  final notif.NotificationService _notificationService = notif.NotificationService();
  int _unreadMessageCount = 0;
  final Map<String, Map<String, dynamic>> _unreadMessages = {};
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _conversationSubscription;
  StreamSubscription<int>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final rawRole = await TokenStorage.getUserRoleFromToken();
      final userIdFromToken = await TokenStorage.getUserId();
      print('Raw role from TokenStorage: $rawRole');
      final normalizedRole = rawRole?.toLowerCase().trim();
      setState(() {
        userRole = normalizedRole ?? 'client';
        userId = userIdFromToken;
        if (normalizedRole == 'vet' || normalizedRole == 'veterinaire') {
          userRole = 'veterinarian';
        }
        print('Final userRole: $userRole, userId: $userId');
      });
      await _initializeChatService();
      await _initializeNotificationService();
      _listenToNotifications();
    } catch (e) {
      print('Error fetching user role or ID: $e');
      setState(() {
        userRole = 'client';
        userId = null;
        print('Final userRole (error): $userRole');
      });
    }
  }

  Future<void> _initializeChatService() async {
    if (userId != null && userRole != null) {
      try {
        print('Initializing ChatService for userId: $userId, role: $userRole');
        await _chatService.connect(userId!, userRole!);
        _listenToMessages();
        _listenToConversations();
        await Future.delayed(const Duration(milliseconds: 500));
        await _chatService.getConversations(userId!);
        print('ChatService initialized and conversations fetched');
      } catch (e) {
        print('Error initializing ChatService: $e');
      }
    } else {
      print('Cannot initialize ChatService: userId or userRole is null');
    }
  }

  Future<void> _initializeNotificationService() async {
    if (userId != null) {
      try {
        print('Initializing NotificationService for userId: $userId');
        await _notificationService.connectToSocket();
        print('NotificationService initialized');
      } catch (e) {
        print('Error initializing NotificationService: $e');
      }
    } else {
      print('Cannot initialize NotificationService: userId is null');
    }
  }

  void _listenToMessages() {
    _messageSubscription = _chatService.onNewMessage().listen((data) {
      print('New message event: $data');
      if (data['type'] == 'NEW_MESSAGE' && data['message'] != null && data['message']['sender']['id'] != userId) {
        setState(() {
          final chatId = data['chatId'] as String? ?? '';
          if (chatId.isEmpty) return;
          final sender = data['message']['sender'] as Map<String, dynamic>? ?? {};
          _unreadMessages[chatId] = {
            'senderId': sender['id'] ?? '',
            'firstName': sender['firstName'] ?? 'Unknown',
            'lastName': sender['lastName'] ?? '',
            'profilePicture': sender['profilePicture'],
            'content': data['message']['content'] ?? '',
            'chatId': chatId,
          };
          _unreadMessageCount = _unreadMessages.length;
          print('Added unread message for chatId: $chatId, count: $_unreadMessageCount');
        });
      } else if (data['type'] == 'MESSAGE_READ' && data['readBy'] != null && (data['readBy'] as List).contains(userId)) {
        setState(() {
          final chatId = data['chatId'] as String? ?? '';
          _unreadMessages.remove(chatId);
          _unreadMessageCount = _unreadMessages.length;
          print('Removed unread message for chatId: $chatId, count: $_unreadMessageCount');
        });
      }
    }, onError: (error) {
      print('Error in message subscription: $error');
    });
  }

  void _listenToConversations() {
    _conversationSubscription = _chatService.onConversations().listen((data) {
      print('Conversation event: $data');
      if (data['type'] == 'CONVERSATIONS_LIST' && data['conversations'] != null) {
        setState(() {
          int totalUnread = 0;
          final conversations = List<Map<String, dynamic>>.from(data['conversations']);
          _unreadMessages.clear();

          for (var convo in conversations) {
            final unreadCount = convo['unreadCount'] as int? ?? 0;
            totalUnread += unreadCount;

            if (unreadCount > 0 && convo['lastMessage'] != null) {
              final chatId = convo['chatId'] as String? ?? '';
              final lastMessage = convo['lastMessage'] as Map<String, dynamic>? ?? {};
              final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);

              Map<String, dynamic>? otherParticipant;
              for (var participant in participants) {
                if (participant['id'] != userId) {
                  otherParticipant = participant;
                  break;
                }
              }

              if (chatId.isNotEmpty && otherParticipant != null) {
                _unreadMessages[chatId] = {
                  'senderId': otherParticipant['id'] ?? '',
                  'firstName': otherParticipant['firstName'] ?? 'Unknown',
                  'lastName': otherParticipant['lastName'] ?? '',
                  'profilePicture': otherParticipant['profilePicture'],
                  'content': lastMessage['content'] ?? '',
                  'chatId': chatId,
                };
              }
            }
          }

          _unreadMessageCount = totalUnread;
          print('Updated unread messages from conversations, count: $_unreadMessageCount');
        });
      }
    }, onError: (error) {
      print('Error in conversation subscription: $error');
    });
  }

  void _listenToNotifications() {
    _notificationSubscription = _notificationService.unreadNotificationCountStream.listen((count) {
      print('Notification count updated: $count');
    }, onError: (error) {
      print('Error in notification subscription: $error');
    });
  }

  List<Widget> get _screens {
    if (userRole == 'admin') {
      return [
        HomeContent(
          onServiceChanged: () => setState(() {}),
          unreadMessageCount: _unreadMessageCount,
          unreadMessages: _unreadMessages,
        ),
        const ServiceScreen(),
        const FypScreen(),
        const VetsScreen(),
        const ProfileScreen(),
      ];
    } else if (userRole == 'veterinarian' || userRole == 'secretary') {
      return [
        HomeContent(
          unreadMessageCount: _unreadMessageCount,
          unreadMessages: _unreadMessages,
        ),
        const VetAppointmentScreen(),
        const FypScreen(),
        const VetClientScreen(),
        const ProfileScreen(),
      ];
    } else {
      return [
        HomeContent(
          unreadMessageCount: _unreadMessageCount,
          unreadMessages: _unreadMessages,
        ),
        const AppointmentScreen(),
        const FypScreen(),
        const PetsScreen(),
        const ProfileScreen(),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConversationsScreen()),
    ).then((_) {
      if (userId != null) {
        _chatService.getConversations(userId!);
        print('Refreshed conversations after returning from ConversationsScreen');
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _notificationSubscription?.cancel();
    _chatService.dispose();
    // Avoid closing NotificationService unless logging out
    print('Disposed HomeScreen subscriptions and ChatService');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: userRole == null
            ? const Center(child: CircularProgressIndicator())
            : _screens[_selectedIndex],
        bottomNavigationBar: _buildCustomBottomNavigationBar(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedIndex != 0 || userRole == null || userRole == 'guest') {
      return null;
    }
    if (userRole == 'veterinarian' || userRole == 'secretary' || userRole == 'client') {
      return FloatingActionButton(
        onPressed: _openChat,
        backgroundColor: Colors.purple[600],
        elevation: 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.chat,
              color: Colors.white,
              size: 28,
            ),
            if (_unreadMessageCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$_unreadMessageCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        tooltip: 'Chat',
      );
    }
    return null;
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF4B0082),
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: userRole == 'admin'
              ? [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service, size: 28),
              label: 'Service',
            ),
            BottomNavigationBarItem(
              icon: _CustomNavIcon(icon: Icons.stacked_bar_chart, isSelected: _selectedIndex == 2),
              label: 'Fyp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital, size: 28),
              label: 'Vets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ]
              : userRole == 'veterinarian' || userRole == 'secretary'
              ? [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(
              icon: _CustomNavIcon(icon: Icons.stacked_bar_chart, isSelected: _selectedIndex == 2),
              label: 'Fyp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people, size: 28),
              label: 'Client',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ]
              : [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today, size: 28),
              label: 'Appointment',
            ),
            BottomNavigationBarItem(
              icon: _CustomNavIcon(icon: Icons.stacked_bar_chart, isSelected: _selectedIndex == 2),
              label: 'Fyp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pets, size: 28),
              label: 'Pets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _CustomNavIcon({
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          icon,
          size: 36,
          color: isSelected ? Colors.deepPurple : Colors.grey,
        ),
      ],
    );
  }
}

class HomeContent extends StatefulWidget {
  final VoidCallback? onServiceChanged;
  final int unreadMessageCount;
  final Map<String, Map<String, dynamic>> unreadMessages;

  const HomeContent({
    super.key,
    this.onServiceChanged,
    required this.unreadMessageCount,
    required this.unreadMessages,
  });

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int currentPage = 1;
  String? locationFilter;
  String? specialtyFilter;
  String? nameFilter;
  int limit = 10;
  String sort = "desc";
  late Future<Map<String, dynamic>> veterinariansFuture;
  Future<Map<String, dynamic>>? servicesFuture;
  String? username;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  final List<String> specialties = [
    'General Practice',
    'Surgery',
    'Dentistry',
    'Dermatology',
    'Cardiology',
    'Oncology',
    'Chirurgie canine',
    'Urgences vétérinaires & NAC',
  ];

  @override
  void initState() {
    super.initState();
    _locationController.text = locationFilter ?? '';
    _searchController.text = nameFilter ?? '';
    veterinariansFuture = VetService.fetchVeterinarians(
      location: locationFilter,
      specialty: specialtyFilter,
      page: currentPage,
      limit: limit,
      sort: sort,
    );
    servicesFuture = ServiceService.getAllServices();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final fetchedUsername = await TokenStorage.getUsernameFromToken();
      setState(() {
        username = fetchedUsername ?? "User";
      });
    } catch (e) {
      print("Error fetching username: $e");
      setState(() {
        username = "Error";
      });
    }
  }

  void _refreshVeterinarians(int newPage) {
    setState(() {
      currentPage = newPage;
      veterinariansFuture = VetService.fetchVeterinarians(
        location: locationFilter,
        specialty: specialtyFilter,
        page: currentPage,
        limit: limit,
        sort: sort,
      );
      debugPrint('Refreshing veterinarians with: page=$currentPage, location=$locationFilter, specialty=$specialtyFilter, name=$nameFilter, limit=$limit, sort=$sort');
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<int>(
      stream: notif.NotificationService().unreadNotificationCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final unreadNotificationCount = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none, size: 25 ,color: Colors.purple[600],),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotifScreen()),
                );
              },
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadNotificationCount > 9 ? '9+' : '$unreadNotificationCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showSearchDialog() {
    String? tempNameFilter = nameFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search Veterinarians'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Search by Name'),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter first or last name (e.g., Pierre)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                          setDialogState(() {
                            tempNameFilter = value;
                          });
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  nameFilter = null;
                  _searchController.text = '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  nameFilter = tempNameFilter != null && tempNameFilter!.isNotEmpty ? tempNameFilter?.trim() : null;
                  _searchController.text = nameFilter ?? '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome,",
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Poppins'),
                    ),
                    Text(
                      username ?? 'Loading...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.search, color: Colors.purple[600],),
                      onPressed: _showSearchDialog,
                    ),
                    _buildNotificationIcon(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AutoSlidingPageView(),
            const SizedBox(height: 20),
            _buildServicesSectionHeader('Services'),
            const SizedBox(height: 12),
            _buildServicesSection(),
            const SizedBox(height: 20),
            _buildVeterinariansSectionHeader('Our best veterinarians'),
            const SizedBox(height: 12),
            if ((locationFilter != null && locationFilter!.isNotEmpty) ||
                specialtyFilter != null ||
                (nameFilter != null && nameFilter!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (nameFilter != null && nameFilter!.isNotEmpty)
                      Chip(
                        label: Text('Name: $nameFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            nameFilter = null;
                            _searchController.text = '';
                            _refreshVeterinarians(1);
                          });
                        },
                      ),
                    if (locationFilter != null && locationFilter!.isNotEmpty)
                      Chip(
                        label: Text('Location: $locationFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            locationFilter = null;
                            _locationController.text = '';
                            _refreshVeterinarians(1);
                          });
                        },
                      ),
                    if (specialtyFilter != null)
                      Chip(
                        label: Text('Specialty: $specialtyFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            specialtyFilter = null;
                            _refreshVeterinarians(1);
                          });
                        },
                      ),
                  ],
                ),
              ),
            VeterinarianList(
              veterinariansFuture: veterinariansFuture,
              currentPage: currentPage,
              locationFilter: locationFilter,
              specialtyFilter: specialtyFilter,
              nameFilter: nameFilter,
              onPageChange: _refreshVeterinarians,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AllServicesScreen()),
            );
          },
          child: Text(
            'See All',
            style: TextStyle(
              color: Colors.purple[600],
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVeterinariansSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.purple),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  void _showFilterDialog() {
    String? tempLocationFilter = locationFilter ?? '';
    String? tempSpecialtyFilter = specialtyFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Veterinarians'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filter by Location'),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter location (e.g., Lyon)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                          setDialogState(() {
                            tempLocationFilter = value;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Filter by Specialty'),
                    DropdownButton<String>(
                      value: tempSpecialtyFilter,
                      hint: const Text('Select specialty'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any'),
                        ),
                        ...specialties.map((String specialty) {
                          return DropdownMenuItem<String>(
                            value: specialty,
                            child: Text(specialty),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        setDialogState(() {
                          tempSpecialtyFilter = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  locationFilter = null;
                  specialtyFilter = null;
                  _locationController.text = '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  locationFilter = tempLocationFilter != null && tempLocationFilter!.isNotEmpty
                      ? tempLocationFilter?.trim()
                      : null;
                  specialtyFilter = tempSpecialtyFilter;
                  _locationController.text = locationFilter ?? '';
                  _refreshVeterinarians(1);
                });
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesSection() {
    if (servicesFuture == null) {
      return const Center(child: Text('Services not loaded'));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Service fetch error: ${snapshot.error}');
          return const Center(child: Text('Error loading services'));
        }
        if (!snapshot.hasData || !snapshot.data!['success']) {
          print('Service fetch failed: ${snapshot.data?['message']}');
          return Center(
            child: Text(snapshot.data?['message'] ?? 'Failed to load services'),
          );
        }

        final services = snapshot.data!['services'] as List<Service>;
        if (services.isEmpty) {
          return const Center(child: Text('No services available'));
        }

        final displayServices = services.take(4).toList();

        return Column(
          children: [
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  if (displayServices.length > 0)
                    Expanded(
                      flex: 6,
                      child: _buildServiceCard(displayServices[0]),
                    )
                  else
                    Expanded(flex: 6, child: _buildPlaceholderCard()),
                  const SizedBox(width: 10),
                  if (displayServices.length > 1)
                    Expanded(
                      flex: 4,
                      child: _buildServiceCard(displayServices[1]),
                    )
                  else
                    Expanded(flex: 4, child: _buildPlaceholderCard()),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  if (displayServices.length > 2)
                    Expanded(
                      flex: 4,
                      child: _buildServiceCard(displayServices[2]),
                    )
                  else
                    Expanded(flex: 4, child: _buildPlaceholderCard()),
                  const SizedBox(width: 10),
                  if (displayServices.length > 3)
                    Expanded(
                      flex: 6,
                      child: _buildServiceCard(displayServices[3]),
                    )
                  else
                    Expanded(flex: 6, child: _buildPlaceholderCard()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(Service service) {
    final imageUrl = service.image != null && service.image!.isNotEmpty
        ? service.image!.replaceAll('http://localhost:3000', 'http://192.168.1.16:3000')
        : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailsScreen(service: service),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Image load error for $imageUrl: $error');
                return Container(
                  color: Colors.grey,
                  child: const Icon(Icons.image_not_supported, color: Colors.white),
                );
              },
            )
                : Container(
              color: Colors.grey,
              child: const Icon(Icons.image_not_supported, color: Colors.white),
            ),
            Container(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                service.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPlaceholderCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.grey,
            child: const Icon(Icons.image_not_supported, color: Colors.white),
          ),
          Container(
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: const Text(
              'No Service',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AutoSlidingPageView extends StatefulWidget {
  final ScrollController? scrollController;

  const AutoSlidingPageView({super.key, this.scrollController});

  @override
  State<AutoSlidingPageView> createState() => _AutoSlidingPageViewState();
}

class _AutoSlidingPageViewState extends State<AutoSlidingPageView> {
  final List<Map<String, dynamic>> _carouselItems = [
    {
      'image': 'assets/images/discover.jpg',
      'title': 'Edit Your Profile',
      'subtitle': 'Personalize your account details.',
      'destination': () => ProfileScreen(),
    },
    {
      'image': 'assets/images/vet2.jpg',
      'title': 'Interact with Pet Lovers',
      'subtitle': 'Connect and share with the pet community.',
      'destination': () => FypScreen(),
    },
    {
      'image': 'assets/images/discover2.jpg',
      'title': 'Discover Our Best Vets',
      'subtitle': 'Find top veterinarians near you.',
      'destination': null, // Handled by scrollToVets
    },
  ];
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _carouselItems.length * 100);
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleInteraction(BuildContext context, int index) {
    final itemIndex = index % _carouselItems.length;
    if (itemIndex == 2 && widget.scrollController != null) {
      // Scroll to the veterinarian list section for the third slide
      final scrollPosition = widget.scrollController!.position;
      // Approximate offset to the "Our best veterinarians" section
      // Adjust this value based on your UI layout (estimated here)
      scrollPosition.animateTo(
        scrollPosition.pixels + 600, // Adjust offset as needed
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final destination = _carouselItems[itemIndex]['destination'] as Widget Function()?;
      if (destination != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentPage = index % _carouselItems.length;
                });
              }
            },
            itemCount: _carouselItems.length * 1000,
            itemBuilder: (context, index) {
              final itemIndex = index % _carouselItems.length;
              return GestureDetector(
                onTap: () => _handleInteraction(context, itemIndex),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    _carouselItems[itemIndex]['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey,
                        child: const Icon(Icons.image_not_supported, color: Colors.white),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _carouselItems[_currentPage]['title']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _carouselItems[_currentPage]['subtitle']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _handleInteraction(context, _currentPage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                    ),
                    child: Text(
                      'Discover',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.purple[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _carouselItems.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.white : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}