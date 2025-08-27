import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for discovering devices over the internet using a lightweight discovery server
class InternetDiscoveryService {
  static final InternetDiscoveryService _instance = InternetDiscoveryService._internal();
  factory InternetDiscoveryService() => _instance;
  InternetDiscoveryService._internal();

  // Use a free service like Firebase Functions, or your own simple server
  static const String _discoveryServerUrl = 'https://your-discovery-server.com/api';

  final Map<String, dynamic> _registeredDevices = {};
  Timer? _heartbeatTimer;
  String? _deviceId;

  /// Register this device for discovery
  Future<bool> registerDevice({
    required String phoneNumber,
    required String deviceName,
    required String publicIP,
    required int port,
  }) async {
    try {
      _deviceId = phoneNumber;

      final response = await http.post(
        Uri.parse('$_discoveryServerUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': phoneNumber,
          'deviceName': deviceName,
          'publicIP': publicIP,
          'port': port,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200) {
        _startHeartbeat();
        return true;
      }
      return false;
    } catch (e) {
      print('Error registering device: $e');
      return false;
    }
  }

  /// Start sending heartbeat to keep device alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _sendHeartbeat();
    });
  }

  /// Send heartbeat to discovery server
  Future<void> _sendHeartbeat() async {
    if (_deviceId == null) return;

    try {
      await http.post(
        Uri.parse('$_discoveryServerUrl/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': _deviceId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      print('Heartbeat failed: $e');
    }
  }

  /// Discover devices by phone number
  Future<Map<String, dynamic>?> discoverDevice(String phoneNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_discoveryServerUrl/discover/$phoneNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['device'];
      }
      return null;
    } catch (e) {
      print('Error discovering device: $e');
      return null;
    }
  }

  /// Get your public IP address
  Future<String?> getPublicIP() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
      return null;
    } catch (e) {
      print('Error getting public IP: $e');
      return null;
    }
  }

  /// Unregister device
  Future<void> unregisterDevice() async {
    if (_deviceId == null) return;

    try {
      await http.delete(
        Uri.parse('$_discoveryServerUrl/unregister/$_deviceId'),
      );
      _heartbeatTimer?.cancel();
      _deviceId = null;
    } catch (e) {
      print('Error unregistering device: $e');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    unregisterDevice();
  }
}
