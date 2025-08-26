import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // Socket.IO client instance
  IO.Socket? _socket;

  // Services
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final Uuid _uuid = const Uuid();

  // Stream controllers for real-time events
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _qrConnectionStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingStreamController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusStreamController.stream;
  Stream<Map<String, dynamic>> get connectionStream => _connectionStreamController.stream;
  Stream<Map<String, dynamic>> get qrConnectionStream => _qrConnectionStreamController.stream;

  // Connection state
  bool _isConnected = false;
  User? _currentUser;
  String? _currentSocketId;

  // Peer-to-peer connection state (for compatibility with real-time messaging service)
  final Map<String, dynamic> _connectedPeers = {};
  String? _localIP;
  int? _localPort;

  // Socket.IO server URL (replace with your actual server URL)
  static const String SERVER_URL = 'http://localhost:3000'; // For local development
  // static const String SERVER_URL = 'https://your-chatlink-server.com'; // For production

  // Getters
  bool get isConnected => _isConnected;
  String? get currentSocketId => _currentSocketId;
  Map<String, dynamic> get connectedPeers => _connectedPeers;
  String? get localIP => _localIP;
  int? get localPort => _localPort;

  /// Initialize WebSocket connection for a user
  Future<bool> connect() async {
    try {
      // Get current user
      final userPhone = await _sessionService.getCurrentUser();
      if (userPhone == null) {
        throw Exception('No user session found');
      }

      _currentUser = await _databaseService.getUserByPhone(userPhone);
      if (_currentUser == null) {
        throw Exception('User not found in database');
      }

      // Generate unique socket ID if not exists
      if (_currentUser!.socketId == null) {
        final newSocketId = _uuid.v4();
        _currentUser = _currentUser!.copyWith(socketId: newSocketId);
        await _databaseService.updateUser(_currentUser!);
      }

      _currentSocketId = _currentUser!.socketId;

      // Configure Socket.IO options
      final options = IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            'user_phone': _currentUser!.phone,
            'user_name': _currentUser!.name,
            'socket_id': _currentSocketId!,
          })
          .build();

      // Create socket connection
      _socket = IO.io(SERVER_URL, options);

      // Set up event listeners
      _setupEventListeners();

      // Connect to server
      _socket!.connect();

      // Wait for connection
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _socket!.on('connect', (_) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      return await completer.future;

    } catch (e) {
      print('WebSocket connection error: $e');
      return false;
    }
  }

  /// Set up all Socket.IO event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.on('connect', (data) {
      print('Connected to WebSocket server');
      _isConnected = true;
      _currentSocketId = _socket!.id;

      // Register user with server
      _socket!.emit('user_register', {
        'phone': _currentUser!.phone,
        'name': _currentUser!.name,
        'socketId': _currentSocketId,
        'bio': _currentUser!.bio,
      });

      _connectionStreamController.add({
        'event': 'connected',
        'socketId': _currentSocketId,
      });
    });

    _socket!.on('disconnect', (data) {
      print('Disconnected from WebSocket server');
      _isConnected = false;
      _connectionStreamController.add({
        'event': 'disconnected',
        'reason': data,
      });
    });

    _socket!.on('connect_error', (data) {
      print('Connection error: $data');
      _connectionStreamController.add({
        'event': 'error',
        'error': data,
      });
    });

    // Message events
    _socket!.on('new_message', (data) async {
      await _handleIncomingMessage(data);
    });

    _socket!.on('message_delivered', (data) {
      _handleMessageDelivered(data);
    });

    _socket!.on('message_read', (data) {
      _handleMessageRead(data);
    });

    // Typing events
    _socket!.on('user_typing', (data) {
      _typingStreamController.add({
        'phone': data['phone'],
        'name': data['name'],
        'isTyping': true,
      });
    });

    _socket!.on('user_stopped_typing', (data) {
      _typingStreamController.add({
        'phone': data['phone'],
        'name': data['name'],
        'isTyping': false,
      });
    });

    // User status events
    _socket!.on('user_online', (data) {
      _userStatusStreamController.add({
        'phone': data['phone'],
        'status': 'online',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _socket!.on('user_offline', (data) {
      _userStatusStreamController.add({
        'phone': data['phone'],
        'status': 'offline',
        'lastSeen': data['lastSeen'],
      });
    });
  }

  /// Send a message to a specific user
  Future<bool> sendMessage({
    required String toPhone,
    required String content,
    required int sessionId,
    String messageType = 'text',
  }) async {
    if (!_isConnected || _socket == null) {
      print('WebSocket not connected');
      return false;
    }

    try {
      final messageData = {
        'from': _currentUser!.phone,
        'fromName': _currentUser!.name,
        'to': toPhone,
        'content': content,
        'messageType': messageType,
        'sessionId': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageId': _uuid.v4(),
      };

      // Emit message to server
      _socket!.emit('send_message', messageData);

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Handle incoming message from WebSocket
  Future<void> _handleIncomingMessage(dynamic data) async {
    try {
      final messageData = Map<String, dynamic>.from(data);

      // Find or create chat session
      final currentUser = await _databaseService.getUserByPhone(_currentUser!.phone);
      if (currentUser == null) return;

      var chatSession = await _databaseService.getChatSessionByUserAndPhone(
        currentUser.id!,
        messageData['from'],
      );

      int sessionId;
      // Create chat session if doesn't exist
      if (chatSession == null) {
        sessionId = await _databaseService.createChatSessionForUser(
          userId: currentUser.id!,
          contactName: messageData['fromName'],
          contactPhone: messageData['from'],
        );
      } else {
        sessionId = chatSession.id!;
      }

      // Save message to database
      final messageId = await _databaseService.insertMessage(
        sessionId: sessionId,
        content: messageData['content'],
        isFromMe: false,
        messageType: messageData['messageType'] ?? 'text',
      );

      // Create message object
      final message = Message(
        id: messageId,
        sessionId: sessionId,
        content: messageData['content'],
        isFromMe: false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(messageData['timestamp']),
        messageType: messageData['messageType'] ?? 'text',
        isRead: false,
        isDelivered: true,
        isSent: true,
      );

      // Emit to UI
      _messageStreamController.add(message);

      // Send delivery confirmation
      _socket!.emit('message_delivered', {
        'messageId': messageData['messageId'],
        'to': messageData['from'],
      });

    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  /// Handle message delivered confirmation
  void _handleMessageDelivered(dynamic data) {
    // Update message status in database
    // This would typically update the specific message's delivery status
    print('Message delivered: ${data['messageId']}');
  }

  /// Handle message read confirmation
  void _handleMessageRead(dynamic data) {
    // Update message status in database
    print('Message read: ${data['messageId']}');
  }

  /// Send typing indicator
  void sendTypingIndicator(String toPhone, bool isTyping) {
    if (!_isConnected || _socket == null) return;

    if (isTyping) {
      _socket!.emit('typing', {
        'to': toPhone,
        'from': _currentUser!.phone,
        'fromName': _currentUser!.name,
      });
    } else {
      _socket!.emit('stop_typing', {
        'to': toPhone,
        'from': _currentUser!.phone,
        'fromName': _currentUser!.name,
      });
    }
  }

  /// Mark message as read
  void markMessageAsRead(String messageId, String fromPhone) {
    if (!_isConnected || _socket == null) return;

    _socket!.emit('message_read', {
      'messageId': messageId,
      'to': fromPhone,
      'from': _currentUser!.phone,
    });
  }

  /// Join a chat room for direct messaging
  void joinChatRoom(String contactPhone) {
    if (!_isConnected || _socket == null) return;

    final roomId = _generateRoomId(_currentUser!.phone, contactPhone);
    _socket!.emit('join_room', {
      'roomId': roomId,
      'userPhone': _currentUser!.phone,
    });
  }

  /// Leave a chat room
  void leaveChatRoom(String contactPhone) {
    if (!_isConnected || _socket == null) return;

    final roomId = _generateRoomId(_currentUser!.phone, contactPhone);
    _socket!.emit('leave_room', {
      'roomId': roomId,
      'userPhone': _currentUser!.phone,
    });
  }

  /// Generate consistent room ID for two users
  String _generateRoomId(String phone1, String phone2) {
    final phones = [phone1, phone2]..sort();
    return '${phones[0]}_${phones[1]}';
  }

  /// Get online status of a user
  void requestUserStatus(String phone) {
    if (!_isConnected || _socket == null) return;

    _socket!.emit('get_user_status', {'phone': phone});
  }

  /// Update user's online status
  void updateOnlineStatus(bool isOnline) {
    if (!_isConnected || _socket == null) return;

    _socket!.emit('update_status', {
      'phone': _currentUser!.phone,
      'isOnline': isOnline,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    if (_socket != null) {
      // Update offline status before disconnecting
      updateOnlineStatus(false);

      _socket!.disconnect();
      _socket = null;
    }

    _isConnected = false;
    _currentSocketId = null;
  }

  /// Reconnect to WebSocket server
  Future<bool> reconnect() async {
    await disconnect();
    await Future.delayed(const Duration(seconds: 1));
    return await connect();
  }

  // ===== Missing methods that real_time_messaging_service.dart expects =====

  /// Generate QR data for peer connection (compatibility method)
  Map<String, dynamic> generateQRData() {
    return {
      'userPhone': _currentUser?.phone ?? '',
      'userName': _currentUser?.name ?? '',
      'socketId': _currentSocketId ?? '',
      'serverUrl': SERVER_URL,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Connect to peer via QR code (compatibility method)
  Future<bool> connectToPeerViaQR(Map<String, dynamic> qrData) async {
    try {
      // For Socket.IO implementation, we just emit a peer connection request
      if (_isConnected && _socket != null) {
        _socket!.emit('peer_connect_request', {
          'from': _currentUser!.phone,
          'fromName': _currentUser!.name,
          'to': qrData['userPhone'],
          'qrData': qrData,
        });

        // Simulate connection success for compatibility
        _qrConnectionStreamController.add({
          'event': 'peer_connected',
          'peer': qrData,
          'success': true,
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error connecting to peer via QR: $e');
      return false;
    }
  }

  /// Send typing status (compatibility method - maps to existing sendTypingIndicator)
  Future<void> sendTypingStatus(String toPhone, bool isTyping) async {
    sendTypingIndicator(toPhone, isTyping);
  }

  /// Check if peer is online (compatibility method)
  bool isPeerOnline(String contactPhone) {
    // For Socket.IO implementation, we can check if we have recent status
    // This is a simplified implementation - in reality you'd check server status
    return _connectedPeers.containsKey(contactPhone);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _connectionStreamController.close();
    _qrConnectionStreamController.close();
  }
}
