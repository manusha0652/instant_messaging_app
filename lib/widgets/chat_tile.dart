import 'package:flutter/material.dart';
import '../models/chat_session_model.dart';
import '../themes/app_theme.dart';
import '../utils/helpers.dart';

class ChatTile extends StatelessWidget {
  final ChatSessionModel chatSession;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chatSession,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: chatSession.peerAvatar != null
              ? ClipOval(
                  child: Image.asset(
                    chatSession.peerAvatar!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialsAvatar();
                    },
                  ),
                )
              : _buildInitialsAvatar(),
        ),
        title: Text(
          chatSession.peerName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: chatSession.lastMessage != null
            ? Text(
                chatSession.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            : Text(
                'Tap to start chatting',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              chatSession.timeAgoString,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (chatSession.isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Text(
      Helpers.getInitials(chatSession.peerName),
      style: const TextStyle(
        color: AppColors.textLight,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }
}
