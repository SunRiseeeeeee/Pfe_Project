import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter/foundation.dart';
import '../models/token_storage.dart';

// =========================
// 📦 Notification Model
// =========================
class Notification {
  final String id;
  final String userId;
  final String appointmentId;
  final String message;
  final bool read;
  final String createdAt;
  final String? updatedAt;

  Notification({
    required this.id,
    required this.userId,
    required this.appointmentId,
    required this.message,
    required this.read,
    required this.createdAt,
    this.updatedAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      appointmentId: json['appointmentId'] as String,
      message: json['message'] as String,
      read: json['read'] as bool,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'appointmentId': appointmentId,
      'message': message,
      'read': read,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

// =========================
// 📦 Appointment Model
// =========================
class Appointment {
  final String id;
  final String date;
  final String type;
  final String caseDescription;

  Appointment({
    required this.id,
    required this.date,
    required this.type,
    required this.caseDescription,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['_id'] as String,
      date: json['date'] as String,
      type: json['type'] as String,
      caseDescription: json['caseDescription'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'date': date,
      'type': type,
      'caseDescription': caseDescription,
    };
  }
}

// =========================
// 📦 API Response Models
// =========================
class NotificationsResponse {
  final bool success;
  final List<Notification> notifications;
  final int count;
  final int unreadCount;
  final String? message;

  NotificationsResponse({
    required this.success,
    required this.notifications,
    required this.count,
    required this.unreadCount,
    this.message,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      success: json['success'] as bool,
      notifications: (json['notifications'] as List)
          .map((item) => Notification.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
      unreadCount: json['unreadCount'] as int,
      message: json['message'] as String?,
    );
  }
}

class MarkReadResponse {
  final bool success;
  final Notification notification;
  final String message;

  MarkReadResponse({
    required this.success,
    required this.notification,
    required this.message,
  });

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] as bool,
      notification: Notification.fromJson(json['notification'] as Map<String, dynamic>),
      message: json['message'] as String,
    );
  }
}

// =========================
// 🔌 Notification Service
// =========================
class NotificationService {
  final Dio _dio;
  socket_io.Socket? _socket;

  static const List<String> _socketUrls = [
    'http://localhost:3000',
    'http://192.168.1.16:3001',
    'http://192.168.1.16:3000',
  ];

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.16:3000',
  );

  NotificationService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: _baseUrl));

  Future<bool> connectSocket(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found in storage');
      return false;
    }

    for (final url in _socketUrls) {
      try {
        _socket = socket_io.io(
          url,
          <String, dynamic>{
            'transports': ['websocket', 'polling'],
            'path': '/socket.io',
            'reconnection': true,
            'reconnectionAttempts': 5,
            'reconnectionDelay': 1000,
            'auth': {'token': token},
          },
        );

        _socket?.onConnect((_) {
          if (kDebugMode) print('✅ Socket connected for user $userId to $url');
        });

        _socket?.onDisconnect((_) {
          if (kDebugMode) print('❌ Socket disconnected for user $userId');
        });

        _socket?.onConnectError((error) {
          if (kDebugMode) print('[Socket] Connection error for $url: $error');
        });

        _socket?.on('error', (data) {
          if (kDebugMode) print('[Socket] Received error: $data');
        });

        await Future.any([
          Future.delayed(const Duration(seconds: 10)),
          Future(() async {
            while (_socket?.connected != true) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }),
        ]);

        if (_socket?.connected == true) {
          return true;
        } else {
          if (kDebugMode) print('Failed to connect to $url: Timeout');
          _socket?.dispose();
          _socket = null;
        }
      } catch (e) {
        if (kDebugMode) print('Failed to connect to $url: $e');
        _socket?.dispose();
        _socket = null;
      }
    }

    return false;
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (kDebugMode) print('🔌 Socket disconnected');
  }

  void onNewNotification(void Function(Notification) callback) {
    _socket?.on('newNotification', (data) {
      if (kDebugMode) print('[Socket] Received newNotification: $data');
      try {
        callback(Notification.fromJson(data as Map<String, dynamic>));
      } catch (e) {
        if (kDebugMode) print('[Socket] Error parsing notification: $e');
      }
    });
  }

  void onAnyEvent(void Function(String, dynamic) callback) {
    _socket?.onAny((event, data) {
      if (kDebugMode) print('[Socket] Received event: $event, data: $data');
      callback(event, data);
    });
  }
  Future<List<Notification>> fetchUnreadNotifications(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token for fetchUnreadNotifications');
      throw Exception('No JWT token found');
    }

    try {
      final response = await _dio.get(
        '/notifications/$userId/unread',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> list = response.data['notifications'];
      return list.map((e) => Notification.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('[fetchUnreadNotifications] Error: $e');
      throw Exception('Failed to fetch unread notifications');
    }
  }

  /// ✅ Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found for markAllAsRead');
      throw Exception('No JWT token found');
    }

    try {
      await _dio.patch(
        '/notifications/$userId/read-all',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (kDebugMode) print('✅ All notifications marked as read');
    } catch (e) {
      if (kDebugMode) print('[markAllAsRead] Error: $e');
      throw Exception('Failed to mark all notifications as read');
    }
  }

  /// ❌ Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found for deleteNotification');
      throw Exception('No JWT token found');
    }

    try {
      await _dio.delete(
        '/notifications/$notificationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (kDebugMode) print('🗑️ Notification $notificationId deleted');
    } catch (e) {
      if (kDebugMode) print('[deleteNotification] Error: $e');
      throw Exception('Failed to delete notification');
    }
  }

  /// 🧹 Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found for deleteAllNotifications');
      throw Exception('No JWT token found');
    }

    try {
      await _dio.delete(
        '/notifications/user/$userId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (kDebugMode) print('🧹 All notifications for user $userId deleted');
    } catch (e) {
      if (kDebugMode) print('[deleteAllNotifications] Error: $e');
      throw Exception('Failed to delete all notifications');
    }
  }


  /// 🧪 Send a test notification via HTTP (NOT socket emit)
  Future<void> sendTestNotification(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) return;

    try {
      await _dio.post(
        '/notifications/test',
        data: {'userId': userId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (kDebugMode) {
        print('📤 Sent test notification request to backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending test notification: $e');
      }
    }
  }

  Future<NotificationsResponse> getUserNotifications(String userId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found for fetching notifications');
      throw Exception('No JWT token found');
    }

    try {
      final response = await _dio.get(
        '/notifications/$userId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return NotificationsResponse.fromJson(response.data);
    } catch (error) {
      if (kDebugMode) {
        print('[getUserNotifications] Error: $error');
      }
      throw Exception('Failed to fetch notifications');
    }
  }

  Future<MarkReadResponse> markNotificationAsRead(String notificationId) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('No JWT token found for marking notification as read');
      throw Exception('No JWT token found');
    }

    try {
      final response = await _dio.patch(
        '/notifications/$notificationId/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return MarkReadResponse.fromJson(response.data);
    } catch (error) {
      if (kDebugMode) {
        print('[markNotificationAsRead] Error: $error');
      }
      throw Exception('Failed to mark notification as read');
    }
  }
}

// Singleton instance
final notificationService = NotificationService();
