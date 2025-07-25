import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/custom_button.dart';
import '../../themes/app_theme.dart';
import '../../utils/constants.dart';
import '../splash_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await DatabaseService.instance.getUser();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService.instance.clearSession();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _changePIN() async {
    // TODO: Implement PIN change functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN change feature coming soon')),
      );
    }
  }

  Future<void> _toggleBiometric() async {
    if (_user == null) return;

    try {
      final isAvailable = await AuthService.instance.isBiometricAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication not available'),
            ),
          );
        }
        return;
      }

      final updatedUser = _user!.copyWith(
        biometricEnabled: !_user!.biometricEnabled,
      );

      await DatabaseService.instance.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _user = updatedUser;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedUser.biometricEnabled
                  ? 'Biometric login enabled'
                  : 'Biometric login disabled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update biometric setting')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 32),

          // Settings List
          _buildSettingsList(),
          const SizedBox(height: 32),

          // App Info
          _buildAppInfo(),
          const SizedBox(height: 32),

          // Logout Button
          CustomButton(
            text: 'Logout',
            onPressed: _logout,
            isSecondary: true,
            icon: Icons.logout,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            UserAvatar(
              name: _user?.name ?? 'User',
              imagePath: _user?.profilePicturePath,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              _user?.name ?? 'User',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Member since ${_formatDate(_user?.createdAt)}',
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

  Widget _buildSettingsList() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock, color: AppColors.primary),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your security PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePIN,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: AppColors.primary),
            title: const Text('Biometric Login'),
            subtitle: Text(
              _user?.biometricEnabled == true
                  ? 'Currently enabled'
                  : 'Currently disabled',
            ),
            trailing: Switch(
              value: _user?.biometricEnabled ?? false,
              onChanged: (_) => _toggleBiometric(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.primary),
            title: const Text('Edit Profile'),
            subtitle: const Text('Update name and avatar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement edit profile
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit profile feature coming soon'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About ChatLink',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Version', AppConstants.appVersion),
            const Divider(),
            _buildInfoRow('Build', '1'),
            const Divider(),
            const Row(
              children: [
                Icon(Icons.security, size: 16, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data is stored securely on your device',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
