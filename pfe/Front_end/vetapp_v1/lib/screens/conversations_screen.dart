import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:vetapp_v1/services/chat_service.dart';
import 'package:vetapp_v1/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/token_storage.dart';

class Participant {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? role;

  Participant({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.role,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? 'Inconnu',
      lastName: json['lastName'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
      role: json['role'] as String?,
    );
  }
}

class LastMessage {
  final String content;
  final String type;
  final String createdAt;
  final Map<String, dynamic>? sender;

  LastMessage({
    required this.content,
    required this.type,
    required this.createdAt,
    this.sender,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: json['createdAt'] as String? ?? '',
      sender: json['sender'] as Map<String, dynamic>?,
    );
  }
}

class Conversation {
  final String chatId;
  final List<Participant> participants;
  final LastMessage? lastMessage;
  final int unreadCount;
  final String updatedAt;

  Conversation({
    required this.chatId,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, String currentUserId) {
    final participantsJson = json['participants'] as List<dynamic>? ?? [];
    final lastMessageJson = json['lastMessage'] as Map<String, dynamic>?;

    return Conversation(
      chatId: json['chatId'] as String? ?? '',
      participants: participantsJson
          .map((p) => Participant.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: lastMessageJson != null
          ? LastMessage.fromJson(lastMessageJson)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  bool get hasUnreadMessages => unreadCount > 0;

  bool isLastMessageFromCurrentUser(String currentUserId) {
    if (lastMessage?.sender == null) return false;
    final senderId = lastMessage!.sender!['id'] as String? ??
        lastMessage!.sender!['_id'] as String? ?? '';
    return senderId == currentUserId;
  }
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  String? _userId;
  String? _userRole;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final role = await TokenStorage.getUserRoleFromToken() ?? 'client';

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur non connecté')),
          );
        }
        return;
      }

      setState(() {
        _userId = userId;
        _userRole = role;
      });

      // Connect to chat service
      await _chatService.connect(userId, role.toUpperCase());

      // Listen to conversation updates
      _conversationsSubscription = _chatService.onConversations().listen(
            (data) {
          if (data['type'] == 'CONVERSATIONS_LIST') {
            _handleConversationsUpdate(data);
          }
        },
        onError: (error) {
          debugPrint('Conversations stream error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur de mise à jour : $error')),
            );
          }
        },
      );

      // Listen to new messages for real-time updates
      _messagesSubscription = _chatService.onNewMessage().listen(
            (data) {
          if (data['type'] == 'NEW_MESSAGE' || data['type'] == 'MESSAGE_SENT') {
            // Force refresh conversations for immediate update
            _refreshConversations();
          } else if (data['type'] == 'MESSAGE_READ') {
            _handleMessageRead(data);
          }
        },
        onError: (error) {
          debugPrint('Messages stream error: $error');
        },
      );

      // Initial load of conversations
      await _chatService.getConversations(userId);

    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'initialisation : $e')),
        );
      }
    }
  }

  void _handleConversationsUpdate(Map<String, dynamic> data) {
    final conversationsJson = data['conversations'] as List<dynamic>? ?? [];

    final updatedConversations = conversationsJson
        .map((convo) => Conversation.fromJson(
      convo as Map<String, dynamic>,
      _userId ?? '',
    ))
        .toList();

    // Sort conversations by updated time (most recent first)
    updatedConversations.sort((a, b) =>
        DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt)));

    setState(() {
      _conversations = updatedConversations;
      _applySearchFilter();
      _isLoading = false;
    });
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;

    setState(() {
      final index = _conversations.indexWhere((c) => c.chatId == chatId);
      if (index != -1) {
        final oldConvo = _conversations[index];
        _conversations[index] = Conversation(
          chatId: oldConvo.chatId,
          participants: oldConvo.participants,
          lastMessage: oldConvo.lastMessage,
          unreadCount: 0, // Mark as read
          updatedAt: oldConvo.updatedAt,
        );
      }
      _applySearchFilter();
    });
  }

  Future<void> _refreshConversations() async {
    if (_userId != null && mounted) {
      try {
        await _chatService.getConversations(_userId!);
      } catch (e) {
        debugPrint('Refresh conversations error: $e');
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _applySearchFilter();
      }
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applySearchFilter();
    });
  }

  void _applySearchFilter() {
    final searchTerm = _searchController.text.trim().toLowerCase();

    if (searchTerm.isEmpty) {
      setState(() {
        _filteredConversations = _conversations;
      });
    } else {
      setState(() {
        _filteredConversations = _conversations.where((conversation) {
          final participant = _getDisplayParticipant(conversation);
          final fullName = '${participant.firstName} ${participant.lastName}'.toLowerCase();
          return fullName.contains(searchTerm);
        }).toList();
      });
    }
  }

  Participant _getDisplayParticipant(Conversation conversation) {
    if (conversation.participants.isEmpty) {
      return Participant(
        id: '',
        firstName: 'Inconnu',
        lastName: '',
      );
    }

    final currentUserRole = _userRole?.toLowerCase();

    // For veterinarians and secretaries, prioritize showing clients
    if (currentUserRole == 'veterinaire' || currentUserRole == 'secretaire' || currentUserRole == 'secretary') {
      // Look for client participants first
      final clientParticipant = conversation.participants.firstWhere(
            (p) => p.role?.toLowerCase() == 'client' && p.id != _userId,
        orElse: () => Participant(id: '', firstName: '', lastName: ''),
      );

      if (clientParticipant.id.isNotEmpty) {
        return clientParticipant;
      }

      // Fallback: show any other participant that's not the current user
      final otherParticipant = conversation.participants.firstWhere(
            (p) => p.id != _userId,
        orElse: () => conversation.participants.first,
      );

      return otherParticipant;
    }

    // For clients, show the veterinarian (or secretary if no vet available)
    else if (currentUserRole == 'client') {
      // Look for veterinarian first
      final vetParticipant = conversation.participants.firstWhere(
            (p) => p.role?.toLowerCase() == 'veterinaire' && p.id != _userId,
        orElse: () => Participant(id: '', firstName: '', lastName: ''),
      );

      if (vetParticipant.id.isNotEmpty) {
        return vetParticipant;
      }

      // Fallback: show secretary or any other participant
      final otherParticipant = conversation.participants.firstWhere(
            (p) => p.id != _userId,
        orElse: () => conversation.participants.first,
      );

      return otherParticipant;
    }

    // Default fallback
    final otherParticipant = conversation.participants.firstWhere(
          (p) => p.id != _userId,
      orElse: () => conversation.participants.first,
    );

    return otherParticipant;
  }

  String _formatTime(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}j';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Maintenant';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildProfilePicture(String? profilePicture, double size) {
    if (profilePicture != null && profilePicture.isNotEmpty) {
      // Handle network images
      if (profilePicture.startsWith('http')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: profilePicture.replaceFirst('localhost', '192.168.1.16'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => _defaultAvatar(size),
            errorWidget: (context, url, error) => _defaultAvatar(size),
          ),
        );
      }
      // Handle local files
      else {
        return ClipOval(
          child: Image.file(
            File(profilePicture),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _defaultAvatar(size),
          ),
        );
      }
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[300],
      child: Icon(
        Icons.person,
        color: Colors.grey[600],
        size: size / 2,
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final participant = _getDisplayParticipant(conversation);
    final lastMessage = conversation.lastMessage;
    final isUnread = conversation.hasUnreadMessages &&
        !conversation.isLastMessageFromCurrentUser(_userId ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isUnread ? 2 : 1,
      child: ListTile(
        leading: _buildProfilePicture(participant.profilePicture, 50),
        title: Text(
          '${participant.firstName} ${participant.lastName}'.trim(),
          style: GoogleFonts.poppins(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          lastMessage != null && lastMessage.content.isNotEmpty
              ? lastMessage.content
              : 'Aucun message',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(conversation.updatedAt),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: conversation.chatId,
                veterinaireId: _getVeterinaireId(conversation, participant),
                participants: conversation.participants
                    .map((p) => {
                  'id': p.id,
                  'firstName': p.firstName,
                  'lastName': p.lastName,
                  'profilePicture': p.profilePicture,
                  'role': p.role,
                })
                    .toList(),
                vetId: _getVeterinaireId(conversation, participant),
                recipientId: _getRecipientId(conversation, participant),
                recipientName: '${participant.firstName} ${participant.lastName}'.trim(),
              ),
            ),
          );
          // Refresh conversations when returning from ChatScreen
          if (result == true && _userId != null) {
            await _refreshConversations();
          }
        },
      ),
    );
  }

  String? _getVeterinaireId(Conversation conversation, Participant participant) {
    final currentUserRole = _userRole?.toLowerCase();
    if (currentUserRole == 'client') {
      // Client: return veterinarian or secretary ID
      return conversation.participants.firstWhere(
            (p) => p.role?.toLowerCase() == 'veterinaire',
        orElse: () => conversation.participants.firstWhere(
              (p) => p.role?.toLowerCase() == 'secretaire' || p.role?.toLowerCase() == 'secretary',
          orElse: () => Participant(id: '', firstName: '', lastName: ''),
        ),
      ).id;
    } else if (currentUserRole == 'veterinaire') {
      // Veterinarian: return own ID
      return _userId;
    } else if (currentUserRole == 'secretaire' || currentUserRole == 'secretary') {
      // Secretary: return associated veterinarian ID
      return conversation.participants.firstWhere(
            (p) => p.role?.toLowerCase() == 'veterinaire',
        orElse: () => Participant(id: '', firstName: '', lastName: ''),
      ).id;
    }
    return null;
  }

  String? _getRecipientId(Conversation conversation, Participant participant) {
    final currentUserRole = _userRole?.toLowerCase();
    if (currentUserRole == 'veterinaire' || currentUserRole == 'secretaire' || currentUserRole == 'secretary') {
      // Veterinarian/Secretary: return client ID
      return conversation.participants.firstWhere(
            (p) => p.role?.toLowerCase() == 'client',
        orElse: () => Participant(id: '', firstName: '', lastName: ''),
      ).id;
    }
    // Client: no recipient ID needed
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? Row(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white,
                      width: 1.0,
                    ),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.poppins(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search with name...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.only(bottom: 4),
                  ),
                ),
              ),
            ),
          ],
        )
            : Text(
          'Conversations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Cancel the search' : 'Rechercher',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshConversations,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshConversations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredConversations.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No conversation found for "${_searchController.text}"'
                    : 'No conversation',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : ListView.builder(
          itemCount: _filteredConversations.length,
          itemBuilder: (context, index) {
            final conversation = _filteredConversations[index];
            return _buildConversationTile(conversation);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}