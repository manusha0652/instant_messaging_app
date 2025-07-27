import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232A32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C333B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: AssetImage('assets/profile_avatar.png'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aria Dwitolio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '+62 81234567890',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF232A32),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Colors.white38),
                  ),
                ],
              ),
            ),
            // Bio Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C333B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Bio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Available', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Settings Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C333B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Setting', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.white54),
                    title: const Text('Notification', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Default', style: TextStyle(color: Colors.white38)),
                    onTap: () {},
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.nightlight_round, color: Colors.white54),
                    title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Switch to a dark color scheme', style: TextStyle(color: Colors.white38)),
                    value: true,
                    onChanged: (val) {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code, color: Colors.white54),
                    title: const Text('My QR', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Connect to Chat', style: TextStyle(color: Colors.white38)),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white54),
                    title: const Text('Log Out', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Archive chat', style: TextStyle(color: Colors.white38)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}