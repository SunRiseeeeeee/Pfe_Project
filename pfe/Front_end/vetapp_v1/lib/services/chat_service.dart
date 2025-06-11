import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/token_storage.dart';

class ChatService {
  WebSocketChannel? _channel;
  final String _wsUrl = 'ws://192.168.1.16:3001';
  String? _userId;
  String? _userRole;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamController<Map<String, dynamic>>? _conversationController;
  String? _lastSentContent;
  List<Map<String, dynamic>> _conversations = [];
  String? _pendingChatId;

  bool isConnected() {
    return _channel != null;
  }

  ChatService() {
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
    _conversationController = StreamController<Map<String, dynamic>>.broadcast();
  }

  Future<void> connect(String userId, String role) async {
    _userId = userId;
    _userRole = role;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      print('Connecting to WebSocket: $_wsUrl');

      // Register client with backend
      _channel!.sink.add(jsonEncode({
        'role': role.toUpperCase(),
        'senderId': userId,
      }));

      _channel!.stream.listen(
            (data) {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          print('Received WebSocket message: $message');
          _handleWebSocketMessage(message, _userId!); // <-- Pass clientId
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
          _channel = null;
        },
      );
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }


  void _handleWebSocketMessage(Map<String, dynamic> message, String clientId) {
    switch (message['type']) {
      case 'CONVERSATIONS_LIST':
        _handleConversationsList(message, clientId);
        break;
      case 'MESSAGES_LIST':
        _handleMessagesList(message);
        break;
      case 'NEW_MESSAGE':
        _handleNewMessage(message);
        break;
      case 'MESSAGE_SENT':
        _handleMessageSent(message);
        break;
      case 'MESSAGE_READ':
        _handleMessageRead(message);
        break;
      default:
        if (message['status'] == 'error') {
          print('WebSocket error: ${message['message']}');
        } else if (message['status'] == 'success') {
          print('WebSocket success: ${message['message']}');
        }
    }
  }


  void _handleConversationsList(Map<String, dynamic> message, String clientId) {
    final conversations = List<Map<String, dynamic>>.from(message['conversations'] ?? []);
    print('Processing CONVERSATIONS_LIST with ${conversations.length} conversations');

    _conversations = conversations.map((conv) => _normalizeConversation(conv, clientId)).toList();

    _conversationController?.add({
      'type': 'CONVERSATIONS_LIST',
      'conversations': _conversations,
    });
  }


  Map<String, dynamic> _normalizeConversation(Map<String, dynamic> conv, String clientId) {
    final participants = List<Map<String, dynamic>>.from(conv['participants'] ?? []);
    final lastMessage = conv['lastMessage'] as Map<String, dynamic>?;

    // Check if client is already in participants
    final hasClient = participants.any((p) => p['id'] == clientId);

    // Add dummy client if missing
    if (!hasClient) {
      participants.add({
        'id': clientId,
        'firstName': 'Inconnu',
        'lastName': '',
        'profilePicture': null,
        'role': 'client',
      });
    }

    return {
      'chatId': conv['chatId'] as String,
      'participants': participants.map((p) => {
        'id': p['id'] as String,
        'firstName': p['firstName'] as String? ?? 'Inconnu',
        'lastName': p['lastName'] as String? ?? '',
        'profilePicture': p['profilePicture'] as String?,
        'role': p['role'] as String?,
      }).toList(),
      'lastMessage': lastMessage != null
          ? {
        'content': lastMessage['content'] as String? ?? '',
        'type': lastMessage['type'] as String? ?? 'text',
        'createdAt': lastMessage['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        'sender': lastMessage['sender'] != null
            ? {
          'id': lastMessage['sender']['id'] as String,
          'firstName': lastMessage['sender']['firstName'] as String? ?? 'Inconnu',
          'lastName': lastMessage['sender']['lastName'] as String? ?? '',
          'profilePicture': lastMessage['sender']['profilePicture'] as String?,
          'role': lastMessage['sender']['role'] as String?,
        }
            : null,
      }
          : null,
      'unreadCount': conv['unreadCount'] as int? ?? 0,
      'updatedAt': conv['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }


  void _handleMessagesList(Map<String, dynamic> message) {
    final messages = List<Map<String, dynamic>>.from(message['messages'] ?? []);
    final normalizedMessages = messages.map((msg) => _normalizeMessage(msg)).toList();

    _messageController?.add({
      'type': 'MESSAGES_LIST',
      'chatId': message['chatId'],
      'messages': normalizedMessages,
    });
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> msg) {
    final sender = msg['sender'] as Map<String, dynamic>?;

    return {
      'id': msg['_id'] as String? ?? msg['id'] as String? ?? '',
      'chatId': msg['chatId'] as String,
      'sender': sender != null ? {
        'id': sender['_id'] as String? ?? sender['id'] as String? ?? '',
        'firstName': sender['firstName'] as String? ?? 'Inconnu',
        'lastName': sender['lastName'] as String? ?? '',
        'profilePicture': sender['profilePicture'] as String?,
      } : null,
      'content': msg['content'] as String? ?? '',
      'type': msg['type'] as String? ?? 'text',
      'createdAt': msg['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'updatedAt': msg['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      'readBy': List<String>.from(msg['readBy'] ?? []),
    };
  }

  void _handleNewMessage(Map<String, dynamic> message) {
    // Extract message data from the NEW_MESSAGE format
    final messageData = message['message'] as Map<String, dynamic>?;
    if (messageData == null) return;

    final newMessage = _normalizeMessage({
      '_id': messageData['_id'] as String,
      'chatId': message['chatId'] as String,
      'sender': messageData['sender'],
      'content': messageData['content'] as String,
      'type': messageData['type'] as String? ?? 'text',
      'createdAt': messageData['createdAt'] as String,
      'readBy': messageData['readBy'] ?? [],
    });

    _messageController?.add({
      'type': 'NEW_MESSAGE',
      'chatId': message['chatId'],
      'message': newMessage,
    });

    // Update conversations list
    _updateConversationWithNewMessage(message['chatId'] as String, newMessage);
  }

  void _updateConversationWithNewMessage(String chatId, Map<String, dynamic> newMessage) {
    final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
    final isOwnMessage = newMessage['sender']?['id'] == _userId;

    if (index != -1) {
      // Update existing conversation
      final conv = Map<String, dynamic>.from(_conversations[index]);
      conv['lastMessage'] = {
        'content': newMessage['content'],
        'type': newMessage['type'],
        'createdAt': newMessage['createdAt'],
        'sender': newMessage['sender'],
      };
      conv['unreadCount'] = isOwnMessage
          ? (conv['unreadCount'] as int? ?? 0)
          : (conv['unreadCount'] as int? ?? 0) + 1;
      conv['updatedAt'] = DateTime.now().toIso8601String();

      _conversations[index] = conv;
    } else {
      // Create new conversation entry (shouldn't normally happen)
      final sender = newMessage['sender'] as Map<String, dynamic>?;
      if (sender != null) {
        _conversations.insert(0, {
          'chatId': chatId,
          'participants': [
            {
              'id': sender['id'],
              'firstName': sender['firstName'],
              'lastName': sender['lastName'],
              'profilePicture': sender['profilePicture'],
            }
          ],
          'lastMessage': {
            'content': newMessage['content'],
            'type': newMessage['type'],
            'createdAt': newMessage['createdAt'],
            'sender': sender,
          },
          'unreadCount': isOwnMessage ? 0 : 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    _conversationController?.add({
      'type': 'CONVERSATIONS_LIST',
      'conversations': _conversations,
    });
  }

  void _handleMessageSent(Map<String, dynamic> message) {
    _pendingChatId = message['chatId'] as String?;
    print('Message sent confirmation: $_pendingChatId');

    _messageController?.add({
      'type': 'MESSAGE_SENT',
      'chatId': message['chatId'],
      'messageId': message['messageId'],
      'status': message['status'],
    });

    // Refresh conversations to get updated data
    if (_userId != null) {
      getConversations(_userId!);
    }
  }

  void _handleMessageRead(Map<String, dynamic> message) {
    _messageController?.add({
      'type': 'MESSAGE_READ',
      'chatId': message['chatId'],
      'modifiedCount': message['modifiedCount'],
    });

    // Update conversation unread count
    final chatId = message['chatId'] as String?;
    if (chatId != null) {
      final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
      if (index != -1) {
        final conv = Map<String, dynamic>.from(_conversations[index]);
        conv['unreadCount'] = 0;
        _conversations[index] = conv;

        _conversationController?.add({
          'type': 'CONVERSATIONS_LIST',
          'conversations': _conversations,
        });
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    print('WebSocket disconnected');
  }

  Stream<Map<String, dynamic>> onNewMessage() {
    return _messageController!.stream;
  }

  Stream<Map<String, dynamic>> onConversations() {
    return _conversationController!.stream;
  }

  Future<void> getConversations(String userId, {String? searchTerm}) async {
    if (_channel == null) throw Exception('WebSocket not connected');

    final request = {
      'type': 'GET_CONVERSATIONS',
      'userId': userId,
    };

    if (searchTerm != null && searchTerm.isNotEmpty) {
      request['searchTerm'] = searchTerm;
    }

    _channel!.sink.add(jsonEncode(request));
  }

  Future<void> getMessages(String chatId) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'GET_MESSAGES',
      'chatId': chatId,
    }));
  }

  Future<void> markAsRead({required String chatId, required String userId}) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'MARK_AS_READ',
      'chatId': chatId,
      'userId': userId,
    }));
  }

  // Add the missing markMessagesAsRead method
  Future<void> markMessagesAsRead({required String chatId, required String userId}) async {
    return markAsRead(chatId: chatId, userId: userId);
  }

  Future<void> sendMessage({
    required String senderId,
    required String targetId,
    required String content,
    String contentType = 'text',
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _lastSentContent = content;

    final userRole = await TokenStorage.getUserRoleFromToken();
    print('SendMessage - User role: $userRole, SenderId: $senderId, TargetId: $targetId');

    // Determine veterinaireId and clientId based on user role
    String veterinaireId;
    String? clientId;

    if (userRole?.toLowerCase() == 'client') {
      veterinaireId = targetId; // Target is the veterinarian
      clientId = senderId; // Sender is the client
      print('Client to Vet: veterinaireId=$veterinaireId, clientId=$clientId');
    } else if (userRole?.toLowerCase() == 'veterinaire') {
      veterinaireId = senderId; // Sender is the veterinarian
      clientId = targetId; // Target is the client
      print('Vet to Client: veterinaireId=$veterinaireId, clientId=$clientId');
    } else if (userRole?.toLowerCase() == 'secretaire' || userRole?.toLowerCase() == 'secretary') {
      // Fetch the veterinarian ID associated with the secretary
      // This might require an additional API call or stored data
      final vetId = await TokenStorage.getVeterinaireId(); // Implement this method
      if (vetId == null) {
        throw Exception('Veterinaire ID not found for secretary');
      }
      veterinaireId = vetId;
      clientId = targetId; // Target is the client
      print('Secretary message: veterinaireId=$veterinaireId, clientId=$clientId');
    } else {
      throw Exception('Invalid user role: $userRole');
    }

    final messageData = {
      'type': 'SEND_MESSAGE',
      'senderId': senderId,
      'veterinaireId': veterinaireId,
      'content': content,
      'contentType': contentType,
    };

    if (clientId != null) {
      messageData['clientId'] = clientId;
    }

    print('Sending message with data: $messageData');
    _channel!.sink.add(jsonEncode(messageData));
  }

  // Replace the existing getOrCreateConversation method in your ChatService with this improved version

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userId,
    required String targetId,
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');

    try {
      print('Looking for conversation between user $userId and target $targetId');
      print('Current user role: $_userRole');

      // First, refresh conversations list to ensure we have the latest data
      await getConversations(userId);

      // Wait a bit for the response
      await Future.delayed(const Duration(milliseconds: 500));

      // Check existing conversations
      for (var convo in _conversations) {
        final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
        final participantIds = participants.map((p) => p['id'] as String).toSet();

        // Check if this conversation includes the target (veterinarian for client)
        bool hasTarget = participantIds.contains(targetId);

        if (hasTarget) {
          print('Found existing conversation: ${convo['chatId']}');
          print('Participants: ${participants.map((p) => '${p['firstName']} ${p['lastName']} (${p['role']})').join(', ')}');
          return _formatConversationResponse(convo);
        }
      }

      print('No existing conversation found. Creating new conversation...');

      // Set up listener for new conversation
      final completer = Completer<Map<String, dynamic>>();
      late StreamSubscription messageSubscription;
      late StreamSubscription conversationSubscription;

      final timeoutTimer = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          print('Conversation creation timed out');
          messageSubscription.cancel();
          conversationSubscription.cancel();
          completer.completeError(Exception('Conversation creation timeout - please try again'));
        }
      });

      // Listen for message sent confirmation
      messageSubscription = onNewMessage().listen((data) {
        print('Received message data: $data');

        if (data['type'] == 'MESSAGE_SENT' && data['status'] == 'success') {
          print('Message sent successfully: ${data['messageId']}');
          _pendingChatId = data['chatId'] as String?;
        }
      });

      // Listen for updated conversations list
      conversationSubscription = onConversations().listen((data) {
        if (data['type'] == 'CONVERSATIONS_LIST') {
          final conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);

          // Look for conversation with the pending chatId or with target participant
          for (var convo in conversations) {
            final chatId = convo['chatId'] as String;
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['id'] as String).toSet();

            // Check if this is the conversation we're looking for
            bool isTargetConversation = false;

            if (_pendingChatId != null && chatId == _pendingChatId) {
              isTargetConversation = true;
              print('Found conversation by pending chatId: $chatId');
            } else if (participantIds.contains(targetId)) {
              isTargetConversation = true;
              print('Found conversation by target: $chatId');
            }

            if (isTargetConversation) {
              timeoutTimer.cancel();
              messageSubscription.cancel();
              conversationSubscription.cancel();
              _pendingChatId = null;

              if (!completer.isCompleted) {
                print('Successfully found/created conversation: $chatId');
                print('Participants: ${participants.map((p) => '${p['firstName']} ${p['lastName']} (${p['role']})').join(', ')}');
                completer.complete(_formatConversationResponse(convo));
              }
              return;
            }
          }
        }
      });

      // Send initial message to trigger conversation creation
      print('Sending initial message to create conversation...');
      await sendMessage(
        senderId: userId,
        targetId: targetId,
        content: 'Conversation démarrée',
        contentType: 'text',
      );

      // Wait for the conversation to be created/found
      final result = await completer.future;
      return result;

    } catch (e) {
      print('Error getting or creating conversation: $e');
      _pendingChatId = null;
      rethrow;
    }
  }

// Also add this helper method to better format the conversation response
  Map<String, dynamic> _formatConversationResponse(Map<String, dynamic> convo) {
    final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);

    return {
      'chatId': convo['chatId'] as String,
      'participants': participants,
      'unreadCount': convo['unreadCount'] ?? 0,
      'lastMessage': convo['lastMessage'],
      'updatedAt': convo['updatedAt'],
      'success': true,
    };
  }


  // Helper method to check if user is participating in a conversation
  bool _isUserInConversation(Map<String, dynamic> conversation, String userId, String targetId) {
    final participants = List<Map<String, dynamic>>.from(conversation['participants'] ?? []);
    final participantIds = participants.map((p) => p['id'] as String).toSet();

    // For conversations list, the current user is not included in participants
    // So we only need to check if targetId is present
    return participantIds.contains(targetId);
  }

  // Get cached conversations
  List<Map<String, dynamic>> getCachedConversations() {
    return List<Map<String, dynamic>>.from(_conversations);
  }

  // Get specific conversation by chatId
  Map<String, dynamic>? getCachedConversation(String chatId) {
    try {
      return _conversations.firstWhere((c) => c['chatId'] == chatId);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _messageController?.close();
    _conversationController?.close();
    disconnect();
  }
}