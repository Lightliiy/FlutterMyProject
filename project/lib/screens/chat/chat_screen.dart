import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String counselorId;
  final String chatId;
  final String counselorName;

  const ChatScreen({
    Key? key,
    required this.counselorId,
    required this.chatId,
    required this.counselorName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentId = authProvider.user?.studentId;

    if (studentId != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final chat = await chatProvider.getOrCreateChat(
        widget.counselorId,
        studentId,
        widget.counselorName,
      );
      if (chat != null) {
        _chatId = chat.id;
        await chatProvider.loadMessages(chat.id, studentId);

        if (!mounted) return;
        setState(() {});
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && _chatId != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        Provider.of<ChatProvider>(context, listen: false)
            .sendMessage(
              _chatId!,
              text,
              user.studentId,
              user.name,
              widget.counselorId,
              user.studentId,
              widget.counselorName,
            )
            .then((_) {
          _messageController.clear();
          _scrollToBottom();
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final fileName = result.files.first.name;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;
        if (user != null) {
          await Provider.of<ChatProvider>(context, listen: false).sendMessage(
            widget.chatId,
            '📎 $fileName',
            user.studentId,
            user.name,
            widget.counselorId,
            user.studentId,
            widget.counselorName,
          );
          _scrollToBottom();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error sending file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteChat() async {
    if (_chatId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.deleteChat(_chatId!);
        // Clear UI state after deletion
        setState(() {
          _chatId = null;
        });
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
        Navigator.of(context).pop(); // Optionally close the chat screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChatInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteChat,
            tooltip: 'Delete Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatProvider.messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                final List<ChatMessage> messages = List.from(chatProvider.messages)
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      showAvatarAndName: true,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _pickAndSendFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _sendMessage,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chat Info"),
        content: const Text("This chat is between you and the counselor."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatarAndName;

  const _MessageBubble({
    required this.message,
    this.showAvatarAndName = true,
  });

  @override
  Widget build(BuildContext context) {
    final senderInitial = message.senderName.isNotEmpty
        ? message.senderName[0].toUpperCase()
        : '?';
    final senderDisplayName = message.senderName.isNotEmpty
        ? message.senderName
        : 'Unknown';

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatarAndName ? 12 : 4),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe && showAvatarAndName)
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                senderInitial,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (!message.isMe && !showAvatarAndName)
            const SizedBox(width: 40),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isMe
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                      message.isMe || showAvatarAndName ? 18 : 6),
                  bottomRight: Radius.circular(
                      message.isMe ? (showAvatarAndName ? 18 : 6) : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isMe && showAvatarAndName)
                    Text(
                      senderDisplayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  Text(
                    message.message,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
