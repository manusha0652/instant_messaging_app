import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/qr_websocket_service.dart';
import 'qr_websocket_chat_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _torchOn = false;
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final QRWebSocketService _webSocketService = QRWebSocketService();
  MobileScannerController? cameraController;
  bool _hasScanned = false;
  bool _cameraInitialized = false;
  String? _cameraError;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _webSocketService.initialize();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied) {
        setState(() {
          _cameraError = 'Camera permission denied';
        });
        return;
      }

      cameraController = MobileScannerController(
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
      );

      setState(() {
        _cameraInitialized = true;
        _cameraError = null;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _processQRCode(String qrData) async {
    if (_isProcessing || _hasScanned) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    // Stop the camera immediately to prevent multiple scans
    if (cameraController != null) {
      await cameraController!.stop();
    }

    try {
      final Map<String, dynamic> data = jsonDecode(qrData);

      if (data['type'] == 'qr_websocket_connection') {
        await _handleWebSocketConnection(data);
      } else {
        throw Exception('Invalid QR code type. Expected WebSocket connection.');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _hasScanned = false;
      });

      // Restart camera if there was an error
      if (cameraController != null) {
        await cameraController!.start();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleWebSocketConnection(Map<String, dynamic> qrData) async {
    try {
      final String? currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone == null) {
        throw Exception('No user session found');
      }

      final currentUser = await _databaseService.getUserByPhone(currentUserPhone);
      if (currentUser == null) {
        throw Exception('Current user not found in database');
      }

      final String serverIP = qrData['ip'] ?? '';
      final int serverPort = qrData['port'] ?? 0;
      final String sessionId = qrData['sessionId'] ?? '';
      final String remoteUserName = qrData['userName'] ?? 'Unknown User';
      final String remoteUserPhone = qrData['userPhone'] ?? '';
      final String remoteUserBio = qrData['userBio'] ?? '';

      if (serverIP.isEmpty || serverPort == 0 || sessionId.isEmpty) {
        throw Exception('Invalid QR code: Missing connection info');
      }

      if (remoteUserPhone == currentUserPhone) {
        throw Exception('Cannot connect to yourself');
      }

      if (mounted) {
        final bool? shouldConnect = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A4A6B),
            title: const Text(
              'Connect via WebSocket',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect to WebSocket server:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  remoteUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  remoteUserPhone,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (remoteUserBio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    remoteUserBio,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'WebSocket Connection',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Server: $serverIP:$serverPort',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                      Text(
                        'Session: $sessionId',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A8FF),
                ),
                child: const Text('Connect', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldConnect == true && mounted) {
          // Show connecting dialog with more details
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2A4A6B),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Connecting to WebSocket server...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Server: $serverIP:$serverPort',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Make sure both devices are on the same WiFi network',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );

          // Connect to WebSocket server with detailed error handling
          try {
            final success = await _webSocketService.connectToServer(
              serverIP: serverIP,
              serverPort: serverPort,
              sessionId: sessionId,
              userName: currentUser.name,
              userPhone: currentUser.phone,
            );

            if (mounted) {
              Navigator.of(context).pop(); // Close connecting dialog
            }

            if (success && mounted) {
              // Navigate to WebSocket chat screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => QRWebSocketChatScreen(
                    remoteUserName: remoteUserName,
                    remoteUserPhone: remoteUserPhone,
                    sessionId: sessionId,
                    serverInfo: '$serverIP:$serverPort',
                  ),
                ),
              );
            } else {
              if (mounted) {
                _showDetailedError(serverIP, serverPort);
              }
              setState(() {
                _isProcessing = false;
                _hasScanned = false;
              });
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Close connecting dialog
              _showDetailedError(serverIP, serverPort, error: e.toString());
            }
            setState(() {
              _isProcessing = false;
              _hasScanned = false;
            });
          }
        } else {
          setState(() {
            _isProcessing = false;
            _hasScanned = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _hasScanned = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetailedError(String serverIP, int serverPort, {String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A4A6B),
        title: const Text(
          'Connection Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null) ...[
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Unable to connect to the WebSocket server.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Server IP: $serverIP',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
            ),
            Text(
              'Server Port: $serverPort',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Troubleshooting Tips:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Ensure the server is running.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Text(
              '• Check your internet connection.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Text(
              '• Make sure both devices are on the same WiFi network.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_cameraInitialized && cameraController != null)
            IconButton(
              onPressed: () {
                cameraController!.toggleTorch();
                setState(() {
                  _torchOn = !_torchOn;
                });
              },
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera section - responsive height
            Flexible(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  minHeight: 300,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildCameraView(),
                ),
              ),
            ),

            // Bottom section - adaptive height
            Flexible(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasScanned)
                        _buildScannedResult()
                      else
                        _buildInstructions(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A8FF),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00A8FF)),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: cameraController!,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) => Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error: ${error.errorCode}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8FF),
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          placeholderBuilder: (context, child) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A8FF)),
            ),
          ),
        ),
        // Custom overlay
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00A8FF), width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildScannedResult() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A4A6B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'QR Code Detected!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Processing connection...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A4A6B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_scanner, color: Color(0xFF00A8FF), size: 48),
          SizedBox(height: 12),
          Text(
            'Point your camera at a QR code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'The QR code will be scanned automatically',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && !_hasScanned && !_isProcessing) {
        setState(() {
          _hasScanned = true;
        });
        _processQRCode(barcode.rawValue!);
        break;
      }
    }
  }

  @override
  void dispose() {
    if (cameraController != null) {
      cameraController!.dispose();
    }
    super.dispose();
  }
}
