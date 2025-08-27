import 'package:flutter/material.dart';
import 'fingerprint_authentication.dart';
import 'profile_setup_screen.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String completePhoneNumber = '';
  bool isLoading = false;
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();

  void _handleLogin() async {
    if (completePhoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check if user exists in database
      final User? existingUser = await _databaseService.getUserByPhone(
        completePhoneNumber,
      );

      setState(() {
        isLoading = false;
      });

      if (existingUser != null) {
        // Existing user - go directly to fingerprint authentication
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FingerprintAuthScreen(
              phoneNumber: completePhoneNumber,
              isSetup: false, // Authentication mode for existing users
            ),
          ),
        );
      } else {
        // User not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found. Please register first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleRegister() {
    if (completePhoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to profile setup for new user registration
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileSetupScreen(phoneNumber: completePhoneNumber),
      ),
    );
  }

  void _handleExistingUserLogin() async {
    // Get last authenticated user for quick access
    final String? lastUser = await _sessionService.getLastAuthenticatedUser();

    if (lastUser != null) {
      // Navigate to fingerprint authentication
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FingerprintAuthScreen(phoneNumber: lastUser, isSetup: false),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No previous user found. Please enter your phone number.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F), // Dark blue background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top section with logo and title
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ChatLink Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A8FF),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ChatLink Text
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: 'Link',
                              style: TextStyle(
                                color: Color(0xFF00A8FF),
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom section with login form
                Flexible(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: double.infinity),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A4A6B),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Back title
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        const Text(
                          'Enter your registered phone number to log in',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),

                        const SizedBox(height: 32),

                        // Quick Access for Existing Users
                        FutureBuilder<bool>(
                          future: _sessionService.hasLoggedInBefore(),
                          builder: (context, snapshot) {
                            if (snapshot.data == true) {
                              return Column(
                                children: [
                                  // Quick Access Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleExistingUserLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00A8FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(
                                        Icons.fingerprint,
                                        size: 24,
                                      ),
                                      label: const Text(
                                        'Quick Access',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          thickness: 1,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Phone number input
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: IntlPhoneField(
                            initialCountryCode: 'LK', // Sri Lanka as default
                            decoration: InputDecoration(
                              hintText: 'Phone Number',
                              hintStyle: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              counterText: '', // Hide the character counter
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            dropdownTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            dropdownIcon: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            flagsButtonPadding: const EdgeInsets.only(
                              left: 16,
                              right: 8,
                            ),
                            dropdownDecoration: BoxDecoration(
                              color: const Color(0xFF2A4A6B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            searchText: 'Search countries...',
                            onChanged: (phone) {
                              setState(() {
                                completePhoneNumber = phone.completeNumber;
                              });
                            },
                            onCountryChanged: (country) {
                              // Optional: Handle country change
                              print('Country changed to: ${country.name}');
                            },
                            validator: (phone) {
                              if (phone == null || phone.number.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            showDropdownIcon: true,
                            autovalidateMode: AutovalidateMode.disabled,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Log In button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90A4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const Spacer(),

                        // Register link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: _handleRegister,
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: Color(0xFF00A8FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
