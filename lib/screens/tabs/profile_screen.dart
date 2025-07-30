import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/user_session_service.dart';
import '../../models/user.dart';
import '../fingerprint_authentication.dart';
import '../qr_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  User? _currentUser;
  bool _isLoading = true;
  bool _isDarkMode = false;
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDarkModeSetting();
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user's phone number
      final String? currentUserPhone = await _sessionService.getCurrentUser();

      if (currentUserPhone != null) {
        // Load user data from database
        final User? user = await _databaseService.getUserByPhone(
          currentUserPhone,
        );
        final Map<String, dynamic> settings = await _databaseService
            .getSettings();

        setState(() {
          _currentUser = user;
          _settings = settings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDarkModeSetting() async {
    try {
      final settings = await _databaseService.getSettings();
      setState(() {
        _isDarkMode = settings['darkModeEnabled'] == 1;
      });
    } catch (e) {
      print('Error loading dark mode setting: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      bool? confirmLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (confirmLogout == true) {
        // Get current user phone before clearing session
        final String? currentUserPhone = await _sessionService.getCurrentUser();

        // Clear current session but keep last authenticated user
        await _sessionService.clearSession();

        // Navigate to fingerprint authentication screen for re-authentication
        if (mounted && currentUserPhone != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => FingerprintAuthScreen(
                phoneNumber: currentUserPhone,
                isSetup: false, // Authentication mode, not setup
              ),
            ),
            (route) => false,
          );
        } else {
          // Fallback to login if no current user found
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    try {
      await _databaseService.updateSettings({'darkModeEnabled': value ? 1 : 0});
      setState(() {
        _isDarkMode = value;
        _settings['darkModeEnabled'] = value ? 1 : 0;
      });
    } catch (e) {
      print('Error updating dark mode: $e');
    }
  }

  void _openQRProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A5F),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00A8FF)),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A5F),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

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
                    // Top row with back button and QR button
                    Row(
                      children: [
                        // Back button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
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

                        // QR Code button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A8FF).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00A8FF),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _openQRProfile,
                            icon: const Icon(
                              Icons.qr_code,
                              color: Color(0xFF00A8FF),
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'My QR Code',
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Edit button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
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
                      backgroundImage: _currentUser!.profilePicture != null
                          ? NetworkImage(_currentUser!.profilePicture!)
                          : NetworkImage(
                              'https://api.dicebear.com/7.x/avataaars/png?seed=${_currentUser!.name}&backgroundColor=1e3a5f',
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Name - from database
                    Text(
                      _currentUser!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Phone number - from database
                    Text(
                      _currentUser!.phone,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Call button
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E3A5F),
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

                        const SizedBox(width: 20),

                        // QR Share button
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A8FF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00A8FF).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _openQRProfile,
                            icon: const Icon(
                              Icons.qr_code_2,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Share QR Code',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bio section - from database
              if (_currentUser!.bio != null && _currentUser!.bio!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A4A6B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF00A8FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentUser!.bio!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Quick Actions Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A4A6B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // QR Code option
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A8FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF00A8FF),
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'My QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Share your contact details',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 16,
                      ),
                      onTap: _openQRProfile,
                    ),

                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                    ),

                    // Settings option
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'App preferences',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 16,
                      ),
                      onTap: () {
                        // Handle settings
                      },
                    ),

                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                    ),

                    // Dark mode toggle
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _isDarkMode ? 'Enabled' : 'Disabled',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Switch(
                        value: _isDarkMode,
                        onChanged: _toggleDarkMode,
                        activeColor: const Color(0xFF00A8FF),
                      ),
                    ),

                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                    ),

                    // Logout option
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Sign out of account',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.red,
                        size: 16,
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
