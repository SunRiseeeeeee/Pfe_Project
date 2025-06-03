import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:vetapp_v1/services/chat_service.dart';
import 'package:vetapp_v1/screens/chat_screen.dart'; // Ensure correct import path
import 'package:shared_preferences/shared_preferences.dart';

// Define interfaces for type safety
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
    return Participant(
      id: json['id'] as String? ?? '',
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

  LastMessage({
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

interface class Conversation {
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

  factory Conversation.fromJson(Map<String, dynamic> json) {
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
      updatedAt: json['updatedAt'] as String? ?? '',
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
  List<Conversation> _conversations = [];
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      const role = 'CLIENT';

      if (userId != null) {
        setState(() {
          _userId = userId;
        });
        await _chatService.connect(userId, role);
        _chatService.onConversations().listen((data) {
          print('Received conversation stream event: $data');
          if (data['type'] == 'CONVERSATIONS_LIST') {
            final conversationsJson = data['conversations'] as List<dynamic>? ?? [];
            setState(() {
              _conversations = conversationsJson
                  .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
                  .toList();
              _isLoading = false;
              print('Updated conversations in UI: ${_conversations.length} conversations');
              for (final convo in _conversations) {
                print('Conversation ${convo.chatId}: lastMessage = ${convo.lastMessage?.content}');
              }
            });
          }
        });
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
              print('Network image error for $profilePicture: $error');
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
              print('File image error for $profilePicture: $error');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conversations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? Center(
        child: Text(
          'Aucune conversation',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final participants = conversation.participants;
          final participant = participants.isNotEmpty
              ? participants.firstWhere(
                (p) => p.id != _userId,
            orElse: () => participants[0],
          )
              : Participant(
            id: '',
            firstName: 'Inconnu',
            lastName: '',
          );
          final lastMessage = conversation.lastMessage;
          final chatId = conversation.chatId;
          final unreadCount = conversation.unreadCount;

          return ListTile(
            leading: _buildProfilePicture(participant.profilePicture, 50),
            title: Text(
              '${participant.firstName} ${participant.lastName}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              lastMessage != null && lastMessage.content.isNotEmpty
                  ? lastMessage.content
                  : 'Aucun message',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            trailing: unreadCount > 0
                ? CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blue,
              child: Text(
                unreadCount.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    veterinaireId: participant.id,
                    participants: participants
                        .map((p) => {
                      'id': p.id,
                      'firstName': p.firstName,
                      'lastName': p.lastName,
                      'profilePicture': p.profilePicture,
                    })
                        .toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}