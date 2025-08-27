import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/qr_websocket_service.dart';
import '../models/user.dart';
import 'dart:async';

class QRProfileScreen extends StatefulWidget {
  const QRProfileScreen({super.key});

  @override
  State<QRProfileScreen> createState() => _QRProfileScreenState();
}

class _QRProfileScreenState extends State<QRProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final QRWebSocketService _webSocketService = QRWebSocketService();

  User? _currentUser;
  bool _isLoading = true;
  String _qrData = '';
  Map<String, dynamic>? _connectionInfo;
  bool _isServerRunning = false;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    await _webSocketService.initialize();
    await _loadUserDataAndStartServer();

    // Listen for connection events
    _connectionSubscription = _webSocketService.connectionStream.listen((event) {
      if (mounted) {
        switch (event['type']) {
          case 'server_started':
            setState(() {
              _isServerRunning = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('QR server started - ready for connections!'),
                backgroundColor: Colors.green,
              ),
            );
            break;
          case 'client_connected':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device connected via QR code!'),
                backgroundColor: Colors.blue,
              ),
            );
            break;
          case 'connection_established':
            final remoteUser = event['remoteUser'];
            if (remoteUser != null) {
              _showConnectionEstablished(remoteUser);
            }
            break;
        }
      }
    });
  }

  Future<void> _loadUserDataAndStartServer() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final String? currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone != null) {
        final User? user = await _databaseService.getUserByPhone(currentUserPhone);
        if (user != null) {
          setState(() {
            _currentUser = user;
          });

          // Start WebSocket server
          final connectionInfo = await _webSocketService.startServer(
            userName: user.name,
            userPhone: user.phone,
            userBio: user.bio,
          );

          if (connectionInfo != null) {
            setState(() {
              _connectionInfo = connectionInfo;
              _qrData = jsonEncode(connectionInfo);
              _isLoading = false;
            });
            print('QR WebSocket server started: ${connectionInfo['ip']}:${connectionInfo['port']}');
          } else {
            throw Exception('Failed to start WebSocket server');
          }
        } else {
          throw Exception('User not found in database');
        }
      } else {
        throw Exception('No current user session found');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConnectionEstablished(Map<String, dynamic> remoteUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A4A6B),
        title: const Text(
          'Device Connected!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '${remoteUser['name']} has connected to your QR code',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              remoteUser['phone'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8FF),
            ),
            child: const Text('Start Chatting', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareQRCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: _qrData));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection info copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _regenerateQR() {
    _webSocketService.stopServer().then((_) {
      _loadUserDataAndStartServer();
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _webSocketService.stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4A6B),
        foregroundColor: Colors.white,
        title: const Text('My QR Code'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _regenerateQR,
            tooltip: 'Regenerate QR Code',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Connection Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isServerRunning ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isServerRunning ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isServerRunning ? Icons.wifi : Icons.wifi_off,
                          color: _isServerRunning ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isServerRunning
                                ? 'WebSocket Server Running - Ready for connections!'
                                : 'Starting WebSocket server...',
                            style: TextStyle(
                              color: _isServerRunning ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // User info card
                  if (_currentUser != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF00A8FF),
                            child: Text(
                              _currentUser!.name.isNotEmpty
                                  ? _currentUser!.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _currentUser!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _currentUser!.phone,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          if (_currentUser!.bio != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _currentUser!.bio!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        if (_qrData.isNotEmpty)
                          QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 250.0,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        const SizedBox(height: 15),
                        const Text(
                          'Scan this QR code to connect',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Connection info display
                  if (_connectionInfo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WebSocket Server Info:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'IP: ${_connectionInfo!['ip']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Port: ${_connectionInfo!['port']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Session: ${_connectionInfo!['sessionId']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareQRCode,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Info'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A8FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _regenerateQR,
                          icon: const Icon(Icons.refresh),
                          label: const Text('New Server'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Instructions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How WebSocket QR Connection Works:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1. Your device starts a WebSocket server\n'
                          '2. QR code contains server IP, port, and session info\n'
                          '3. Other device scans QR and connects to your server\n'
                          '4. Real-time chat begins through WebSocket connection\n'
                          '5. Both devices can send/receive messages instantly',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
