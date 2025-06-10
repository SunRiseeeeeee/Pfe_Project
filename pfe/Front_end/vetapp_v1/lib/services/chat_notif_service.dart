import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import 'chat_service.dart'; // Import your ChatService
// Import your ChatScreen
import 'package:shared_preferences/shared_preferences.dart'; // For storing userId

class ChatNotifService {
  final ChatService _chatService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  String? _currentUserId;
  BuildContext? _context; // To navigate on notification tap

  ChatNotifService(this._chatService);

  Future<void> initialize(BuildContext context) async {
    _context = context;

    // Load current userId from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId'); // Adjust key based on your app's storage

    if (_currentUserId == null) {
      print('ChatNotifService: No userId found, notifications disabled');
      return;
    }

    // Initialize notification settings
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          final payload = jsonDecode(response.payload!);
          final chatId = payload['chatId'] as String?;
          final vetId = payload['vetId'] as String?;
          final participants = List<Map<String, dynamic>>.from(payload['participants'] ?? []);

          if (_context != null && chatId != null && vetId != null) {
            Navigator.push(
              _context!,
              MaterialPageRoute<void>(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  veterinaireId: vetId,
                  participants: participants,
                  vetId: '',
                  recipientId: null,
                  recipientName: '',
                ),
              ),
            );
          }
        }
      },
    );

    // Request permissions for iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to WebSocket messages from ChatService
    _chatService.onConversations().listen((data) {
      if (data['type'] == 'NEW_MESSAGE' && data['notification'] != null) {
        final notification = data['notification'] as Map<String, dynamic>;
        final senderId = notification['senderId'] as String?;
        final chatId = notification['chatId'] as String?;
        final title = notification['title'] as String?;
        final body = notification['body'] as String?;
        final participants = List<Map<String, dynamic>>.from(data['message']['sender'] != null
            ? [
          {
            'id': data['message']['sender']['_id'],
            'firstName': data['message']['sender']['firstName'],
            'lastName': data['message']['sender']['lastName'],
            'profilePicture': data['message']['sender']['profilePicture']?.replaceAll('localhost', '192.168.1.16'),
            'role': data['message']['sender']['role'],
          }
        ]
            : []);

        // Skip notifications for messages sent by the current user
        if (senderId == _currentUserId) {
          print('Skipping notification for message sent by current user: $_currentUserId');
          return;
        }

        if (chatId != null && title != null && body != null) {
          _showNotification(
            chatId: chatId,
            vetId: data['message']['sender']['_id'] as String,
            title: title,
            body: body,
            participants: participants,
          );
        }
      }
    });
  }

  Future<void> _showNotification({
    required String chatId,
    required String vetId,
    required String title,
    required String body,
    required List<Map<String, dynamic>> participants,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create payload for navigation
    final payload = jsonEncode({
      'chatId': chatId,
      'vetId': vetId,
      'participants': participants,
    });

    await _notificationsPlugin.show(
      chatId.hashCode, // Unique ID for notification
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    print('Displayed notification for chat $chatId: $title - $body');
  }

  void dispose() {
    _context = null;
  }
}