import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type;
  final String? reply;
  final String? userId; 

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.reply,
    this.userId, 
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? reply,
    String? userId, 
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      reply: reply ?? this.reply,
      userId: userId ?? this.userId,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['read'] ?? false,
      type: json['type'],
      reply: json['reply'],
      userId: json['userId'], 
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'type': type,
    'reply': reply,
    'userId': userId, 
  };
}

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final String backendBaseUrl;
  String? _userId;

  NotificationProvider({
    required this.backendBaseUrl,
    String? userId, // userId can be passed during initialization
  }) : _userId = userId;

  String? get userId => _userId;
  //  UPDATED: Set a new user ID and refresh notifications
  set userId(String? value) {
    if (_userId != value) {
      _userId = value;
      // Fetch new notifications if the user changes
      if (_userId != null) {
        fetchNotifications();
      } else {
        // Clear notifications if the user logs out
        _notifications.clear();
        notifyListeners();
      }
    }
  }

  Future<void> fetchNotifications() async {
    if (userId == null || userId!.isEmpty) {
      print('Skipping fetchNotifications: userId is null or empty.');
      return;
    }

    try {
      final url = '$backendBaseUrl/notifications/user?userId=${Uri.encodeQueryComponent(userId!)}';
      print('Fetching notifications for userId: "$userId"');
      final response = await http.get(Uri.parse(url));
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data.map((json) => NotificationItem.fromJson(json)).toList();
        notifyListeners();
      } else {
        print('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  /// Deletes a notification from backend and removes it locally
  Future<void> deleteNotification(String notificationId) async {
    final url = Uri.parse('$backendBaseUrl/notifications/$notificationId');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200 || response.statusCode == 204) {
        _notifications.removeWhere((n) => n.id == notificationId);
        notifyListeners();
        print('Notification $notificationId deleted successfully.');
      } else {
        print('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // ✅ UPDATED: The sendNotification method now correctly handles a notification with a userId.
  Future<bool> sendNotification(NotificationItem notification) async {
    // Ensure the notification has a userId before sending
    if (notification.userId == null || notification.userId!.isEmpty) {
      print('Error: Notification must have a userId to be sent.');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notification.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Add the notification to the local list if it's for the current user
        if (notification.userId == _userId) {
          addNotification(notification);
        }
        return true;
      } else {
        print('Failed to send notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (unreadCount > 0) {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    }
  }
  

  /// Creates a cancellation notification and sends it to the specified student
  Future<void> addBookingCancellationNotification({
    required String studentId,
    required String bookingId,
    required String counselorName,
    required DateTime scheduledDate,
  }) async {
    final cancellationNotification = NotificationItem(
      id: bookingId,
      userId: studentId, 
      title: 'Booking Cancelled',
      message: 'Your session with $counselorName on ${scheduledDate.day}/${scheduledDate.month} has been cancelled.',
      timestamp: DateTime.now(),
      type: 'booking_cancellation',
      isRead: false,
    );
    await sendNotification(cancellationNotification);
  }

  /// Creates a confirmation notification and sends it to the specified student
  Future<void> addBookingNotification({
    required String studentId,
    required String bookingId,
    required String counselorName,
    required DateTime scheduledDate,
  }) async {
    final newNotification = NotificationItem(
      id: bookingId,
      userId: studentId, 
      title: 'Booking Confirmed',
      message: 'Your session with $counselorName on ${scheduledDate.day}/${scheduledDate.month} is confirmed.',
      timestamp: DateTime.now(),
      type: 'booking',
      isRead: false,
    );
    await sendNotification(newNotification);
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Send a reply for a notification
  Future<bool> sendReply(String notificationId, String replyMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/notifications/$notificationId/reply'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reply': replyMessage}),
      );

      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(reply: replyMessage);
          notifyListeners();
        }
        return true;
      } else {
        print('Failed to send reply: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending reply: $e');
      return false;
    }
  }
}