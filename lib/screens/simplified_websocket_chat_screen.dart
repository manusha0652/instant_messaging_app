import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/qr_websocket_service.dart';
import '../services/database_service.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import 'home_screen.dart';
import 'dart:async';

class SimplifiedWebSocketChatScreen extends StatefulWidget {
  final User currentUser;
  final String remoteUserName;
  final String remoteUserPhone;
  final String sessionId;
  final bool isHost;
  final String? serverIp;
  final int? serverPort;

  const SimplifiedWebSocketChatScreen({
    super.key,
    required this.currentUser,
    required this.remoteUserName,
    required this.remoteUserPhone,
    required this.sessionId,
    required this.isHost,
    this.serverIp,
    this.serverPort,
  });

  @override
  State<SimplifiedWebSocketChatScreen> createState() =>
      _SimplifiedWebSocketChatScreenState();
}

class _SimplifiedWebSocketChatScreenState
    extends State<SimplifiedWebSocketChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _processedMessageIds = {}; // Track processed messages to prevent duplicates
  final ScrollController _scrollController = ScrollController();
  final QRWebSocketService _webSocketService = QRWebSocketService();
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  bool _isConnected = false;
  bool _isInitialized = false; // Prevent multiple initializations
  ChatSession? _currentChatSession;

  @override
  void initState() {
    super.initState();
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeChat();
    }
  }

  Future<void> _initializeChat() async {
    try {
      print('🚀 Initializing chat for ${widget.remoteUserName}');
      print('🔍 Chat Initialization Debug:');
      print('  - widget.serverIp: ${widget.serverIp} (${widget.serverIp.runtimeType})');
      print('  - widget.serverPort: ${widget.serverPort} (${widget.serverPort.runtimeType})');
      print('  - widget.isHost: ${widget.isHost}');
      print('  - widget.sessionId: ${widget.sessionId}');
      
      // Create or load existing chat session
      await _loadOrCreateChatSession();
      
      // Cancel any existing subscriptions to prevent duplicates
      await _messageSubscription?.cancel();
      await _connectionSubscription?.cancel();
      
      // Listen for incoming messages
      _messageSubscription = _webSocketService.messageStream.listen((message) {
        print('📥 Received message in chat screen: ${message.content} from ${message.senderPhone}');
        if (mounted) {
          // Only save messages from other users to database
          // Your own sent messages are already saved in _sendMessage()
          if (message.senderPhone != widget.currentUser.phone) {
            _saveMessageToDatabase(message);
          } else {
            print('📤 Skipping database save for own message: ${message.content}');
          }
          
          // Only add messages from other users to avoid duplicates
          // Your own sent messages are already added locally for instant feedback
          if (message.senderPhone != widget.currentUser.phone) {
            final messageId = '${message.content}_${message.timestamp.millisecondsSinceEpoch}';
            print('🔍 Checking message ID: $messageId');
            if (!_processedMessageIds.contains(messageId)) {
              print('✅ Adding new message from ${message.senderPhone}');
              _processedMessageIds.add(messageId);
              setState(() {
                _messages.add({
                  'id': messageId,
                  'sender': widget.remoteUserName,
                  'content': message.content,
                  'timestamp': message.timestamp.millisecondsSinceEpoch,
                  'isMe': false,
                });
              });
              _scrollToBottom();
            } else {
              print('⚠️ Duplicate message detected: $messageId');
            }
          } else {
            print('📤 Ignoring own message: ${message.content}');
          }
        }
      });

      // Listen for connection status
      _connectionSubscription = _webSocketService.connectionStream.listen((
        event,
      ) {
        print('📡 Connection event in chat: ${event['type']}');
        if (mounted) {
          setState(() {
            _isConnected = event['type'] == 'connection_established' ||
                event['type'] == 'client_connected' ||
                _webSocketService.isConnected;
          });
        }
      });

      // Initialize WebSocket service
      await _webSocketService.initialize();

      // Connect as client if not host and we have server details
      if (!widget.isHost &&
          widget.serverIp != null &&
          widget.serverPort != null) {
        print(
          '🔗 Connecting as client to ${widget.serverIp}:${widget.serverPort}',
        );
        
        final success = await _webSocketService.connectToServer(
          serverIP: widget.serverIp!,
          serverPort: widget.serverPort!,
          sessionId: widget.sessionId,
          userName: widget.currentUser.name,
          userPhone: widget.currentUser.phone,
        );
        print('Client connection result: $success');
      }

      // Set initial connection status
      setState(() => _isConnected = _webSocketService.isConnected);

      print('✅ Chat initialized. Connection status: $_isConnected');
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !_isConnected) return;

    try {
      print('📤 Sending message: $messageText');

      // Send via WebSocket
      await _webSocketService.sendChatMessage(
        content: messageText,
        senderName: widget.currentUser.name,
        senderPhone: widget.currentUser.phone,
      );

      // Save to database
      if (_currentChatSession?.id != null) {
        await _databaseService.insertMessage(
          sessionId: _currentChatSession!.id!,
          content: messageText,
          isFromMe: true,
          timestamp: DateTime.now(),
        );

        // Update chat session
        await _databaseService.updateChatSession(_currentChatSession!.copyWith(
          lastMessage: messageText,
          lastMessageTime: DateTime.now(),
        ));
      }

      // Add to local messages immediately for instant feedback
      final now = DateTime.now();
      final messageId = '${messageText}_${now.millisecondsSinceEpoch}';
      print('📤 Adding local message with ID: $messageId');
      
      if (!_processedMessageIds.contains(messageId)) {
        _processedMessageIds.add(messageId);
        setState(() {
          _messages.add({
            'id': messageId,
            'sender': widget.currentUser.name,
            'content': messageText,
            'timestamp': now.millisecondsSinceEpoch,
            'isMe': true,
          });
        });
        print('✅ Added sent message to UI');
      } else {
        print('⚠️ Duplicate sent message detected: $messageId');
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadOrCreateChatSession() async {
    try {
      // Check if session already exists
      _currentChatSession = await _databaseService.getChatSessionByUserAndPhone(
        widget.currentUser.id!,
        widget.remoteUserPhone,
      );

      if (_currentChatSession == null) {
        // Create new chat session using the correct method with userId and server details
        final sessionId = await _databaseService.createChatSessionForUser(
          userId: widget.currentUser.id!,
          contactName: widget.remoteUserName,
          contactPhone: widget.remoteUserPhone,
          serverIP: widget.serverIp,
          serverPort: widget.serverPort,
          sessionId: widget.sessionId,
        );
        
        // Get the created session
        _currentChatSession = await _databaseService.getChatSessionById(sessionId);
        print('✅ Created new chat session with ID: $sessionId');
        print('💾 Stored server details: ${widget.serverIp}:${widget.serverPort}');
      } else {
        print('✅ Loaded existing chat session: ${_currentChatSession!.id}');
        
        // Load existing messages
        await _loadChatHistory();
      }
    } catch (e) {
      print('Error loading chat session: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentChatSession?.id == null) return;

    try {
      print('📚 Loading chat history for session ${_currentChatSession!.id}');
      final messages = await _databaseService.getMessagesForSession(_currentChatSession!.id!);
      print('📚 Found ${messages.length} messages in database');
      
      setState(() {
        _messages.clear();
        _processedMessageIds.clear();
        print('🧹 Cleared existing messages and processed IDs');
        
        for (final message in messages) {
          // Use a consistent ID format: content + timestamp for deduplication
          final messageId = '${message.content}_${message.timestamp.millisecondsSinceEpoch}';
          print('🔍 Processing message ID: $messageId, isFromMe: ${message.isFromMe}');
          
          if (!_processedMessageIds.contains(messageId)) {
            _processedMessageIds.add(messageId);
            _messages.add({
              'id': messageId,
              'sender': message.isFromMe 
                  ? widget.currentUser.name 
                  : widget.remoteUserName,
              'content': message.content,
              'timestamp': message.timestamp.millisecondsSinceEpoch,
              'isMe': message.isFromMe,
            });
            print('✅ Added message: ${message.content} (${message.isFromMe ? "me" : "them"})');
          } else {
            print('⚠️ Skipped duplicate message: $messageId');
          }
        }
      });
      
      _scrollToBottom();
      print('✅ Loaded ${_messages.length} unique messages from history');
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  Future<void> _saveMessageToDatabase(Message message) async {
    if (_currentChatSession?.id == null) return;

    try {
      await _databaseService.insertMessage(
        sessionId: _currentChatSession!.id!,
        content: message.content,
        isFromMe: message.senderPhone == widget.currentUser.phone,
        timestamp: message.timestamp,
      );
      
      // Update chat session with last message
      await _databaseService.updateChatSession(_currentChatSession!.copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
      ));
      
      print('✅ Saved message to database');
    } catch (e) {
      print('Error saving message to database: $e');
    }
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

    // Disconnect from WebSocket when leaving chat
    _webSocketService.disconnect();

    _messageController.dispose();
    _scrollController.dispose();
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
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00A8FF),
              child: Text(
                widget.remoteUserName.isNotEmpty
                    ? widget.remoteUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.remoteUserName.isNotEmpty
                        ? widget.remoteUserName
                        : 'Unknown User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isConnected ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2A4A6B),
                  title: const Text(
                    'Chat Info',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remote User: ${widget.remoteUserName}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Phone: ${widget.remoteUserPhone}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Session: ${widget.sessionId}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Role: ${widget.isHost ? "Host" : "Client"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Messages: ${_messages.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isConnected ? Icons.wifi : Icons.wifi_off,
                            color: _isConnected ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isConnected
                                ? 'Real-time WebSocket'
                                : 'Connection Lost',
                            style: TextStyle(
                              color: _isConnected ? Colors.green : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Color(0xFF00A8FF)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start your WebSocket conversation!\nMessages will appear here in real-time.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isConnected ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isConnected ? Icons.wifi : Icons.wifi_off,
                                size: 16,
                                color: _isConnected ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isConnected ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isConnected
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
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
                      final isMe = message['isMe'] ?? false;

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
                                backgroundColor: const Color(0xFF00A8FF),
                                child: Text(
                                  message['sender'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF00A8FF)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          message['sender'],
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      message['content'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message['timestamp']),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF4CAF50),
                                child: Text(
                                  widget.currentUser.name.isNotEmpty
                                      ? widget.currentUser.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message Input
          Container(
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
            child: Column(
              children: [
                // Message input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        enabled: _isConnected,
                        decoration: InputDecoration(
                          hintText: _isConnected
                              ? 'Type a message...'
                              : 'Connection lost...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: _isConnected
                          ? const Color(0xFF00A8FF)
                          : Colors.grey,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isConnected ? _sendMessage : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ), // End of Scaffold
    ); // End of WillPopScope
  } // End of build method

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
