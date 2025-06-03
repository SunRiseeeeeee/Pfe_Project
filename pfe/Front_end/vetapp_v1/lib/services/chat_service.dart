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
              _messageController?.add(message);
              break;
            case 'NEW_MESSAGE':
              final newMessage = {
                '_id': message['timestamp'].toString(),
                'sender': {
                  'id': message['senderId'],
                  'firstName': message['senderName'].split(' ')[0],
                  'lastName': message['senderName'].split(' ').length > 1
                      ? message['senderName'].split(' ')[1]
                      : '',
                },
                'content': message['content'],
                'type': message['contentType'] ?? 'text',
                'createdAt': DateTime.now().toIso8601String(),
                'readBy': [message['senderId']],
              };
              _messageController?.add({
                'type': 'NEW_MESSAGE',
                'chatId': message['chatId'],
                'message': newMessage,
              });

              final chatId = message['chatId'] as String?;
              if (chatId != null) {
                final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
                if (index != -1) {
                  _conversations[index] = {
                    ..._conversations[index],
                    'lastMessage': newMessage,
                    'unreadCount': message['senderId'] == _userId
                        ? _conversations[index]['unreadCount']
                        : (_conversations[index]['unreadCount'] as int? ?? 0) + 1,
                  };
                } else {
                  _conversations.add({
                    'chatId': chatId,
                    'participants': [
                      {
                        'id': message['senderId'],
                        'firstName': message['senderName'].split(' ')[0],
                        'lastName': message['senderName'].split(' ').length > 1
                            ? message['senderName'].split(' ')[1]
                            : '',
                        'profilePicture': null,
                      },
                    ],
                    'lastMessage': newMessage,
                    'unreadCount': message['senderId'] == _userId ? 0 : 1,
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
                'readBy': message['readBy'],
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

  Future<void> getConversations(String userId) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'type': 'GET_CONVERSATIONS',
      'userId': userId,
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
    required String veterinaireId,
    required String content,
    String contentType = 'text',
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _lastSentContent = content;
    _channel!.sink.add(jsonEncode({
      'type': 'SEND_MESSAGE',
      'senderId': senderId,
      'veterinaireId': veterinaireId,
      'content': content,
      'contentType': contentType,
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

      const maxFetchRetries = 3;
      for (int attempt = 1; attempt <= maxFetchRetries; attempt++) {
        print('Fetching conversations (attempt $attempt/$maxFetchRetries) for user $userId');
        await getConversations(userId);
        await Future.delayed(Duration(seconds: 2));
        print('Conversations after fetch: ${_conversations.length} conversations');
        print('Fetched conversation IDs: ${_conversations.map((c) => c['chatId']).toList()}');
        for (var convo in _conversations) {
          final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
          final participantIds = participants.map((p) => p['id'] as String).toSet();
          if (participantIds.contains(userId) && participantIds.contains(vetId)) {
            print('Found existing conversation after fetch: ${convo['chatId']}');
            return {
              'chatId': convo['chatId'] as String,
              'participants': participants,
              'unreadCount': convo['unreadCount'] ?? 0,
            };
          }
        }
      }

      print('No existing conversation found. Creating new conversation for user $userId with vet $vetId');
      await sendMessage(
        senderId: userId,
        veterinaireId: vetId,
        content: 'Conversation started',
      );

      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription? subscription;
      StreamSubscription? messageSubscription;
      int retryCount = 0;
      const maxRetries = 5;

      // Listen for SEND_MESSAGE success
      messageSubscription = _channel!.stream.listen((data) async {
        final message = jsonDecode(data as String) as Map<String, dynamic>;
        if (message['status'] == 'success' && message['chatId'] != null && message['message']?.startsWith('Message envoyé au chat')) {
          final chatId = message['chatId'] as String;
          print('Received SEND_MESSAGE success for chat: $chatId');
          await getConversations(userId);
          final convo = _conversations.firstWhere(
                (c) => c['chatId'] == chatId,
            orElse: () => {},
          );
          if (convo.isNotEmpty) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['id'] as String).toSet();
            if (participantIds.contains(userId) && participantIds.contains(vetId)) {
              print('Found new conversation via SEND_MESSAGE: $chatId');
              completer.complete({
                'chatId': chatId,
                'participants': participants,
                'unreadCount': convo['unreadCount'] ?? 0,
              });
              subscription?.cancel();
              messageSubscription?.cancel();
            }
          }
        }
      });

      // Listen for CONVERSATIONS_LIST
      subscription = onConversations().listen((data) async {
        if (data['type'] == 'CONVERSATIONS_LIST') {
          final conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
          print('Received CONVERSATIONS_LIST during creation: ${conversations.map((c) => c['chatId']).toList()}');
          for (var convo in conversations) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['id'] as String).toSet();
            if (participantIds.contains(userId) && participantIds.contains(vetId)) {
              print('Found new conversation: ${convo['chatId']}');
              completer.complete({
                'chatId': convo['chatId'] as String,
                'participants': participants,
                'unreadCount': convo['unreadCount'] ?? 0,
              });
              subscription?.cancel();
              messageSubscription?.cancel();
              return;
            }
          }

          if (retryCount < maxRetries) {
            retryCount++;
            print('New conversation not found, retrying ($retryCount/$maxRetries)');
            await getConversations(userId);
          } else {
            print('Max retries reached for new conversation');
            completer.completeError(Exception('Failed to find new conversation'));
            subscription?.cancel();
            messageSubscription?.cancel();
          }
        }
      });

      Future.delayed(Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          print('Conversation creation timed out');
          completer.completeError(Exception('Failed to find new conversation'));
          subscription?.cancel();
          messageSubscription?.cancel();
        }
      });

      final result = await completer.future;
      subscription?.cancel();
      messageSubscription?.cancel();
      return result;
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