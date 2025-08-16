// lib/screens/chat/chat_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'video_call_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  StreamSubscription<QuerySnapshot>? _callSubscription;
  bool _isHandlingCall = false;

  @override
  void initState() {
    super.initState();
    _initializeCallListener();
    _loadChats();
  }

  void _initializeCallListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
    });
  }

  Future<void> _loadChats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Provider.of<ChatProvider>(context, listen: false).loadChats(authProvider);
  }

  void _listenForIncomingCalls() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentStudentId = authProvider.user?.id;

    if (currentStudentId == null) {
      print("DEBUG: Current user ID is null, cannot listen for calls.");
      return;
    }

    print("DEBUG: Listening for incoming calls for studentId: $currentStudentId");

    _callSubscription?.cancel();
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentStudentId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added && !_isHandlingCall) {
          _isHandlingCall = true;
          final callData = change.doc.data() as Map<String, dynamic>;
          final callId = change.doc.id;
          final callerId = callData['callerId'] as String;
          final callerName = callData['callerName'] as String? ?? 'Counselor';

          print("DEBUG: Incoming call detected! Caller: $callerName, Call ID: $callId");
          
          final accepted = await _showIncomingCallDialog(callerName);
          
          if (accepted) {
            await FirebaseFirestore.instance
                .collection('calls')
                .doc(callId)
                .update({
              'status': 'accepted',
              'answeredAt': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    callId: callId,
                    isCaller: false,
                    currentUserId: currentStudentId,
                    otherUserId: callerId,
                  ),
                ),
              );
            }
          } else {
            await FirebaseFirestore.instance
                .collection('calls')
                .doc(callId)
                .update({
              'status': 'declined',
              'declinedAt': FieldValue.serverTimestamp(),
            });
          }
          
          _isHandlingCall = false;
        }
      }
    }, onError: (error) {
      print("DEBUG: Error listening for calls: $error");
      _isHandlingCall = false;
    });
  }

  Future<bool> _showIncomingCallDialog(String callerName) async {
    final completer = Completer<bool>();
    
    if (!mounted) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Video Call'),
        content: Text('Call from $callerName'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              completer.complete(false);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              completer.complete(true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    return completer.future;
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _isHandlingCall = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.id; // Use the 'id' field

    print("DEBUG: The user ID for the chat query is: $currentUserId");

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
        ),
        body: const Center(child: Text('Please log in to see your chats.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('studentId', isEqualTo: currentUserId) // Match the Firestore field
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active chats.'));
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatData = chatDocs[index].data() as Map<String, dynamic>;
              final chatId = chatDocs[index].id;
              final counselorName = chatData['counselorName'] as String? ?? 'Counselor';
              final lastMessage = chatData['lastMessage'] as String? ?? 'No messages yet';
              final unreadCount = chatData['unreadCount'] as int? ?? 0;
              final counselorId = chatData['counselorId'] as String;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(counselorName[0]),
                  ),
                  title: Text(counselorName),
                  subtitle: Text(lastMessage),
                  trailing: unreadCount > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          counselorId: counselorId,
                          chatId: chatId,
                          counselorName: counselorName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}