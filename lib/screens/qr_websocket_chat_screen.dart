import 'package:flutter/material.dart';
import '../services/qr_websocket_service.dart';
import '../services/user_session_service.dart';
import '../models/message.dart';
import 'home_screen.dart';
import 'dart:async';

class QRWebSocketChatScreen extends StatefulWidget {
  final String remoteUserName;
  final String remoteUserPhone;
  final String sessionId;
  final String serverInfo;

  const QRWebSocketChatScreen({
    super.key,
    required this.remoteUserName,
    required this.remoteUserPhone,
    required this.sessionId,
    required this.serverInfo,
  });

  @override
  State<QRWebSocketChatScreen> createState() => _QRWebSocketChatScreenState();
}

class _QRWebSocketChatScreenState extends State<QRWebSocketChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final QRWebSocketService _webSocketService = QRWebSocketService();
  final UserSessionService _sessionService = UserSessionService();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  String? _currentUserPhone;
  String? _currentUserName;
  bool _isConnected = true;
  bool _isTyping = false;
  bool _remoteUserTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Get current user info
    _currentUserPhone = await _sessionService.getCurrentUser();

    // Listen for new messages
    _messageSubscription = _webSocketService.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    });

    // Listen for connection events
    _connectionSubscription = _webSocketService.connectionStream.listen((
      event,
    ) {
      switch (event['type']) {
        case 'disconnected':
          setState(() {
            _isConnected = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WebSocket connection lost'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
        case 'typing_indicator':
          setState(() {
            _remoteUserTyping = event['isTyping'] ?? false;
          });
          break;
      }
    });

    setState(() {});
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || !_isConnected) return;

    _webSocketService.sendChatMessage(
      content: content,
      senderName: _currentUserName ?? 'You',
      senderPhone: _currentUserPhone ?? '',
    );

    _messageController.clear();
    _stopTyping();
    _scrollToBottom();
  }

  void _startTyping() {
    if (!_isTyping && _isConnected) {
      _isTyping = true;
      _webSocketService.sendTypingIndicator(
        isTyping: true,
        userName: _currentUserName ?? 'User',
      );
    }
  }

  void _stopTyping() {
    if (_isTyping && _isConnected) {
      _isTyping = false;
      _webSocketService.sendTypingIndicator(
        isTyping: false,
        userName: _currentUserName ?? 'User',
      );
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

  void _handleBackButton() {
    // Disconnect WebSocket and navigate to HomeScreen (Chats tab)
    _webSocketService.disconnect();

    // Navigate to HomeScreen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackButton();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E3A5F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2A4A6B),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackButton(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.remoteUserName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 12,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showConnectionInfo,
            ),
          ],
        ),
        body: Column(
          children: [
            // Connection status banner
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.withValues(alpha: 0.2),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Connection lost. Messages may not be delivered.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi, size: 64, color: Colors.white30),
                          SizedBox(height: 16),
                          Text(
                            'WebSocket Chat Connected!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start messaging in real-time',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_remoteUserTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _remoteUserTyping) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),

            // Message input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4A6B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        enabled: _isConnected,
                        decoration: InputDecoration(
                          hintText: _isConnected
                              ? 'Type a message...'
                              : 'Offline',
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (text) {
                          if (text.isNotEmpty) {
                            _startTyping();
                          } else {
                            _stopTyping();
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? const Color(0xFF00A8FF)
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isConnected ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // End of Scaffold
    ); // End of WillPopScope
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.isFromMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4CAF50),
              child: Text(
                message.senderPhone?.isNotEmpty == true
                    ? message.senderPhone![0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF00A8FF)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderPhone != null)
                    Text(
                      message.senderPhone!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.wifi, size: 10, color: Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF00A8FF),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF4CAF50),
            child: Text(
              widget.remoteUserName.isNotEmpty
                  ? widget.remoteUserName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'typing...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A4A6B),
        title: const Text(
          'WebSocket Connection Info',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Contact', widget.remoteUserName),
            _buildInfoRow('Phone', widget.remoteUserPhone),
            _buildInfoRow('Session ID', widget.sessionId),
            _buildInfoRow('Server', widget.serverInfo),
            _buildInfoRow('Status', _isConnected ? 'Online' : 'Offline'),
            const SizedBox(height: 16),
            const Text(
              'This is a real-time WebSocket chat session. Messages are sent instantly when both devices are connected.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
