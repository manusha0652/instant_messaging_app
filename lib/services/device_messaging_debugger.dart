import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'device_to_device_messaging_service.dart';

class DeviceMessagingDebugger {
  static final DeviceToDeviceMessagingService _messagingService = DeviceToDeviceMessagingService();

  /// Run comprehensive diagnostics for device-to-device messaging
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};

    // Check permissions
    results['permissions'] = await _checkPermissions();

    // Check storage access
    results['storage'] = await _checkStorageAccess();

    // Check file system
    results['fileSystem'] = await _checkFileSystem();

    // Check messaging service
    results['messagingService'] = await _checkMessagingService();

    return results;
  }

  /// Check storage permissions
  static Future<Map<String, bool>> _checkPermissions() async {
    final permissions = <String, bool>{};

    try {
      permissions['storage'] = await Permission.storage.isGranted;
      permissions['manageExternalStorage'] = await Permission.manageExternalStorage.isGranted;
      permissions['photos'] = await Permission.photos.isGranted;
    } catch (e) {
      print('Error checking permissions: $e');
    }

    return permissions;
  }

  /// Check storage access capabilities
  static Future<Map<String, dynamic>> _checkStorageAccess() async {
    final storage = <String, dynamic>{};

    try {
      // Test Downloads directory access
      final downloadsDir = Directory('/storage/emulated/0/Download');
      storage['downloadsExists'] = downloadsDir.existsSync();

      if (storage['downloadsExists']) {
        try {
          final testFile = File('${downloadsDir.path}/test_chatlink.txt');
          await testFile.writeAsString('test');
          storage['downloadsWritable'] = true;
          await testFile.delete();
        } catch (e) {
          storage['downloadsWritable'] = false;
          storage['downloadsError'] = e.toString();
        }
      }

      // Test external storage
      try {
        final externalDir = await getExternalStorageDirectory();
        storage['externalStorageAvailable'] = externalDir != null;
        if (externalDir != null) {
          storage['externalStoragePath'] = externalDir.path;
        }
      } catch (e) {
        storage['externalStorageError'] = e.toString();
      }

    } catch (e) {
      storage['error'] = e.toString();
    }

    return storage;
  }

  /// Check file system operations
  static Future<Map<String, dynamic>> _checkFileSystem() async {
    final fileSystem = <String, dynamic>{};

    try {
      final sharedPath = _messagingService.getSharedStoragePath();
      fileSystem['sharedStoragePath'] = sharedPath;

      if (sharedPath != null) {
        final dir = Directory(sharedPath);
        fileSystem['sharedStorageExists'] = dir.existsSync();

        if (dir.existsSync()) {
          // List files in directory
          final files = <String>[];
          await for (final entity in dir.list()) {
            files.add(entity.path.split('/').last);
          }
          fileSystem['filesInDirectory'] = files;

          // Test write access
          try {
            final testFile = File('$sharedPath/test_write.json');
            await testFile.writeAsString('{"test": true}');
            fileSystem['writeAccess'] = true;
            await testFile.delete();
          } catch (e) {
            fileSystem['writeAccess'] = false;
            fileSystem['writeError'] = e.toString();
          }
        }
      }
    } catch (e) {
      fileSystem['error'] = e.toString();
    }

    return fileSystem;
  }

  /// Check messaging service status
  static Future<Map<String, dynamic>> _checkMessagingService() async {
    final service = <String, dynamic>{};

    try {
      // Try to initialize the service
      final initialized = await _messagingService.initialize();
      service['initialized'] = initialized;
      service['sharedStoragePath'] = _messagingService.getSharedStoragePath();

    } catch (e) {
      service['error'] = e.toString();
    }

    return service;
  }

  /// Generate a diagnostic report
  static Future<String> generateReport() async {
    final diagnostics = await runDiagnostics();

    final buffer = StringBuffer();
    buffer.writeln('=== ChatLink Device-to-Device Messaging Diagnostics ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln();

    // Permissions
    buffer.writeln('PERMISSIONS:');
    final permissions = diagnostics['permissions'] as Map<String, bool>;
    permissions.forEach((key, value) {
      buffer.writeln('  $key: ${value ? "✓ GRANTED" : "✗ DENIED"}');
    });
    buffer.writeln();

    // Storage
    buffer.writeln('STORAGE ACCESS:');
    final storage = diagnostics['storage'] as Map<String, dynamic>;
    storage.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    // File System
    buffer.writeln('FILE SYSTEM:');
    final fileSystem = diagnostics['fileSystem'] as Map<String, dynamic>;
    fileSystem.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    // Messaging Service
    buffer.writeln('MESSAGING SERVICE:');
    final messagingService = diagnostics['messagingService'] as Map<String, dynamic>;
    messagingService.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    // Recommendations
    buffer.writeln('RECOMMENDATIONS:');

    if (!permissions['storage']!) {
      buffer.writeln('  • Grant storage permission to enable device-to-device messaging');
    }

    if (!permissions['manageExternalStorage']!) {
      buffer.writeln('  • Grant "All files access" permission for better cross-device compatibility');
    }

    if (storage['downloadsWritable'] == false) {
      buffer.writeln('  • Downloads folder not writable - using fallback storage');
    }

    if (fileSystem['writeAccess'] == false) {
      buffer.writeln('  • Cannot write to shared storage - device-to-device messaging will not work');
    }

    return buffer.toString();
  }
}
