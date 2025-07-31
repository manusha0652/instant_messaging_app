import 'dart:async';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';

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

  Stream<Map<String, dynamic>> get userStatusStream => _userStatusStreamController.stream;

  // Add missing streams for chat screen compatibility
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStatusStream => _typingStreamController.stream;

  bool _isInitialized = false;
  StreamSubscription<Message>? _webSocketMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _webSocketTypingSubscription;
  StreamSubscription<Map<String, dynamic>>? _webSocketStatusSubscription;

  /// Initialize the real-time messaging service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Connect to WebSocket server
      final connected = await _webSocketService.connect();
      if (!connected) {
        print('Failed to connect to WebSocket server');
        return false;
      }

      // Subscribe to WebSocket events
      _subscribeToWebSocketEvents();

      _isInitialized = true;
      print('Real-time messaging service initialized successfully');
      return true;

    } catch (e) {
      print('Error initializing real-time messaging service: $e');
      return false;
    }
  }

  /// Subscribe to WebSocket events
  void _subscribeToWebSocketEvents() {
    // Forward messages from WebSocket to local stream
    _webSocketMessageSubscription = _webSocketService.messageStream.listen(
      (message) {
        _messageStreamController.add(message);
      },
      onError: (error) {
        print('WebSocket message stream error: $error');
      },
    );

    // Forward typing indicators from WebSocket to local stream
    _webSocketTypingSubscription = _webSocketService.typingStream.listen(
      (typingData) {
        _typingStreamController.add(typingData);
      },
      onError: (error) {
        print('WebSocket typing stream error: $error');
      },
    );

    // Forward user status updates from WebSocket to local stream
    _webSocketStatusSubscription = _webSocketService.userStatusStream.listen(
      (statusData) {
        _userStatusStreamController.add(statusData);
      },
      onError: (error) {
        print('WebSocket status stream error: $error');
      },
    );
  }

  /// Send message to specific contact via WebSocket
  Future<bool> sendMessageToContact({
    required String contactPhone,
    required String message,
    required int sessionId,
  }) async {
    try {
      // Save message to database first
      await _databaseService.insertMessage(
        sessionId: sessionId,
        content: message,
        isFromMe: true,
      );

      // Send via WebSocket for real-time delivery
      final success = await _webSocketService.sendMessage(
        toPhone: contactPhone,
        content: message,
        sessionId: sessionId,
      );

      if (!success) {
        print('Failed to send message via WebSocket');
        // Fallback to offline message queue if needed
      }

      return success;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Send typing indicator to contact
  void sendTypingIndicator(String toPhone, bool isTyping) {
    _webSocketService.sendTypingIndicator(toPhone, isTyping);
  }

  /// Join chat room for real-time messaging
  void joinChatRoom(String contactPhone) {
    _webSocketService.joinChatRoom(contactPhone);
  }

  /// Leave chat room
  void leaveChatRoom(String contactPhone) {
    _webSocketService.leaveChatRoom(contactPhone);
  }

  /// Get online status of contact
  Future<bool> isContactOnline(String contactPhone) async {
    _webSocketService.requestUserStatus(contactPhone);

    // Listen for status response
    final completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = userStatusStream.listen((statusData) {
      if (statusData['phone'] == contactPhone) {
        completer.complete(statusData['status'] == 'online');
        subscription.cancel();
      }
    });

    // Timeout after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(false);
        subscription.cancel();
      }
    });

    return completer.future;
  }

  /// Get last seen timestamp of contact
  Future<DateTime?> getContactLastSeen(String contactPhone) async {
    _webSocketService.requestUserStatus(contactPhone);

    final completer = Completer<DateTime?>();
    late StreamSubscription subscription;

    subscription = userStatusStream.listen((statusData) {
      if (statusData['phone'] == contactPhone) {
        final lastSeen = statusData['lastSeen'];
        if (lastSeen != null) {
          completer.complete(DateTime.fromMillisecondsSinceEpoch(lastSeen));
        } else {
          completer.complete(null);
        }
        subscription.cancel();
      }
    });

    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        subscription.cancel();
      }
    });

    return completer.future;
  }

  /// Mark message as read
  void markMessageAsRead(String messageId, String fromPhone) {
    _webSocketService.markMessageAsRead(messageId, fromPhone);
  }

  /// Update user's online status
  void updateOnlineStatus(bool isOnline) {
    _webSocketService.updateOnlineStatus(isOnline);
  }

  /// Check if WebSocket is connected
  bool get isConnected => _webSocketService.isConnected;

  /// Reconnect to WebSocket if disconnected
  Future<bool> reconnect() async {
    return await _webSocketService.reconnect();
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _webSocketService.disconnect();
    _isInitialized = false;
  }

  // Clean up resources
  void dispose() {
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _webSocketMessageSubscription?.cancel();
    _webSocketTypingSubscription?.cancel();
    _webSocketStatusSubscription?.cancel();
  }
}
