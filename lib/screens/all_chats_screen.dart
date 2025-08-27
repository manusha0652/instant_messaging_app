import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'simplified_websocket_chat_screen.dart';
import 'qr_scanner_screen.dart';

class AllChatsScreen extends StatefulWidget {
  const AllChatsScreen({super.key});

  @override
  State<AllChatsScreen> createState() => _AllChatsScreenState();
}

class _AllChatsScreenState extends State<AllChatsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  List<Map<String, dynamic>> _chatSessions = [];
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadAllChats();
  }

  Future<void> _loadAllChats() async {
    setState(() => _isLoading = true);

    try {
      // Get current user
      final String? currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUser = await _databaseService.getUserByPhone(currentUserPhone);
      if (_currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all chat sessions for this user
      final sessions = await _databaseService.getChatSessions(
        _currentUser!.id!,
      );

      List<Map<String, dynamic>> chatList = [];

      for (ChatSession session in sessions) {
        // Get the last message for each session
        final messages = await _databaseService.getMessagesForSession(
          session.id!,
        );
        Message? lastMessage;
        if (messages.isNotEmpty) {
          lastMessage = messages.last;
        }

        chatList.add({
          'session': session,
          'lastMessage': lastMessage,
          'otherUserName': session.contactName,
          'otherUserPhone': session.contactPhone,
          'unreadCount': session.unreadCount,
        });
      }

      // Sort by last message time (most recent first)
      chatList.sort((a, b) {
        final aTime =
            a['lastMessage']?.timestamp ??
            a['session'].lastMessageTime ??
            DateTime.now();
        final bTime =
            b['lastMessage']?.timestamp ??
            b['session'].lastMessageTime ??
            DateTime.now();
        return bTime.compareTo(aTime);
      });

      setState(() {
        _chatSessions = chatList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chats: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today - show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildChatCard(Map<String, dynamic> chatData) {
    final ChatSession session = chatData['session'];
    final Message? lastMessage = chatData['lastMessage'];
    final String otherUserName = chatData['otherUserName'];
    final String otherUserPhone = chatData['otherUserPhone'];
    final int unreadCount = chatData['unreadCount'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF2A4A6B),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF00A8FF),
          child: Text(
            otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          otherUserName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (otherUserPhone.isNotEmpty)
              Text(
                otherUserPhone,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              lastMessage?.content ?? 'No messages yet',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lastMessage != null
                  ? _formatTime(lastMessage.timestamp)
                  : (session.lastMessageTime != null
                        ? _formatTime(session.lastMessageTime!)
                        : 'No messages'),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () => _openChat(session, otherUserName, otherUserPhone),
      ),
    );
  }

  void _openChat(
    ChatSession session,
    String otherUserName,
    String otherUserPhone,
  ) {
    if (_currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimplifiedWebSocketChatScreen(
          currentUser: _currentUser!,
          remoteUserName: otherUserName,
          remoteUserPhone: otherUserPhone,
          sessionId: session.id.toString(),
          isHost: false, // This will be determined by the chat screen
        ),
      ),
    ).then((_) {
      // Refresh the chat list when returning from chat
      _loadAllChats();
    });
  }

  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    ).then((_) {
      // Refresh the chat list when returning from QR scanner
      _loadAllChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4A6B),
        foregroundColor: Colors.white,
        title: const Text(
          'ChatLink',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _startNewChat,
            tooltip: 'Start New Chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A8FF)),
            )
          : _chatSessions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAllChats,
              color: const Color(0xFF00A8FF),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _chatSessions.length,
                itemBuilder: (context, index) {
                  return _buildChatCard(_chatSessions[index]);
                },
              ),
            ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _startNewChat,
      //   backgroundColor: const Color(0xFF00A8FF),
      //   child: const Icon(
      //     Icons.qr_code_scanner,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a QR code to start chatting',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startNewChat,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
