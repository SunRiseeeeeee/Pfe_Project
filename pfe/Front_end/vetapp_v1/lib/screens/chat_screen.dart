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

    if (widget.chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid chat ID')),
      );
      Navigator.pop(context);
      setState(() => _isLoading = false);
      return;
    }

    // Set conversation title from participants
    final otherParticipants = widget.participants
        .where((p) => p['_id'] != _userId)
        .map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    _conversationTitle = otherParticipants.isEmpty ? 'Group Chat' : otherParticipants.join(', ');

    try {
      await _chatService.connect(_userId!, 'CLIENT'); // Adjust role as needed
      _chatService.onNewMessage().listen((data) {
        if (data['chatId'] == widget.chatId && data['type'] == 'NEW_MESSAGE') {
          final newMessage = data['message'] as Map<String, dynamic>;
          setState(() {
            if (!_messages.any((m) => m['_id'] == newMessage['_id'])) {
              _messages.insert(0, newMessage);
            }
          });
          _scrollToBottom();
          if (newMessage['sender']['_id'] != _userId) {
            _chatService.markMessagesAsRead(
              chatId: widget.chatId,
              userId: _userId!,
            );
          }
        } else if (data['chatId'] == widget.chatId && data['type'] == 'MESSAGES_LIST') {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []).reversed.toList();
          });
          _scrollToBottom();
        } else if (data['type'] == 'MESSAGE_READ') {
          final messageId = data['messageId'] as String?;
          final readBy = List<String>.from(data['readBy'] ?? []);
          if (messageId != null) {
            setState(() {
              final index = _messages.indexWhere((m) => m['_id'] == messageId);
              if (index != -1) {
                _messages[index] = {
                  ..._messages[index],
                  'readBy': readBy,
                };
              }
            });
          }
        }
      });
      await _chatService.getMessages(widget.chatId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // Optimistically add message to UI
    setState(() {
      _messages.insert(0, {
        '_id': tempId,
        'sender': {
          '_id': _userId,
          'firstName': 'You', // Replace with actual user data if available
          'lastName': '',
        },
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
        'readBy': [], // Empty readBy for "Sent" status
      });
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      await _chatService.sendMessage(
        senderId: _userId!,
        veterinaireId: widget.veterinaireId,
        content: content,
      );
    } catch (e) {
      // Remove optimistic message on failure
      setState(() {
        _messages.removeWhere((m) => m['_id'] == tempId);
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
      appBar: AppBar(title: Text(_conversationTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = (message['sender']?['_id'] as String?) == _userId;
                final readBy = List<String>.from(message['readBy'] ?? []);
                final isRead = isMe ? readBy.any((id) => id != _userId) : readBy.contains(_userId);
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['content'] as String? ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${message['sender']?['firstName'] ?? ''} ${message['sender']?['lastName'] ?? ''}'
                              .trim(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          isRead ? 'Read' : 'Sent',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}