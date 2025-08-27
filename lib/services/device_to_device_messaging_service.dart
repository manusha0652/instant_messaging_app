import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';

class DeviceToDeviceMessagingService {
  static final DeviceToDeviceMessagingService _instance = DeviceToDeviceMessagingService._internal();
  factory DeviceToDeviceMessagingService() => _instance;
  DeviceToDeviceMessagingService._internal();

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
  String? _sharedMessagesDirectory;
  Map<String, int> _lastMessageCounts = {};

  /// Initialize device-to-device messaging service
  Future<bool> initialize() async {
    try {
      // Get current user
      _currentUserPhone = await _sessionService.getCurrentUser();
      if (_currentUserPhone == null) {
        print('No user session found');
        return false;
      }

      // Use external storage for device-to-device sharing
      await _setupSharedStorage();

      // Start watching for new messages
      _startMessageWatcher();

      print('Device-to-device messaging service initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize device-to-device messaging service: $e');
      return false;
    }
  }

  /// Request storage permissions for the app
  Future<bool> _requestStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), request specific media permissions
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        // Also request manage external storage for Android 11+
        var manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          manageStatus = await Permission.manageExternalStorage.request();
        }

        if (status.isGranted || manageStatus.isGranted) {
          print('Storage permissions granted');
          return true;
        } else {
          print('Storage permissions denied');
          return false;
        }
      }
      return true; // For non-Android platforms
    } catch (e) {
      print('Error requesting storage permissions: $e');
      return false;
    }
  }

  /// Setup shared storage directory that other devices can access
  Future<void> _setupSharedStorage() async {
    try {
      // Request storage permissions first
      final hasPermissions = await _requestStoragePermissions();

      if (Platform.isAndroid && hasPermissions) {
        // Use public Downloads folder for better cross-device access
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download/ChatLink');
          if (!downloadsDir.existsSync()) {
            downloadsDir.createSync(recursive: true);
          }

          // Test write access
          final testFile = File('${downloadsDir.path}/test.txt');
          await testFile.writeAsString('test');
          await testFile.delete();

          _sharedMessagesDirectory = downloadsDir.path;
          print('Using Downloads directory: $_sharedMessagesDirectory');
          return;
        } catch (e) {
          print('Cannot access Downloads directory: $e, falling back...');
        }
      }

      // Fallback: Use app's external storage directory
      try {
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          _sharedMessagesDirectory = '${appDir.path}/shared_messages';
          final dir = Directory(_sharedMessagesDirectory!);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          print('Using external app directory: $_sharedMessagesDirectory');
          return;
        }
      } catch (e) {
        print('Cannot access external storage: $e');
      }

      // Final fallback: Use internal app directory
      final appDir = await getApplicationDocumentsDirectory();
      _sharedMessagesDirectory = '${appDir.path}/local_messages';
      final dir = Directory(_sharedMessagesDirectory!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      print('Using internal app directory: $_sharedMessagesDirectory');

    } catch (e) {
      print('Error setting up shared storage: $e');
      // Emergency fallback
      final appDir = await getApplicationDocumentsDirectory();
      _sharedMessagesDirectory = '${appDir.path}/emergency_messages';
      final dir = Directory(_sharedMessagesDirectory!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }
  }

  /// Send message to contact
  Future<bool> sendMessage({
    required String contactPhone,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      if (_currentUserPhone == null || _sharedMessagesDirectory == null) {
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
          sessionId: chatSession.id!,
          content: content,
          isFromMe: true,
          messageType: messageType,
        );
      }

      // Create message data for device sharing
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

      // Save message to shared file for the contact's device
      await _saveMessageToSharedFile(contactPhone, messageData);

      // Emit message to local stream
      _messageStreamController.add(message);

      print('Message sent successfully to $contactPhone via shared storage');
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Save message to shared file that other devices can access
  Future<void> _saveMessageToSharedFile(String contactPhone, Map<String, dynamic> messageData) async {
    try {
      // Create a shared file that both devices can access
      final fileName = '${_sharedMessagesDirectory}/messages_for_$contactPhone.json';
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

      // Write back to file with proper permissions
      await file.writeAsString(jsonEncode(messages));
      
      // Make file readable by other apps (Android)
      if (Platform.isAndroid) {
        try {
          await Process.run('chmod', ['666', fileName]);
        } catch (e) {
          print('Could not change file permissions: $e');
        }
      }

      print('Message saved to shared file: $fileName');
    } catch (e) {
      print('Error saving message to shared file: $e');
    }
  }

  /// Start watching for new messages from other devices
  void _startMessageWatcher() {
    _messageWatcher?.cancel();
    _messageWatcher = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkForNewMessages();
    });
  }

  /// Check for new messages from contacts' devices
  Future<void> _checkForNewMessages() async {
    try {
      if (_currentUserPhone == null || _sharedMessagesDirectory == null) return;

      final fileName = '${_sharedMessagesDirectory}/messages_for_$_currentUserPhone.json';
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

  /// Handle incoming message from another device
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

      int sessionId;
      // Create chat session if doesn't exist
      if (chatSession == null) {
        sessionId = await _databaseService.createChatSessionForUser(
          userId: currentUser.id!,
          contactName: messageData['fromName'] ?? 'Unknown',
          contactPhone: messageData['from'],
        );
      } else {
        sessionId = chatSession.id!;
      }

      // Save message to database
      await _databaseService.insertMessage(
        sessionId: sessionId,
        content: messageData['content'],
        isFromMe: false,
        messageType: messageData['messageType'] ?? 'text',
      );

      // Create message object
      final message = Message(
        sessionId: sessionId,
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

  /// Send typing indicator to shared storage
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

      // Save typing status to shared file
      final fileName = '${_sharedMessagesDirectory}/typing_$contactPhone.json';
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
        await _databaseService.markMessagesAsRead(chatSession.id!);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get contact last seen (mock implementation)
  Future<DateTime?> getContactLastSeen(String contactPhone) async {
    return null;
  }

  /// Get shared storage path for debugging
  String? getSharedStoragePath() {
    return _sharedMessagesDirectory;
  }

  /// Cleanup resources
  void dispose() {
    _messageWatcher?.cancel();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
  }
}
