import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/user_session_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import 'home_screen.dart';

class FingerprintAuthScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isSetup; // true for setting up, false for authentication

  const FingerprintAuthScreen({
    super.key,
    required this.phoneNumber,
    this.isSetup = false,
  });

  @override
  State<FingerprintAuthScreen> createState() => _FingerprintAuthScreenState();
}

class _FingerprintAuthScreenState extends State<FingerprintAuthScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final UserSessionService _sessionService = UserSessionService();
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  bool _usePinMode = false;
  bool _isConfirmingPin = false;
  bool _isCreatingNewPin = false;
  String _statusMessage = '';
  String _enteredPin = '';
  String _setupPin = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        if (!_isBiometricAvailable) {
          _statusMessage =
              'Biometric authentication not available on this device';
          _usePinMode = true; // Default to PIN if biometric not available
        }
      });

      if (_isBiometricAvailable && !widget.isSetup) {
        // Auto-trigger authentication for existing users
        Future.delayed(const Duration(milliseconds: 500), () {
          _authenticateWithBiometrics();
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking biometric availability: $e';
        _usePinMode = true; // Fallback to PIN
      });
    }
  }

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin + widget.phoneNumber); // Salt with phone number
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handlePinSetup(String pin) async {
    if (pin.length != 6) {
      setState(() {
        _statusMessage = 'PIN must be exactly 6 digits';
      });
      return;
    }

    if (!_isConfirmingPin) {
      setState(() {
        _setupPin = pin;
        _isConfirmingPin = true;
        _statusMessage = 'Please confirm your PIN';
        _enteredPin = '';
      });
      return;
    }

    if (pin != _setupPin) {
      setState(() {
        _statusMessage = 'PINs do not match. Please try again.';
        _isConfirmingPin = false;
        _isCreatingNewPin = false;
        _setupPin = '';
        _enteredPin = '';
      });
      return;
    }

    // Save PIN to database
    try {
      final User? user = await _databaseService.getUserByPhone(
        widget.phoneNumber,
      );
      if (user != null) {
        final updatedUser = User(
          id: user.id,
          name: user.name,
          phone: user.phone,
          bio: user.bio,
          profilePicture: user.profilePicture,
          pinHash: _hashPin(pin),
          createdAt: user.createdAt,
        );
        await _databaseService.updateUser(updatedUser);

        await _sessionService.saveUserSession(widget.phoneNumber);
        
        if (widget.isSetup) {
          _showSuccessAndNavigate('PIN setup completed successfully!');
        } else {
          _showSuccessAndNavigate('PIN created and authentication successful!');
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error saving PIN: $e';
      });
    }
  }

  Future<void> _handlePinLogin(String pin) async {
    if (pin.length != 6) {
      setState(() {
        _statusMessage = 'PIN must be exactly 6 digits';
      });
      return;
    }

    try {
      final User? user = await _databaseService.getUserByPhone(
        widget.phoneNumber,
      );
      if (user != null && user.pinHash != null) {
        // User has a PIN, verify it
        final String hashedPin = _hashPin(pin);
        if (hashedPin == user.pinHash) {
          await _sessionService.saveUserSession(widget.phoneNumber);
          _showSuccessAndNavigate('PIN authentication successful!');
        } else {
          setState(() {
            _statusMessage = 'Incorrect PIN. Please try again.';
            _enteredPin = '';
          });
        }
      } else if (user != null && user.pinHash == null) {
        // User exists but no PIN found - create new PIN
        setState(() {
          _statusMessage = 'No PIN found. Creating new PIN...';
          _isCreatingNewPin = true;
        });
        
        // Switch to PIN setup mode
        await _handlePinSetup(pin);
      } else {
        setState(() {
          _statusMessage = 'User account not found.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error verifying PIN: $e';
      });
    }
  }

  void _onPinDigitPressed(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _statusMessage = '';
      });

      if (_enteredPin.length == 6) {
        if (widget.isSetup || _isCreatingNewPin) {
          _handlePinSetup(_enteredPin);
        } else {
          _handlePinLogin(_enteredPin);
        }
      }
    }
  }

  void _onPinBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _statusMessage = '';
      });
    }
  }

  void _clearPin() {
    setState(() {
      _enteredPin = '';
      _statusMessage = '';
      if (widget.isSetup || _isCreatingNewPin) {
        _isConfirmingPin = false;
        _setupPin = '';
      }
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: widget.isSetup
            ? 'Set up your fingerprint for secure access to ChatLink'
            : 'Please authenticate to access ChatLink',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        // Save user session
        await _sessionService.saveUserSession(widget.phoneNumber);

        if (widget.isSetup) {
          _showSuccessAndNavigate('Fingerprint setup completed successfully!');
        } else {
          _showSuccessAndNavigate('Authentication successful!');
        }
      } else {
        setState(() {
          _statusMessage = 'Authentication failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Authentication error: $e';
        _isLoading = false;
      });
    }
  }

  void _showSuccessAndNavigate(String message) {
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });

    // Show success animation and navigate after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  void _skipForNow() {
    // For setup only - allow skipping biometric setup
    _sessionService.saveUserSession(widget.phoneNumber);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Widget _buildBiometricInterface() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fingerprint Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF00A8FF).withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00A8FF), width: 2),
          ),
          child: Icon(
            _isLoading ? Icons.hourglass_empty : Icons.fingerprint,
            size: 60,
            color: const Color(0xFF00A8FF),
          ),
        ),

        const SizedBox(height: 32),

        // Title
        Text(
          widget.isSetup ? 'Set Up Fingerprint' : 'Fingerprint Authentication',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          widget.isSetup
              ? 'Use your fingerprint to secure your account and quick access to ChatLink'
              : 'Please use your fingerprint to access your account',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Phone number
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A4A6B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.phoneNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Status message
        if (_statusMessage.isNotEmpty) _buildStatusMessage(),

        const SizedBox(height: 32),

        // Action button
        if (_isBiometricAvailable && !_isLoading)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _authenticateWithBiometrics,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A8FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    widget.isSetup ? 'Set Up Fingerprint' : 'Authenticate',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Loading indicator
        if (_isLoading)
          const Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF00A8FF)),
              SizedBox(height: 16),
              Text(
                'Authenticating...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPinInterface() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // PIN Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00A8FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00A8FF), width: 2),
              ),
              child: const Icon(Icons.pin, size: 50, color: Color(0xFF00A8FF)),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              widget.isSetup
                  ? (_isConfirmingPin ? 'Confirm Your PIN' : 'Set Up PIN')
                  : _isCreatingNewPin
                      ? (_isConfirmingPin ? 'Confirm Your New PIN' : 'Create Your PIN')
                      : 'Enter Your PIN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              widget.isSetup
                  ? (_isConfirmingPin
                        ? 'Re-enter your 6-digit PIN to confirm'
                        : 'Create a 6-digit PIN to secure your account')
                  : _isCreatingNewPin
                      ? (_isConfirmingPin
                            ? 'Re-enter your 6-digit PIN to confirm'
                            : 'No PIN found. Create a 6-digit PIN for your account')
                      : 'Enter your 6-digit PIN to access your account',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Phone number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4A6B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.phoneNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? const Color(0xFF00A8FF)
                        : const Color(0xFF2A4A6B),
                    border: Border.all(color: const Color(0xFF00A8FF), width: 1),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Status message
            if (_statusMessage.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildStatusMessage(),
              ),

            // PIN Keypad
            _buildPinKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            _statusMessage.contains('successful') ||
                _statusMessage.contains('completed')
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              _statusMessage.contains('successful') ||
                  _statusMessage.contains('completed')
              ? Colors.green
              : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusMessage.contains('successful') ||
                    _statusMessage.contains('completed')
                ? Icons.check_circle
                : Icons.error,
            color:
                _statusMessage.contains('successful') ||
                    _statusMessage.contains('completed')
                ? Colors.green
                : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color:
                    _statusMessage.contains('successful') ||
                        _statusMessage.contains('completed')
                    ? Colors.green
                    : Colors.red,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinKeypad() {
    return Column(
      children: [
        // Numbers 1-3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        // Numbers 4-6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        // Numbers 7-9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        // 0 and backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('clear', icon: Icons.clear),
            _buildKeypadButton('0'),
            _buildKeypadButton('backspace', icon: Icons.backspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String value, {IconData? icon}) {
    return GestureDetector(
      onTap: () {
        if (value == 'backspace') {
          _onPinBackspace();
        } else if (value == 'clear') {
          _clearPin();
        } else {
          _onPinDigitPressed(value);
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2A4A6B),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00A8FF).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              if (widget.isSetup)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    if (widget.isSetup)
                      TextButton(
                        onPressed: _skipForNow,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Color(0xFF00A8FF),
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),

              // Content
              Expanded(
                child: _usePinMode
                    ? _buildPinInterface()
                    : _buildBiometricInterface(),
              ),

              // Switch between modes
              if (_isBiometricAvailable && !widget.isSetup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _usePinMode = false;
                            _enteredPin = '';
                            _statusMessage = '';
                            _isCreatingNewPin = false;
                            _isConfirmingPin = false;
                          });
                        },
                        child: Text(
                          'Use Fingerprint',
                          style: TextStyle(
                            color: _usePinMode
                                ? Colors.white54
                                : const Color(0xFF00A8FF),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Text(
                        ' | ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _usePinMode = true;
                            _statusMessage = '';
                            _isCreatingNewPin = false;
                            _isConfirmingPin = false;
                          });
                        },
                        child: Text(
                          'Use PIN',
                          style: TextStyle(
                            color: !_usePinMode
                                ? Colors.white54
                                : const Color(0xFF00A8FF),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // For setup mode, show both options
              if (widget.isSetup && _isBiometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _usePinMode = false;
                              _enteredPin = '';
                              _statusMessage = '';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_usePinMode
                                ? const Color(0xFF00A8FF)
                                : const Color(0xFF2A4A6B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Fingerprint'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _usePinMode = true;
                              _enteredPin = '';
                              _statusMessage = '';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _usePinMode
                                ? const Color(0xFF00A8FF)
                                : const Color(0xFF2A4A6B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('PIN'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
