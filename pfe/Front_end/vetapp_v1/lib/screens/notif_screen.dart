import 'package:flutter/material.dart';
import '../services/notif_service.dart';

class NotifScreen extends StatefulWidget {
  const NotifScreen({super.key});

  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _fetchNotifications();
  }

  Future<void> _initializeSocket() async {
    try {
      await NotificationService().connectToSocket();
      NotificationService().onNotificationReceived((notification) {
        print('NotifScreen: New notification received: $notification');
        setState(() {
          _notifications.insert(0, notification);
          print('NotifScreen: Updated notifications: $_notifications');
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to notification server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final fetched = await NotificationService().fetchNotifications();
      setState(() {
        _notifications = fetched;
        _isLoading = false;
        _errorMessage = null;
        print('NotifScreen: Fetched notifications: $_notifications');
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching notifications: $e';
      });
    }
  }

  @override
  void dispose() {
    NotificationService().disconnectSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchNotifications,
            tooltip: 'Refresh Notifications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeSocket();
                _fetchNotifications();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _notifications.isEmpty
          ? const Center(
        child: Text(
          'No new appointment notifications.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            final message = notification['message'] ?? 'No message';
            final createdAt = notification['createdAt'] ?? DateTime.now().toString();
            final isRead = notification['read'] ?? false;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              color: isRead ? Colors.white : Colors.blue[50],
              child: ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : Colors.blue,
                ),
                title: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Received: ${DateTime.parse(createdAt).toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                onTap: () async {
                  if (!isRead) {
                    final success = await NotificationService().markAsRead(notification['id']);
                    if (success) {
                      setState(() {
                        _notifications[index]['read'] = true;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to mark notification as read')),
                      );
                    }
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}