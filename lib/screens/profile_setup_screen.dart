import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/pin_input_widget.dart';
import '../utils/constants.dart';
import '../themes/app_theme.dart';
import 'main_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _pin = '';
  bool _biometricEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await AuthService.instance.isBiometricAvailable();
    setState(() {
      _biometricEnabled = isAvailable;
    });
  }

  Future<void> _setupProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.length < AppConstants.minPinLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please set a PIN first')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hashedPin = AuthService.instance.hashPin(_pin);
      final user = UserModel(
        name: _nameController.text.trim(),
        pinHash: hashedPin,
        biometricEnabled: _biometricEnabled,
        createdAt: DateTime.now(),
      );

      await DatabaseService.instance.insertUser(user);

      // Create session
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
            content: Text('Failed to setup profile. Please try again.'),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Header
                _buildHeader(),
                const SizedBox(height: 40),

                // Name Input
                _buildNameInput(),
                const SizedBox(height: 32),

                // PIN Setup
                _buildPinSetup(),
                const SizedBox(height: 32),

                // Biometric Option
                _buildBiometricOption(),
                const SizedBox(height: 40),

                // Setup Button
                CustomButton(
                  text: 'Complete Setup',
                  onPressed: _setupProfile,
                  isLoading: _isLoading,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.person_add,
            size: 40,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Let\'s set up your profile!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We need a few details to get you started with secure messaging.',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Name',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length > AppConstants.maxNameLength) {
              return 'Name is too long';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPinSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Security PIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (_pin.length >= AppConstants.minPinLength)
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Set a 4-6 digit PIN to secure your app',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        PinInputWidget(
          pinLength: 6,
          onCompleted: (pin) {
            setState(() {
              _pin = pin;
            });
          },
          onChanged: (pin) {
            setState(() {
              _pin = pin;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBiometricOption() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fingerprint, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Biometric Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    final isAvailable = await AuthService.instance
                        .isBiometricAvailable();
                    if (isAvailable) {
                      setState(() {
                        _biometricEnabled = value;
                      });
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Biometric authentication not available',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _biometricEnabled
                  ? 'Use fingerprint to unlock the app quickly and securely'
                  : 'Enable fingerprint login for quick access',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
