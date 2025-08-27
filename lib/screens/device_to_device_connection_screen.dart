import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enhanced_websocket_service.dart';
import '../services/internet_discovery_service.dart';
import '../services/user_session_service.dart';
import '../models/message.dart';

class DeviceToDeviceConnectionScreen extends StatefulWidget {
  const DeviceToDeviceConnectionScreen({Key? key}) : super(key: key);

  @override
  State<DeviceToDeviceConnectionScreen> createState() => _DeviceToDeviceConnectionScreenState();
}

class _DeviceToDeviceConnectionScreenState extends State<DeviceToDeviceConnectionScreen> {
  final EnhancedWebSocketService _webSocketService = EnhancedWebSocketService();
  final InternetDiscoveryService _discoveryService = InternetDiscoveryService();
  final UserSessionService _sessionService = UserSessionService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<Message> _messages = [];
  Map<String, dynamic> _connectedPeers = {};
  String _connectionStatus = 'Disconnected';
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _connectionStatus = 'Initializing...';
    });

    try {
      // Get current user
      _currentUserPhone = await _sessionService.getCurrentUser();

      // Initialize WebSocket service
      final connected = await _webSocketService.connect();

      if (connected) {
        setState(() {
          _connectionStatus = 'Connected - Ready for device-to-device messaging';
        });

        // Listen to messages
        _webSocketService.messageStream.listen((message) {
          setState(() {
            _messages.add(message);
          });
        });

        // Listen to connection events
        _webSocketService.connectionStream.listen((event) {
          if (event['event'] == 'peer_connected') {
            setState(() {
              _connectedPeers = _webSocketService.connectedPeers;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Device connected: ${event['peerName']} (${event['peerPhone']})'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });

        // Update connected peers
        setState(() {
          _connectedPeers = _webSocketService.connectedPeers;
        });
      } else {
        setState(() {
          _connectionStatus = 'Failed to connect';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _connectToDevice() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (phoneNumber == _currentUserPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot connect to yourself!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Searching for device...'),
          ],
        ),
      ),
    );

    try {
      final connected = await _webSocketService.connectToPeerByPhone(phoneNumber);

      Navigator.of(context).pop(); // Close loading dialog

      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to device with phone: $phoneNumber'),
            backgroundColor: Colors.green,
          ),
        );
        _phoneController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device with phone $phoneNumber not found or not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _connectedPeers.isEmpty) return;

    // For demo, send to the first connected peer
    final firstPeerPhone = _connectedPeers.keys.first;

    try {
      final sent = await _webSocketService.sendMessage(
        toPhone: firstPeerPhone,
        content: message,
        sessionId: 1, // Demo session ID
      );

      if (sent) {
        _messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device-to-Device Messaging'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_connectionStatus),
                  if (_currentUserPhone != null) ...[
                    const SizedBox(height: 8),
                    Text('Your Phone: $_currentUserPhone'),
                  ],
                  const SizedBox(height: 8),
                  Text('Connected Devices: ${_connectedPeers.length}'),
                ],
              ),
            ),
          ),

          // Connection Controls
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect to Another Device',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the phone number of the device you want to connect to:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+1234567890',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _connectToDevice,
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Connected Peers
          if (_connectedPeers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Connected Devices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(16),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _connectedPeers.length,
                itemBuilder: (context, index) {
                  final phone = _connectedPeers.keys.elementAt(index);
                  final peer = _connectedPeers[phone];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.phone_android),
                    ),
                    title: Text(peer['name'] ?? 'Unknown'),
                    subtitle: Text(phone),
                    trailing: const Icon(
                      Icons.circle,
                      color: Colors.green,
                      size: 12,
                    ),
                  );
                },
              ),
            ),
          ],

          // Messages
          if (_connectedPeers.isNotEmpty) ...[
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Messages',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isFromMe = message.senderId == _currentUserPhone;

                          return Align(
                            alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isFromMe ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isFromMe)
                                    Text(
                                      message.senderId ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isFromMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isFromMe ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Message input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send),
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Instructions
          if (_connectedPeers.isEmpty)
            Expanded(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'How to Connect Devices',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '1. Install this app on another device\n'
                          '2. Make sure both devices have internet\n'
                          '3. Create accounts with different phone numbers\n'
                          '4. Enter the other device\'s phone number above\n'
                          '5. Start chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Note: Both devices need to be running the app and connected to the internet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
