import 'dart:async';
import 'dart:convert';
import '../models/message.dart';
import '../models/user.dart';
import '../models/chat_session.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/websocket_service.dart';

class RealTimeMessagingService {
  static final RealTimeMessagingService _instance = RealTimeMessagingService._internal();
  factory RealTimeMessagingService() => _instance;
  RealTimeMessagingService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final WebSocketService _webSocketService = WebSocketService();

  // Stream controllers for real-time messaging
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStatusStream => _typingStreamController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusStreamController.stream;
  Stream<Map<String, dynamic>> get connectionStream => _connectionStreamController.stream;

  // Subscriptions to websocket streams
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _userStatusSubscription;
  StreamSubscription<Map<String, dynamic>>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _qrConnectionSubscription;

  bool _isInitialized = false;
  User? _currentUser;

  /// Initialize the real-time messaging service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Get current user
      final userPhone = await _sessionService.getCurrentUser();
      if (userPhone == null) {
        print('No user session found');
        return false;
      }

      _currentUser = await _databaseService.getUserByPhone(userPhone);
      if (_currentUser == null) {
        print('User not found in database');
        return false;
      }

      // Connect to P2P websocket service
      final connected = await _webSocketService.connect();
      if (!connected) {
        print('Failed to connect to P2P websocket service');
        return false;
      }

      // Subscribe to websocket streams
      _subscribeToWebSocketStreams();

      _isInitialized = true;
      print('Real-time messaging service initialized successfully');
      return true;

    } catch (e) {
      print('Error initializing real-time messaging service: $e');
      return false;
    }
  }

  /// Subscribe to websocket streams
  void _subscribeToWebSocketStreams() {
    // Subscribe to message stream
    _messageSubscription = _webSocketService.messageStream.listen((message) {
      _messageStreamController.add(message);
    });

    // Subscribe to typing stream
    _typingSubscription = _webSocketService.typingStream.listen((typingData) {
      _typingStreamController.add(typingData);
    });

    // Subscribe to user status stream
    _userStatusSubscription = _webSocketService.userStatusStream.listen((statusData) {
      _userStatusStreamController.add(statusData);
    });

    // Subscribe to connection stream
    _connectionSubscription = _webSocketService.connectionStream.listen((connectionData) {
      _connectionStreamController.add(connectionData);
    });

    // Subscribe to QR connection stream
    _qrConnectionSubscription = _webSocketService.qrConnectionStream.listen((qrData) {
      _handleQRConnection(qrData);
    });
  }

  /// Handle QR connection events
  void _handleQRConnection(Map<String, dynamic> qrData) {
    _connectionStreamController.add({
      'event': 'qr_connected',
      'peer': qrData['peer'],
    });
  }

  /// Connect to a peer via QR code
  Future<bool> connectViaQR(String qrCodeData) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Parse QR code data
      final qrData = jsonDecode(qrCodeData);

      // Validate QR data
      if (!_isValidQRData(qrData)) {
        throw Exception('Invalid QR code data');
      }

      // Connect to peer via websocket service
      final connected = await _webSocketService.connectToPeerViaQR(qrData);

      if (connected) {
        _connectionStreamController.add({
          'event': 'peer_connected_via_qr',
          'peerPhone': qrData['phone'],
          'peerName': qrData['name'],
        });
      }

      return connected;
    } catch (e) {
      print('Error connecting via QR: $e');
      return false;
    }
  }

  /// Validate QR code data
  bool _isValidQRData(Map<String, dynamic> qrData) {
    return qrData.containsKey('ip') &&
           qrData.containsKey('port') &&
           qrData.containsKey('phone') &&
           qrData.containsKey('name') &&
           qrData.containsKey('socketId');
  }

  /// Generate QR code data for sharing
  String generateQRCode() {
    if (!_isInitialized || !_webSocketService.isConnected) {
      throw Exception('Service not initialized or connected');
    }

    final qrData = _webSocketService.generateQRData();
    return jsonEncode(qrData);
  }

  /// Send a message to a contact
  Future<bool> sendMessage({
    required String toPhone,
    required String content,
    required int sessionId,
    String messageType = 'text',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Send via websocket service
      final sent = await _webSocketService.sendMessage(
        toPhone: toPhone,
        content: content,
        sessionId: sessionId,
        messageType: messageType,
      );

      if (sent) {
        // Update chat session
        await _updateChatSessionLastMessage(sessionId, content);
      }

      return sent;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Update chat session with last message
  Future<void> _updateChatSessionLastMessage(int sessionId, String content) async {
    try {
      final chatSession = await _databaseService.getChatSessionById(sessionId);
      if (chatSession != null) {
        final updatedSession = ChatSession(
          id: chatSession.id,
          userId: chatSession.userId,
          contactPhone: chatSession.contactPhone,
          contactName: chatSession.contactName,
          contactAvatar: chatSession.contactAvatar,
          lastMessage: content,
          lastMessageTime: DateTime.now(),
          unreadCount: chatSession.unreadCount,
          isActive: chatSession.isActive,
        );

        await _databaseService.updateChatSession(updatedSession);
      }
    } catch (e) {
      print('Error updating chat session: $e');
    }
  }

  /// Join a chat room (for typing indicators)
  Future<void> joinChatRoom(String contactPhone) async {
    if (!_isInitialized) {
      await initialize();
    }

    // No specific join required for P2P, just ensure we're connected
    print('Joined chat room for: $contactPhone');
  }

  /// Leave a chat room
  Future<void> leaveChatRoom(String contactPhone) async {
    print('Left chat room for: $contactPhone');
  }

  /// Send typing status
  Future<void> sendTypingStatus(String toPhone, bool isTyping) async {
    if (!_isInitialized) return;

    await _webSocketService.sendTypingStatus(toPhone, isTyping);
  }

  /// Check if a contact is online
  Future<bool> isContactOnline(String contactPhone) async {
    if (!_isInitialized) return false;

    return _webSocketService.isPeerOnline(contactPhone);
  }

  /// Check if a peer is online (delegate to websocket service)
  bool isPeerOnline(String contactPhone) {
    if (!_isInitialized) return false;
    return _webSocketService.isPeerOnline(contactPhone);
  }

  /// Get all connected peers
  Map<String, Map<String, dynamic>> getConnectedPeers() {
    if (!_isInitialized) return {};

    // Convert Map<String, dynamic> to Map<String, Map<String, dynamic>>
    final peers = <String, Map<String, dynamic>>{};
    _webSocketService.connectedPeers.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        peers[key] = value;
      }
    });
    return peers;
  }

  /// Get messages for a chat session
  Future<List<Message>> getMessages(int sessionId, {int limit = 50, int offset = 0}) async {
    try {
      return await _databaseService.getMessages(sessionId, limit: limit, offset: offset);
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(int sessionId) async {
    try {
      await _databaseService.markMessagesAsRead(sessionId);

      // Update chat session unread count
      final chatSession = await _databaseService.getChatSessionById(sessionId);
      if (chatSession != null) {
        final updatedSession = ChatSession(
          id: chatSession.id,
          userId: chatSession.userId,
          contactPhone: chatSession.contactPhone,
          contactName: chatSession.contactName,
          contactAvatar: chatSession.contactAvatar,
          lastMessage: chatSession.lastMessage,
          lastMessageTime: chatSession.lastMessageTime,
          unreadCount: 0, // Reset unread count
          isActive: chatSession.isActive,
        );

        await _databaseService.updateChatSession(updatedSession);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get all chat sessions for current user
  Future<List<ChatSession>> getChatSessions() async {
    try {
      if (_currentUser == null) return [];

      return await _databaseService.getChatSessions(_currentUser!.id!);
    } catch (e) {
      print('Error getting chat sessions: $e');
      return [];
    }
  }

  /// Get chat session by contact phone
  Future<ChatSession?> getChatSessionByPhone(String contactPhone) async {
    try {
      if (_currentUser == null) return null;

      return await _databaseService.getChatSessionByUserAndPhone(
        _currentUser!.id!,
        contactPhone,
      );
    } catch (e) {
      print('Error getting chat session by phone: $e');
      return null;
    }
  }

  /// Create a new chat session
  Future<ChatSession?> createChatSession({
    required String contactPhone,
    required String contactName,
    String? contactAvatar,
  }) async {
    try {
      if (_currentUser == null) return null;

      final newSession = ChatSession(
        userId: _currentUser!.id!,
        contactPhone: contactPhone,
        contactName: contactName,
        contactAvatar: contactAvatar,
        lastMessage: null,
        lastMessageTime: null,
        unreadCount: 0,
        isActive: true,
      );

      return await _databaseService.createChatSessionFromModel(newSession);
    } catch (e) {
      print('Error creating chat session: $e');
      return null;
    }
  }

  /// Get contact last seen (placeholder method)
  Future<DateTime?> getContactLastSeen(String contactPhone) async {
    // For P2P communication, we can check if peer is currently online
    if (isPeerOnline(contactPhone)) {
      return DateTime.now();
    }
    return null;
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isConnected': _webSocketService.isConnected,
      'localIP': _webSocketService.localIP,
      'localPort': _webSocketService.localPort,
      'connectedPeersCount': _webSocketService.connectedPeers.length,
      'currentUser': _currentUser?.toMap(),
    };
  }

  /// Disconnect from the service
  Future<void> disconnect() async {
    try {
      // Cancel subscriptions
      await _messageSubscription?.cancel();
      await _typingSubscription?.cancel();
      await _userStatusSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _qrConnectionSubscription?.cancel();

      // Disconnect websocket service
      await _webSocketService.disconnect();

      _isInitialized = false;
      print('Real-time messaging service disconnected');
    } catch (e) {
      print('Error disconnecting real-time messaging service: $e');
    }
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _connectionStreamController.close();
  }
}
