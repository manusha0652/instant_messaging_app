import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/message.dart';

class QRWebSocketService {
  static final QRWebSocketService _instance = QRWebSocketService._internal();
  factory QRWebSocketService() => _instance;
  QRWebSocketService._internal();

  // WebSocket server and client
  HttpServer? _server;
  WebSocketChannel? _clientChannel;
  WebSocketChannel? _serverChannel;

  // Connection info
  String? _localIP;
  int? _localPort;
  bool _isServer = false;
  bool _isConnected = false;
  String? _sessionId;

  // Stream controllers
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _connectionStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get connectionStream => _connectionStreamController.stream;
  bool get isConnected => _isConnected;
  String? get connectionInfo => _localIP != null && _localPort != null ? '$_localIP:$_localPort' : null;

  /// Initialize the QR WebSocket service
  Future<bool> initialize() async {
    try {
      await _getLocalIP();
      print('QR WebSocket Service initialized. Local IP: $_localIP');
      return true;
    } catch (e) {
      print('Error initializing QR WebSocket Service: $e');
      return false;
    }
  }

  /// Get local IP address
  Future<void> _getLocalIP() async {
    try {
      // Try to get WiFi/Network interface first
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

      // Look for WiFi interface first (usually starts with 'wlan' or similar)
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('eth')) {
          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
              // Check if it's a private network address
              final addressParts = address.address.split('.');
              if (addressParts.length == 4) {
                final firstOctet = int.tryParse(addressParts[0]) ?? 0;
                final secondOctet = int.tryParse(addressParts[1]) ?? 0;

                // Check for private IP ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
                if ((firstOctet == 192 && secondOctet == 168) ||
                    (firstOctet == 10) ||
                    (firstOctet == 172 && secondOctet >= 16 && secondOctet <= 31)) {
                  _localIP = address.address;
                  print('Found WiFi IP address: $_localIP on interface ${interface.name}');
                  return;
                }
              }
            }
          }
        }
      }

      // If no WiFi interface found, try any non-loopback IPv4 address
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            _localIP = address.address;
            print('Found IP address: $_localIP on interface ${interface.name}');
            return;
          }
        }
      }

      // Fallback to localhost if no network interface found
      _localIP = '192.168.1.100'; // Use a common private IP as fallback instead of localhost
      print('No network interface found, using fallback IP: $_localIP');
    } catch (e) {
      print('Error getting local IP: $e');
      _localIP = '192.168.1.100'; // Fallback IP
    }
  }

  /// Start WebSocket server (for QR code generator)
  Future<Map<String, dynamic>?> startServer({
    required String userName,
    required String userPhone,
    String? userBio,
  }) async {
    try {
      if (_server != null) {
        await stopServer();
      }

      // Find available port
      _localPort = await _findAvailablePort();

      // Start HTTP server
      _server = await HttpServer.bind(_localIP!, _localPort!);

      print('QR WebSocket server started on $_localIP:$_localPort');

      // Generate connection info for QR code
      final connectionInfo = {
        'type': 'qr_websocket_connection',
        'ip': _localIP,
        'port': _localPort,
        'userName': userName,
        'userPhone': userPhone,
        'userBio': userBio ?? '',
        'sessionId': _generateSessionId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _isServer = true;
      _sessionId = connectionInfo['sessionId'] as String;

      // Listen for WebSocket connections
      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/ws') {
          try {
            final socket = await WebSocketTransformer.upgrade(request);
            _handleServerConnection(socket);
          } catch (e) {
            print('Error upgrading to WebSocket: $e');
          }
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });

      _connectionStreamController.add({
        'type': 'server_started',
        'connectionInfo': connectionInfo,
      });

      return connectionInfo;
    } catch (e) {
      print('Error starting QR WebSocket server: $e');
      return null;
    }
  }

  /// Connect to WebSocket server (for QR code scanner)
  Future<bool> connectToServer({
    required String serverIP,
    required int serverPort,
    required String sessionId,
    required String userName,
    required String userPhone,
  }) async {
    try {
      if (_clientChannel != null) {
        await _clientChannel!.sink.close();
        _clientChannel = null;
      }

      final uri = Uri.parse('ws://$serverIP:$serverPort/ws');
      print('Connecting to QR WebSocket server: $uri');

      // Reset connection state
      _isConnected = false;
      _sessionId = sessionId;

      // Create connection
      _clientChannel = IOWebSocketChannel.connect(uri);

      // Create completer for connection establishment
      final connectionCompleter = Completer<bool>();
      bool connectionHandshakeComplete = false;

      // Listen for messages and connection events
      _clientChannel!.stream.listen(
        (data) {
          print('Received WebSocket data: $data');
          _handleMessage(data);

          // If we receive any message, the connection is established
          if (!connectionHandshakeComplete) {
            connectionHandshakeComplete = true;
            _isConnected = true;
            if (!connectionCompleter.isCompleted) {
              connectionCompleter.complete(true);
            }
          }
        },
        onError: (error) {
          print('WebSocket client error: $error');
          _handleDisconnection();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
        onDone: () {
          print('WebSocket client connection closed');
          _handleDisconnection();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
      );

      // Wait a moment for the connection to establish, then send connection request
      await Future.delayed(const Duration(milliseconds: 500));

      print('Sending connection request...');
      _sendMessage({
        'type': 'connection_request',
        'sessionId': sessionId,
        'userName': userName,
        'userPhone': userPhone,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Wait for connection handshake or timeout
      final result = await connectionCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('WebSocket connection timeout after 15 seconds');
          return false;
        },
      );

      if (result) {
        print('WebSocket connection established successfully');
        _connectionStreamController.add({
          'type': 'connected_to_server',
          'serverIP': serverIP,
          'serverPort': serverPort,
        });
      } else {
        print('Failed to establish WebSocket connection');
        if (_clientChannel != null) {
          await _clientChannel!.sink.close();
          _clientChannel = null;
        }
      }

      return result;
    } catch (e) {
      print('Error connecting to QR WebSocket server: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Handle server-side WebSocket connection
  void _handleServerConnection(WebSocket socket) {
    print('New WebSocket client connected');
    _serverChannel = IOWebSocketChannel(socket);
    _isConnected = true;

    _serverChannel!.stream.listen(
      (data) => _handleMessage(data),
      onError: (error) {
        print('WebSocket server error: $error');
        _handleDisconnection();
      },
      onDone: () {
        print('WebSocket server connection closed');
        _handleDisconnection();
      },
    );

    _connectionStreamController.add({
      'type': 'client_connected',
    });
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> messageData = jsonDecode(data.toString());
      final messageType = messageData['type'];

      switch (messageType) {
        case 'connection_request':
          _handleConnectionRequest(messageData);
          break;
        case 'connection_accepted':
          _handleConnectionAccepted(messageData);
          break;
        case 'chat_message':
          _handleChatMessage(messageData);
          break;
        case 'typing_indicator':
          _handleTypingIndicator(messageData);
          break;
        default:
          print('Unknown message type: $messageType');
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  /// Handle connection request
  void _handleConnectionRequest(Map<String, dynamic> data) {
    print('Received connection request from ${data['userName']}');

    // Auto-accept connection request
    _sendMessage({
      'type': 'connection_accepted',
      'sessionId': _sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _connectionStreamController.add({
      'type': 'connection_established',
      'remoteUser': {
        'name': data['userName'],
        'phone': data['userPhone'],
      },
    });
  }

  /// Handle connection accepted
  void _handleConnectionAccepted(Map<String, dynamic> data) {
    print('Connection accepted by server');

    _connectionStreamController.add({
      'type': 'connection_established',
    });
  }

  /// Handle chat message
  void _handleChatMessage(Map<String, dynamic> data) {
    try {
      final message = Message(
        id: int.tryParse(data['messageId']?.toString() ?? ''),
        sessionId: int.tryParse(_sessionId ?? '0') ?? 0,
        content: data['content'] ?? '',
        isFromMe: false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
        senderPhone: data['senderPhone'] ?? '',
        receiverPhone: null,
      );

      _messageStreamController.add(message);
    } catch (e) {
      print('Error handling chat message: $e');
    }
  }

  /// Handle typing indicator
  void _handleTypingIndicator(Map<String, dynamic> data) {
    _connectionStreamController.add({
      'type': 'typing_indicator',
      'isTyping': data['isTyping'] ?? false,
      'userName': data['userName'] ?? 'Unknown',
    });
  }

  /// Send chat message
  Future<bool> sendChatMessage({
    required String content,
    required String senderName,
    required String senderPhone,
  }) async {
    if (!_isConnected) {
      print('Cannot send message: not connected');
      return false;
    }

    try {
      final messageData = {
        'type': 'chat_message',
        'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': content,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'sessionId': _sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _sendMessage(messageData);

      // Also add to local stream
      final message = Message(
        id: int.tryParse(messageData['messageId'].toString()) ?? DateTime.now().millisecondsSinceEpoch,
        sessionId: int.tryParse(_sessionId ?? '0') ?? 0,
        content: content,
        isFromMe: true,
        timestamp: DateTime.now(),
        senderPhone: senderPhone,
        receiverPhone: null,
      );

      _messageStreamController.add(message);
      return true;
    } catch (e) {
      print('Error sending chat message: $e');
      return false;
    }
  }

  /// Send typing indicator
  void sendTypingIndicator({required bool isTyping, required String userName}) {
    if (_isConnected) {
      _sendMessage({
        'type': 'typing_indicator',
        'isTyping': isTyping,
        'userName': userName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Send message through WebSocket
  void _sendMessage(Map<String, dynamic> data) {
    try {
      final jsonData = jsonEncode(data);

      if (_isServer && _serverChannel != null) {
        _serverChannel!.sink.add(jsonData);
      } else if (!_isServer && _clientChannel != null) {
        _clientChannel!.sink.add(jsonData);
      }
    } catch (e) {
      print('Error sending WebSocket message: $e');
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    _isConnected = false;
    _connectionStreamController.add({
      'type': 'disconnected',
    });
  }

  /// Stop WebSocket server
  Future<void> stopServer() async {
    try {
      if (_serverChannel != null) {
        await _serverChannel!.sink.close();
        _serverChannel = null;
      }

      if (_server != null) {
        await _server!.close();
        _server = null;
      }

      _isServer = false;
      _isConnected = false;
      print('QR WebSocket server stopped');
    } catch (e) {
      print('Error stopping server: $e');
    }
  }

  /// Disconnect client
  Future<void> disconnect() async {
    try {
      if (_clientChannel != null) {
        await _clientChannel!.sink.close();
        _clientChannel = null;
      }

      _isConnected = false;
      print('QR WebSocket client disconnected');
    } catch (e) {
      print('Error disconnecting client: $e');
    }
  }

  /// Find available port
  Future<int> _findAvailablePort() async {
    final random = Random();
    for (int i = 0; i < 10; i++) {
      final port = 8000 + random.nextInt(2000); // Random port between 8000-9999
      try {
        final server = await HttpServer.bind(_localIP!, port);
        await server.close();
        return port;
      } catch (e) {
        // Port is taken, try next
        continue;
      }
    }
    throw Exception('Could not find available port');
  }

  /// Generate session ID
  String _generateSessionId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Dispose the service
  void dispose() {
    stopServer();
    disconnect();
    _messageStreamController.close();
    _connectionStreamController.close();
  }
}
