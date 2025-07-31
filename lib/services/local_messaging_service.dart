import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';

class LocalMessagingService {
  static final LocalMessagingService _instance = LocalMessagingService._internal();
  factory LocalMessagingService() => _instance;
  LocalMessagingService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();

  // Stream controllers for real-time messaging
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStatusStream => _typingStreamController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusStreamController.stream;

  // File watcher for real-time updates
  Timer? _messageWatcher;
  String? _currentUserPhone;
  String? _messagesDirectory;
  Map<String, int> _lastMessageCounts = {};

  /// Initialize local messaging service
  Future<bool> initialize() async {
    try {
      // Get current user
      _currentUserPhone = await _sessionService.getCurrentUser();
      if (_currentUserPhone == null) {
        print('No user session found');
        return false;
      }

      // Create messages directory
      final appDir = await getApplicationDocumentsDirectory();
      _messagesDirectory = '${appDir.path}/local_messages';
      final dir = Directory(_messagesDirectory!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Start watching for new messages
      _startMessageWatcher();

      print('Local messaging service initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize local messaging service: $e');
      return false;
    }
  }

  /// Send message to contact
  Future<bool> sendMessage({
    required String contactPhone,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      if (_currentUserPhone == null || _messagesDirectory == null) {
        throw Exception('Service not initialized');
      }

      // Get current user info
      final currentUser = await _databaseService.getUserByPhone(_currentUserPhone!);
      if (currentUser == null) {
        throw Exception('Current user not found');
      }

      // Create message object
      final message = Message(
        sessionId: 0, // Will be updated when saved to database
        content: content,
        isFromMe: true,
        timestamp: DateTime.now(),
        messageType: messageType,
        isRead: true,
        isDelivered: false,
        isSent: true,
      );

      // Save message to local database
      final chatSession = await _databaseService.getChatSessionByUserAndPhone(
        currentUser.id!,
        contactPhone,
      );

      if (chatSession != null) {
        await _databaseService.insertMessage(
          sessionId: chatSession['id'],
          content: content,
          isFromMe: true,
          messageType: messageType,
        );
      }

      // Create message data for file sharing
      final messageData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'from': _currentUserPhone,
        'fromName': currentUser.name,
        'to': contactPhone,
        'content': content,
        'messageType': messageType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };

      // Save message to shared file for the contact
      await _saveMessageToFile(contactPhone, messageData);

      // Emit message to local stream
      _messageStreamController.add(message);

      print('Message sent successfully to $contactPhone');
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Save message to file for contact to read
  Future<void> _saveMessageToFile(String contactPhone, Map<String, dynamic> messageData) async {
    try {
      final fileName = '${_messagesDirectory}/messages_for_$contactPhone.json';
      final file = File(fileName);

      List<Map<String, dynamic>> messages = [];
      
      // Read existing messages
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> existingMessages = jsonDecode(content);
          messages = existingMessages.cast<Map<String, dynamic>>();
        }
      }

      // Add new message
      messages.add(messageData);

      // Write back to file
      await file.writeAsString(jsonEncode(messages));
    } catch (e) {
      print('Error saving message to file: $e');
    }
  }

  /// Start watching for new messages
  void _startMessageWatcher() {
    _messageWatcher?.cancel();
    _messageWatcher = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkForNewMessages();
    });
  }

  /// Check for new messages from contacts
  Future<void> _checkForNewMessages() async {
    try {
      if (_currentUserPhone == null || _messagesDirectory == null) return;

      final fileName = '${_messagesDirectory}/messages_for_$_currentUserPhone.json';
      final file = File(fileName);

      if (!file.existsSync()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> messages = jsonDecode(content);
      final currentCount = messages.length;
      final lastCount = _lastMessageCounts[_currentUserPhone] ?? 0;

      if (currentCount > lastCount) {
        // Process new messages
        final newMessages = messages.skip(lastCount).toList();
        
        for (final messageData in newMessages) {
          await _handleIncomingMessage(messageData);
        }

        _lastMessageCounts[_currentUserPhone!] = currentCount;
      }
    } catch (e) {
      print('Error checking for new messages: $e');
    }
  }

  /// Handle incoming message
  Future<void> _handleIncomingMessage(dynamic data) async {
    try {
      final messageData = Map<String, dynamic>.from(data);

      // Skip if message is from current user
      if (messageData['from'] == _currentUserPhone) return;

      // Get current user
      final currentUser = await _databaseService.getUserByPhone(_currentUserPhone!);
      if (currentUser == null) return;

      // Find or create chat session
      var chatSession = await _databaseService.getChatSessionByUserAndPhone(
        currentUser.id!,
        messageData['from'],
      );

      // Create chat session if doesn't exist
      if (chatSession == null) {
        final sessionId = await _databaseService.createChatSessionForUser(
          userId: currentUser.id!,
          contactName: messageData['fromName'] ?? 'Unknown',
          contactPhone: messageData['from'],
        );
        chatSession = {'id': sessionId};
      }

      // Save message to database
      await _databaseService.insertMessage(
        sessionId: chatSession['id'],
        content: messageData['content'],
        isFromMe: false,
        messageType: messageData['messageType'] ?? 'text',
      );

      // Create message object
      final message = Message(
        sessionId: chatSession['id'],
        content: messageData['content'],
        isFromMe: false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(messageData['timestamp']),
        messageType: messageData['messageType'] ?? 'text',
        isRead: false,
        isDelivered: true,
        isSent: true,
      );

      // Emit to stream for real-time updates
      _messageStreamController.add(message);

      print('Received message from ${messageData['from']}: ${messageData['content']}');
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  /// Send typing indicator
  Future<void> sendTypingStatus({
    required String contactPhone,
    required bool isTyping,
  }) async {
    try {
      final typingData = {
        'from': _currentUserPhone,
        'to': contactPhone,
        'isTyping': isTyping,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Save typing status to file
      final fileName = '${_messagesDirectory}/typing_$contactPhone.json';
      final file = File(fileName);
      await file.writeAsString(jsonEncode(typingData));

      // Auto-clear typing after 3 seconds
      if (isTyping) {
        Timer(const Duration(seconds: 3), () {
          sendTypingStatus(contactPhone: contactPhone, isTyping: false);
        });
      }
    } catch (e) {
      print('Error sending typing status: $e');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String contactPhone) async {
    try {
      if (_currentUserPhone == null) return;

      // Mark as read in database
      final currentUser = await _databaseService.getUserByPhone(_currentUserPhone!);
      if (currentUser == null) return;

      final chatSession = await _databaseService.getChatSessionByUserAndPhone(
        currentUser.id!,
        contactPhone,
      );

      if (chatSession != null) {
        await _databaseService.markMessagesAsRead(chatSession['id']);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get contact last seen (mock implementation)
  Future<DateTime?> getContactLastSeen(String contactPhone) async {
    // Return null since we don't track last seen in local mode
    return null;
  }

  /// Cleanup resources
  void dispose() {
    _messageWatcher?.cancel();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
  }
}
