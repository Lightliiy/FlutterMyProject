import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class WebSocketService {
  StompClient? _client;

  void connect(String userId, void Function(Map<String, dynamic>) onMessageReceived) {
_client = StompClient(
  config: StompConfig.SockJS(
    url: 'http://10.192.163.181:8080/ws-chat',
    onConnect: (StompFrame frame) {
      print('WebSocket connected');

      _client!.subscribe(
        destination: '/topic/messages/$userId',
        callback: (frame) {
          final Map<String, dynamic> message = json.decode(frame.body!);
          onMessageReceived(message);
        },
      );
    },
    onWebSocketError: (error) => print('WebSocket error: $error'),
    onDisconnect: (_) => print('WebSocket disconnected'),
  ),
);


    _client!.activate();
  }

  void sendMessage(String chatId, Map<String, dynamic> message) {
    _client?.send(
      destination: '/app/chat/$chatId',
      body: json.encode(message),
    );
  }

  void disconnect() {
    _client?.deactivate();
  }
}

final webSocketService = WebSocketService();
