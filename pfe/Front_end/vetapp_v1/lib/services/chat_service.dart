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
      clientId = targetId;
      veterinaireId = senderId;
    } else {
      throw Exception('Invalid user role: $userRole');
    }

    _channel!.sink.add(jsonEncode({
      'type': 'SEND_MESSAGE',
      'senderId': senderId,
      'veterinaireId': veterinaireId,
      'content': content,
      'contentType': contentType,
      'clientId': clientId,
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

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userId,
    required String vetId,
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    try {
      print('Checking cached conversations for user $userId and vet $vetId');
      print('Cached conversation IDs: ${_conversations.map((c) => c['chatId']).toList()}');

      for (var convo in _conversations) {
        final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
        final participantIds = participants.map((p) => p['id'] as String).toSet();
        if (participantIds.contains(userId) && participantIds.contains(vetId)) {
          print('Found existing conversation in cache: ${convo['chatId']}');
          return {
            'chatId': convo['chatId'] as String,
            'participants': participants,
            'unreadCount': convo['unreadCount'] ?? 0,
          };
        }
      }

      print('No existing conversation found. Creating new conversation for user $userId with vet $vetId');

      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription? subscription;

      subscription = onConversations().listen((data) {
        if (data['type'] == 'CONVERSATIONS_LIST') {
          final conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
          print('Received CONVERSATIONS_LIST: ${conversations.map((c) => c['chatId']).toList()}');
          for (var convo in conversations) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['id'] as String).toSet();
            if (participantIds.contains(userId) && participantIds.contains(vetId)) {
              if (_pendingChatId == null || convo['chatId'] == _pendingChatId) {
                print('Found new conversation: ${convo['chatId']}');
                completer.complete({
                  'chatId': convo['chatId'] as String,
                  'participants': participants,
                  'unreadCount': convo['unreadCount'] ?? 0,
                });
                subscription?.cancel();
                return;
              }
            }
          }
        }
      }, onError: (error) {
        print('Conversation stream error: $error');
      });

      await sendMessage(
        senderId: userId,
        targetId: vetId,
        content: 'Conversation started',
      );

      await getConversations(userId);

      Future.delayed(const Duration(seconds: 40), () {
        if (!completer.isCompleted) {
          print('Conversation creation timed out');
          completer.completeError(Exception('Failed to find new conversation'));
          subscription?.cancel();
        }
      });

      return await completer.future;
    } catch (e) {
      print('Error getting or creating conversation: $e');
      rethrow;
    }
  }

  void dispose() {
    _messageController?.close();
    _conversationController?.close();
    disconnect();
  }
}