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
      final status = await Permission.camera.request();
      if (status.isDenied) {
        setState(() {
          _cameraError = 'Camera permission denied';
        });
        return;
      }

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
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isDenied) {
        throw Exception('Camera permission is required to scan QR codes');
      }
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
                      if (result != null && !_hasScanned)
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
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Process the scanned result directly
              if (result != null) {
                _handleScanResult(result!);
              }
            },
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      if (barcode.rawValue != null && !_hasScanned) {
        setState(() {
          result = barcode.rawValue;
        });
        _handleScanResult(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _handleScanResult(String scannedData) async {
    if (_hasScanned) return;
    _hasScanned = true;

    try {
      // Parse QR code data
      final qrData = jsonDecode(scannedData);
      final contactPhone = qrData['phone'] as String;
      final contactName = qrData['name'] as String;
      final contactBio = qrData['bio'] as String?;
      final socketId = qrData['socketId'] as String?;

      // Get current user
      final currentUserPhone = await _sessionService.getCurrentUser();
      if (currentUserPhone == null) {
        _showErrorDialog('User session not found');
        return;
      }

      final currentUser = await _databaseService.getUserByPhone(currentUserPhone);
      if (currentUser == null) {
        _showErrorDialog('Current user not found');
        return;
      }

      // Check if trying to add themselves
      if (contactPhone == currentUserPhone) {
        _showErrorDialog('You cannot add yourself as a contact');
        return;
      }

      // Check if contact already exists
      final existingContact = await _databaseService.isContactExists(currentUser.id!, contactPhone);
      if (existingContact) {
        _showErrorDialog('Contact already exists');
        return;
      }

      // Add contact to database
      await _databaseService.addContact(
        userId: currentUser.id!,
        contactPhone: contactPhone,
        contactName: contactName,
        contactBio: contactBio,
      );

      // Create or get chat session
      final existingSession = await _databaseService.getChatSessionByUserAndPhone(currentUser.id!, contactPhone);

      if (existingSession == null) {
        await _databaseService.createChatSessionForUser(
          userId: currentUser.id!,
          contactName: contactName,
          contactPhone: contactPhone,
        );
      }

      // Show success dialog
      _showSuccessDialog(contactName);

    } catch (e) {
      _showErrorDialog('Invalid QR code format');
    }
  }

  void _showSuccessDialog(String contactName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Added'),
        content: Text('$contactName has been added to your contacts!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _hasScanned = false; // Allow scanning again
              });
            },
            child: const Text('OK'),
          ),
        ],
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
