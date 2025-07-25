import 'dart:convert';
import 'dart:math';
import '../models/chat_session_model.dart';
import '../models/message_model.dart';
import 'database_service.dart';

class ChatService {
  static final ChatService instance = ChatService._init();

  ChatService._init();

  /// Generate QR code data for user
  String generateQRData(String userName, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'type': 'chatlink',
      'userName': userName,
      'userId': userId,
      'timestamp': timestamp,
      'version': '1.0',
    };
    return jsonEncode(data);
  }

  /// Parse QR code data
  Map<String, dynamic>? parseQRData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['type'] == 'chatlink') {
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Start a new chat session
  Future<ChatSessionModel> startChatSession({
    required String peerName,
    String? peerAvatar,
    String? peerQrData,
  }) async {
    final session = ChatSessionModel(
      peerName: peerName,
      peerAvatar: peerAvatar,
      peerQrData: peerQrData,
      startTime: DateTime.now(),
      isActive: true,
    );

    final sessionId = await DatabaseService.instance.insertChatSession(session);
    return session.copyWith(id: sessionId);
  }

  /// End a chat session
  Future<void> endChatSession(int sessionId) async {
    final session = await DatabaseService.instance.getChatSession(sessionId);
    if (session != null) {
      final updatedSession = session.copyWith(
        isActive: false,
        endTime: DateTime.now(),
      );
      await DatabaseService.instance.updateChatSession(updatedSession);
    }
  }

  /// Send a message
  Future<MessageModel> sendMessage({
    required int sessionId,
    required String content,
    String messageType = 'text',
    String? attachmentPath,
  }) async {
    final message = MessageModel(
      sessionId: sessionId,
      content: content,
      isFromMe: true,
      timestamp: DateTime.now(),
      messageType: messageType,
      attachmentPath: attachmentPath,
    );

    final messageId = await DatabaseService.instance.insertMessage(message);
    return message.copyWith(id: messageId);
  }

  /// Receive a message (simulate from peer)
  Future<MessageModel> receiveMessage({
    required int sessionId,
    required String content,
    String messageType = 'text',
    String? attachmentPath,
  }) async {
    final message = MessageModel(
      sessionId: sessionId,
      content: content,
      isFromMe: false,
      timestamp: DateTime.now(),
      messageType: messageType,
      attachmentPath: attachmentPath,
    );

    final messageId = await DatabaseService.instance.insertMessage(message);
    return message.copyWith(id: messageId);
  }

  /// Get all chat sessions
  Future<List<ChatSessionModel>> getChatSessions() async {
    return await DatabaseService.instance.getChatSessions();
  }

  /// Get messages for a session
  Future<List<MessageModel>> getMessages(int sessionId) async {
    return await DatabaseService.instance.getMessages(sessionId);
  }

  /// Generate a random peer name for demo purposes
  String generateRandomPeerName() {
    final names = [
      'Alice',
      'Bob',
      'Charlie',
      'Diana',
      'Eve',
      'Frank',
      'Grace',
      'Henry',
      'Ivy',
      'Jack',
      'Kate',
      'Liam',
    ];
    final random = Random();
    return names[random.nextInt(names.length)];
  }

  /// Simulate receiving messages for demo
  Future<void> simulateIncomingMessage(int sessionId) async {
    final messages = [
      'Hello there!',
      'How are you doing?',
      'This is a test message',
      'ChatLink is working great!',
      'Thanks for connecting',
    ];
    final random = Random();
    final content = messages[random.nextInt(messages.length)];

    await Future.delayed(Duration(seconds: random.nextInt(3) + 1));
    await receiveMessage(sessionId: sessionId, content: content);
  }

  /// Delete a chat session
  Future<void> deleteChatSession(int sessionId) async {
    await DatabaseService.instance.deleteChatSession(sessionId);
  }

  /// Check if QR data is valid and not expired
  bool isQRDataValid(Map<String, dynamic> qrData) {
    try {
      final timestamp = qrData['timestamp'] as int;
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(qrTime);

      // QR code expires after 5 minutes
      return difference.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }
}
