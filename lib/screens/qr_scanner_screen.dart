import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'simplified_websocket_chat_screen.dart';
import '../models/user.dart';
import '../services/user_session_service.dart';
import '../services/database_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera permission to scan QR codes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        _hasScanned = true;
        cameraController.stop();
        _processQRCode(code);
      }
    }
  }

  void _processQRCode(String qrData) {
    try {
      final Map<String, dynamic> data = jsonDecode(qrData);

      if (data['type'] == 'chatlink_websocket') {
        _connectToWebSocketChat(data);
      } else {
        _showErrorDialog(
          'Invalid QR Code',
          'This QR code is not supported for chat connection.',
        );
      }
    } catch (e) {
      _showErrorDialog(
        'QR Code Error',
        'Failed to read QR code data: ${e.toString()}',
      );
    }
  }

  void _connectToWebSocketChat(Map<String, dynamic> qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host: ${qrData['hostName'] ?? 'Unknown'}'),
            Text('Phone: ${qrData['hostPhone'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            const Text('Do you want to connect to this chat?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startWebSocketConnection(qrData);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _startWebSocketConnection(Map<String, dynamic> qrData) async {
    try {
      // Get current user data
      final UserSessionService sessionService = UserSessionService();
      final DatabaseService databaseService = DatabaseService();

      final String? currentUserPhone = await sessionService.getCurrentUser();
      if (currentUserPhone == null) {
        _showErrorDialog('Error', 'No current user session found');
        return;
      }

      final User? currentUser = await databaseService.getUserByPhone(
        currentUserPhone,
      );
      if (currentUser == null) {
        _showErrorDialog('Error', 'Current user data not found');
        return;
      }

      // Parse and ensure proper types for server details
      final String? serverIP = qrData['ip']?.toString();
      final int? serverPort = qrData['port'] is int
          ? qrData['port']
          : int.tryParse(qrData['port']?.toString() ?? '');

      print('🔍 QR Scanner Debug:');
      print('  - Raw IP: ${qrData['ip']} (${qrData['ip'].runtimeType})');
      print('  - Raw Port: ${qrData['port']} (${qrData['port'].runtimeType})');
      print('  - Parsed IP: $serverIP');
      print('  - Parsed Port: $serverPort');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SimplifiedWebSocketChatScreen(
            currentUser: currentUser,
            remoteUserName: qrData['hostName'] ?? 'Host',
            remoteUserPhone: qrData['hostPhone'] ?? 'Unknown',
            sessionId: qrData['sessionId'],
            isHost: false,
            serverIp: serverIP,
            serverPort: serverPort,
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog(
        'Connection Error',
        'Failed to start connection: ${e.toString()}',
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
    });
    cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00A8FF), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: _onQRViewCreated,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Color(0xFF00A8FF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan QR Code to Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point your camera at a QR code to connect to a chat',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_hasScanned)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00A8FF),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
