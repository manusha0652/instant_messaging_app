import 'dart:async';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/local_messaging_service.dart'; // Changed from websocket_service
import '../models/message.dart';

class RealTimeMessagingService {
  static final RealTimeMessagingService _instance = RealTimeMessagingService._internal();
  factory RealTimeMessagingService() => _instance;
  RealTimeMessagingService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final LocalMessagingService _localMessagingService = LocalMessagingService(); // Changed

  // Stream controllers for real-time messaging
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get userStatusStream => _userStatusStreamController.stream;

  // Add missing streams for chat screen compatibility
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStatusStream => _typingStreamController.stream;

  bool _isInitialized = false;
  StreamSubscription<Message>? _localMessageSubscription; // Changed
  StreamSubscription<Map<String, dynamic>>? _localTypingSubscription; // Changed
  StreamSubscription<Map<String, dynamic>>? _localStatusSubscription; // Changed

  /// Initialize the real-time messaging service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Connect to local messaging service instead of WebSocket
      final connected = await _localMessagingService.initialize();
      if (!connected) {
        print('Failed to initialize local messaging service');
        return false;
      }

      // Subscribe to local messaging events
      _subscribeToLocalMessagingEvents();

      _isInitialized = true;
      print('Real-time messaging service initialized successfully with local storage');
      return true;
    } catch (e) {
      print('Failed to initialize real-time messaging service: $e');
      return false;
    }
  }

  /// Subscribe to local messaging events
  void _subscribeToLocalMessagingEvents() {
    // Subscribe to message stream
    _localMessageSubscription = _localMessagingService.messageStream.listen((message) {
      _messageStreamController.add(message);
    });

    // Subscribe to typing status stream
    _localTypingSubscription = _localMessagingService.typingStatusStream.listen((typingData) {
      _typingStreamController.add(typingData);
    });

    // Subscribe to user status stream
    _localStatusSubscription = _localMessagingService.userStatusStream.listen((statusData) {
      _userStatusStreamController.add(statusData);
    });
  }

  /// Send message to contact
  Future<bool> sendMessage({
    required String contactPhone,
    required String content,
    String messageType = 'text',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _localMessagingService.sendMessage(
      contactPhone: contactPhone,
      content: content,
      messageType: messageType,
    );
  }

  /// Send typing indicator
  Future<void> sendTypingStatus({
    required String contactPhone,
    required bool isTyping,
  }) async {
    if (!_isInitialized) return;

    await _localMessagingService.sendTypingStatus(
      contactPhone: contactPhone,
      isTyping: isTyping,
    );
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String contactPhone) async {
    if (!_isInitialized) return;

    await _localMessagingService.markMessagesAsRead(contactPhone);
  }

  /// Get contact last seen
  Future<DateTime?> getContactLastSeen(String contactPhone) async {
    if (!_isInitialized) return null;

    return await _localMessagingService.getContactLastSeen(contactPhone);
  }

  /// Join chat room (for local messaging compatibility)
  Future<void> joinChatRoom(String contactPhone) async {
    if (!_isInitialized) {
      await initialize();
    }
    // In local messaging, we don't need to join rooms, but we can use this
    // to initialize the chat session or mark as active
    print('Joined chat with $contactPhone (local mode)');
  }

  /// Check if contact is online (mock implementation for local messaging)
  Future<bool> isContactOnline(String contactPhone) async {
    if (!_isInitialized) return false;

    // In local messaging mode, we can't determine online status
    // Always return false for local mode
    return false;
  }

  /// Cleanup resources
  void dispose() {
    _localMessageSubscription?.cancel();
    _localTypingSubscription?.cancel();
    _localStatusSubscription?.cancel();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _localMessagingService.dispose();
    _isInitialized = false;
  }
}
