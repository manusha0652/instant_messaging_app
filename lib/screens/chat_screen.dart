import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/real_time_messaging_service.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final ChatSession chatSession;

  const ChatScreen({
    super.key,
    required this.chatSession,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final RealTimeMessagingService _messagingService = RealTimeMessagingService();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isContactTyping = false;
  bool _isContactOnline = false;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    _initializeRealTimeMessaging();
  }

  /// Initialize real-time messaging
  Future<void> _initializeRealTimeMessaging() async {
    try {
      // Initialize the real-time messaging service
      final initialized = await _messagingService.initialize();
      
      if (initialized) {
        print('Real-time messaging initialized successfully');
        
        // Join chat room for this contact
        _messagingService.joinChatRoom(widget.chatSession.contactPhone);
        
        // Subscribe to real-time updates
        _subscribeToRealTimeUpdates();
        
        // Check contact's online status
        _checkContactStatus();
      } else {
        print('Failed to initialize real-time messaging');
        // Fall back to offline mode
      }
    } catch (e) {
      print('Error initializing real-time messaging: $e');
    }
  }

  /// Check contact's online status
  Future<void> _checkContactStatus() async {
    try {
      final isOnline = await _messagingService.isContactOnline(widget.chatSession.contactPhone);
      final lastSeen = await _messagingService.getContactLastSeen(widget.chatSession.contactPhone);
      
      setState(() {
        _isContactOnline = isOnline;
      });
    } catch (e) {
      print('Error checking contact status: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesData = await _databaseService.getMessagesForSession(
        widget.chatSession.id!,
      );

      setState(() {
        // messagesData is already a List<Message>, no need to convert
        _messages = messagesData;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load messages: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _databaseService.markMessagesAsRead(widget.chatSession.id!);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Create temporary message for immediate UI update
      final tempMessage = Message(
        sessionId: widget.chatSession.id!,
        content: messageText,
        isFromMe: true,
        timestamp: DateTime.now(),
        isSent: false, // Will be updated when actually sent
      );

      setState(() {
        _messages.add(tempMessage);
        _messageController.clear();
      });

      _scrollToBottom();

      // Save message to database
      final messageId = await _databaseService.insertMessage(
        sessionId: widget.chatSession.id!,
        content: messageText,
        isFromMe: true,
      );

      // Update the temporary message with the actual ID
      final savedMessage = tempMessage.copyWith(
        id: messageId,
        isSent: true,
      );

      setState(() {
        _messages[_messages.length - 1] = savedMessage;
      });

      // In a real implementation, you would send this message via WebSocket/Socket.IO
      // For simulation, we'll add an auto-reply after a short delay
      _simulateReply();

    } catch (e) {
      _showError('Failed to send message: $e');
      // Remove the temporary message on error
      setState(() {
        _messages.removeLast();
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // Simulate receiving a reply (for demo purposes)
  Future<void> _simulateReply() async {
    await Future.delayed(const Duration(seconds: 2));

    final replies = [
      'Hello! How are you?',
      'Thanks for your message!',
      'That sounds great!',
      'Sure, let me know when you\'re free.',
      'I\'ll get back to you soon.',
      'Nice to hear from you!',
    ];

    final reply = replies[DateTime.now().millisecond % replies.length];

    try {
      final messageId = await _databaseService.insertMessage(
        sessionId: widget.chatSession.id!,
        content: reply,
        isFromMe: false,
      );

      final replyMessage = Message(
        id: messageId,
        sessionId: widget.chatSession.id!,
        content: reply,
        isFromMe: false,
        timestamp: DateTime.now(),
        isRead: true,
        isDelivered: true,
        isSent: true,
      );

      setState(() {
        _messages.add(replyMessage);
      });

      _scrollToBottom();
    } catch (e) {
      print('Error adding simulated reply: $e');
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _subscribeToRealTimeUpdates() {
    _messageSubscription = _messagingService.messageStream.listen((message) {
      // Handle incoming message
      _handleIncomingMessage(message);
    });

    _typingSubscription = _messagingService.typingStatusStream.listen((status) {
      // Handle typing status - status is a Map<String, dynamic>
      final contactPhone = status['phone'] as String?;
      final isTyping = status['isTyping'] as bool?;

      if (contactPhone == widget.chatSession.contactPhone) {
        setState(() {
          _isContactTyping = isTyping ?? false;
        });
      }
    });
  }

  void _handleIncomingMessage(Message message) {
    // Add the new message to the list and update the UI
    setState(() {
      _messages.add(message);
    });

    // Scroll to the bottom to show the new message
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4A6B),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            // Contact Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A8FF),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Contact Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatSession.contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Online', // In real implementation, check online status
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Video call functionality
            },
            icon: const Icon(Icons.videocam, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              // Voice call functionality
            },
            icon: const Icon(Icons.call, color: Colors.white),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF2A4A6B),
            onSelected: (value) {
              switch (value) {
                case 'view_contact':
                  // View contact info
                  break;
                case 'clear_chat':
                  // Clear chat history
                  break;
                case 'block_contact':
                  // Block contact
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_contact',
                child: Text('View Contact', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: Text('Clear Chat', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'block_contact',
                child: Text('Block Contact', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A8FF)),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white.withOpacity(0.3),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation with ${widget.chatSession.contactName}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
          ),

          // Typing Indicator (placeholder for real implementation)
          if (_isContactTyping) _buildTypingIndicator(),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isFromMe = message.isFromMe;
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            // Contact avatar for received messages
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A8FF).withOpacity(0.7),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromMe
                    ? const Color(0xFF00A8FF)
                    : const Color(0xFF2A4A6B),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      if (isFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all
                              : message.isDelivered
                                  ? Icons.done_all
                                  : message.isSent
                                      ? Icons.done
                                      : Icons.access_time,
                          color: message.isRead
                              ? Colors.blue[300]
                              : Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isFromMe) ...[
            const SizedBox(width: 8),
            // User avatar for sent messages
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00A8FF),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A4A6B),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: () {
              // Show attachment options
              _showAttachmentOptions();
            },
            icon: const Icon(
              Icons.attach_file,
              color: Colors.white70,
            ),
          ),

          // Message input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00A8FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A4A6B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Attachments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle gallery selection
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle camera
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'File',
                  onTap: () {
                    Navigator.pop(context);
                    // Handle file selection
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF00A8FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Contact avatar
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00A8FF).withOpacity(0.7),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          // Typing indicator dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildDot(),
                const SizedBox(width: 4),
                _buildDot(),
                const SizedBox(width: 4),
                _buildDot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }
}
