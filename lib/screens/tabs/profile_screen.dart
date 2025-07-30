import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/user_session_service.dart';
import '../../models/user.dart';
import '../fingerprint_authentication.dart';

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
            content: const Text(
              'Are you sure you want to logout?',
            ),
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
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                  ],
                ),
              ),

              // Bio section - from database
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A4A6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentUser!.bio ?? 'No bio added yet',
                            style: TextStyle(
                              color: _currentUser!.bio != null
                                  ? Colors.white70
                                  : Colors.white54,
                              fontSize: 14,
                              fontStyle: _currentUser!.bio != null
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
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
                            switchValue: _isDarkMode,
                            onTap: () {},
                            onSwitchChanged: _toggleDarkMode,
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
                            subtitle: 'Sign out of your account',
                            onTap: _handleLogout,
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
    required VoidCallback onTap,
    Function(bool)? onSwitchChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasSwitch ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasSwitch)
                Switch(
                  value: switchValue,
                  onChanged: onSwitchChanged,
                  activeColor: const Color(0xFF00A8FF),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 20,
                ),
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
