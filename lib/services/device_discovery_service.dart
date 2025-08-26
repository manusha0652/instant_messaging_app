import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'device_to_device_messaging_service.dart';

class DeviceDiscoveryService {
  static final DeviceDiscoveryService _instance = DeviceDiscoveryService._internal();
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._internal();

  final DeviceToDeviceMessagingService _messagingService = DeviceToDeviceMessagingService();
  Timer? _discoveryTimer;
  final StreamController<List<String>> _availableDevicesController = StreamController<List<String>>.broadcast();

  Stream<List<String>> get availableDevicesStream => _availableDevicesController.stream;

  /// Start device discovery
  Future<void> startDiscovery() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _scanForDevices();
    });
    
    // Initial scan
    await _scanForDevices();
  }

  /// Scan for other devices by looking for their message files
  Future<void> _scanForDevices() async {
    try {
      final sharedPath = _messagingService.getSharedStoragePath();
      if (sharedPath == null) return;

      final directory = Directory(sharedPath);
      if (!directory.existsSync()) return;

      final List<String> availableDevices = [];
      
      // Look for files that indicate other devices are active
      await for (final entity in directory.list()) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          
          // Look for device info files
          if (fileName.startsWith('device_info_') && fileName.endsWith('.json')) {
            try {
              final content = await entity.readAsString();
              final deviceInfo = jsonDecode(content);
              
              // Check if device was active recently (within last 5 minutes)
              final lastSeen = DateTime.fromMillisecondsSinceEpoch(deviceInfo['lastSeen']);
              final timeDiff = DateTime.now().difference(lastSeen);
              
              if (timeDiff.inMinutes < 5) {
                availableDevices.add(deviceInfo['phoneNumber']);
              }
            } catch (e) {
              // Ignore malformed files
            }
          }
        }
      }

      _availableDevicesController.add(availableDevices);
    } catch (e) {
      print('Error scanning for devices: $e');
    }
  }

  /// Announce this device's presence
  Future<void> announcePresence(String phoneNumber, String deviceName) async {
    try {
      final sharedPath = _messagingService.getSharedStoragePath();
      if (sharedPath == null) return;

      final deviceInfo = {
        'phoneNumber': phoneNumber,
        'deviceName': deviceName,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'platform': Platform.operatingSystem,
      };

      final file = File('$sharedPath/device_info_$phoneNumber.json');
      await file.writeAsString(jsonEncode(deviceInfo));
    } catch (e) {
      print('Error announcing presence: $e');
    }
  }

  /// Stop device discovery
  void stopDiscovery() {
    _discoveryTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    _discoveryTimer?.cancel();
    _availableDevicesController.close();
  }
}
