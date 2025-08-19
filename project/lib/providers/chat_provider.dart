import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

class Chat {
  final String id;
  final String counselorId;
  final String counselorName;
  final String studentId;
  final String name;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Chat({
    required this.id,
    required this.counselorId,
    required this.counselorName,
    required this.studentId,
    required this.name,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'].toString(),
      counselorId: json['counselorId'].toString(),
      counselorName: json['counselorName'] ?? 'Counselor',
      studentId: json['studentId'].toString(),
      name: json['counselorName'] ?? 'Chat',
      createdAt: DateTime.parse(json['createdAt']),
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isMe;
  final String? reply;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.reply,
  });

  factory ChatMessage.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String currentUserId) {
    final data = doc.data()!;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'].toString(),
      senderName: data['senderName'] ?? '',
      message: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isMe: data['senderId'].toString() == currentUserId,
      reply: data['reply'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': message,
      'timestamp': timestamp,
      'reply': reply,
    };
  }
}

class ChatProvider with ChangeNotifier {
  final String? userId;
  static const String _baseUrl = 'http://10.8.5.77:8080/api/chats';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Chat> _chats = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _messageSubscription;

  List<Chat> get chats => _chats;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider({this.userId});

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadChats(AuthProvider authProvider) async {
    _isLoading = true;
    notifyListeners();

    try {
      final studentId = authProvider.user?.studentId;
      if (studentId == null) {
        throw Exception('No logged in studentId');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/assigned?studentId=$studentId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> body = json.decode(response.body);
        _chats = body.map((e) => Chat.fromJson(e)).toList();
      } else {
        _chats = [];
        throw Exception(
            'Failed to load assigned counselor chats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading assigned counselor chats: $e');
      _chats = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$chatId'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _chats.removeWhere((chat) => chat.id == chatId);
        _messages.clear();
        notifyListeners();
      } else {
        throw Exception('Failed to delete chat: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }

  Future<String?> getOrCreateChat(String counselorId, String studentId, String counselorName) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/between?counselorId=$counselorId&studentId=$studentId&counselorName=$counselorName'),
      );
      if (response.statusCode == 200) {
        final chat = Chat.fromJson(json.decode(response.body));
        return chat.id;
      }
    } catch (e) {
      print('Error getting or creating chat: $e');
    }
    return null;
  }

  void listenToMessages(String chatId, String currentUserId) {
    _messageSubscription?.cancel();
    _messages.clear();
    _isLoading = true;
    notifyListeners();

    _messageSubscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc, currentUserId))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print('Error listening to messages: $error');
      _messages = [];
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> sendMessage(
    String chatId,
    String message,
    String currentUserId,
    String currentUserName,
  ) async {
    final newMessage = ChatMessage(
      id: '',
      senderId: currentUserId,
      senderName: currentUserName,
      message: message,
      timestamp: DateTime.now(),
      isMe: true,
    );

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(newMessage.toFirestore());
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}