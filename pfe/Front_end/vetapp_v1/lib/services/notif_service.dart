import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/token_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final String _baseUrl = 'http://192.168.1.16:3000/api';
  final String _socketUrl = 'http://192.168.1.16:3000/socket.io';
  IO.Socket? _socket;
  String? _userId;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _pollingTimer;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  int _notificationId = 0;
  int _unreadNotificationCount = 0;
  bool _shouldDisconnect = false; // New flag to control disconnection
  final StreamController<int> _unreadCountStreamController = StreamController<int>.broadcast();

  Stream<int> get unreadNotificationCountStream => _unreadCountStreamController.stream;

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        print('NotificationService: Notification tapped: ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: backgroundHandler,
    );

    const androidChannel = AndroidNotificationChannel(
      'notification_channel',
      'Notifications',
      description: 'Appointment notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _showLocalNotification(String title, String body, {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'notification_channel',
      'Notifications',
      channelDescription: 'Appointment notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
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
    await _localNotificationsPlugin.show(
      _notificationId++,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    print('NotificationService: Displayed notification ID: ${_notificationId - 1}, Title: $title, Body: $body');
  }

  void resetOnLogout() {
    print('NotificationService: Resetting for logout');
    _shouldDisconnect = true;
    disconnectSocket();
    _userId = null;
    _unreadNotificationCount = 0;
    _unreadCountStreamController.add(0);
  }

  Future<void> connectToSocket() async {
    await _initLocalNotifications();
    _userId = await TokenStorage.getUserId();
    final token = await TokenStorage.getToken();

    if (_userId == null || token == null) {
      print('NotificationService: User ID or token not found');
      throw Exception('User ID or token not found');
    }

    if (_socket != null && _socket!.connected) {
      print('NotificationService: Socket already connected for userId: $_userId');
      return;
    }

    print('NotificationService: Attempting to connect to $_socketUrl for userId: $_userId (Attempt ${_retryCount + 1}/$_maxRetries)');
    _socket = IO.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'timeout': 5000,
      'query': {'userId': _userId},
      'auth': {'token': token},
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('NotificationService: Connected to socket as $_userId');
      _retryCount = 0;
      _socket!.emit('join', _userId);
      _stopPolling();
      _fetchUnreadCount();
    });

    _socket!.onConnectError((data) {
      print('NotificationService: Connection error for userId: $_userId: $data');
      if (data.toString().contains('timeout')) {
        print('NotificationService: Connection timeout detected');
      }
      _retryCount++;
      if (_retryCount < _maxRetries) {
        print('NotificationService: Retrying in 5 seconds...');
        Future.delayed(const Duration(seconds: 5), connectToSocket);
      } else {
        print('NotificationService: Failed after $_maxRetries attempts: $data');
        _startPolling();
      }
    });

    _socket!.onDisconnect((_) {
      print('NotificationService: Disconnected from socket for userId: $_userId');
      _retryCount = 0;
      if (!_shouldDisconnect) {
        print('NotificationService: Attempting to reconnect for userId: $_userId');
        Future.delayed(const Duration(seconds: 5), connectToSocket);
      } else {
        _stopPolling();
      }
    });

    _socket!.onError((data) => print('NotificationService: Socket error for userId: $_userId: $data'));
  }

  void _startPolling() {
    if (_pollingTimer != null || _shouldDisconnect) return;
    print('NotificationService: Starting HTTP polling for userId: $_userId');
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final notifications = await fetchNotifications();
        if (notifications.isNotEmpty) {
          final latest = notifications.first;
          if (!(latest['read'] ?? true)) {
            await _showLocalNotification(
              'New Notification',
              latest['message'] ?? 'No message',
              payload: json.encode(latest),
            );
            _fetchUnreadCount();
          }
        }
      } catch (e) {
        print('NotificationService: Polling error for userId: $_userId: $e');
      }
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      print('NotificationService: Stopping HTTP polling for userId: $_userId');
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  void disconnectSocket() {
    if (!_shouldDisconnect) {
      print('NotificationService: Unauthorized disconnect attempt blocked for userId: $_userId');
      return;
    }
    _stopPolling();
    _socket?.disconnect();
    _socket = null;
    _retryCount = 0;
    print('NotificationService: Socket disconnected for userId: $_userId');
  }

  void onNotificationReceived(Function(Map<String, dynamic>) callback) {
    _socket?.on('newNotification', (data) {
      print('NotificationService: New notification for userId: $_userId: $data');
      final notification = Map<String, dynamic>.from(data);
      callback(notification);
      if (!(notification['read'] ?? false)) {
        _unreadNotificationCount++;
        _unreadCountStreamController.add(_unreadNotificationCount);
      }
      _showLocalNotification(
        'New Notification',
        notification['message'] ?? 'No message',
        payload: json.encode(notification),
      );
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final token = await TokenStorage.getToken();
      final userId = _userId ?? await TokenStorage.getUserId();

      if (token == null || userId == null) {
        throw Exception('Token or User ID not found');
      }

      print('NotificationService: Fetching notifications for userId: $userId');
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('NotificationService: Fetched notifications for userId: $userId: ${data['notifications']}');
        _updateUnreadCount(data['notifications']);
        return List<Map<String, dynamic>>.from(data['notifications']);
      } else {
        print('NotificationService: Failed to fetch notifications for userId: $userId: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch: ${response.statusCode}');
      }
    } catch (e) {
      print('NotificationService: Error fetching notifications for userId: $_userId: $e');
      throw e;
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final notifications = await fetchNotifications();
      _updateUnreadCount(notifications);
      return _unreadNotificationCount;
    } catch (e) {
      print('NotificationService: Error fetching unread count: $e');
      return _unreadNotificationCount;
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await getUnreadNotificationCount();
      _unreadNotificationCount = count;
      _unreadCountStreamController.add(_unreadNotificationCount);
      print('NotificationService: Fetched unread count: $_unreadNotificationCount');
    } catch (e) {
      print('NotificationService: Error in _fetchUnreadCount: $e');
    }
  }

  void _updateUnreadCount(List<dynamic> notifications) {
    _unreadNotificationCount = notifications.where((n) => !(n['read'] ?? true)).length;
    _unreadCountStreamController.add(_unreadNotificationCount);
    print('NotificationService: Updated unread count: $_unreadNotificationCount');
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('Token not found');

      final response = await http.patch(
        Uri.parse('$_baseUrl/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('NotificationService: Notification $notificationId marked as read for userId: $_userId');
        _unreadNotificationCount = _unreadNotificationCount > 0 ? _unreadNotificationCount - 1 : 0;
        _unreadCountStreamController.add(_unreadNotificationCount);
        return true;
      } else {
        print('NotificationService: Failed to mark as read for userId: $_userId: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('NotificationService: Error marking as read for userId: $_userId: $e');
      return false;
    }
  }

  void close() {
    if (_shouldDisconnect) {
      _unreadCountStreamController.close();
      print('NotificationService: Closing stream controller for userId: $_userId');
    } else {
      print('NotificationService: Preserving stream controller for userId: $_userId');
    }
  }
}

@pragma('vm:entry-point')
void backgroundHandler(NotificationResponse response) {
  print('NotificationService: Background notification tapped: ${response.payload}');
}