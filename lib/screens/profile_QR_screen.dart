import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileQRScreen extends StatelessWidget {
  const ProfileQRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A4147),
      body: SafeArea(
        child: Column(
          children: [
            // Top section with background, back button, avatar, name, phone
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/profile_bg.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 32,
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: AssetImage('assets/profile_avatar.png'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aria Dwitolio',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        '+62 81234567890',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // QR code
            QrImageView(
              data: '+62 81234567890', // Use your data here
              size: 220,
              backgroundColor: Colors.white,
            ),
            const Spacer(),
            // Bottom navigation
            Container(
              color: const Color(0xFF353C44),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6A7A),
                      shape: StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: const Text('My QR', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {

                      // Navigate to scan QR page
                    },
                    child: const Text('Scan QR', style: TextStyle(color: Colors.white70)),

                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}