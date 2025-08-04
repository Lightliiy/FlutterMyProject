import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart'; // Adjust path if needed
class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
   WidgetsBinding.instance.addPostFrameCallback((_) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  Provider.of<ChatProvider>(context, listen: false).loadChats(authProvider);
});

  }

  @override
Widget build(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final currentStudentId = authProvider.user?.studentId;

  return Scaffold(
    appBar: AppBar(
      title: const Text('Chats'),
    ),
    body: Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final filteredChats = chatProvider.chats.where((chat) =>
            chat.studentId == currentStudentId).toList();

        if (filteredChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No chats yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Start a conversation with your counselor',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  chat.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  chat.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Text(
                  chat.lastMessageTime != null
                      ? DateFormat.Hm().format(chat.lastMessageTime!)
                      : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: chat,
                  );
                },
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        _showStartChatDialog(context);
      },
      child: const Icon(Icons.chat),
    ),
  );
}
  void _showStartChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: const Text('Choose how you\'d like to start chatting:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
            child: const Text('With Counselor'),
          ),
        ],
      ),
    );
  }
}
