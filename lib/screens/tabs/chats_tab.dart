import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../models/chat_session_model.dart';
import '../../widgets/chat_tile.dart';
import '../../themes/app_theme.dart';
import '../../utils/constants.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  List<ChatSessionModel> _chatSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  Future<void> _loadChatSessions() async {
    try {
      final sessions = await ChatService.instance.getChatSessions();
      setState(() {
        _chatSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createDemoChat() async {
    try {
      final session = await ChatService.instance.startChatSession(
        peerName: ChatService.instance.generateRandomPeerName(),
      );

      // Simulate receiving a message
      await ChatService.instance.simulateIncomingMessage(session.id!);

      _loadChatSessions();
    } catch (e) {
      // Handle error
    }
  }

  void _onChatTap(ChatSessionModel session) {
    // Navigate to chat screen
    Navigator.pushNamed(context, '/chat', arguments: session);
  }

  void _onChatLongPress(ChatSessionModel session) {
    _showChatOptions(session);
  }

  void _showChatOptions(ChatSessionModel session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                _deleteChat(session);
              },
            ),
            if (session.isActive)
              ListTile(
                leading: const Icon(
                  Icons.stop_circle,
                  color: AppColors.warning,
                ),
                title: const Text('End Session'),
                onTap: () {
                  Navigator.pop(context);
                  _endSession(session);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChat(ChatSessionModel session) async {
    try {
      await ChatService.instance.deleteChatSession(session.id!);
      _loadChatSessions();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _endSession(ChatSessionModel session) async {
    try {
      await ChatService.instance.endChatSession(session.id!);
      _loadChatSessions();
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatSessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadChatSessions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.smallPadding,
        ),
        itemCount: _chatSessions.length,
        itemBuilder: (context, index) {
          final session = _chatSessions[index];
          return ChatTile(
            chatSession: session,
            onTap: () => _onChatTap(session),
            onLongPress: () => _onChatLongPress(session),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start one by scanning a QR code or create a demo chat to test the app!',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createDemoChat,
              icon: const Icon(Icons.add_comment),
              label: const Text('Create Demo Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
