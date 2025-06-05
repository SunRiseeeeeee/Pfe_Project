import 'package:flutter/material.dart';
import '../services/notif_service.dart' as notif;

class NotifScreen extends StatefulWidget {
  final notif.NotificationService notificationService;
  final String? userId;

  const NotifScreen({
    super.key,
    required this.notificationService,
    required this.userId,
  });

  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  Map<String, notif.Notification> _unreadNotifications = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (widget.userId == null) return;

    try {
      final notifications =
      await widget.notificationService.fetchUnreadNotifications(widget.userId!);

      setState(() {
        _unreadNotifications = notifications as Map<String, notif.Notification>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching notifications: $e");
    }
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unreadNotifications.isEmpty
          ? const Center(
        child: Text(
          'No new appointment notifications.',
          style:
          TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _unreadNotifications.entries.map((entry) {
            final notification = entry.value;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications, color: Colors.blue),
                title: Text(
                  notification.message,
                  style: const TextStyle(fontFamily: 'Poppins'),
                ),
                subtitle: Text(
                  'Received: ${DateTime.parse(notification.createdAt).toLocal().toString().substring(0, 16)}',
                  style:
                  const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey),
                ),


              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
