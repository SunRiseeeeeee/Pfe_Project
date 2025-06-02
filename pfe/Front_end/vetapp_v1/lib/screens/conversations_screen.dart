import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/token_storage.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _conversations = [];
  String? _userId;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    _userId = await TokenStorage.getUserId();
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _chatService.connect(_userId!, 'CLIENT'); // Adjust role as needed
      _chatService.onConversations().listen((data) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
        });
      });
      await _chatService.getConversations(_userId!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  String _getConversationTitle(Map<String, dynamic> conversation) {
    final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);
    final otherParticipants = participants.where((p) => p['_id'] != _userId).toList();
    if (otherParticipants.isEmpty) return 'Unknown';
    return otherParticipants
        .map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
  }

  String _getLastMessagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null || lastMessage['content'] == null) return 'No messages yet';
    final content = lastMessage['content'] as String;
    return content.length > 30 ? '${content.substring(0, 27)}...' : content;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String? _getVeterinaireId(Map<String, dynamic> conversation) {
    final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);
    final vet = participants.firstWhere(
          (p) => (p['role']?.toLowerCase() ?? '') == 'veterinaire',
      orElse: () => participants.firstWhere(
            (p) => p['_id'] != _userId,
        orElse: () => <String, dynamic>{},
      ),
    );
    return vet['_id'] as String?;
  }

  Widget _getVetAvatar(Map<String, dynamic> conversation) {
    final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);
    final vet = participants.firstWhere(
          (p) => (p['role']?.toLowerCase() ?? '') == 'veterinaire',
      orElse: () => <String, dynamic>{},
    );
    final imageUrl = vet['profileImageUrl'] as String?;
    final firstName = vet['firstName'] as String? ?? '';
    final lastName = vet['lastName'] as String? ?? '';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 25,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 25,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 25,
          child: Text(
            _getInitials(firstName, lastName),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 25,
      child: Text(
        _getInitials(firstName, lastName),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search if backend supports it
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? const Center(child: Text('No conversations found'))
          : ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final lastMessage = conversation['lastMessage'] as Map<String, dynamic>?;
          final unreadCount = conversation['unreadCount'] as int? ?? 0;
          return ListTile(
            leading: _getVetAvatar(conversation),
            title: Text(_getConversationTitle(conversation)),
            subtitle: Text(_getLastMessagePreview(lastMessage)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTimestamp(
                    lastMessage != null && lastMessage['createdAt'] != null
                        ? DateTime.tryParse(lastMessage['createdAt'] as String)
                        : null,
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              final vetId = _getVeterinaireId(conversation);
              if (vetId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid conversation participants')),
                );
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: conversation['chatId'] as String,
                    veterinaireId: vetId,
                    participants: List<Map<String, dynamic>>.from(
                      conversation['participants'] ?? [],
                    ),
                  ),
                ),
              );
              // Refresh conversations on return
              await _chatService.getConversations(_userId!);
            },
          );
        },
      ),
    );
  }
}