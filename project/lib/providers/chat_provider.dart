import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isMe;
  final String? attachmentUrl;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.attachmentUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isMe: json['isMe'] ?? false,
      attachmentUrl: json['attachmentUrl'],
    );
  }
}

class ChatRoom {
  final String id;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final String? counselorId;

  ChatRoom({
    required this.id,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.counselorId,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      isGroup: json['isGroup'] ?? false,
      counselorId: json['counselorId'],
    );
  }
}

class ChatProvider with ChangeNotifier {
  static const String _baseUrl = 'http://10.8.5.237:8080'; // Your backend URL

  List<ChatRoom> _chatRooms = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatRoom> get chatRooms => _chatRooms;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  // Load all chat rooms
  Future<void> loadChatRooms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/chatrooms'));

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        _chatRooms = body.map((e) => ChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load chat rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading chat rooms: $e');
      _chatRooms = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load messages for a specific chat room
  Future<void> loadMessages(String chatRoomId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/chatrooms/$chatRoomId/messages'));

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        _messages = body.map((e) => ChatMessage.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading messages: $e');
      _messages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send a message
  Future<void> sendMessage(String chatRoomId, String message) async {
    const String currentUserId = 'your_user_id'; // Replace with actual user ID
    const String currentUserName = 'You';         // Replace with actual user name

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUserId,
      senderName: currentUserName,
      message: message,
      timestamp: DateTime.now(),
      isMe: true,
    );

    // Optimistic UI update
    _messages.add(newMessage);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chatrooms/$chatRoomId/messages'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'senderId': currentUserId,
          'senderName': currentUserName,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        final sentMessage = ChatMessage.fromJson(json.decode(response.body));
        final index = _messages.indexWhere((msg) => msg.id == newMessage.id);
        if (index != -1) {
          _messages[index] = sentMessage;
        }
        _updateChatRoomLastMessage(chatRoomId, sentMessage.message, sentMessage.timestamp);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      _messages.remove(newMessage);
      print('Error sending message: $e');
    } finally {
      notifyListeners();
    }
  }

  // Create a new group chat
  Future<ChatRoom?> createGroupChat(String groupName, {List<String>? memberIds}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chatrooms'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': groupName,
          'isGroup': true,
          'memberIds': memberIds ?? [],
        }),
      );

      if (response.statusCode == 201) {
        final newRoom = ChatRoom.fromJson(json.decode(response.body));
        _chatRooms.add(newRoom);
        _chatRooms.sort((a, b) => (b.lastMessageTime ?? DateTime(0)).compareTo(a.lastMessageTime ?? DateTime(0)));
        return newRoom;
      } else {
        throw Exception('Failed to create group chat: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating group chat: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateChatRoomLastMessage(String chatRoomId, String lastMessage, DateTime timestamp) {
    final index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
    if (index != -1) {
      _chatRooms[index] = ChatRoom(
        id: _chatRooms[index].id,
        name: _chatRooms[index].name,
        lastMessage: lastMessage,
        lastMessageTime: timestamp,
        unreadCount: _chatRooms[index].unreadCount,
        isGroup: _chatRooms[index].isGroup,
        counselorId: _chatRooms[index].counselorId,
      );
      _chatRooms.sort((a, b) => (b.lastMessageTime ?? DateTime(0)).compareTo(a.lastMessageTime ?? DateTime(0)));
      notifyListeners();
    }
  }
}
