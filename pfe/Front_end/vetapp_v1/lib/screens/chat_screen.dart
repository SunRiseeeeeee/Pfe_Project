import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/token_storage.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? veterinaireId;
  final List<Map<String, dynamic>> participants;
  final String? vetId;
  final String? recipientId;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.veterinaireId,
    required this.participants,
    this.vetId,
    this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  String? _userRole;
  bool _isLoading = false;
  bool _isSending = false;
  String _conversationTitle = 'Chat';
  StreamSubscription? _messageSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
      // App came back to foreground
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
      // App went to background
        _handleAppPaused();
        break;
      default:
        break;
    }
  }

  void _handleAppResumed() {
    if (_userId != null && !_chatService.isConnected()) {
      _reconnectToChat();
    }
  }

  void _handleAppPaused() {
    // Cancel any pending reconnection attempts
    _reconnectTimer?.cancel();
  }

  Future<void> _reconnectToChat() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _showError('Connection failed. Please restart the app.');
      return;
    }

    _reconnectAttempts++;

    try {
      await _chatService.connect(_userId!, _userRole ?? 'CLIENT');
      _setupMessageListeners();
      await _chatService.getMessages(widget.chatId);
      _reconnectAttempts = 0; // Reset on successful connection
    } catch (e) {
      debugPrint('Reconnection attempt $_reconnectAttempts failed: $e');

      // Exponential backoff for reconnection
      final delay = Duration(seconds: _reconnectAttempts * 2);
      _reconnectTimer = Timer(delay, _reconnectToChat);
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      _userId = await TokenStorage.getUserId();
      _userRole = await TokenStorage.getUserRoleFromToken();

      if (_userId == null || _userId!.isEmpty) {
        _showError('User not logged in');
        if (mounted) Navigator.pop(context);
        return;
      }

      if (widget.chatId.isEmpty) {
        _showError('Invalid chat ID');
        if (mounted) Navigator.pop(context);
        return;
      }

      // Set conversation title with fallback
      _conversationTitle = widget.recipientName.isNotEmpty
          ? widget.recipientName
          : 'Chat';

      // Connect to chat service with retry logic
      await _connectWithRetry();

    } catch (e) {
      debugPrint('Initialization error: $e');
      _showError('Error connecting: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectWithRetry() async {
    try {
      if (!_chatService.isConnected()) {
        await _chatService.connect(_userId!, _userRole ?? 'CLIENT');
      }

      _setupMessageListeners();
      await _chatService.getMessages(widget.chatId);

      // Mark messages as read after a short delay
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _chatService.markMessagesAsRead(
            chatId: widget.chatId,
            userId: _userId!,
          );
        }
      });

    } catch (e) {
      debugPrint('Connection error: $e');
      rethrow;
    }
  }

  void _setupMessageListeners() {
    _messageSubscription?.cancel();

    _messageSubscription = _chatService.onNewMessage().listen(
          (data) {
        if (!mounted) return;

        debugPrint('Received message data: $data');

        final String? messageType = data['type'] as String?;
        final String? messageChatId = data['chatId'] as String?;

        // Only process messages for this chat
        if (messageChatId != widget.chatId) return;

        switch (messageType) {
          case 'MESSAGES_LIST':
            _handleMessagesList(data);
            break;
          case 'NEW_MESSAGE':
            _handleNewMessage(data);
            break;
          case 'MESSAGE_SENT':
            _handleMessageSent(data);
            break;
          case 'MESSAGE_READ':
            _handleMessageRead(data);
            break;
          case 'ERROR':
            _handleError(data);
            break;
          default:
            debugPrint('Unhandled message type: $messageType');
        }
      },
      onError: (error) {
        debugPrint('Message stream error: $error');
        if (mounted) {
          _showError('Connection error occurred');
          _reconnectToChat();
        }
      },
      onDone: () {
        debugPrint('Message stream closed');
        if (mounted) {
          _reconnectToChat();
        }
      },
    );
  }

  void _handleError(Map<String, dynamic> data) {
    final String? errorMessage = data['message'] as String?;
    _showError(errorMessage ?? 'An error occurred');
  }

  void _handleMessagesList(Map<String, dynamic> data) {
    if (!mounted) return;

    final List<dynamic>? messagesData = data['messages'] as List<dynamic>?;
    if (messagesData == null) return;

    final messages = messagesData
        .cast<Map<String, dynamic>>()
        .where((msg) => msg['content'] != null && msg['content'].toString().trim().isNotEmpty)
        .toList();

    // Sort messages by creation time to ensure proper order
    messages.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? '';
      if (aTime.isEmpty || bTime.isEmpty) return 0;

      try {
        final aDateTime = DateTime.parse(aTime);
        final bDateTime = DateTime.parse(bTime);
        return aDateTime.compareTo(bDateTime); // Oldest first, newest last
      } catch (e) {
        return 0;
      }
    });

    setState(() {
      _messages = messages; // Keep chronological order: oldest at top, newest at bottom
    });

    // Auto-scroll to bottom with delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    if (!mounted) return;

    final Map<String, dynamic>? newMessage = data['message'] as Map<String, dynamic>?;
    if (newMessage == null) return;

    // Validate message content
    final String? content = newMessage['content'] as String?;
    if (content == null || content.trim().isEmpty) return;

    setState(() {
      final String? messageId = newMessage['id'] as String?;
      if (messageId != null) {
        // Check for duplicates
        final existingIndex = _messages.indexWhere((m) => m['id'] == messageId);

        if (existingIndex == -1) {
          // Add new message at the end (bottom of the list)
          _messages.add(newMessage);
        } else {
          _messages[existingIndex] = newMessage;
        }
      } else {
        // Fallback for messages without ID - add at the end
        _messages.add(newMessage);
      }

      // Sort messages to maintain chronological order
      _messages.sort((a, b) {
        final aTime = a['createdAt'] as String? ?? '';
        final bTime = b['createdAt'] as String? ?? '';
        if (aTime.isEmpty || bTime.isEmpty) return 0;

        try {
          final aDateTime = DateTime.parse(aTime);
          final bDateTime = DateTime.parse(bTime);
          return aDateTime.compareTo(bDateTime); // Oldest first, newest last
        } catch (e) {
          return 0;
        }
      });
    });

    // Auto-scroll and mark as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();

      // Mark as read if from someone else
      final String? senderId = newMessage['sender']?['id'] as String? ??
          newMessage['sender']?['_id'] as String?;
      if (senderId != null && senderId != _userId) {
        _chatService.markMessagesAsRead(
          chatId: widget.chatId,
          userId: _userId!,
        );
      }
    });
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() => _isSending = false);

    final String? status = data['status'] as String?;
    if (status == 'success') {
      debugPrint('Message sent successfully');
      // Refresh messages to get the latest state
      _chatService.getMessages(widget.chatId);
    } else {
      final String? error = data['error'] as String?;
      _showError('Failed to send message: ${error ?? 'Unknown error'}');
    }
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        final message = Map<String, dynamic>.from(_messages[i]);
        final readBy = List<String>.from(message['readBy'] ?? []);

        if (!readBy.contains(_userId!)) {
          readBy.add(_userId!);
          message['readBy'] = readBy;
          _messages[i] = message;
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _userId == null) return;

    // Clear input and set sending state
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final String targetId = _determineTargetId();

      if (targetId.isEmpty) {
        throw Exception('Cannot determine message recipient');
      }

      await _chatService.sendMessage(
        senderId: _userId!,
        targetId: targetId,
        content: content,
      );

      // Dismiss keyboard
      _messageFocusNode.unfocus();

    } catch (e) {
      debugPrint('Send message error: $e');
      _showError('Failed to send message: ${e.toString()}');

      // Restore message on error
      _messageController.text = content;
      setState(() => _isSending = false);
    }
  }

  String _determineTargetId() {
    // Priority order for determining target ID
    if (_userRole?.toLowerCase() == 'client') {
      return widget.veterinaireId ?? widget.vetId ?? widget.recipientId ?? '';
    } else {
      return widget.recipientId ?? '';
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildProfilePicture(String? profilePicture, double size) {
    if (profilePicture != null && profilePicture.isNotEmpty) {
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
      } else {
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

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final sender = message['sender'] as Map<String, dynamic>?;
    final senderId = sender?['id'] as String? ?? sender?['_id'] as String? ?? '';
    final isMe = senderId == _userId;
    final content = message['content'] as String? ?? '';
    final createdAt = message['createdAt'] as String? ?? '';
    final readBy = List<String>.from(message['readBy'] ?? []);

    // Validate content
    if (content.trim().isEmpty) return const SizedBox.shrink();

    // Check read status
    final isRead = isMe ? readBy.any((id) => id != _userId) : true;

    // Get sender info
    final senderFirstName = sender?['firstName'] as String? ?? '';
    final senderLastName = sender?['lastName'] as String? ?? '';
    final senderName = '$senderFirstName $senderLastName'.trim();
    final senderPicture = sender?['profilePicture'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar for other users
          if (!isMe) ...[
            _buildProfilePicture(senderPicture, 32),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name
                if (!isMe && senderName.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 12),
                    child: Text(
                      senderName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                // Message container
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.purple[600] : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    content,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),

                // Time and read status
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead ? Colors.blue : Colors.grey[400],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    try {
      if (isoTime == null || isoTime.isEmpty) return '';

      final dateTime = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _reconnectTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversationTitle,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple[600],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_chatService.isConnected())
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.wifi_off,
                color: Colors.white70,
                size: 20,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
              ),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              )
                  : _messages.isEmpty
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
                      'No messages yet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
          ),

          // Message input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
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
                          focusNode: _messageFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[500],
                            ),
                            border: InputBorder.none,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isSending,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isSending ? Colors.grey : Colors.purple[600],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white),
                      iconSize: 20,
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}