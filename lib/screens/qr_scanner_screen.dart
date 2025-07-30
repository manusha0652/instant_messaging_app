import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/user_session_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _torchOn = false;
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  MobileScannerController? cameraController;
  String? result;
  bool _hasScanned = false;
  bool _cameraInitialized = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request permission first
      await _requestCameraPermission();
      
      // Initialize camera controller
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
      print('Camera initialization error: $e');
      setState(() {
        _cameraError = 'Failed to initialize camera: $e';
        _cameraInitialized = false;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    
    if (status.isDenied) {
      throw Exception('Camera permission is required to scan QR codes');
    } else if (status.isPermanentlyDenied) {
      throw Exception('Camera permission permanently denied. Please enable in settings.');
    }
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
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(20),
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
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (result != null && !_hasScanned)
                    _buildScannedResult()
                  else
                    _buildInstructions(),
                ],
              ),
            ),
          ),
        ],
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
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
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
          onDetect: _onQRViewCreated,
          errorBuilder: (context, error, child) {
            return Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: \\${error.errorCode}',
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
            );
          },
          placeholderBuilder: (context, child) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00A8FF),
                ),
              ),
            );
          },
        ),
        // Custom overlay
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00A8FF),
              width: 3,
            ),
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
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Contact Found!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to add contact and start chatting',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _handleScanResult(result!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add),
            label: const Text(
              'Add Contact',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          Icon(
            Icons.qr_code_scanner,
            color: Color(0xFF00A8FF),
            size: 48,
          ),
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
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(BarcodeCapture capture) {
    if (!_hasScanned && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          result = barcode.rawValue;
          _hasScanned = true;
        });
      }
    }
  }

  Future<void> _handleScanResult(String scanResult) async {
    if (!_hasScanned) {
      setState(() {
        _hasScanned = true;
      });
    } else {
      return;
    }

    try {
      // Parse the QR code data
      final Map<String, dynamic> qrData = jsonDecode(scanResult);

      // Validate QR code format
      if (qrData['type'] != 'chatlink_contact') {
        _showError('Invalid QR code format');
        return;
      }

      final String contactName = qrData['name'] ?? 'Unknown';
      final String contactPhone = qrData['phone'] ?? '';

      if (contactPhone.isEmpty) {
        _showError('Invalid contact information');
        return;
      }

      // Check if user is trying to add themselves
      final String? currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone == contactPhone) {
        _showError('You cannot add yourself as a contact');
        return;
      }

      // Check if contact already exists
      final existingSession = await _databaseService.getChatSessionByPhone(contactPhone);
      if (existingSession != null) {
        _showError('Contact already exists in your chat list');
        return;
      }

      // Create new chat session
      await _databaseService.createChatSession(
        contactName: contactName,
        contactPhone: contactPhone,
        contactAvatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=$contactName&backgroundColor=1e3a5f',
      );

      // Show success message
      _showSuccessDialog(contactName);

    } catch (e) {
      _showError('Failed to add contact: ${e.toString()}');
    }
  }

  void _showSuccessDialog(String contactName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A4A6B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Contact Added!',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            '$contactName has been added to your contacts. You can now start chatting!',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to home
              },
              child: const Text(
                'Go to Chats',
                style: TextStyle(color: Color(0xFF00A8FF)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    setState(() {
      _hasScanned = false;
      result = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    if (cameraController != null) {
      cameraController!.dispose();
    }
    super.dispose();
  }
}
