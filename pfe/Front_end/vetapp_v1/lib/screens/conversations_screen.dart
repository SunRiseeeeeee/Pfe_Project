import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:vetapp_v1/services/chat_service.dart';
import 'package:vetapp_v1/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/token_storage.dart';
import '../services/user_service.dart';

interface class Participant {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;

  Participant({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    String extractId(dynamic id) {
      if (id is String) return id;
      try {
        String idString = id.toString();
        final regex = RegExp(r'id: ([a-fA-F0-9]{24})');
        final match = regex.firstMatch(idString);
        if (match != null) {
          return match.group(1)!;
        }
        final altRegex = RegExp(r'([a-fA-F0-9]{24})');
        final altMatch = altRegex.firstMatch(idString);
        return altMatch?.group(0) ?? idString;
      } catch (e) {
        debugPrint('Error extracting participant ID: $e');
        return '';
      }
    }

    return Participant(
      id: extractId(json['id']),
      firstName: json['firstName'] as String? ?? 'Inconnu',
      lastName: json['lastName'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
    );
  }
}

interface class LastMessage {
  final String content;
  final String type;
  final String createdAt;
  final String senderId;
  final List<String> readBy;

  LastMessage({
    required this.content,
    required this.type,
    required this.createdAt,
    required this.senderId,
    required this.readBy,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    String extractId(dynamic id) {
      if (id is String) return id;
      try {
        String idString = id.toString();
        final regex = RegExp(r'id: ([a-fA-F0-9]{24})');
        final match = regex.firstMatch(idString);
        if (match != null) {
          return match.group(1)!;
        }
        final altRegex = RegExp(r'([a-fA-F0-9]{24})');
        final altMatch = altRegex.firstMatch(idString);
        return altMatch?.group(0) ?? idString;
      } catch (e) {
        debugPrint('Error extracting sender ID: $e');
        return '';
      }
    }

    return LastMessage(
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: json['createdAt'] as String? ?? '',
      senderId: extractId(json['senderId'] ?? json['sender']?['id'] ?? ''),
      readBy: List<String>.from(json['readBy'] ?? []),
    );
  }
}

interface class Conversation {
  final String chatId;
  final List<Participant> participants;
  final LastMessage? lastMessage;
  final int? unreadCount;
  final String updatedAt;
  final bool isLastMessageUnread;
  final String? clientId;

  Conversation({
    required this.chatId,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
    required this.isLastMessageUnread,
    this.clientId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final participantsJson = json['participants'] as List<dynamic>? ?? [];
    final lastMessageJson = json['lastMessage'] as Map<String, dynamic>?;
    final currentUserId = json['currentUserId'] as String?;

    final lastMessage = lastMessageJson != null
        ? LastMessage.fromJson(lastMessageJson)
        : null;

    final bool isUnread = lastMessage != null &&
        lastMessage.senderId != currentUserId &&
        currentUserId != null &&
        !lastMessage.readBy.contains(currentUserId);

    return Conversation(
      chatId: json['chatId'] as String? ?? '',
      participants: participantsJson
          .map((p) => Participant.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: lastMessage,
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: json['updatedAt'] as String? ?? '',
      isLastMessageUnread: isUnread,
      clientId: json['clientId'] as String?,
    );
  }
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = []; // For client-side filtering
  String? _userId;
  String? _userRole;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
    _searchController.addListener(_onSearchChanged); // Listen to search input changes
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final role = await TokenStorage.getUserRoleFromToken() ?? 'client';

      if (userId != null) {
        setState(() {
          _userId = userId;
          _userRole = role;
        });
        await _chatService.connect(userId, role);
        _chatService.onConversations().listen(
              (data) async {
            if (data['type'] == 'CONVERSATIONS_LIST') {
              final conversationsJson = data['conversations'] as List<dynamic>? ?? [];
              debugPrint('Received ${conversationsJson.length} conversations');
              for (var convo in conversationsJson) {
                debugPrint(
                    'Conversation: chatId=${convo['chatId']}, lastMessage=${convo['lastMessage']?['content'] ?? "None"}, senderId=${convo['lastMessage']?['senderId']}, unreadCount=${convo['unreadCount']}, clientId=${convo['clientId']}, participants=${convo['participants']}');
              }
              List<Conversation> updatedConversations = [];
              for (var convo in conversationsJson) {
                var conversationJson = {...convo as Map<String, dynamic>, 'currentUserId': _userId};
                if (_userRole == 'veterinaire' || _userRole == 'secretary') {
                  final clientId = convo['clientId'] as String?;
                  if (clientId != null) {
                    try {
                      final clientData = await _userService.getUserById(clientId);
                      conversationJson['participants'] = [
                        {
                          'id': clientId,
                          'firstName': clientData['firstName'] ?? 'Inconnu',
                          'lastName': clientData['lastName'] ?? '',
                          'profilePicture': clientData['profilePicture'],
                        }
                      ];
                    } catch (e) {
                      debugPrint('Failed to fetch client data for $clientId: $e');
                    }
                  }
                }
                updatedConversations.add(Conversation.fromJson(conversationJson));
              }
              setState(() {
                _conversations = updatedConversations;
                _filteredConversations = updatedConversations; // Update filtered list
                _isLoading = false;
              });
            } else if (data['type'] == 'MARK_AS_READ' && data['chatId'] != null) {
              final chatId = data['chatId'] as String;
              setState(() {
                final index = _conversations.indexWhere((c) => c.chatId == chatId);
                if (index != -1) {
                  final convo = _conversations[index];
                  _conversations[index] = Conversation(
                    chatId: convo.chatId,
                    participants: convo.participants,
                    lastMessage: convo.lastMessage != null
                        ? LastMessage(
                      content: convo.lastMessage!.content,
                      type: convo.lastMessage!.type,
                      createdAt: convo.lastMessage!.createdAt,
                      senderId: convo.lastMessage!.senderId,
                      readBy: [...convo.lastMessage!.readBy, _userId!],
                    )
                        : null,
                    unreadCount: 0,
                    updatedAt: convo.updatedAt,
                    isLastMessageUnread: false,
                    clientId: convo.clientId,
                  );
                  _filteredConversations[index] = _conversations[index]; // Sync filtered list
                }
              });
              if (_userId != null) {
                _chatService.getConversations(_userId!);
              }
            }
          },
          onError: (error) {
            debugPrint('Conversation stream error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur de mise à jour : $error')),
              );
            }
          },
        );
        await _chatService.getConversations(userId);
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur non connecté')),
          );
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d’initialisation : $e')),
        );
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredConversations = _conversations; // Reset to full list
        _isLoading = false;
      }
    });
  }

  void _onSearchChanged() {
    final searchTerm = _searchController.text.trim();
    debugPrint('Search term changed: $searchTerm');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _isLoading = true;
      });

      if (_userId != null) {
        // Attempt server-side filtering
        _chatService.getConversations(_userId!, searchTerm: searchTerm.isNotEmpty ? searchTerm : null).then((_) {
          // If server-side filtering is not supported or returns unfiltered results,
          // fallback to client-side filtering
          if (searchTerm.isNotEmpty) {
            setState(() {
              _filteredConversations = _conversations.where((conversation) {
                final participant = _selectDisplayParticipant(conversation);
                final fullName = '${participant.firstName} ${participant.lastName}'.toLowerCase();
                return fullName.contains(searchTerm.toLowerCase());
              }).toList();
              _isLoading = false;
            });
            debugPrint('Client-side filtered: ${_filteredConversations.length} conversations');
          } else {
            setState(() {
              _filteredConversations = _conversations;
              _isLoading = false;
            });
          }
        }).catchError((e) {
          debugPrint('Error fetching conversations with search: $e');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de recherche : $e')),
          );
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
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
      if (profilePicture.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            profilePicture.replaceFirst('localhost', '192.168.1.16'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Network image error for $profilePicture: $error');
              return _defaultAvatar(size);
            },
          ),
        );
      } else {
        return ClipOval(
          child: Image.file(
            File(profilePicture),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('File image error for $profilePicture: $error');
              return _defaultAvatar(size);
            },
          ),
        );
      }
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, color: Colors.white, size: size / 2),
    );
  }

  Participant _selectDisplayParticipant(Conversation conversation) {
    if (conversation.participants.isEmpty) {
      return Participant(
        id: '',
        firstName: 'Inconnu',
        lastName: '',
      );
    }

    // For clients, show the vet's info
    if (_userRole == 'client') {
      return conversation.participants.firstWhere(
            (p) => p.id != _userId,
        orElse: () => Participant(
          id: '',
          firstName: 'Inconnu',
          lastName: '',
        ),
      );
    }
    // For vets/secretaries, show the client's info
    else if (_userRole == 'veterinaire' || _userRole == 'secretary') {
      // First try to find by clientId if available
      if (conversation.clientId != null) {
        return conversation.participants.firstWhere(
              (p) => p.id == conversation.clientId,
          orElse: () => Participant(
            id: conversation.clientId!,
            firstName: 'Client',
            lastName: '',
          ),
        );
      }
      // Fallback: find participant who is not the current user and not a secretary
      return conversation.participants.firstWhere(
            (p) => p.id != _userId && !p.firstName.toLowerCase().contains('secrétaire'),
        orElse: () => Participant(
          id: '',
          firstName: 'Client',
          lastName: '',
        ),
      );
    }

    // Default fallback
    return conversation.participants.firstWhere(
          (p) => p.id != _userId,
      orElse: () => Participant(
        id: '',
        firstName: 'Inconnu',
        lastName: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher par nom...',
            hintStyle: GoogleFonts.poppins(color: Colors.white70),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _filteredConversations = _conversations;
                  _isLoading = false;
                });
              },
            ),
          ),
        )
            : Text(
          'Conversations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.purple[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Annuler la recherche' : 'Rechercher',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredConversations.isEmpty
          ? Center(
        child: Text(
          _searchController.text.isNotEmpty
              ? 'Aucune conversation trouvée pour "${_searchController.text}"'
              : 'Aucune conversation',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          final participant = _selectDisplayParticipant(conversation);
          final lastMessage = conversation.lastMessage;

          debugPrint('Rendering conversation ${index + 1}: chatId=${conversation.chatId}, '
              'participant=${participant.firstName} ${participant.lastName}, '
              'lastMessage=${lastMessage?.content ?? "None"}, '
              'isLastMessageUnread=${conversation.isLastMessageUnread}, '
              'unreadCount=${conversation.unreadCount}, '
              'clientId=${conversation.clientId}');

          return ListTile(
            leading: _buildProfilePicture(participant.profilePicture, 50),
            title: Text(
              '${participant.firstName} ${participant.lastName}',
              style: GoogleFonts.poppins(
                fontWeight: conversation.isLastMessageUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              lastMessage != null && lastMessage.content.isNotEmpty
                  ? lastMessage.content
                  : 'Aucun message',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: conversation.isLastMessageUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(conversation.updatedAt),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (conversation.unreadCount != null && conversation.unreadCount! > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
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
              debugPrint('Tapped conversation ${conversation.chatId}');
              if (_userId != null && conversation.unreadCount != null && conversation.unreadCount! > 0) {
                await _chatService.markAsRead(chatId: conversation.chatId, userId: _userId!);
              }
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: conversation.chatId,
                      veterinaireId: _userRole == 'client' ? participant.id : null,
                      participants: conversation.participants
                          .map((p) => {
                        'id': p.id,
                        'firstName': p.firstName,
                        'lastName': p.lastName,
                        'profilePicture': p.profilePicture,
                      })
                          .toList(),
                      vetId: _userRole == 'client' ? participant.id : null,
                      recipientId: _userRole != 'client' ? (conversation.clientId ?? participant.id) : null,
                      recipientName: '${participant.firstName} ${participant.lastName}'.trim(),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}