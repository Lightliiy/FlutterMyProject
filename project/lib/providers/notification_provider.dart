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

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'type': type,
      };
}

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final String backendBaseUrl;
  final String userId;

  NotificationProvider({required this.backendBaseUrl, required this.userId});

  /// Fetch notifications from backend
  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse('$backendBaseUrl/notifications/user/$userId'));
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

  /// Send a new notification to backend
  Future<bool> sendNotification(NotificationItem notification) async {
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notification.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        addNotification(notification);
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

  

  /// Add to local list only
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

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Add a booking notification and send to backend
  Future<void> addBookingNotification(String bookingId, String counselorName, DateTime scheduledDate) async {
    final newNotification = NotificationItem(
      id: bookingId,
      title: 'Booking Confirmed',
      message: 'Your session with $counselorName on ${scheduledDate.day}/${scheduledDate.month} is confirmed.',
      timestamp: DateTime.now(),
      type: 'booking',
      isRead: false,
    );

    await sendNotification(newNotification);
  }

  Future<void> initialize() async {
    await fetchNotifications();
  }
}

