import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/user_session_service.dart';
import '../chat_screen.dart';
import '../../models/chat_session.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> with AutomaticKeepAliveClientMixin {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  List<Map<String, dynamic>> _chatSessions = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  Future<void> _loadChatSessions() async {
    try {
      // Get current user first
      final String? currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final currentUser = await _databaseService.getUserByPhone(currentUserPhone);
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load chat sessions for current user
      final sessions = await _databaseService.getUserChatSessions(currentUser.id!);
      setState(() {
        _chatSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat sessions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshChats() async {
    setState(() {
      _isLoading = true;
    });
    await _loadChatSessions();
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      // Today - show time
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day
      const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekDays[messageTime.weekday - 1];
    } else {
      // Older - show date
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshChats,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A8FF)),
              ),
            )
          : _chatSessions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _refreshChats,
                  color: const Color(0xFF00A8FF),
                  backgroundColor: const Color(0xFF2A4A6B),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatSessions.length,
                    itemBuilder: (context, index) {
                      final session = _chatSessions[index];
                      return _buildChatTile(session);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Colors.white.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            'No chats yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scan a QR code to start chatting with friends',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to QR scanner
              Navigator.pushNamed(context, '/qr_scanner');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text(
              'Scan QR Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> session) {
    final contactName = session['contactName'] ?? 'Unknown';
    final contactPhone = session['contactPhone'] ?? '';
    final lastMessage = session['lastMessage'] ?? 'No messages yet';
    final lastMessageTime = session['lastMessageTime'];
    final unreadCount = session['unreadCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A4A6B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF00A8FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A8FF).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          contactName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          lastMessage,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(lastMessageTime),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF00A8FF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () => _openChat(session),
      ),
    );
  }

  void _openChat(Map<String, dynamic> sessionData) {
    // Import the ChatSession model and ChatScreen
    final chatSession = ChatSession.fromMap(sessionData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatSession: chatSession),
      ),
    ).then((_) {
      // Refresh chat list when returning from chat
      _refreshChats();
    });
  }
}
