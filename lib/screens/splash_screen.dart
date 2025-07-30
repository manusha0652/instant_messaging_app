import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Start animation
    _animationController.forward();

    // Navigate after delay
    _navigateToNextScreen();
  }

  _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F), // Dark blue from your design
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Chat Bubble Icon - matching your design
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF00A8FF,
                          ), // Bright blue from design
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Main chat bubble
                            Positioned(
                              top: 25,
                              left: 25,
                              child: Container(
                                width: 70,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            // Chat tail
                            Positioned(
                              bottom: 35,
                              left: 35,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 25,
                              left: 25,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // App Name "ChatLink"
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Chat',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Link',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00A8FF),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Suitable phrase below the app name
                      const Text(
                        'Connect Beyond Boundaries',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w300,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Secondary tagline
                      const Text(
                        'Secure • Fast • Reliable',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w200,
                        ),
                      ),

                      const SizedBox(height: 80),

                      // Loading indicator with custom styling
                      Container(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00A8FF),
                          ),
                          strokeWidth: 3.0,
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Loading your conversations...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Temporary Home Screen for navigation
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatLink'),
        backgroundColor: const Color(0xFF00A8FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00A8FF), Color(0xFF1E3A5F)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Welcome to ChatLink!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Your secure messaging experience starts here',
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
