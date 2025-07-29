import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile header card
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A4A6B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Top row with back button and edit button
                    Row(
                      children: [
                        // Back button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        const Spacer(),

                        // Edit button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              // Handle edit profile
                            },
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Profile picture
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF00A8FF),
                      backgroundImage: const NetworkImage(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=AriaDwitollo&backgroundColor=1e3a5f',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Name
                    const Text(
                      'Aria Dwitollo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Phone number
                    const Text(
                      '+62 812 3456 7890',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),

                    const SizedBox(height: 20),

                    // Call button
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Handle call
                        },
                        icon: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bio section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A4A6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Bio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Settings section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Setting',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Settings options
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notification',
                            subtitle: 'Default',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.dark_mode_outlined,
                            title: 'Dark Mode',
                            subtitle: 'Switch to a dark color scheme',
                            hasSwitch: true,
                            switchValue: true,
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.qr_code_outlined,
                            title: 'My QR',
                            subtitle: 'Connect to Chat',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.logout,
                            title: 'Log Out',
                            subtitle: 'Archive chat',
                            onTap: () {
                              // Handle logout
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/splash',
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool hasSwitch = false,
    bool switchValue = false,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (hasSwitch)
                Switch(
                  value: switchValue,
                  onChanged: (value) {
                    // Handle switch toggle
                  },
                  activeColor: const Color(0xFF00A8FF),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else
                Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
