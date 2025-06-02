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

          if (message['status'] == 'success') {
            switch (message['type']) {
              case 'CONVERSATIONS_LIST':
                _conversations = List<Map<String, dynamic>>.from(message['conversations'] ?? []);
                print('Updated conversations list: ${_conversations.length} conversations');
                _conversationController?.add(message);
                break;
              case 'MESSAGES_LIST':
                _messageController?.add(message);
                break;
              case 'NEW_MESSAGE':
                final newMessage = {
                  '_id': message['timestamp'].toString(),
                  'sender': {
                    '_id': message['senderId'],
                    'firstName': message['senderName'].split(' ')[0],
                    'lastName': message['senderName'].split(' ').length > 1
                        ? message['senderName'].split(' ')[1]
                        : '',
                  },
                  'content': message['content'],
                  'createdAt': DateTime.now().toIso8601String(),
                  'readBy': [],
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
                          '_id': message['senderId'],
                          'firstName': message['senderName'].split(' ')[0],
                          'lastName': message['senderName'].split(' ').length > 1
                              ? message['senderName'].split(' ')[1]
                              : '',
                          'role': 'client',
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
                break;
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
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _lastSentContent = content;
    _channel!.sink.add(jsonEncode({
      'type': 'SEND_MESSAGE',
      'senderId': senderId,
      'veterinaireId': veterinaireId,
      'content': content,
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
    final index = _conversations.indexWhere((c) => c['chatId'] == chatId);
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
  }

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String userId,
    required String vetId,
  }) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    try {
      // Check cached conversations
      print('Checking cached conversations for user $userId and vet $vetId');
      for (var convo in _conversations) {
        final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
        final participantIds = participants.map((p) => p['_id'] as String).toSet();
        if (participantIds.contains(userId) && participantIds.contains(vetId)) {
          print('Found existing conversation in cache: ${convo['chatId']}');
          return {
            'chatId': convo['chatId'] as String,
            'participants': participants,
          };
        }
      }

      // Fetch fresh conversations with retries
      const maxFetchRetries = 2;
      for (int attempt = 1; attempt <= maxFetchRetries; attempt++) {
        print('Fetching conversations (attempt $attempt/$maxFetchRetries) for user $userId');
        await getConversations(userId);
        await Future.delayed(Duration(seconds: 1)); // Wait for CONVERSATIONS_LIST
        print('Conversations after fetch: ${_conversations.length} conversations');
        for (var convo in _conversations) {
          final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
          final participantIds = participants.map((p) => p['_id'] as String).toSet();
          if (participantIds.contains(userId) && participantIds.contains(vetId)) {
            print('Found existing conversation after fetch: ${convo['chatId']}');
            return {
              'chatId': convo['chatId'] as String,
              'participants': participants,
            };
          }
        }
      }

      // Create new conversation
      print('No existing conversation found. Creating new conversation for user $userId with vet $vetId');
      await sendMessage(
        senderId: userId,
        veterinaireId: vetId,
        content: 'Conversation started',
      );

      // Wait for CONVERSATIONS_LIST or NEW_MESSAGE
      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription? subscription;
      StreamSubscription? messageSubscription;
      int retryCount = 0;
      const maxRetries = 3;

      // Listen for NEW_MESSAGE
      messageSubscription = onNewMessage().listen((data) async {
        if (data['type'] == 'NEW_MESSAGE' && data['chatId'] != null) {
          final chatId = data['chatId'] as String;
          await getConversations(userId);
          final convo = _conversations.firstWhere(
                (c) => c['chatId'] == chatId,
            orElse: () => {},
          );
          if (convo.isNotEmpty) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['_id'] as String).toSet();
            if (participantIds.contains(userId) && participantIds.contains(vetId)) {
              print('Found new conversation via NEW_MESSAGE: $chatId');
              completer.complete({
                'chatId': chatId,
                'participants': participants,
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
          for (var convo in conversations) {
            final participants = List<Map<String, dynamic>>.from(convo['participants'] ?? []);
            final participantIds = participants.map((p) => p['_id'] as String).toSet();
            if (participantIds.contains(userId) && participantIds.contains(vetId)) {
              print('Found new conversation: ${convo['chatId']}');
              completer.complete({
                'chatId': convo['chatId'] as String,
                'participants': participants,
              });
              subscription?.cancel();
              messageSubscription?.cancel();
              return;
            }
          }

          // Retry if not found
          if (retryCount < maxRetries) {
            retryCount++;
            print('New conversation not found, retrying ($retryCount/$maxRetries)');
            await getConversations(userId);
          }
        }
      });

      // Timeout after 10 seconds
      Future.delayed(Duration(seconds: 10), () {
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