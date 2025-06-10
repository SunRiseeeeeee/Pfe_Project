import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/token_storage.dart';

class ChatService {
  WebSocketChannel? _channel;
  final String _wsUrl = 'ws://192.168.1.16:3001';
  String? _userId;
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
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      print('Connecting to WebSocket: $_wsUrl');

      _channel!.sink.add(jsonEncode({
        'role': role,
        'senderId': userId,
      }));

      _channel!.stream.listen(
            (data) {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          print('Received WebSocket message: $message');

          switch (message['type']) {
            case 'CONVERSATIONS_LIST':
              final conversations = List<Map<String, dynamic>>.from(message['conversations'] ?? []);
              print('Processing CONVERSATIONS_LIST with ${conversations.length} conversations');
              print('Conversation IDs: ${conversations.map((c) => c['chatId']).toList()}');
              _conversations = conversations;
              _conversationController?.add({
                'type': 'CONVERSATIONS_LIST',
                'conversations': _conversations,
              });
              break;
            case 'MESSAGES_LIST':
              _messageController?.add({
                'type': 'MESSAGES_LIST',
                'chatId': message['chatId'],
                'messages': List<Map<String, dynamic>>.from(message['messages'] ?? []),
              });
              break;
            case 'NEW_MESSAGE':
              final newMessage = {
                'id': message['message']?['_id'] ?? message['timestamp'].toString(),
                'sender': {
                  'id': message['senderId'] ?? '',
                  'firstName': (message['senderName'] as String?)?.split(' ')[0] ?? 'Inconnu',
                  'lastName': (message['senderName'] as String?)!.split(' ').length > 1
                      ? (message['senderName'] as String).split(' ')[1]
                      : '',
                  'profilePicture': message['sender']?['profilePicture'] as String?,
                },
                'content': message['content'] as String? ?? '',
                'type': message['contentType'] as String? ?? 'text',
                'createdAt': message['message']?['createdAt'] as String? ?? DateTime.now().toIso8601String(),
                'readBy': List<String>.from(message['message']?['readBy'] ?? [message['senderId']]),
              };
              _messageController?.add({
                'type': 'NEW_MESSAGE',
                'chatId': message['chatId'],
                'message': newMessage,
              });

              final chatId = message['chatId'] as String?;
              if (chatId != null && _userId != null) {
                final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
                final isOwnMessage = message['senderId'] == _userId;
                if (index != -1) {
                  _conversations[index] = {
                    ..._conversations[index],
                    'lastMessage': {
                      'content': newMessage['content'],
                      'type': newMessage['type'],
                      'createdAt': newMessage['createdAt'],
                    },
                    'unreadCount': isOwnMessage
                        ? _conversations[index]['unreadCount'] as int? ?? 0
                        : (_conversations[index]['unreadCount'] as int? ?? 0) + 1,
                    'updatedAt': DateTime.now().toIso8601String(),
                  };
                } else {
                  _conversations.add({
                    'chatId': chatId,
                    'participants': [
                      {
                        'id': message['senderId'] ?? '',
                        'firstName': (message['senderName'] as String?)?.split(' ')[0] ?? 'Inconnu',
                        'lastName': (message['senderName'] as String?)!.split(' ').length > 1
                            ? (message['senderName'] as String).split(' ')[1]
                            : '',
                        'profilePicture': message['sender']?['profilePicture'] as String?,
                      },
                    ],
                    'lastMessage': {
                      'content': newMessage['content'],
                      'type': newMessage['type'],
                      'createdAt': newMessage['createdAt'],
                    },
                    'unreadCount': isOwnMessage ? 0 : 1,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });
                }
                _conversationController?.add({
                  'type': 'CONVERSATIONS_LIST',
                  'conversations': _conversations,
                });
              }
              break;
            case 'MESSAGE_READ':
              _messageController?.add({
                'type': 'MESSAGE_READ',
                'chatId': message['chatId'],
                'messageId': message['messageId'],
                'readBy': List<String>.from(message['readBy'] ?? []),
              });
              final index = _conversations.indexWhere((c) => c['chatId'] == message['chatId']);
              if (index != -1) {
                _conversations[index] = {
                  ..._conversations[index],
                  'unreadCount': 0,
                };
                _conversationController?.add({
                  'type': 'CONVERSATIONS_LIST',
                  'conversations': _conversations,
                });
              }
              break;
            case 'MESSAGE_SENT':
              _pendingChatId = message['chatId'] as String?;
              print('Message sent confirmation: $_pendingChatId');
              if (_pendingChatId != null && _userId != null && _lastSentContent != null) {
                final index = _conversations.indexWhere((c) => c['chatId'] == _pendingChatId);
                final targetId = message['targetId'] as String? ?? '';
                if (index != -1) {
                  _conversations[index] = {
                    ..._conversations[index],
                    'lastMessage': {
                      'content': _lastSentContent!,
                      'type': 'text',
                      'createdAt': DateTime.now().toIso8601String(),
                    },
                    'unreadCount': _conversations[index]['unreadCount'] as int? ?? 0,
                    'updatedAt': DateTime.now().toIso8601String(),
                  };
                } else {
                  _conversations.add({
                    'chatId': _pendingChatId!,
                    'participants': [
                      {
                        'id': _userId!,
                        'firstName': 'Moi',
                        'lastName': '',
                      },
                      {
                        'id': targetId,
                        'firstName': 'Inconnu',
                        'lastName': '',
                      },
                    ],
                    'lastMessage': {
                      'content': _lastSentContent!,
                      'type': 'text',
                      'createdAt': DateTime.now().toIso8601String(),
                    },
                    'unreadCount': 0,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });
                }
                _conversationController?.add({
                  'type': 'CONVERSATIONS_LIST',
                  'conversations': _conversations,
                });
                getConversations(_userId!);
              }
              _messageController?.add({
                'type': 'MESSAGE_SENT',
                'chatId': message['chatId'],
                'messageId': message['messageId'],
              });
              break;
            default:
              if (message['status'] == 'error') {
                print('WebSocket error: ${message['message']}');
              }
          }
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
    _channel!.sink.add(jsonEncode({
      'type': 'GET_CONVERSATIONS',
      'userId': userId,
      if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
    }));
  }

  Future<void> getMessages(String chatId) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'GET_MESSAGES',
      'chatId': chatId,
    }));
  }
  Future<void> fetchUnreadMessages(String chatId, String userId) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'FETCH_UNREAD_MESSAGES',
      'chatId': chatId,
      'userId': userId,
    }));
  }
  Future<void> markAsRead({required String chatId, required String userId}) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'MARK_AS_READ',
      'chatId': chatId,
      'userId': userId,
    }));
    // Refresh conversations to ensure UI sync
    await getConversations(userId);
  }

  void _handleNewMessage(Map<String, dynamic> message) {
    final newMessage = {
      'id': message['message']?['_id'] ?? message['timestamp'].toString(),
      'sender': {
        'id': message['senderId'] ?? '',
        'firstName': (message['senderName'] as String?)?.split(' ')[0] ?? 'Inconnu',
        'lastName': (message['senderName'] as String?)!.split(' ').length > 1
            ? (message['senderName'] as String).split(' ')[1]
            : '',
        'profilePicture': message['sender']?['profilePicture'] as String?,
      },
      'content': message['content'] as String? ?? '',
      'type': message['contentType'] as String? ?? 'text',
      'createdAt': message['message']?['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'readBy': List<String>.from(message['message']?['readBy'] ?? [message['senderId']]),
    };
    _messageController?.add({
      'type': 'NEW_MESSAGE',
      'chatId': message['chatId'],
      'message': newMessage,
    });

    final chatId = message['chatId'] as String?;
    if (chatId != null && _userId != null) {
      final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
      final isOwnMessage = message['senderId'] == _userId;
      if (index != -1) {
        _conversations[index] = {
          ..._conversations[index],
          'lastMessage': {
            'content': newMessage['content'],
            'type': newMessage['type'],
            'createdAt': newMessage['createdAt'],
            'senderId': newMessage['sender']['id'],
            'readBy': newMessage['readBy'],
          },
          'unreadCount': isOwnMessage
              ? _conversations[index]['unreadCount'] as int? ?? 0
              : (_conversations[index]['unreadCount'] as int? ?? 0) + 1,
          'updatedAt': DateTime.now().toIso8601String(),
        };
      } else {
        _conversations.add({
          'chatId': chatId,
          'participants': [
            {
              'id': message['senderId'] ?? '',
              'firstName': (message['senderName'] as String?)?.split(' ')[0] ?? 'Inconnu',
              'lastName': (message['senderName'] as String?)!.split(' ').length > 1
                  ? (message['senderName'] as String).split(' ')[1]
                  : '',
              'profilePicture': message['sender']?['profilePicture'] as String?,
            },
          ],
          'lastMessage': {
            'content': newMessage['content'],
            'type': newMessage['type'],
            'createdAt': newMessage['createdAt'],
            'senderId': newMessage['sender']['id'],
            'readBy': newMessage['readBy'],
          },
          'unreadCount': isOwnMessage ? 0 : 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      _conversationController?.add({
        'type': 'CONVERSATIONS_LIST',
        'conversations': _conversations,
      });
      // Refresh from backend
      getConversations(_userId!);
    }
  }

  void _handleMessageRead(Map<String, dynamic> message) {
    _messageController?.add({
      'type': 'MESSAGE_READ',
      'chatId': message['chatId'],
      'messageId': message['messageId'],
      'readBy': List<String>.from(message['readBy'] ?? []),
    });
    final index = _conversations.indexWhere((c) => c['chatId'] == message['chatId']);
    if (index != -1) {
      final lastMessage = _conversations[index]['lastMessage'] as Map<String, dynamic>?;
      if (lastMessage != null) {
        _conversations[index] = {
          ..._conversations[index],
          'lastMessage': {
            ...lastMessage,
            'readBy': List<String>.from(message['readBy'] ?? []),
          },
          'unreadCount': 0,
        };
      }
      _conversationController?.add({
        'type': 'CONVERSATIONS_LIST',
        'conversations': _conversations,
      });
    }
    if (_userId != null) {
      getConversations(_userId!);
    }
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
    String? clientId;
    String? veterinaireId;

    if (userRole == 'client') {
      clientId = senderId;
      veterinaireId = targetId;
    } else if (userRole == 'veterinaire' || userRole == 'secretary') {
      // For vets/secretaries, the target is always the client
      clientId = targetId;
      veterinaireId = senderId; // The vet is sending the message
    } else {
      throw Exception('Invalid user role: $userRole');
    }

    _channel!.sink.add(jsonEncode({
      'type': 'SEND_MESSAGE',
      'senderId': senderId,
      'veterinaireId': veterinaireId,
      'content': content,
      'contentType': contentType,
      'clientId': clientId, // Explicitly send clientId
    }));
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'MARK_AS_READ',
      'chatId': chatId,
      'userId': userId,
    }));
  }

  bool _isParticipating(List<Map<String, dynamic>> participants, String userId, String vetId) {
    // Backend includes only other participants (excludes userId) and may include secretaries
    // Check if vetId is in participants, since userId is not included in CONVERSATIONS_LIST response
    final participantIds = participants.map((p) => p['id'] as String).toSet();
    return participantIds.contains(vetId);
  }

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userId,
    required String vetId,
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');

    try {
      print('Checking cached conversations for user $userId and vet $vetId');
      print('Cached conversation IDs: ${_conversations.map((c) => c['chatId']).toList()}');

      // First check existing conversations
      for (var convo in _conversations) {
        final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
        if (_isParticipating(participants, userId, vetId)) {
          print('Found existing conversation in cache: ${convo['chatId']}');
          return _formatConversationResponse(convo);
        }
      }

      print('No existing conversation found. Initiating new conversation for user $userId with vet $vetId');

      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription? subscription;
      String? newChatId;

      // Set timeout
      final timeoutTimer = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          print('Conversation creation timed out');
          completer.completeError(Exception('Failed to find new conversation'));
          subscription?.cancel();
        }
      });

      subscription = onConversations().listen((data) async {
        if (data['type'] == 'CONVERSATIONS_LIST') {
          final conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
          print('Received CONVERSATIONS_LIST: ${conversations.map((c) => c['chatId']).toList()}');

          for (var convo in conversations) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            if (_isParticipating(participants, userId, vetId)) {
              print('Found new conversation: ${convo['chatId']}');
              completer.complete(_formatConversationResponse(convo));
              timeoutTimer.cancel();
              subscription?.cancel();
              return;
            }
          }
        } else if (data['type'] == 'MESSAGE_SENT' && data['chatId'] != null) {
          newChatId = data['chatId'] as String?;
          print('Received MESSAGE_SENT with chatId: $newChatId');
          if (newChatId != null) {
            // Immediately confirm conversation using chatId from MESSAGE_SENT
            await getConversations(userId);
            final convo = _conversations.firstWhere(
                  (c) => c['chatId'] == newChatId,
              orElse: () => <String, dynamic>{},
            );
            if (convo.isNotEmpty) {
              print('Confirmed new conversation via MESSAGE_SENT: $newChatId');
              completer.complete(_formatConversationResponse(convo));
              timeoutTimer.cancel();
              subscription?.cancel();
            }
          }
        }
      }, onError: (error) {
        print('Conversation stream error: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
          timeoutTimer.cancel();
        }
      });

      // Send the initial message to create the conversation only if no existing conversation was found
      await sendMessage(
        senderId: userId,
        targetId: vetId,
        content: 'Conversation started',
      );

      return await completer.future;
    } catch (e) {
      print('Error getting or creating conversation: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _formatConversationResponse(Map<String, dynamic> convo) {
    return {
      'chatId': convo['chatId'] as String,
      'participants': List<Map<String, dynamic>>.from(convo['participants'] ?? []),
      'unreadCount': convo['unreadCount'] ?? 0,
    };
  }

  void dispose() {
    _messageController?.close();
    _conversationController?.close();
    disconnect();
  }
}