import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/message.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/internet_discovery_service.dart';

/// Enhanced WebSocket service supporting both local and internet connections
class EnhancedWebSocketService {
  static final EnhancedWebSocketService _instance =
      EnhancedWebSocketService._internal();
  factory EnhancedWebSocketService() => _instance;
  EnhancedWebSocketService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final InternetDiscoveryService _discoveryService = InternetDiscoveryService();

  HttpServer? _server;
  final Map<String, WebSocket> _connectedClients = {};
  final Map<String, Map<String, dynamic>> _connectedPeers = {};

  // Stream controllers
  final StreamController<Message> _messageStreamController =
      StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _typingStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _qrConnectionStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get typingStream =>
      _typingStreamController.stream;
  Stream<Map<String, dynamic>> get userStatusStream =>
      _userStatusStreamController.stream;
  Stream<Map<String, dynamic>> get connectionStream =>
      _connectionStreamController.stream;
  Stream<Map<String, dynamic>> get qrConnectionStream =>
      _qrConnectionStreamController.stream;

  bool _isConnected = false;
  String? _currentSocketId;
  String? _localIP;
  int? _localPort;
  String? _publicIP;

  // Getters
  bool get isConnected => _isConnected;
  String? get currentSocketId => _currentSocketId;
  Map<String, dynamic> get connectedPeers =>
      Map<String, dynamic>.from(_connectedPeers);
  String? get localIP => _localIP;
  int? get localPort => _localPort;

  /// Initialize the enhanced WebSocket service
  Future<bool> connect() async {
    try {
      // Get current user
      final userPhone = await _sessionService.getCurrentUser();
      if (userPhone == null) return false;

      final user = await _databaseService.getUserByPhone(userPhone);
      if (user == null) return false;

      // Get local IP
      _localIP = await _getLocalIP();

      // Get public IP for internet discovery
      _publicIP = await _discoveryService.getPublicIP();

      // Start local WebSocket server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _localPort = _server!.port;

      print('WebSocket server started on $_localIP:$_localPort');

      // Handle incoming connections
      _server!.transform(WebSocketTransformer()).listen(_handleConnection);

      // Register for internet discovery
      if (_publicIP != null) {
        await _discoveryService.registerDevice(
          phoneNumber: userPhone,
          deviceName: user.name,
          publicIP: _publicIP!,
          port: _localPort!,
        );
        print('Device registered for internet discovery');
      }

      _isConnected = true;
      _currentSocketId =
          '${userPhone}_${DateTime.now().millisecondsSinceEpoch}';

      return true;
    } catch (e) {
      print('Error starting WebSocket service: $e');
      return false;
    }
  }

  /// Handle incoming WebSocket connections
  void _handleConnection(WebSocket webSocket) {
    print('New WebSocket connection established');

    webSocket.listen(
      (data) => _handleMessage(webSocket, data),
      onDone: () => _handleDisconnection(webSocket),
      onError: (error) => print('WebSocket error: $error'),
    );
  }

  /// Handle incoming messages
  void _handleMessage(WebSocket webSocket, dynamic data) async {
    try {
      final message = jsonDecode(data);
      final messageType = message['type'];

      switch (messageType) {
        case 'peer_info':
          await _handlePeerInfo(webSocket, message);
          break;
        case 'chat_message':
          await _handleChatMessage(message);
          break;
        case 'typing_status':
          _handleTypingStatus(message);
          break;
        case 'ping':
          _sendPong(webSocket);
          break;
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  /// Handle peer information exchange
  Future<void> _handlePeerInfo(
    WebSocket webSocket,
    Map<String, dynamic> message,
  ) async {
    final peerPhone = message['phone'];
    final peerName = message['name'];

    if (peerPhone != null) {
      _connectedClients[peerPhone] = webSocket;
      _connectedPeers[peerPhone] = {
        'name': peerName,
        'phone': peerPhone,
        'connectedAt': DateTime.now().toIso8601String(),
        'isOnline': true,
      };

      print('Peer connected: $peerName ($peerPhone)');

      // Notify about new connection
      _connectionStreamController.add({
        'event': 'peer_connected',
        'peerPhone': peerPhone,
        'peerName': peerName,
      });

      // Send our info back
      final currentUser = await _getCurrentUser();
      if (currentUser != null) {
        _sendMessage(webSocket, {
          'type': 'peer_info',
          'phone': currentUser.phone,
          'name': currentUser.name,
        });
      }
    }
  }

  /// Handle incoming chat messages
  Future<void> _handleChatMessage(Map<String, dynamic> messageData) async {
    try {
      final message = Message(
        sessionId: messageData['sessionId'],
        content: messageData['content'],
        isFromMe: false, // Incoming message
        timestamp: DateTime.parse(messageData['timestamp']),
        messageType: messageData['messageType'] ?? 'text',
        senderPhone: messageData['senderId'],
        receiverPhone: messageData['receiverId'],
      );

      // Save to database
      await _databaseService.insertMessage(
        sessionId: message.sessionId,
        content: message.content,
        isFromMe: message.isFromMe,
        timestamp: message.timestamp,
        messageType: message.messageType,
      );

      // Notify listeners
      _messageStreamController.add(message);

      print('Message received from ${message.senderId}: ${message.content}');
    } catch (e) {
      print('Error handling chat message: $e');
    }
  }

  /// Handle typing status
  void _handleTypingStatus(Map<String, dynamic> message) {
    _typingStreamController.add(message);
  }

  /// Connect to a peer via phone number (internet discovery)
  Future<bool> connectToPeerByPhone(String phoneNumber) async {
    try {
      // Try to discover device via internet
      final deviceInfo = await _discoveryService.discoverDevice(phoneNumber);

      if (deviceInfo != null) {
        return await _connectToPeerDirect(
          deviceInfo['publicIP'],
          deviceInfo['port'],
          phoneNumber,
          deviceInfo['deviceName'],
        );
      }

      print('Device not found for phone: $phoneNumber');
      return false;
    } catch (e) {
      print('Error connecting to peer by phone: $e');
      return false;
    }
  }

  /// Connect directly to a peer
  Future<bool> _connectToPeerDirect(
    String ip,
    int port,
    String phone,
    String name,
  ) async {
    try {
      final webSocket = await WebSocket.connect('ws://$ip:$port');

      // Send our info
      final currentUser = await _getCurrentUser();
      if (currentUser != null) {
        _sendMessage(webSocket, {
          'type': 'peer_info',
          'phone': currentUser.phone,
          'name': currentUser.name,
        });
      }

      // Store connection
      _connectedClients[phone] = webSocket;
      _connectedPeers[phone] = {
        'name': name,
        'phone': phone,
        'ip': ip,
        'port': port,
        'connectedAt': DateTime.now().toIso8601String(),
        'isOnline': true,
      };

      // Listen for messages
      webSocket.listen(
        (data) => _handleMessage(webSocket, data),
        onDone: () => _handleDisconnection(webSocket),
        onError: (error) => print('Peer connection error: $error'),
      );

      print('Connected to peer: $name ($phone) at $ip:$port');

      _connectionStreamController.add({
        'event': 'peer_connected',
        'peerPhone': phone,
        'peerName': name,
      });

      return true;
    } catch (e) {
      print('Error connecting to peer directly: $e');
      return false;
    }
  }

  /// Send a message to a specific peer
  Future<bool> sendMessage({
    required String toPhone,
    required String content,
    required int sessionId,
    String messageType = 'text',
  }) async {
    try {
      final currentUser = await _getCurrentUser();
      if (currentUser == null) return false;

      // Create message object
      final message = Message(
        sessionId: sessionId,
        content: content,
        isFromMe: true,
        timestamp: DateTime.now(),
        messageType: messageType,
        senderPhone: currentUser.phone,
        receiverPhone: toPhone,
      );

      // Save to local database
      await _databaseService.insertMessage(
        sessionId: sessionId,
        content: content,
        isFromMe: true,
        timestamp: DateTime.now(),
        messageType: messageType,
      );

      // Send to peer if connected
      final peerSocket = _connectedClients[toPhone];
      if (peerSocket != null) {
        _sendMessage(peerSocket, {
          'type': 'chat_message',
          'senderId': currentUser.phone,
          'receiverId': toPhone,
          'content': content,
          'messageType': messageType,
          'timestamp': DateTime.now().toIso8601String(),
          'sessionId': sessionId,
        });

        return true;
      } else {
        // Try to connect and send
        if (await connectToPeerByPhone(toPhone)) {
          return await sendMessage(
            toPhone: toPhone,
            content: content,
            sessionId: sessionId,
            messageType: messageType,
          );
        }
      }

      return false;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Send typing status
  Future<void> sendTypingStatus(String toPhone, bool isTyping) async {
    final peerSocket = _connectedClients[toPhone];
    if (peerSocket != null) {
      final currentUser = await _getCurrentUser();
      if (currentUser != null) {
        _sendMessage(peerSocket, {
          'type': 'typing_status',
          'fromPhone': currentUser.phone,
          'toPhone': toPhone,
          'isTyping': isTyping,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  /// Check if peer is online
  bool isPeerOnline(String contactPhone) {
    return _connectedPeers.containsKey(contactPhone) &&
        _connectedPeers[contactPhone]?['isOnline'] == true;
  }

  /// Send message via WebSocket
  void _sendMessage(WebSocket webSocket, Map<String, dynamic> message) {
    try {
      webSocket.add(jsonEncode(message));
    } catch (e) {
      print('Error sending WebSocket message: $e');
    }
  }

  /// Send pong response
  void _sendPong(WebSocket webSocket) {
    _sendMessage(webSocket, {'type': 'pong'});
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection(WebSocket webSocket) {
    // Find and remove the disconnected peer
    String? disconnectedPhone;
    _connectedClients.forEach((phone, socket) {
      if (socket == webSocket) {
        disconnectedPhone = phone;
      }
    });

    if (disconnectedPhone != null) {
      _connectedClients.remove(disconnectedPhone);
      _connectedPeers[disconnectedPhone!]?['isOnline'] = false;

      print('Peer disconnected: $disconnectedPhone');

      _connectionStreamController.add({
        'event': 'peer_disconnected',
        'peerPhone': disconnectedPhone,
      });
    }
  }

  /// Get current user
  Future<User?> _getCurrentUser() async {
    final userPhone = await _sessionService.getCurrentUser();
    if (userPhone == null) return null;
    return await _databaseService.getUserByPhone(userPhone);
  }

  /// Get local IP address
  Future<String?> _getLocalIP() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting local IP: $e');
      return null;
    }
  }

  /// Generate QR code data (enhanced with internet discovery)
  Map<String, dynamic> generateQRData() {
    final currentUser = _getCurrentUser();
    return {
      'ip': _localIP,
      'port': _localPort,
      'publicIP': _publicIP,
      'phone': currentUser != null ? currentUser.then((u) => u?.phone) : null,
      'name': currentUser != null ? currentUser.then((u) => u?.name) : null,
      'socketId': _currentSocketId,
      'type': 'enhanced_p2p',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Connect via QR code data
  Future<bool> connectToPeerViaQR(Map<String, dynamic> qrData) async {
    try {
      final ip = qrData['ip'] ?? qrData['publicIP'];
      final port = qrData['port'];
      final phone = qrData['phone'];
      final name = qrData['name'];

      if (ip != null && port != null && phone != null) {
        return await _connectToPeerDirect(ip, port, phone, name ?? 'Unknown');
      }
      return false;
    } catch (e) {
      print('Error connecting via QR: $e');
      return false;
    }
  }

  /// Disconnect from service
  Future<void> disconnect() async {
    try {
      // Unregister from discovery service
      await _discoveryService.unregisterDevice();

      // Close all peer connections
      for (var socket in _connectedClients.values) {
        await socket.close();
      }
      _connectedClients.clear();
      _connectedPeers.clear();

      // Close server
      await _server?.close();

      _isConnected = false;
      _currentSocketId = null;

      print('Enhanced WebSocket service disconnected');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageStreamController.close();
    _typingStreamController.close();
    _userStatusStreamController.close();
    _connectionStreamController.close();
    _qrConnectionStreamController.close();
    _discoveryService.dispose();
  }
}
