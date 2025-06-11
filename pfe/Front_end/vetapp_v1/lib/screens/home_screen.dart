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
  String? selectedCountry;
  String? selectedState;
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

  final Map<String, List<String>> countryStates = {
    'Afghanistan': ['Badakhshan', 'Badghis', 'Baghlan', 'Balkh', 'Bamyan', 'Daykundi', 'Farah', 'Faryab', 'Ghazni', 'Ghor', 'Helmand', 'Herat', 'Jowzjan', 'Kabul', 'Kandahar', 'Kapisa', 'Khost', 'Kunar', 'Kunduz', 'Laghman', 'Logar', 'Nangarhar', 'Nimruz', 'Nuristan', 'Paktia', 'Paktika', 'Panjshir', 'Parwan', 'Samangan', 'Sar-e Pol', 'Takhar', 'Uruzgan', 'Wardak', 'Zabul'],
    'Albania': ['Berat', 'Dibër', 'Durrës', 'Elbasan', 'Fier', 'Gjirokastër', 'Korçë', 'Kukës', 'Lezhë', 'Shkodër', 'Tirana', 'Vlorë'],
    'Algeria': ['Adrar', 'Aïn Defla', 'Aïn Témouchent', 'Algiers', 'Annaba', 'Batna', 'Béchar', 'Béjaïa', 'Biskra', 'Blida', 'Bordj Bou Arréridj', 'Bouïra', 'Boumerdès', 'Chlef', 'Constantine', 'Djelfa', 'El Bayadh', 'El Oued', 'El Tarf', 'Ghardaïa', 'Guelma', 'Illizi', 'Jijel', 'Khenchela', 'Laghouat', 'M’Sila', 'Mascara', 'Médéa', 'Mila', 'Mostaganem', 'Naâma', 'Oran', 'Ouargla', 'Oum El Bouaghi', 'Relizane', 'Saïda', 'Sétif', 'Sidi Bel Abbès', 'Skikda', 'Souk Ahras', 'Tamanrasset', 'Tébessa', 'Tiaret', 'Tindouf', 'Tipaza', 'Tissemsilt', 'Tizi Ouzou', 'Tlemcen'],
    'Andorra': [],
    'Angola': ['Bengo', 'Benguela', 'Bié', 'Cabinda', 'Cuando Cubango', 'Cuanza Norte', 'Cuanza Sul', 'Cunene', 'Huambo', 'Huíla', 'Luanda', 'Lunda Norte', 'Lunda Sul', 'Malanje', 'Moxico', 'Namibe', 'Uíge', 'Zaire'],
    'Antigua and Barbuda': ['Barbuda', 'Saint George', 'Saint John', 'Saint Mary', 'Saint Paul', 'Saint Peter', 'Saint Philip'],
    'Argentina': ['Buenos Aires', 'Catamarca', 'Chaco', 'Chubut', 'Córdoba', 'Corrientes', 'Entre Ríos', 'Formosa', 'Jujuy', 'La Pampa', 'La Rioja', 'Mendoza', 'Misiones', 'Neuquén', 'Río Negro', 'Salta', 'San Juan', 'San Luis', 'Santa Cruz', 'Santa Fe', 'Santiago del Estero', 'Tierra del Fuego', 'Tucumán'],
    'Armenia': ['Aragatsotn', 'Ararat', 'Armavir', 'Gegharkunik', 'Kotayk', 'Lori', 'Shirak', 'Syunik', 'Tavush', 'Vayots Dzor', 'Yerevan'],
    'Australia': ['New South Wales', 'Queensland', 'South Australia', 'Tasmania', 'Victoria', 'Western Australia', 'Australian Capital Territory', 'Northern Territory'],
    'Austria': ['Burgenland', 'Carinthia', 'Lower Austria', 'Upper Austria', 'Salzburg', 'Styria', 'Tyrol', 'Vorarlberg', 'Vienna'],
    'Azerbaijan': ['Absheron', 'Aghjabadi', 'Agdam', 'Agdash', 'Aghstafa', 'Agsu', 'Astara', 'Baku', 'Balakan', 'Barda', 'Beylagan', 'Bilasuvar', 'Dashkasan', 'Fuzuli', 'Gadabay', 'Ganja', 'Gobustan', 'Goychay', 'Goygol', 'Hajigabul', 'Imishli', 'Ismailli', 'Jabrayil', 'Jalilabad', 'Julfa', 'Kalbajar', 'Kangarli', 'Khachmaz', 'Khizi', 'Khojavend', 'Kurdamir', 'Lachin', 'Lankaran', 'Lerik', 'Masally', 'Mingachevir', 'Naftalan', 'Nakhchivan', 'Neftchala', 'Oghuz', 'Qabala', 'Qakh', 'Qazakh', 'Quba', 'Qubadli', 'Qusar', 'Saatly', 'Sabirabad', 'Salyan', 'Samukh', 'Shabran', 'Shaki', 'Shamakhi', 'Shamkir', 'Sharur', 'Shirvan', 'Siazan', 'Sumqayit', 'Tartar', 'Tovuz', 'Ujar', 'Yardymli', 'Yevlakh', 'Zangilan', 'Zaqatala', 'Zardab'],
    'Bahamas': ['Acklins', 'Berry Islands', 'Bimini', 'Black Point', 'Cat Island', 'Central Abaco', 'Central Andros', 'Central Eleuthera', 'Crooked Island', 'East Grand Bahama', 'Exuma', 'Freeport', 'Grand Cay', 'Harbour Island', 'Hope Town', 'Inagua', 'Long Island', 'Mangrove Cay', 'Mayaguana', 'Moore’s Island', 'North Abaco', 'North Andros', 'North Eleuthera', 'Ragged Island', 'Rum Cay', 'San Salvador', 'South Abaco', 'South Andros', 'South Eleuthera', 'Spanish Wells', 'West Grand Bahama'],
    'Bahrain': ['Capital', 'Muharraq', 'Northern', 'Southern'],
    'Bangladesh': ['Barisal', 'Chittagong', 'Dhaka', 'Khulna', 'Mymensingh', 'Rajshahi', 'Rangpur', 'Sylhet'],
    'Barbados': ['Christ Church', 'Saint Andrew', 'Saint George', 'Saint James', 'Saint John', 'Saint Joseph', 'Saint Lucy', 'Saint Michael', 'Saint Peter', 'Saint Philip', 'Saint Thomas'],
    'Belarus': ['Brest', 'Gomel', 'Grodno', 'Minsk', 'Mogilev', 'Vitebsk'],
    'Belgium': ['Antwerp', 'East Flanders', 'Flemish Brabant', 'Hainaut', 'Liège', 'Limburg', 'Luxembourg', 'Namur', 'Walloon Brabant', 'West Flanders', 'Brussels-Capital Region'],
    'Belize': ['Belize', 'Cayo', 'Corozal', 'Orange Walk', 'Stann Creek', 'Toledo'],
    'Benin': ['Alibori', 'Atakora', 'Atlantique', 'Borgou', 'Collines', 'Couffo', 'Donga', 'Littoral', 'Mono', 'Ouémé', 'Plateau', 'Zou'],
    'Bhutan': ['Bumthang', 'Chukha', 'Dagana', 'Gasa', 'Haa', 'Lhuntse', 'Mongar', 'Paro', 'Pemagatshel', 'Punakha', 'Samdrup Jongkhar', 'Samtse', 'Sarpang', 'Thimphu', 'Trashigang', 'Trashiyangtse', 'Trongsa', 'Tsirang', 'Wangdue Phodrang', 'Zhemgang'],
    'Bolivia': ['Beni', 'Chuquisaca', 'Cochabamba', 'La Paz', 'Oruro', 'Pando', 'Potosí', 'Santa Cruz', 'Tarija'],
    'Bosnia and Herzegovina': ['Federation of Bosnia and Herzegovina', 'Republika Srpska', 'Brčko District'],
    'Botswana': ['Central', 'Chobe', 'Ghanzi', 'Kgalagadi', 'Kgatleng', 'Kweneng', 'Ngamiland', 'North-East', 'North-West', 'South-East', 'Southern'],
    'Brazil': ['Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará', 'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso', 'Mato Grosso do Sul', 'Minas Gerais', 'Pará', 'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 'Rio de Janeiro', 'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 'Roraima', 'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins', 'Distrito Federal'],
    'Brunei': ['Belait', 'Brunei-Muara', 'Temburong', 'Tutong'],
    'Bulgaria': ['Blagoevgrad', 'Burgas', 'Dobrich', 'Gabrovo', 'Haskovo', 'Kardzhali', 'Kyustendil', 'Lovech', 'Montana', 'Pazardzhik', 'Pernik', 'Pleven', 'Plovdiv', 'Razgrad', 'Ruse', 'Shumen', 'Silistra', 'Sliven', 'Smolyan', 'Sofia', 'Sofia-Capital', 'Stara Zagora', 'Targovishte', 'Varna', 'Veliko Tarnovo', 'Vidin', 'Vratsa', 'Yambol'],
    'Burkina Faso': ['Balé', 'Bam', 'Banwa', 'Bazèga', 'Bougouriba', 'Boulgou', 'Boulkiemdé', 'Comoé', 'Ganzourgou', 'Gnagna', 'Gourma', 'Houet', 'Ioba', 'Kadiogo', 'Kénédougou', 'Komondjari', 'Kompienga', 'Kossi', 'Koulpélogo', 'Kouritenga', 'Kourwéogo', 'Léraba', 'Loroum', 'Mouhoun', 'Nahouri', 'Namentenga', 'Nayala', 'Noumbiel', 'Oubritenga', 'Oudalan', 'Passoré', 'Poni', 'Sanguié', 'Sanmatenga', 'Seno', 'Sissili', 'Soum', 'Sourou', 'Tapoa', 'Tuy', 'Yagha', 'Yatenga', 'Ziro', 'Zondoma', 'Zoundwéogo'],
    'Burundi': ['Bubanza', 'Bujumbura Mairie', 'Bujumbura Rural', 'Bururi', 'Cankuzo', 'Cibitoke', 'Gitega', 'Karuzi', 'Kayanza', 'Kirundo', 'Makamba', 'Muramvya', 'Muyinga', 'Mwaro', 'Ngozi', 'Rumonge', 'Rutana', 'Ruyigi'],
    'Cambodia': ['Banteay Meanchey', 'Battambang', 'Kampong Cham', 'Kampong Chhnang', 'Kampong Speu', 'Kampong Thom', 'Kampot', 'Kandal', 'Kep', 'Koh Kong', 'Kratié', 'Mondulkiri', 'Oddar Meanchey', 'Pailin', 'Phnom Penh', 'Preah Vihear', 'Prey Veng', 'Pursat', 'Ratanakiri', 'Siem Reap', 'Sihanoukville', 'Stung Treng', 'Svay Rieng', 'Takeo'],
    'Cameroon': ['Adamawa', 'Centre', 'East', 'Far North', 'Littoral', 'North', 'Northwest', 'South', 'Southwest', 'West'],
    'Canada': ['Alberta', 'British Columbia', 'Manitoba', 'New Brunswick', 'Newfoundland and Labrador', 'Nova Scotia', 'Ontario', 'Prince Edward Island', 'Quebec', 'Saskatchewan', 'Northwest Territories', 'Nunavut', 'Yukon'],
    'Cape Verde': ['Boa Vista', 'Brava', 'Maio', 'Mosteiros', 'Paul', 'Porto Novo', 'Praia', 'Ribeira Brava', 'Ribeira Grande', 'Ribeira Grande de Santiago', 'Sal', 'Santa Catarina', 'Santa Catarina do Fogo', 'Santa Cruz', 'São Domingos', 'São Filipe', 'São Lourenço dos Órgãos', 'São Miguel', 'São Nicolau', 'São Salvador do Mundo', 'São Vicente', 'Tarrafal', 'Tarrafal de São Nicolau'],
    'Central African Republic': ['Bamingui-Bangoran', 'Bangui', 'Basse-Kotto', 'Haute-Kotto', 'Haut-Mbomou', 'Kémo', 'Lobaye', 'Mambéré-Kadéï', 'Mbomou', 'Nana-Grébizi', 'Nana-Mambéré', 'Ombella-M’Poko', 'Ouaka', 'Ouham', 'Ouham-Pendé', 'Sangha-Mbaéré', 'Vakaga'],
    'Chad': ['Bahr el Gazel', 'Batha', 'Borkou', 'Chari-Baguirmi', 'Ennedi-Est', 'Ennedi-Ouest', 'Guéra', 'Hadjer-Lamis', 'Kanem', 'Lac', 'Logone Occidental', 'Logone Oriental', 'Mandoul', 'Mayo-Kebbi Est', 'Mayo-Kebbi Ouest', 'Moyen-Chari', 'Ouaddaï', 'Salamat', 'Sila', 'Tandjilé', 'Tibesti', 'Wadi Fira'],
    'Chile': ['Aisén', 'Antofagasta', 'Araucanía', 'Arica y Parinacota', 'Atacama', 'Biobío', 'Coquimbo', 'Los Lagos', 'Los Ríos', 'Magallanes', 'Maule', 'Ñuble', 'O’Higgins', 'Santiago', 'Tarapacá', 'Valparaíso'],
    'China': ['Anhui', 'Fujian', 'Gansu', 'Guangdong', 'Guizhou', 'Hainan', 'Hebei', 'Heilongjiang', 'Henan', 'Hubei', 'Hunan', 'Jiangsu', 'Jiangxi', 'Jilin', 'Liaoning', 'Qinghai', 'Shaanxi', 'Shandong', 'Shanxi', 'Sichuan', 'Yunnan', 'Zhejiang', 'Guangxi', 'Inner Mongolia', 'Ningxia', 'Xinjiang', 'Tibet', 'Beijing', 'Chongqing', 'Shanghai', 'Tianjin'],
    'Colombia': ['Amazonas', 'Antioquia', 'Arauca', 'Atlántico', 'Bolívar', 'Boyacá', 'Caldas', 'Caquetá', 'Casanare', 'Cauca', 'Cesar', 'Chocó', 'Córdoba', 'Cundinamarca', 'Guainía', 'Guaviare', 'Huila', 'La Guajira', 'Magdalena', 'Meta', 'Nariño', 'Norte de Santander', 'Putumayo', 'Quindío', 'Risaralda', 'San Andrés y Providencia', 'Santander', 'Sucre', 'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada'],
    'Comoros': ['Anjouan', 'Grande Comore', 'Mohéli'],
    'Congo, Democratic Republic of the': ['Bas-Uélé', 'Équateur', 'Haut-Katanga', 'Haut-Lomami', 'Haut-Uélé', 'Ituri', 'Kasai', 'Kasai-Central', 'Kasai-Oriental', 'Kinshasa', 'Kongo Central', 'Kwango', 'Kwilu', 'Lomami', 'Lualaba', 'Mai-Ndombe', 'Maniema', 'Mongala', 'Nord-Kivu', 'Nord-Ubangi', 'Sankuru', 'Sud-Kivu', 'Sud-Ubangi', 'Tanganyika', 'Tshopo', 'Tshuapa'],
    'Congo, Republic of the': ['Bouenza', 'Brazzaville', 'Cuvette', 'Cuvette-Ouest', 'Kouilou', 'Lékoumou', 'Likouala', 'Niari', 'Plateaux', 'Pointe-Noire', 'Pool', 'Sangha'],
    'Costa Rica': ['Alajuela', 'Cartago', 'Guanacaste', 'Heredia', 'Limón', 'Puntarenas', 'San José'],
    'Croatia': ['Bjelovar-Bilogora', 'Brod-Posavina', 'Dubrovnik-Neretva', 'Istria', 'Karlovac', 'Koprivnica-Križevci', 'Krapina-Zagorje', 'Lika-Senj', 'Međimurje', 'Osijek-Baranja', 'Požega-Slavonia', 'Primorje-Gorski Kotar', 'Šibenik-Knin', 'Sisak-Moslavina', 'Split-Dalmatia', 'Varaždin', 'Virovitica-Podravina', 'Vukovar-Srijem', 'Zadar', 'Zagreb', 'Zagreb City'],
    'Cuba': ['Artemisa', 'Camagüey', 'Ciego de Ávila', 'Cienfuegos', 'Granma', 'Guantánamo', 'Havana', 'Holguín', 'Isla de la Juventud', 'Las Tunas', 'Matanzas', 'Mayabeque', 'Pinar del Río', 'Sancti Spíritus', 'Santiago de Cuba', 'Villa Clara'],
    'Cyprus': ['Famagusta', 'Kyrenia', 'Larnaca', 'Limassol', 'Nicosia', 'Paphos'],
    'Czech Republic': ['Central Bohemian', 'Hradec Králové', 'Karlovy Vary', 'Liberec', 'Moravian-Silesian', 'Olomouc', 'Pardubice', 'Plzeň', 'Prague', 'South Bohemian', 'South Moravian', 'Ústí nad Labem', 'Vysočina', 'Zlín'],
    'Denmark': ['Capital Region', 'Central Denmark', 'North Denmark', 'Zealand', 'Southern Denmark'],
    'Djibouti': ['Ali Sabieh', 'Arta', 'Dikhil', 'Djibouti', 'Obock', 'Tadjourah'],
    'Dominica': ['Saint Andrew', 'Saint David', 'Saint George', 'Saint John', 'Saint Joseph', 'Saint Luke', 'Saint Mark', 'Saint Patrick', 'Saint Paul', 'Saint Peter'],
    'Dominican Republic': ['Azua', 'Baoruco', 'Barahona', 'Dajabón', 'Distrito Nacional', 'Duarte', 'El Seibo', 'Elías Piña', 'Espaillat', 'Hato Mayor', 'Hermanas Mirabal', 'Independencia', 'La Altagracia', 'La Romana', 'La Vega', 'María Trinidad Sánchez', 'Monseñor Nouel', 'Monte Cristi', 'Monte Plata', 'Pedernales', 'Peravia', 'Puerto Plata', 'Samaná', 'San Cristóbal', 'San José de Ocoa', 'San Juan', 'San Pedro de Macorís', 'Sánchez Ramírez', 'Santiago', 'Santiago Rodríguez', 'Santo Domingo', 'Valverde'],
    'Ecuador': ['Azuay', 'Bolívar', 'Cañar', 'Carchi', 'Chimborazo', 'Cotopaxi', 'El Oro', 'Esmeraldas', 'Galápagos', 'Guayas', 'Imbabura', 'Loja', 'Los Ríos', 'Manabí', 'Morona-Santiago', 'Napo', 'Orellana', 'Pastaza', 'Pichincha', 'Santa Elena', 'Santo Domingo de los Tsáchilas', 'Sucumbíos', 'Tungurahua', 'Zamora-Chinchipe'],
    'Egypt': ['Alexandria', 'Aswan', 'Asyut', 'Beheira', 'Beni Suef', 'Cairo', 'Dakahlia', 'Damietta', 'Faiyum', 'Gharbia', 'Giza', 'Ismailia', 'Kafr El Sheikh', 'Luxor', 'Matruh', 'Minya', 'Monufia', 'New Valley', 'North Sinai', 'Port Said', 'Qalyubia', 'Qena', 'Red Sea', 'Sharqia', 'Sohag', 'South Sinai', 'Suez'],
    'El Salvador': ['Ahuachapán', 'Cabañas', 'Chalatenango', 'Cuscatlán', 'La Libertad', 'La Paz', 'La Unión', 'Morazán', 'San Miguel', 'San Salvador', 'San Vicente', 'Santa Ana', 'Sonsonate', 'Usulután'],
    'Equatorial Guinea': ['Annobón', 'Bioko Norte', 'Bioko Sur', 'Centro Sur', 'Kie-Ntem', 'Litoral', 'Wele-Nzas'],
    'Eritrea': ['Anseba', 'Debub', 'Gash-Barka', 'Maekel', 'Northern Red Sea', 'Southern Red Sea'],
    'Estonia': ['Harju', 'Hiiu', 'Ida-Viru', 'Järva', 'Jõgeva', 'Lääne', 'Lääne-Viru', 'Pärnu', 'Põlva', 'Rapla', 'Saare', 'Tartu', 'Valga', 'Viljandi', 'Võru'],
    'Eswatini': ['Hhohho', 'Lubombo', 'Manzini', 'Shiselweni'],
    'Ethiopia': ['Addis Ababa', 'Afar', 'Amhara', 'Benishangul-Gumuz', 'Dire Dawa', 'Gambela', 'Harari', 'Oromia', 'Sidama', 'Somali', 'Southern Nations, Nationalities, and Peoples', 'Tigray'],
    'Fiji': ['Ba', 'Bua', 'Cakaudrove', 'Kadavu', 'Lau', 'Lomaiviti', 'Macuata', 'Nadroga-Navosa', 'Naitasiri', 'Namosi', 'Ra', 'Rewa', 'Serua', 'Tailevu'],
    'Finland': ['Åland Islands', 'Central Finland', 'Central Ostrobothnia', 'Kainuu', 'Kymenlaakso', 'Lapland', 'North Karelia', 'Northern Ostrobothnia', 'Northern Savonia', 'Ostrobothnia', 'Päijänne Tavastia', 'Pirkanmaa', 'Satakunta', 'South Karelia', 'Southern Ostrobothnia', 'Southern Savonia', 'Southwest Finland', 'Tavastia Proper', 'Uusimaa'],
    'France': ['Auvergne-Rhône-Alpes', 'Bourgogne-Franche-Comté', 'Brittany', 'Centre-Val de Loire', 'Corsica', 'Grand Est', 'Hauts-de-France', 'Île-de-France', 'Normandy', 'Nouvelle-Aquitaine', 'Occitanie', 'Pays de la Loire', 'Provence-Alpes-Côte d’Azur'],
    'Gabon': ['Estuaire', 'Haut-Ogooué', 'Moyen-Ogooué', 'Ngounié', 'Nyanga', 'Ogooué-Ivindo', 'Ogooué-Lolo', 'Ogooué-Maritime', 'Woleu-Ntem'],
    'Gambia': ['Banjul', 'Central River', 'Lower River', 'North Bank', 'Upper River', 'West Coast'],
    'Georgia': ['Abkhazia', 'Adjara', 'Guria', 'Imereti', 'Kakheti', 'Kvemo Kartli', 'Mtskheta-Mtianeti', 'Racha-Lechkhumi and Kvemo Svaneti', 'Samegrelo-Zemo Svaneti', 'Samtskhe-Javakheti', 'Shida Kartli', 'Tbilisi'],
    'Germany': ['Baden-Württemberg', 'Bavaria', 'Berlin', 'Brandenburg', 'Bremen', 'Hamburg', 'Hesse', 'Lower Saxony', 'Mecklenburg-Vorpommern', 'North Rhine-Westphalia', 'Rhineland-Palatinate', 'Saarland', 'Saxony', 'Saxony-Anhalt', 'Schleswig-Holstein', 'Thuringia'],
    'Ghana': ['Ahafo', 'Ashanti', 'Bono', 'Bono East', 'Central', 'Eastern', 'Greater Accra', 'North East', 'Northern', 'Oti', 'Savannah', 'Upper East', 'Upper West', 'Volta', 'Western', 'Western North'],
    'Greece': ['Attica', 'Central Greece', 'Central Macedonia', 'Crete', 'Eastern Macedonia and Thrace', 'Epirus', 'Ionian Islands', 'North Aegean', 'Peloponnese', 'South Aegean', 'Thessaly', 'Western Greece', 'Western Macedonia'],
    'Grenada': ['Carriacou and Petite Martinique', 'Saint Andrew', 'Saint David', 'Saint George', 'Saint John', 'Saint Mark', 'Saint Patrick'],
    'Guatemala': ['Alta Verapaz', 'Baja Verapaz', 'Chimaltenango', 'Chiquimula', 'El Progreso', 'Escuintla', 'Guatemala', 'Huehuetenango', 'Izabal', 'Jalapa', 'Jutiapa', 'Petén', 'Quetzaltenango', 'Quiché', 'Retalhuleu', 'Sacatepéquez', 'San Marcos', 'Santa Rosa', 'Sololá', 'Suchitepéquez', 'Totonicapán', 'Zacapa'],
    'Guinea': ['Boké', 'Conakry', 'Faranah', 'Kankan', 'Kindia', 'Labé', 'Mamou', 'Nzérékoré'],
    'Guinea-Bissau': ['Bafatá', 'Biombo', 'Bissau', 'Bolama', 'Cacheu', 'Gabú', 'Oio', 'Quinara', 'Tombali'],
    'Guyana': ['Barima-Waini', 'Cuyuni-Mazaruni', 'Demerara-Mahaica', 'East Berbice-Corentyne', 'Essequibo Islands-West Demerara', 'Mahaica-Berbice', 'Pomeroon-Supenaam', 'Potaro-Siparuni', 'Upper Demerara-Berbice', 'Upper Takutu-Upper Essequibo'],
    'Haiti': ['Artibonite', 'Centre', 'Grand’Anse', 'Nippes', 'Nord', 'Nord-Est', 'Nord-Ouest', 'Ouest', 'Sud', 'Sud-Est'],
    'Holy See': [],
    'Honduras': ['Atlántida', 'Choluteca', 'Colón', 'Comayagua', 'Copán', 'Cortés', 'El Paraíso', 'Francisco Morazán', 'Gracias a Dios', 'Intibucá', 'Islas de la Bahía', 'La Paz', 'Lempira', 'Ocotepeque', 'Olancho', 'Santa Bárbara', 'Valle', 'Yoro'],
    'Hungary': ['Bács-Kiskun', 'Baranya', 'Békés', 'Borsod-Abaúj-Zemplén', 'Csongrád-Csanád', 'Fejér', 'Győr-Moson-Sopron', 'Hajdú-Bihar', 'Heves', 'Jász-Nagykun-Szolnok', 'Komárom-Esztergom', 'Nógrád', 'Pest', 'Somogy', 'Szabolcs-Szatmár-Bereg', 'Tolna', 'Vas', 'Veszprém', 'Zala', 'Budapest'],
    'Iceland': [],
    'India': ['Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'],
    'Indonesia': ['Aceh', 'Bali', 'Bangka Belitung', 'Banten', 'Bengkulu', 'Central Java', 'Central Kalimantan', 'Central Sulawesi', 'East Java', 'East Kalimantan', 'East Nusa Tenggara', 'Gorontalo', 'Jakarta', 'Jambi', 'Lampung', 'Maluku', 'North Kalimantan', 'North Maluku', 'North Sulawesi', 'North Sumatra', 'Papua', 'Riau', 'Riau Islands', 'South Kalimantan', 'South Sulawesi', 'South Sumatra', 'Southeast Sulawesi', 'West Java', 'West Kalimantan', 'West Nusa Tenggara', 'West Papua', 'West Sulawesi', 'West Sumatra', 'Yogyakarta'],
    'Iran': ['Alborz', 'Ardabil', 'Bushehr', 'Chaharmahal and Bakhtiari', 'East Azerbaijan', 'Fars', 'Gilan', 'Golestan', 'Hamadan', 'Hormozgan', 'Ilam', 'Isfahan', 'Kerman', 'Kermanshah', 'Khuzestan', 'Kohgiluyeh and Boyer-Ahmad', 'Kurdistan', 'Lorestan', 'Markazi', 'Mazandaran', 'North Khorasan', 'Qazvin', 'Qom', 'Razavi Khorasan', 'Semnan', 'Sistan and Baluchestan', 'South Khorasan', 'Tehran', 'West Azerbaijan', 'Yazd', 'Zanjan'],
    'Iraq': ['Al Anbar', 'Babylon', 'Baghdad', 'Basra', 'Dhi Qar', 'Al-Qādisiyyah', 'Diyala', 'Dohuk', 'Erbil', 'Karbala', 'Kirkuk', 'Maysan', 'Muthanna', 'Najaf', 'Nineveh', 'Saladin', 'Sulaymaniyah', 'Wasit'],
    'Ireland': ['Carlow', 'Cavan', 'Clare', 'Cork', 'Donegal', 'Dublin', 'Galway', 'Kerry', 'Kildare', 'Kilkenny', 'Laois', 'Leitrim', 'Limerick', 'Longford', 'Louth', 'Mayo', 'Meath', 'Monaghan', 'Offaly', 'Roscommon', 'Sligo', 'Tipperary', 'Waterford', 'Westmeath', 'Wexford', 'Wicklow'],
    'Israel': ['Central District', 'Haifa District', 'Jerusalem District', 'Northern District', 'Southern District', 'Tel Aviv District'],
    'Italy': ['Abruzzo', 'Aosta Valley', 'Apulia', 'Basilicata', 'Calabria', 'Campania', 'Emilia-Romagna', 'Friuli-Venezia Giulia', 'Lazio', 'Liguria', 'Lombardy', 'Marche', 'Molise', 'Piedmont', 'Sardinia', 'Sicily', 'Trentino-South Tyrol', 'Tuscany', 'Umbria', 'Veneto'],
    'Jamaica': ['Clarendon', 'Hanover', 'Kingston', 'Manchester', 'Portland', 'Saint Andrew', 'Saint Ann', 'Saint Catherine', 'Saint Elizabeth', 'Saint James', 'Saint Mary', 'Saint Thomas', 'Trelawny', 'Westmoreland'],
    'Japan': ['Aichi', 'Akita', 'Aomori', 'Chiba', 'Ehime', 'Fukui', 'Fukuoka', 'Fukushima', 'Gifu', 'Gunma', 'Hiroshima', 'Hokkaido', 'Hyogo', 'Ibaraki', 'Ishikawa', 'Iwate', 'Kagawa', 'Kagoshima', 'Kanagawa', 'Kochi', 'Kumamoto', 'Kyoto', 'Mie', 'Miyagi', 'Miyazaki', 'Nagano', 'Nagasaki', 'Nara', 'Niigata', 'Oita', 'Okayama', 'Okinawa', 'Osaka', 'Saga', 'Saitama', 'Shiga', 'Shimane', 'Shizuoka', 'Tochigi', 'Tokushima', 'Tokyo', 'Tottori', 'Toyama', 'Wakayama', 'Yamagata', 'Yamaguchi', 'Yamanashi'],
    'Jordan': ['Ajloun', 'Amman', 'Aqaba', 'Balqa', 'Irbid', 'Jerash', 'Karak', 'Ma’an', 'Madaba', 'Mafraq', 'Tafilah', 'Zarqa'],
    'Kazakhstan': ['Akmola', 'Aktobe', 'Almaty', 'Almaty City', 'Atyrau', 'Baikonur', 'East Kazakhstan', 'Jambyl', 'Karaganda', 'Kostanay', 'Kyzylorda', 'Mangystau', 'North Kazakhstan', 'Nur-Sultan', 'Pavlodar', 'Turkistan', 'West Kazakhstan'],
    'Kenya': ['Baringo', 'Bomet', 'Bungoma', 'Busia', 'Elgeyo-Marakwet', 'Embu', 'Garissa', 'Homa Bay', 'Isiolo', 'Kajiado', 'Kakamega', 'Kericho', 'Kiambu', 'Kilifi', 'Kirinyaga', 'Kisii', 'Kisumu', 'Kitui', 'Kwale', 'Laikipia', 'Lamu', 'Machakos', 'Makueni', 'Mandera', 'Marsabit', 'Meru', 'Migori', 'Mombasa', 'Murang’a', 'Nairobi', 'Nakuru', 'Nandi', 'Narok', 'Nyamira', 'Nyandarua', 'Nyeri', 'Samburu', 'Siaya', 'Taita-Taveta', 'Tana River', 'Tharaka-Nithi', 'Trans Nzoia', 'Turkana', 'Uasin Gishu', 'Vihiga', 'Wajir', 'West Pokot'],
    'Kiribati': ['Gilbert Islands', 'Line Islands', 'Phoenix Islands'],
    'Kuwait': ['Al Ahmadi', 'Al Asimah', 'Al Farwaniyah', 'Al Jahra', 'Hawalli', 'Mubarak Al-Kabeer'],
    'Kyrgyzstan': ['Alai', 'Batken', 'Chuy', 'Jalal-Abad', 'Naryn', 'Osh', 'Talas', 'Ysyk-Köl', 'Bishkek'],
    'Laos': ['Attapeu', 'Bokeo', 'Bolikhamxai', 'Champasak', 'Houaphanh', 'Khammouane', 'Luang Namtha', 'Luang Prabang', 'Oudomxay', 'Phongsaly', 'Salavan', 'Savannakhet', 'Sekong', 'Vientiane', 'Vientiane Prefecture', 'Xaisomboun', 'Xiangkhouang'],
    'Latvia': [],
    'Lebanon': ['Akkar', 'Baalbek-Hermel', 'Beirut', 'Bekaa', 'Mount Lebanon', 'Nabatieh', 'North', 'South'],
    'Lesotho': ['Berea', 'Butha-Buthe', 'Leribe', 'Mafeteng', 'Maseru', 'Mohale’s Hoek', 'Mokhotlong', 'Qacha’s Nek', 'Quthing', 'Thaba-Tseka'],
    'Liberia': ['Bomi', 'Bong', 'Gbarpolu', 'Grand Bassa', 'Grand Cape Mount', 'Grand Gedeh', 'Grand Kru', 'Lofa', 'Margibi', 'Maryland', 'Montserrado', 'Nimba', 'River Cess', 'River Gee', 'Sinoe'],
    'Libya': ['Al Butnan', 'Al Jabal al Akhdar', 'Al Jabal al Gharbi', 'Al Jufrah', 'Al Kufrah', 'Al Marj', 'Al Marqab', 'Al Wahat', 'Benghazi', 'Derna', 'Ghat', 'Jalu', 'Misrata', 'Murqub', 'Nalut', 'Nuqat al Khams', 'Sabha', 'Sirte', 'Tripoli', 'Wadi al Hayaa', 'Wadi al Shatii', 'Zawiya'],
    'Liechtenstein': [],
    'Lithuania': ['Alytus', 'Kaunas', 'Klaipėda', 'Marijampolė', 'Panevėžys', 'Šiauliai', 'Tauragė', 'Telšiai', 'Utena', 'Vilnius'],
    'Luxembourg': [],
    'Madagascar': ['Alaotra-Mangoro', 'Amoron’i Mania', 'Analamanga', 'Analanjirofo', 'Androy', 'Anosy', 'Atsimo-Andrefana', 'Atsimo-Atsinanana', 'Atsinanana', 'Betsiboka', 'Boeny', 'Bongolava', 'Diana', 'Haute Matsiatra', 'Ihorombe', 'Itasy', 'Melaky', 'Menabe', 'Sava', 'Sofia', 'Vakinankaratra', 'Vatovavy-Fitovinany'],
    'Malawi': ['Balaka', 'Blantyre', 'Chikwawa', 'Chiradzulu', 'Chitipa', 'Dedza', 'Dowa', 'Karonga', 'Kasungu', 'Likoma', 'Lilongwe', 'Machinga', 'Mangochi', 'Mchinji', 'Mulanje', 'Mwanza', 'Mzimba', 'Neno', 'Nkhata Bay', 'Nkhotakota', 'Nsanje', 'Ntcheu', 'Ntchisi', 'Phalombe', 'Rumphi', 'Salima', 'Thyolo', 'Zomba'],
    'Malaysia': ['Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Labuan', 'Malacca', 'Negeri Sembilan', 'Pahang', 'Penang', 'Perak', 'Perlis', 'Putrajaya', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu'],
    'Maldives': ['Alif Alif', 'Alif Dhaal', 'Baa', 'Dhaalu', 'Faafu', 'Gaafu Alif', 'Gaafu Dhaal', 'Gnaviyani', 'Haa Alif', 'Haa Dhaal', 'Kaafu', 'Laamu', 'Lhaviyani', 'Meemu', 'Noonu', 'Raa', 'Seenu', 'Shaviyani', 'Thaa', 'Vaavu'],
    'Mali': ['Bamako', 'Gao', 'Kayes', 'Kidal', 'Koulikoro', 'Ménaka', 'Mopti', 'Ségou', 'Sikasso', 'Taoudénit', 'Tombouctou'],
    'Malta': [],
    'Marshall Islands': ['Ailinglaplap', 'Ailuk', 'Arno', 'Aur', 'Bikini', 'Ebon', 'Enewetak', 'Jabat', 'Jaluit', 'Kili', 'Kwajalein', 'Lae', 'Lib', 'Likiep', 'Majuro', 'Maloelap', 'Mejit', 'Mili', 'Namdrik', 'Namu', 'Rongelap', 'Rongrik', 'Ujae', 'Utrik', 'Wotho', 'Wotje'],
    'Mauritania': ['Adrar', 'Assaba', 'Brakna', 'Dakhlet Nouadhibou', 'Gorgol', 'Guidimaka', 'Hodh Ech Chargui', 'Hodh El Gharbi', 'Inchiri', 'Nouakchott-Nord', 'Nouakchott-Ouest', 'Nouakchott-Sud', 'Tagant', 'Tiris Zemmour', 'Trarza'],
    'Mauritius': ['Agaléga', 'Black River', 'Cargados Carajos', 'Flacq', 'Grand Port', 'Moka', 'Pamplemousses', 'Plaines Wilhems', 'Port Louis', 'Rivière du Rempart', 'Rodrigues', 'Savanne'],
    'Mexico': ['Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche', 'Chiapas', 'Chihuahua', 'Coahuila', 'Colima', 'Durango', 'Guanajuato', 'Guerrero', 'Hidalgo', 'Jalisco', 'Mexico City', 'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca', 'Puebla', 'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa', 'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán', 'Zacatecas'],
    'Micronesia': ['Chuuk', 'Kosrae', 'Pohnpei', 'Yap'],
    'Moldova': ['Anenii Noi', 'Basarabeasca', 'Briceni', 'Cahul', 'Cantemir', 'Călărași', 'Căușeni', 'Cimișlia', 'Criuleni', 'Dondușeni', 'Drochia', 'Dubăsari', 'Edineț', 'Fălești', 'Florești', 'Glodeni', 'Hîncești', 'Ialoveni', 'Leova', 'Nisporeni', 'Ocnița', 'Orhei', 'Rezina', 'Rîșcani', 'Sîngerei', 'Soroca', 'Strășeni', 'Șoldănești', 'Ștefan Vodă', 'Taraclia', 'Telenești', 'Ungheni', 'Chișinău', 'Bălți', 'Bender', 'Găgăuzia'],
    'Monaco': [],
    'Mongolia': ['Arkhangai', 'Bayankhongor', 'Bayan-Ölgii', 'Bulgan', 'Darkhan-Uul', 'Dornod', 'Dornogovi', 'Dundgovi', 'Govi-Altai', 'Govisümber', 'Khentii', 'Khovd', 'Khövsgöl', 'Ömnögovi', 'Orkhon', 'Övörkhangai', 'Selenge', 'Sükhbaatar', 'Töv', 'Uvs', 'Zavkhan', 'Ulaanbaatar'],
    'Montenegro': ['Andrijevica', 'Bar', 'Berane', 'Bijelo Polje', 'Budva', 'Cetinje', 'Danilovgrad', 'Gusinje', 'Herceg Novi', 'Kolašin', 'Kotor', 'Mojkovac', 'Nikšić', 'Plav', 'Pljevlja', 'Plužine', 'Podgorica', 'Rožaje', 'Šavnik', 'Tivat', 'Ulcinj', 'Žabljak'],
    'Morocco': ['Béni Mellal-Khénifra', 'Casablanca-Settat', 'Drâa-Tafilalet', 'Fès-Meknès', 'Guelmim-Oued Noun', 'Laâyoune-Sakia El Hamra', 'Marrakech-Safi', 'Oriental', 'Rabat-Salé-Kénitra', 'Souss-Massa', 'Tanger-Tétouan-Al Hoceïma', 'Dakhla-Oued Ed-Dahab'],
    'Mozambique': ['Cabo Delgado', 'Gaza', 'Inhambane', 'Manica', 'Maputo', 'Maputo City', 'Nampula', 'Niassa', 'Sofala', 'Tete', 'Zambezia'],
    'Myanmar': ['Ayeyarwady', 'Bago', 'Chin', 'Kachin', 'Kayah', 'Kayin', 'Magway', 'Mandalay', 'Mon', 'Naypyidaw', 'Rakhine', 'Sagaing', 'Shan', 'Tanintharyi', 'Yangon'],
    'Namibia': ['Erongo', 'Hardap', 'Karas', 'Kavango East', 'Kavango West', 'Khomas', 'Kunene', 'Ohangwena', 'Omaheke', 'Omusati', 'Oshana', 'Oshikoto', 'Otjozondjupa', 'Zambezi'],
    'Nauru': ['Aiwo', 'Anabar', 'Anibare', 'Baitsi', 'Boe', 'Buada', 'Denigomodu', 'Ewa', 'Ijuw', 'Meneng', 'Nibok', 'Uaboe', 'Yaren'],
    'Nepal': ['Bagmati', 'Gandaki', 'Karnali', 'Koshi', 'Lumbini', 'Madhesh', 'Sudurpashchim'],
    'Netherlands': ['Drenthe', 'Flevoland', 'Friesland', 'Gelderland', 'Groningen', 'Limburg', 'North Brabant', 'North Holland', 'Overijssel', 'South Holland', 'Utrecht', 'Zeeland'],
    'New Zealand': ['Auckland', 'Bay of Plenty', 'Canterbury', 'Gisborne', 'Hawke’s Bay', 'Manawatu-Wanganui', 'Marlborough', 'Nelson', 'Northland', 'Otago', 'Southland', 'Taranaki', 'Tasman', 'Waikato', 'Wellington', 'West Coast'],
    'Nicaragua': ['Boaco', 'Carazo', 'Chinandega', 'Chontales', 'Estelí', 'Granada', 'Jinotega', 'León', 'Madriz', 'Managua', 'Masaya', 'Matagalpa', 'Nueva Segovia', 'Río San Juan', 'Rivas', 'North Caribbean Coast', 'South Caribbean Coast'],
    'Niger': ['Agadez', 'Diffa', 'Dosso', 'Maradi', 'Niamey', 'Tahoua', 'Tillabéri', 'Zinder'],
    'Nigeria': ['Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara', 'Federal Capital Territory'],
    'North Korea': ['Chagang', 'North Hamgyong', 'South Hamgyong', 'North Hwanghae', 'South Hwanghae', 'Kangwon', 'North Pyongan', 'South Pyongan', 'Ryanggang', 'Rason', 'Pyongyang'],
    'North Macedonia': ['Berovo', 'Bitola', 'Bogdanci', 'Bogovinje', 'Bosilovo', 'Brvenica', 'Centar Župa', 'Čaška', 'Češinovo-Obleševo', 'Čučer-Sandevo', 'Debar', 'Debarca', 'Delčevo', 'Demir Hisar', 'Demir Kapija', 'Dojran', 'Dolneni', 'Gevgelija', 'Gostivar', 'Gradsko', 'Ilinden', 'Jegunovce', 'Karbinci', 'Kavadarci', 'Kičevo', 'Kočani', 'Konče', 'Kratovo', 'Kriva Palanka', 'Krivogaštani', 'Kruševo', 'Kumanovo', 'Lipkovo', 'Lozovo', 'Makedonska Kamenica', 'Makedonski Brod', 'Mavrovo and Rostuša', 'Mogila', 'Negotino', 'Novaci', 'Novo Selo', 'Ohrid', 'Pehčevo', 'Petrovec', 'Plasnica', 'Prilep', 'Probištip', 'Radoviš', 'Rankovce', 'Resen', 'Rosoman', 'Skopje', 'Sopište', 'Star Dojran', 'Staro Nagoričane', 'Struga', 'Strumica', 'Studeničani', 'Štip', 'Sveti Nikole', 'Tearce', 'Tetovo', 'Valandovo', 'Vasilevo', 'Veles', 'Vevčani', 'Vinica', 'Vrapčište', 'Zelenikovo', 'Želino', 'Zrnovci'],
    'Norway': ['Agder', 'Innlandet', 'Møre og Romsdal', 'Nordland', 'Oslo', 'Rogaland', 'Troms og Finnmark', 'Trøndelag', 'Vestfold og Telemark', 'Vestland', 'Viken'],
    'Oman': ['Ad Dakhiliyah', 'Ad Dhahirah', 'Al Batinah North', 'Al Batinah South', 'Al Buraimi', 'Al Wusta', 'Dhofar', 'Musandam', 'Muscat', 'Ash Sharqiyah North', 'Ash Sharqiyah South'],
    'Pakistan': ['Balochistan', 'Khyber Pakhtunkhwa', 'Punjab', 'Sindh', 'Gilgit-Baltistan', 'Islamabad Capital Territory'],
    'Palau': ['Aimeliik', 'Airai', 'Angaur', 'Hatohobei', 'Kayangel', 'Koror', 'Melekeok', 'Ngaraard', 'Ngarchelong', 'Ngardmau', 'Ngatpang', 'Ngchesar', 'Ngeremlengui', 'Ngiwal', 'Peleliu', 'Sonsorol'],
    'Palestine': ['Bethlehem', 'Deir al-Balah', 'Gaza', 'Hebron', 'Jenin', 'Jericho', 'Jerusalem', 'Khan Yunis', 'Nablus', 'North Gaza', 'Qalqilya', 'Rafah', 'Ramallah and al-Bireh', 'Salfit', 'Tubas', 'Tulkarm'],
    'Panama': ['Bocas del Toro', 'Chiriquí', 'Coclé', 'Colón', 'Darién', 'Emberá', 'Guna Yala', 'Herrera', 'Los Santos', 'Ngäbe-Buglé', 'Panamá', 'Panamá Oeste', 'Veraguas'],
    'Papua New Guinea': ['Bougainville', 'Central', 'Chimbu', 'East New Britain', 'East Sepik', 'Eastern Highlands', 'Enga', 'Gulf', 'Hela', 'Jiwaka', 'Madang', 'Manus', 'Milne Bay', 'Morobe', 'National Capital District', 'New Ireland', 'Northern', 'Southern Highlands', 'West New Britain', 'Western', 'Western Highlands', 'West Sepik'],
    'Paraguay': ['Alto Paraguay', 'Alto Paraná', 'Amambay', 'Asunción', 'Boquerón', 'Caaguazú', 'Caazapá', 'Canindeyú', 'Central', 'Concepción', 'Cordillera', 'Guairá', 'Itapúa', 'Misiones', 'Ñeembucú', 'Paraguarí', 'Presidente Hayes', 'San Pedro'],
    'Peru': ['Amazonas', 'Áncash', 'Apurímac', 'Arequipa', 'Ayacucho', 'Cajamarca', 'Callao', 'Cusco', 'Huancavelica', 'Huánuco', 'Ica', 'Junín', 'La Libertad', 'Lambayeque', 'Lima', 'Loreto', 'Madre de Dios', 'Moquegua', 'Pasco', 'Piura', 'Puno', 'San Martín', 'Tacna', 'Tumbes', 'Ucayali'],
    'Philippines': ['Abra', 'Agusan del Norte', 'Agusan del Sur', 'Aklan', 'Albay', 'Antique', 'Apayao', 'Aurora', 'Basilan', 'Bataan', 'Batanes', 'Batangas', 'Benguet', 'Biliran', 'Bohol', 'Bukidnon', 'Bulacan', 'Cagayan', 'Camarines Norte', 'Camarines Sur', 'Camiguin', 'Capiz', 'Catanduanes', 'Cavite', 'Cebu', 'Cotabato', 'Davao de Oro', 'Davao del Norte', 'Davao del Sur', 'Davao Occidental', 'Davao Oriental', 'Dinagat Islands', 'Eastern Samar', 'Guimaras', 'Ifugao', 'Ilocos Norte', 'Ilocos Sur', 'Iloilo', 'Isabela', 'Kalinga', 'La Union', 'Laguna', 'Lanao del Norte', 'Lanao del Sur', 'Leyte', 'Maguindanao', 'Marinduque', 'Masbate', 'Metro Manila', 'Misamis Occidental', 'Misamis Oriental', 'Mountain Province', 'Negros Occidental', 'Negros Oriental', 'Northern Samar', 'Nueva Ecija', 'Nueva Vizcaya', 'Occidental Mindoro', 'Oriental Mindoro', 'Palawan', 'Pampanga', 'Pangasinan', 'Quezon', 'Quirino', 'Rizal', 'Romblon', 'Samar', 'Sarangani', 'Siquijor', 'Sorsogon', 'South Cotabato', 'Southern Leyte', 'Sultan Kudarat', 'Sulu', 'Surigao del Norte', 'Surigao del Sur', 'Tarlac', 'Tawi-Tawi', 'Zambales', 'Zamboanga del Norte', 'Zamboanga del Sur', 'Zamboanga Sibugay'],
    'Poland': ['Greater Poland', 'Kuyavian-Pomeranian', 'Lesser Poland', 'Łódź', 'Lower Silesian', 'Lublin', 'Lubusz', 'Masovian', 'Opole', 'Podkarpackie', 'Podlaskie', 'Pomeranian', 'Silesian', 'Świętokrzyskie', 'Warmian-Masurian', 'West Pomeranian'],
    'Portugal': ['Aveiro', 'Beja', 'Braga', 'Bragança', 'Castelo Branco', 'Coimbra', 'Évora', 'Faro', 'Guarda', 'Leiria', 'Lisbon', 'Portalegre', 'Porto', 'Santarém', 'Setúbal', 'Viana do Castelo', 'Vila Real', 'Viseu', 'Azores', 'Madeira'],
    'Qatar': ['Ad Dawhah', 'Al Khawr', 'Al Wakrah', 'Ar Rayyan', 'Ash Shamal', 'Umm Salal', 'Al Daayen', 'Al Sheehaniya'],
    'Romania': ['Alba', 'Arad', 'Argeș', 'Bacău', 'Bihor', 'Bistrița-Năsăud', 'Botoșani', 'Brașov', 'Brăila', 'Bucharest', 'Buzău', 'Caraș-Severin', 'Călărași', 'Cluj', 'Constanța', 'Covasna', 'Dâmbovița', 'Dolj', 'Galați', 'Giurgiu', 'Gorj', 'Harghita', 'Hunedoara', 'Ialomița', 'Iași', 'Ilfov', 'Maramureș', 'Mehedinți', 'Mureș', 'Neamț', 'Olt', 'Prahova', 'Satu Mare', 'Sălaj', 'Sibiu', 'Suceava', 'Teleorman', 'Timiș', 'Tulcea', 'Vaslui', 'Vâlcea', 'Vrancea'],
    'Russia': ['Adygea', 'Altai Krai', 'Altai Republic', 'Amur', 'Arkhangelsk', 'Astrakhan', 'Bashkortostan', 'Belgorod', 'Bryansk', 'Buryatia', 'Chechnya', 'Chelyabinsk', 'Chukotka', 'Chuvashia', 'Dagestan', 'Ingushetia', 'Irkutsk', 'Ivanovo', 'Jewish Autonomous Oblast', 'Kabardino-Balkaria', 'Kaliningrad', 'Kalmykia', 'Kaluga', 'Kamchatka', 'Karachay-Cherkessia', 'Karelia', 'Kemerovo', 'Khabarovsk', 'Khakassia', 'Khanty-Mansi', 'Kirov', 'Komi', 'Kostroma', 'Krasnodar', 'Krasnoyarsk', 'Kurgan', 'Kursk', 'Leningrad', 'Lipetsk', 'Magadan', 'Mari El', 'Mordovia', 'Moscow', 'Moscow Oblast', 'Murmansk', 'Nenets', 'Nizhny Novgorod', 'Novgorod', 'Novosibirsk', 'Omsk', 'Orenburg', 'Oryol', 'Penza', 'Perm', 'Primorsky', 'Pskov', 'Rostov', 'Ryazan', 'Sakhalin', 'Samara', 'Saratov', 'Smolensk', 'Stavropol', 'Sverdlovsk', 'Tambov', 'Tatarstan', 'Tomsk', 'Tula', 'Tuva', 'Tver', 'Tyumen', 'Udmurtia', 'Ulyanovsk', 'Vladimir', 'Volgograd', 'Vologda', 'Voronezh', 'Yamal-Nenets', 'Yaroslavl', 'Zabaykalsky'],
    'Rwanda': ['Eastern Province', 'Kigali', 'Northern Province', 'Southern Province', 'Western Province'],
    'Saint Kitts and Nevis': ['Christ Church Nichola Town', 'Saint Anne Sandy Point', 'Saint George Basseterre', 'Saint George Gingerland', 'Saint James Windward', 'Saint John Capisterre', 'Saint John Figtree', 'Saint Mary Cayon', 'Saint Paul Capisterre', 'Saint Paul Charlestown', 'Saint Peter Basseterre', 'Saint Thomas Lowland', 'Saint Thomas Middle Island', 'Trinity Palmetto Point'],
    'Saint Lucia': ['Anse la Raye', 'Canaries', 'Castries', 'Choiseul', 'Dennery', 'Gros Islet', 'Laborie', 'Micoud', 'Soufrière', 'Vieux Fort'],
    'Saint Vincent and the Grenadines': ['Charlotte', 'Grenadines', 'Northern Grenadines', 'Saint Andrew', 'Saint David', 'Saint George', 'Saint Patrick'],
    'Samoa': ['A’ana', 'Aiga-i-le-Tai', 'Atua', 'Fa’asaleleaga', 'Gaga’emauga', 'Gagaifomauga', 'Palauli', 'Satupa’itea', 'Tuamasaga', 'Va’a-o-Fonoti', 'Vaisigano'],
    'San Marino': ['Acquaviva', 'Borgo Maggiore', 'Chiesanuova', 'Domagnano', 'Faetano', 'Fiorentino', 'Montegiardino', 'San Marino', 'Serravalle'],
    'Sao Tome and Principe': ['Água Grande', 'Cantagalo', 'Caué', 'Lembá', 'Lobata', 'Mé-Zóchi', 'Pagué'],
    'Saudi Arabia': ['Al Bahah', 'Al Jawf', 'Al Madinah', 'Al Qassim', 'Ar Riyad', 'Asir', 'Eastern Province', 'Ha’il', 'Jizan', 'Makkah', 'Najran', 'Northern Borders', 'Tabuk'],
    'Senegal': ['Dakar', 'Diourbel', 'Fatick', 'Kaffrine', 'Kaolack', 'Kédougou', 'Kolda', 'Louga', 'Matam', 'Saint-Louis', 'Sédhiou', 'Tambacounda', 'Thiès', 'Ziguinchor'],
    'Serbia': ['Belgrade', 'Bor', 'Braničevo', 'Central Banat', 'Danube', 'Jablanica', 'Kolubara', 'Mačva', 'Moravica', 'Nišava', 'North Bačka', 'North Banat', 'Pčinja', 'Pirot', 'Podunavlje', 'Pomoravlje', 'Rasina', 'Raška', 'South Bačka', 'South Banat', 'Srem', 'Šumadija', 'Toplica', 'West Bačka', 'Zaječar', 'Zlatibor'],
    'Seychelles': ['Anse aux Pins', 'Anse Boileau', 'Anse Étoile', 'Anse Royale', 'Baie Lazare', 'Baie Sainte Anne', 'Beau Vallon', 'Bel Air', 'Bel Ombre', 'Cascade', 'Glacis', 'Grand’Anse Mahé', 'Grand’Anse Praslin', 'La Digue', 'La Rivière Anglaise', 'Les Mamelles', 'Mont Buxton', 'Mont Fleuri', 'Plaisance', 'Pointe La Rue', 'Port Glaud', 'Roche Caiman', 'Saint Louis', 'Takamaka'],
    'Sierra Leone': ['Eastern Province', 'Northern Province', 'North Western Province', 'Southern Province', 'Western Area'],
    'Singapore': [],
    'Slovakia': ['Banská Bystrica', 'Bratislava', 'Košice', 'Nitra', 'Prešov', 'Trenčín', 'Trnava', 'Žilina'],
    'Slovenia': [],
    'Solomon Islands': ['Central', 'Choiseul', 'Guadalcanal', 'Honiara', 'Isabel', 'Makira-Ulawa', 'Malaita', 'Rennell and Bellona', 'Temotu', 'Western'],
    'Somalia': ['Awdal', 'Bakool', 'Banaadir', 'Bari', 'Bay', 'Galguduud', 'Gedo', 'Hiiraan', 'Jubbada Dhexe', 'Jubbada Hoose', 'Mudug', 'Nugaal', 'Sanaag', 'Shabeellaha Dhexe', 'Shabeellaha Hoose', 'Sool', 'Togdheer', 'Woqooyi Galbeed'],
    'South Africa': ['Eastern Cape', 'Free State', 'Gauteng', 'KwaZulu-Natal', 'Limpopo', 'Mpumalanga', 'North West', 'Northern Cape', 'Western Cape'],
    'South Korea': ['Busan', 'Chungcheongbuk-do', 'Chungcheongnam-do', 'Daegu', 'Daejeon', 'Gangwon-do', 'Gwangju', 'Gyeonggi-do', 'Gyeongsangbuk-do', 'Gyeongsangnam-do', 'Incheon', 'Jeju', 'Jeollabuk-do', 'Jeollanam-do', 'Seoul', 'Ulsan'],
    'South Sudan': ['Central Equatoria', 'Eastern Equatoria', 'Jonglei', 'Lakes', 'Northern Bahr el Ghazal', 'Unity', 'Upper Nile', 'Warrap', 'Western Bahr el Ghazal', 'Western Equatoria'],
    'Spain': ['Andalusia', 'Aragon', 'Asturias', 'Balearic Islands', 'Basque Country', 'Canary Islands', 'Cantabria', 'Castile and León', 'Castilla-La Mancha', 'Catalonia', 'Extremadura', 'Galicia', 'La Rioja', 'Madrid', 'Murcia', 'Navarre', 'Valencian Community'],
    'Sri Lanka': ['Central', 'Eastern', 'North Central', 'Northern', 'North Western', 'Sabaragamuwa', 'Southern', 'Uva', 'Western'],
    'Sudan': ['Al Jazirah', 'Al Qadarif', 'Blue Nile', 'Central Darfur', 'East Darfur', 'Kassala', 'Khartoum', 'North Darfur', 'North Kordofan', 'Northern', 'Red Sea', 'River Nile', 'Sennar', 'South Darfur', 'South Kordofan', 'West Darfur', 'West Kordofan', 'White Nile'],
    'Suriname': ['Brokopondo', 'Commewijne', 'Coronie', 'Marowijne', 'Nickerie', 'Para', 'Paramaribo', 'Saramacca', 'Sipaliwini', 'Wanica'],
    'Sweden': ['Blekinge', 'Dalarna', 'Gävleborg', 'Gotland', 'Halland', 'Jämtland', 'Jönköping', 'Kalmar', 'Kronoberg', 'Norrbotten', 'Örebro', 'Östergötland', 'Skåne', 'Södermanland', 'Stockholm', 'Uppsala', 'Värmland', 'Västerbotten', 'Västernorrland', 'Västmanland', 'Västra Götaland'],
    'Switzerland': ['Aargau', 'Appenzell Ausserrhoden', 'Appenzell Innerrhoden', 'Basel-Landschaft', 'Basel-Stadt', 'Bern', 'Fribourg', 'Geneva', 'Glarus', 'Graubünden', 'Jura', 'Lucerne', 'Neuchâtel', 'Nidwalden', 'Obwalden', 'Schaffhausen', 'Schwyz', 'Solothurn', 'St. Gallen', 'Thurgau', 'Ticino', 'Uri', 'Valais', 'Vaud', 'Zug', 'Zurich'],
    'Syria': ['Aleppo', 'As-Suwayda', 'Damascus', 'Daraa', 'Deir ez-Zor', 'Hama', 'Homs', 'Idlib', 'Latakia', 'Quneitra', 'Raqqa', 'Rif Dimashq', 'Tartus'],
    'Taiwan': ['Changhua', 'Chiayi', 'Chiayi City', 'Hsinchu', 'Hsinchu City', 'Hualien', 'Kaohsiung', 'Keelung', 'Kinmen', 'Lienchiang', 'Miaoli', 'Nantou', 'New Taipei', 'Penghu', 'Pingtung', 'Taichung', 'Tainan', 'Taipei', 'Taitung', 'Taoyuan', 'Yilan', 'Yunlin'],
    'Tajikistan': ['Dushanbe', 'Gorno-Badakhshan', 'Khatlon', 'Sughd'],
    'Tanzania': ['Arusha', 'Dar es Salaam', 'Dodoma', 'Geita', 'Iringa', 'Kagera', 'Katavi', 'Kigoma', 'Kilimanjaro', 'Lindi', 'Manyara', 'Mara', 'Mbeya', 'Morogoro', 'Mtwara', 'Mwanza', 'Njombe', 'Pemba North', 'Pemba South', 'Pwani', 'Rukwa', 'Ruvuma', 'Shinyanga', 'Simiyu', 'Singida', 'Songwe', 'Tabora', 'Tanga', 'Zanzibar North', 'Zanzibar South and Central', 'Zanzibar Urban/West'],
    'Thailand': ['Amnat Charoen', 'Ang Thong', 'Bangkok', 'Bueng Kan', 'Buriram', 'Chachoengsao', 'Chai Nat', 'Chaiyaphum', 'Chanthaburi', 'Chiang Mai', 'Chiang Rai', 'Chonburi', 'Chumphon', 'Kalasin', 'Kamphaeng Phet', 'Kanchanaburi', 'Khon Kaen', 'Krabi', 'Lampang', 'Lamphun', 'Loei', 'Lopburi', 'Mae Hong Son', 'Maha Sarakham', 'Mukdahan', 'Nakhon Nayok', 'Nakhon Pathom', 'Nakhon Phanom', 'Nakhon Ratchasima', 'Nakhon Sawan', 'Nakhon Si Thammarat', 'Nan', 'Narathiwat', 'Nong Bua Lamphu', 'Nong Khai', 'Nonthaburi', 'Pathum Thani', 'Pattani', 'Phang Nga', 'Phatthalung', 'Phayao', 'Phetchabun', 'Phetchaburi', 'Phichit', 'Phitsanulok', 'Phra Nakhon Si Ayutthaya', 'Phrae', 'Phuket', 'Prachinburi', 'Prachuap Khiri Khan', 'Ranong', 'Ratchaburi', 'Rayong', 'Roi Et', 'Sa Kaeo', 'Sakon Nakhon', 'Samut Prakan', 'Samut Sakhon', 'Samut Songkhram', 'Saraburi', 'Satun', 'Sing Buri', 'Sisaket', 'Songkhla', 'Sukhothai', 'Suphan Buri', 'Surat Thani', 'Surin', 'Tak', 'Trang', 'Trat', 'Ubon Ratchathani', 'Udon Thani', 'Uthai Thani', 'Uttaradit', 'Yala', 'Yasothon'],
    'Timor-Leste': ['Aileu', 'Ainaro', 'Baucau', 'Bobonaro', 'Cova Lima', 'Dili', 'Ermera', 'Lautém', 'Liquiçá', 'Manatuto', 'Manufahi', 'Oecusse', 'Viqueque'],
    'Togo': ['Centrale', 'Kara', 'Maritime', 'Plateaux', 'Savanes'],
    'Tonga': ['’Eua', 'Ha’apai', 'Niuas', 'Tongatapu', 'Vava’u'],
    'Trinidad and Tobago': ['Arima', 'Chaguanas', 'Couva-Tabaquite-Talparo', 'Diego Martin', 'Mayaro-Rio Claro', 'Penal-Debe', 'Point Fortin', 'Port of Spain', 'Princes Town', 'San Fernando', 'San Juan-Laventille', 'Sangre Grande', 'Siparia', 'Tobago', 'Tunapuna-Piarco'],
    'Tunisia': ['Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Gabès', 'Gafsa', 'Jendouba', 'Kairouan', 'Kasserine', 'Kebili', 'Kef', 'Mahdia', 'Manouba', 'Medenine', 'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid', 'Siliana', 'Sousse', 'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan']
  };

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

    _searchController.text = nameFilter ?? '';
    veterinariansFuture = VetService.fetchVeterinarians(
      location: _buildLocationString(),
      specialty: specialtyFilter,
      page: currentPage,
      limit: limit,
      sort: sort,
    );
    servicesFuture = ServiceService.getAllServices();
    _loadUsername();
  }

  String? _buildLocationString() {
    if (selectedCountry != null && selectedState != null) {
      return '$selectedState, $selectedCountry';
    } else if (selectedCountry != null) {
      return selectedCountry;
    }
    return null;
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
        location: _buildLocationString(), // Update this line
        specialty: specialtyFilter,
        page: currentPage,
        limit: limit,
        sort: sort,
      );
      debugPrint('Refreshing veterinarians with: page=$currentPage, location=${_buildLocationString()}, specialty=$specialtyFilter, name=$nameFilter, limit=$limit, sort=$sort');
    });
  }

  @override
  void dispose() {

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
            if (selectedCountry != null || selectedState != null || specialtyFilter != null ||
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
                    if (selectedCountry != null)
                      Chip(
                        label: Text('Country: $selectedCountry'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            selectedCountry = null;
                            selectedState = null; // Also clear state when country is cleared
                            _refreshVeterinarians(1);
                          });
                        },
                      ),
                    if (selectedState != null)
                      Chip(
                        label: Text('State: $selectedState'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            selectedState = null;
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
              locationFilter: _buildLocationString(),
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
    String? tempSelectedCountry = selectedCountry;
    String? tempSelectedState = selectedState;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter by Country'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: tempSelectedCountry,
                      hint: const Text('Select country'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any Country'),
                        ),
                        ...countryStates.keys.map((String country) {
                          return DropdownMenuItem<String>(
                            value: country,
                            child: Text(country),
                          );
                        }),
                      ],
                      onChanged: (String? value) {
                        setDialogState(() {
                          tempSelectedCountry = value;
                          // Reset state when country changes
                          if (tempSelectedCountry != selectedCountry) {
                            tempSelectedState = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Filter by State/City'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: tempSelectedState,
                      hint: const Text('Select state/city'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any State/City'),
                        ),
                        if (tempSelectedCountry != null)
                          ...countryStates[tempSelectedCountry]!.map((String state) {
                            return DropdownMenuItem<String>(
                              value: state,
                              child: Text(state),
                            );
                          }),
                      ],
                      onChanged: tempSelectedCountry != null
                          ? (String? value) {
                        setDialogState(() {
                          tempSelectedState = value;
                        });
                      }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Filter by Specialty'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: tempSpecialtyFilter,
                      hint: const Text('Select specialty'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Any Specialty'),
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
                  selectedCountry = null;
                  selectedState = null;
                  specialtyFilter = null;
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
                  selectedCountry = tempSelectedCountry;
                  selectedState = tempSelectedState;
                  specialtyFilter = tempSpecialtyFilter;
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