import 'dart:io';

import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/token_storage.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String veterinaireId;
  final List<Map<String, dynamic>> participants;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.veterinaireId,
    required this.participants,
    required String vetId,
    required recipientId,
    required String recipientName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  bool _isLoading = false;
  String _conversationTitle = 'Group Chat';
  final Map<String, String> _participantImages = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    _userId = await TokenStorage.getUserId();

    // Cache participant images
    for (var participant in widget.participants) {
      if (participant['profilePicture'] != null) {
        _participantImages[participant['id']] = participant['profilePicture'];
      }
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (widget.chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid chat ID')),
      );
      Navigator.pop(context);
      setState(() => _isLoading = false);
      return;
    }

    final otherParticipants = widget.participants
        .where((p) => p['id'] != _userId)
        .map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    _conversationTitle = otherParticipants.isEmpty ? 'Group Chat' : otherParticipants.join(', ');

    try {
      final userRole = await TokenStorage.getUserRoleFromToken();
      await _chatService.connect(_userId!, userRole?.toUpperCase() ?? 'CLIENT');
      _setupMessageListeners();
      await _chatService.getMessages(widget.chatId);
      await _chatService.markMessagesAsRead(chatId: widget.chatId, userId: _userId!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _setupMessageListeners() {
    _chatService.onNewMessage().listen((data) {
      print('Received message event: $data');
      if (data['chatId'] == widget.chatId && data['type'] == 'NEW_MESSAGE') {
        final newMessage = data['message'] as Map<String, dynamic>;
        setState(() {
          if (!_messages.any((m) => m['id'] == newMessage['id'])) {
            _messages.insert(0, newMessage);
          }
        });
        _scrollToBottom();
        if (newMessage['sender']['id'] != _userId) {
          _chatService.markMessagesAsRead(
            chatId: widget.chatId,
            userId: _userId!,
          );
        }
      } else if (data['chatId'] == widget.chatId && data['type'] == 'MESSAGES_LIST') {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data['messages'] ?? [])
              .map((m) => {
            'id': m['id'],
            'sender': {
              'id': m['sender']['_id'],
              'firstName': m['sender']['firstName'] ?? '',
              'lastName': m['sender']['lastName'] ?? '',
              'profilePicture': m['sender']['profilePicture'],
            },
            'content': m['content'],
            'type': m['type'],
            'createdAt': m['createdAt'],
            'readBy': List<String>.from(m['readBy'] ?? []),
          })
              .toList()
              .reversed
              .toList();
        });
        _scrollToBottom();
      } else if (data['type'] == 'MESSAGE_READ' && data['chatId'] == widget.chatId) {
        final messageId = data['messageId'] as String?;
        final readBy = List<String>.from(data['readBy'] ?? []);
        print('Updating read status for message $messageId: $readBy');
        setState(() {
          _messages = _messages.map((m) {
            if (m['id'] == messageId) {
              return {...m, 'readBy': readBy};
            }
            return m;
          }).toList();
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.insert(0, {
        'id': tempId,
        'sender': {
          'id': _userId,
          'firstName': 'You',
          'lastName': '',
          'profilePicture': _participantImages[_userId],
        },
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
        'readBy': [_userId],
        'type': 'text',
      });
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      await _chatService.sendMessage(
        senderId: _userId!,
        targetId: widget.veterinaireId,
        content: content,
      );
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m['id'] == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildAvatar(String? imageUrl, String? userId) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    if (imageUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(imageUrl),
      );
    } else {
      return CircleAvatar(
        radius: 20,
        backgroundImage: FileImage(File(imageUrl)),
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = (message['sender']?['id'] as String?) == _userId;
    final readBy = List<String>.from(message['readBy'] ?? []);
    final isRead = isMe ? readBy.any((id) => id != _userId) : readBy.contains(_userId);
    final sender = message['sender'] as Map<String, dynamic>?;
    final senderName = '${sender?['firstName'] ?? ''} ${sender?['lastName'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildAvatar(sender?['profilePicture'], sender?['id']),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue[500] : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message['content'] as String? ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message['createdAt'] as String?),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 15,
                          color: isRead ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildAvatar(sender?['profilePicture'], sender?['id']),
            ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    try {
      if (isoTime == null) return '';
      final dateTime = DateTime.parse(isoTime);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversationTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.withOpacity(0.05),
                    Colors.grey.withOpacity(0.1),
                  ],
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}