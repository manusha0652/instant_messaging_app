import 'package:flutter/material.dart';
import '../services/device_to_device_messaging_service.dart';
import '../services/device_messaging_debugger.dart';
import '../services/device_discovery_service.dart';

class DeviceMessagingTestScreen extends StatefulWidget {
  const DeviceMessagingTestScreen({Key? key}) : super(key: key);

  @override
  State<DeviceMessagingTestScreen> createState() => _DeviceMessagingTestScreenState();
}

class _DeviceMessagingTestScreenState extends State<DeviceMessagingTestScreen> {
  final DeviceToDeviceMessagingService _messagingService = DeviceToDeviceMessagingService();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _diagnosticReport = '';
  bool _isInitialized = false;
  List<String> _availableDevices = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final initialized = await _messagingService.initialize();
      setState(() {
        _isInitialized = initialized;
      });

      if (initialized) {
        // Start device discovery
        await _discoveryService.startDiscovery();

        // Listen for available devices
        _discoveryService.availableDevicesStream.listen((devices) {
          setState(() {
            _availableDevices = devices;
          });
        });

        // Listen for incoming messages
        _messagingService.messageStream.listen((message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New message: ${message.content}'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runDiagnostics() async {
    final report = await DeviceMessagingDebugger.generateReport();
    setState(() {
      _diagnosticReport = report;
    });
  }

  Future<void> _sendTestMessage() async {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in phone number and message')),
      );
      return;
    }

    final success = await _messagingService.sendMessage(
      contactPhone: _phoneController.text,
      content: _messageController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Message sent!' : 'Failed to send message'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Messaging Test'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_isInitialized ? 'Initialized' : 'Not Initialized'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Storage Path: ${_messagingService.getSharedStoragePath() ?? 'Not set'}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Available Devices
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Devices (${_availableDevices.length})',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_availableDevices.isEmpty)
                      const Text('No devices found')
                    else
                      Column(
                        children: _availableDevices.map((device) =>
                          ListTile(
                            leading: const Icon(Icons.phone_android),
                            title: Text(device),
                            onTap: () {
                              _phoneController.text = device;
                            },
                          )
                        ).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Send Message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Test Message',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isInitialized ? _sendTestMessage : null,
                        child: const Text('Send Message'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Diagnostics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diagnostics',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _runDiagnostics,
                        child: const Text('Run Diagnostics'),
                      ),
                    ),
                    if (_diagnosticReport.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _diagnosticReport,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
