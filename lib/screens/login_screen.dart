import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/pin_input_widget.dart';
import '../widgets/user_avatar.dart';
import '../utils/constants.dart';
import '../themes/app_theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserModel? _user;
  String _pin = '';
  bool _isLoading = false;
  bool _showPinInput = false;
  bool _biometricFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await DatabaseService.instance.getUser();
      setState(() {
        _user = user;
      });

      if (user?.biometricEnabled == true && !_biometricFailed) {
        _tryBiometricLogin();
      } else {
        setState(() {
          _showPinInput = true;
        });
      }
    } catch (e) {
      setState(() {
        _showPinInput = true;
      });
    }
  }

  Future<void> _tryBiometricLogin() async {
    try {
      final isAuthenticated = await AuthService.instance
          .authenticateWithBiometrics();
      if (isAuthenticated) {
        _loginSuccess();
      } else {
        setState(() {
          _biometricFailed = true;
          _showPinInput = true;
        });
      }
    } catch (e) {
      setState(() {
        _biometricFailed = true;
        _showPinInput = true;
      });
    }
  }

  Future<void> _loginWithPin() async {
    if (_user == null || _pin.length < AppConstants.minPinLength) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = AuthService.instance.validatePin(_pin, _user!.pinHash);
      if (isValid) {
        _loginSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _pin = '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _loginSuccess() async {
    try {
      final sessionId = AuthService.instance.generateSessionId();
      await AuthService.instance.storeSession(sessionId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create session. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    _buildLogo(),
                    const SizedBox(height: 40),

                    // User Profile
                    if (_user != null) _buildUserProfile(),
                    const SizedBox(height: 40),

                    // Login Content
                    if (!_showPinInput) _buildBiometricPrompt(),
                    if (_showPinInput) _buildPinLogin(),
                  ],
                ),
              ),

              // Alternative Login Options
              if (_showPinInput) _buildAlternativeOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.chat_bubble_outline,
        size: 50,
        color: AppColors.textLight,
      ),
    );
  }

  Widget _buildUserProfile() {
    return Column(
      children: [
        UserAvatar(
          name: _user!.name,
          imagePath: _user!.profilePicturePath,
          size: 80,
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome back, ${_user!.name}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricPrompt() {
    return Column(
      children: [
        const Icon(Icons.fingerprint, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        const Text(
          'Use fingerprint to unlock',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Touch the fingerprint sensor to continue',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Try Again',
          onPressed: _tryBiometricLogin,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildPinLogin() {
    return Column(
      children: [
        const Text(
          'Enter your PIN',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your secure PIN to continue',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        PinInputWidget(
          pinLength: 6,
          onCompleted: (pin) {
            setState(() {
              _pin = pin;
            });
            _loginWithPin();
          },
          onChanged: (pin) {
            setState(() {
              _pin = pin;
            });
          },
        ),
        const SizedBox(height: 32),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          CustomButton(
            text: 'Login',
            onPressed: _pin.length >= AppConstants.minPinLength
                ? _loginWithPin
                : null,
            width: double.infinity,
          ),
      ],
    );
  }

  Widget _buildAlternativeOptions() {
    return Column(
      children: [
        if (_user?.biometricEnabled == true && _biometricFailed)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _biometricFailed = false;
                _showPinInput = false;
              });
              _tryBiometricLogin();
            },
            icon: const Icon(Icons.fingerprint),
            label: const Text('Use Fingerprint'),
          ),
        TextButton(
          onPressed: () {
            // TODO: Implement forgot PIN functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Forgot PIN feature coming soon')),
            );
          },
          child: const Text('Forgot PIN?'),
        ),
      ],
    );
  }
}
