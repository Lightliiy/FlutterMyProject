import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

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
  final List<ChatMessage> messages;

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
    required this.messages,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    List<ChatMessage> parsedMessages = [];

    if (json['messages'] != null && json['messages'] is List) {
      parsedMessages = (json['messages'] as List)
          .map((e) => ChatMessage(
                id: e['id'].toString(),
                senderId: e['senderId'].toString(),
                senderName: e['senderName'] ?? '',
                message: e['content'] ?? '',
                timestamp: DateTime.parse(e['timestamp']),
                isMe: false,
              ))
          .toList();
    }

    ChatMessage? lastMsg = parsedMessages.isNotEmpty ? parsedMessages.last : null;

    return Chat(
      id: json['id'].toString(),
      counselorId: json['counselorId'].toString(),
      counselorName: json['counselorName']?.toString().isNotEmpty == true
          ? json['counselorName']
          : 'Counselor ${json['counselorId']}',
      studentId: json['studentId'].toString(),
      name: json['counselorName'] ?? 'Chat with ${json['studentId']}',
      createdAt: DateTime.parse(json['createdAt']),
      lastMessage: lastMsg?.message,
      lastMessageTime: lastMsg?.timestamp,
      unreadCount: json['unreadCount'] ?? 0,
      messages: parsedMessages,
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

  factory ChatMessage.fromJson(Map<String, dynamic> json, String currentUserId) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: json['senderName'] ?? '',
      message: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isMe: (json['senderId'] ?? '').toString() == currentUserId,
      reply: json['reply'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'reply': reply,
    };
  }
}

class ChatProvider with ChangeNotifier {
  final String? userId;
  static const String _baseUrl = 'http://10.132.251.181:8080/api/chats';

  List<Chat> _chats = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  StompClient? _stompClient;

  List<Chat> get chats => _chats;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider({this.userId}) {
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'http://10.132.251.181:8080/ws-chat',
        onConnect: _onStompConnected,
        onWebSocketError: (error) {
          print('WebSocket error: $error');
        },
        onDisconnect: (_) {
          print('WebSocket disconnected');
        },
      ),
    );
    _stompClient!.activate();
  }

  void _onStompConnected(StompFrame frame) {
    print('STOMP Connected');
    // Do not subscribe here directly since chatId is unknown
  }

  void subscribeToChatTopic(String chatId) {
    if (_stompClient?.connected != true) {
      print('WebSocket not connected. Cannot subscribe.');
      return;
    }

    _stompClient!.subscribe(
      destination: '/topic/chat/$chatId',
      callback: (frame) {
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          final newMessage = ChatMessage.fromJson(data, userId!);
          _messages.add(newMessage);
          notifyListeners();
        }
      },
    );

    print('Subscribed to /topic/chat/$chatId');
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
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
        if (_messages.isNotEmpty) {
          _messages.clear();
        }
        notifyListeners();
      } else {
        throw Exception('Failed to delete chat: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }

  Future<Chat?> getOrCreateChat(
      String counselorId, String studentId, String counselorName) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/between?counselorId=$counselorId&studentId=$studentId&counselorName=$counselorName'),
      );

      if (response.statusCode == 200) {
        final chat = Chat.fromJson(json.decode(response.body));

        // ✅ Subscribe to shared chatId topic
        subscribeToChatTopic(chat.id);

        return chat;
      }
    } catch (e) {
      print('Error getting or creating chat: $e');
    }
    return null;
  }

  Future<void> loadMessages(String chatId, String currentUserId) async {
    print("Loading messages for chatId=$chatId, userId=$currentUserId");
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/$chatId/messages'));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final rawMessages = jsonDecode(response.body) as List;
        _messages =
            rawMessages.map((json) => ChatMessage.fromJson(json, currentUserId)).toList();
        print('Loaded ${_messages.length} messages');
      } else {
        _messages = [];
        print('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading messages: $e');
      _messages = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    String chatId,
    String message,
    String currentUserId,
    String currentUserName,
    String counselorId,
    String studentId,
    String counselorName,
  ) async {
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUserId,
      senderName: currentUserName,
      message: message,
      timestamp: DateTime.now(),
      isMe: true,
    );

    _messages.add(newMessage);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$chatId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': currentUserId,
          'content': message,
          'counselorId': counselorId,
          'studentId': studentId,
          'counselorName': counselorName,
        }),
      );

      if (response.statusCode == 201) {
        final sentMessage =
            ChatMessage.fromJson(json.decode(response.body), currentUserId);
        final index = _messages.indexWhere((msg) => msg.id == newMessage.id);
        if (index != -1) _messages[index] = sentMessage;
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
    } finally {
      notifyListeners();
    }
  }
}
