import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../utils/helpers.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 40,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primary,
        child: imagePath != null
            ? ClipOval(
                child: Image.asset(
                  imagePath!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildInitialsAvatar();
                  },
                ),
              )
            : _buildInitialsAvatar(),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Text(
      Helpers.getInitials(name),
      style: TextStyle(
        color: AppColors.textLight,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.4,
      ),
    );
  }
}
