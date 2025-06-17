import 'package:flutter/material.dart';
import 'package:app/screens/developer_page.dart';
import 'package:app/screens/settings_page.dart';

class ProfileModal extends StatelessWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const ProfileModal({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  void _showDialog(BuildContext context, String title, String content) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light'),
                selected: themeMode == ThemeMode.light,
                onTap: () {
                  onThemeModeChanged(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark'),
                selected: themeMode == ThemeMode.dark,
                onTap: () {
                  onThemeModeChanged(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                selected: themeMode == ThemeMode.system,
                onTap: () {
                  onThemeModeChanged(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            icon,
            color: isDestructive
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? Colors.red
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
        onTap: onTap,
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "User",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  "Statmize User",
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Menu Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildProfileOption(
                  context: context,
                  icon: Icons.settings,
                  title: "Settings",
                  subtitle: "App preferences and configurations",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(
                          isDarkMode: themeMode == ThemeMode.dark,
                          themeMode: themeMode,
                          onThemeModeChanged: onThemeModeChanged,
                          onLogout: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logged out successfully')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.analytics,
                  title: "Performance Analytics",
                  subtitle: "View your sports performance data",
                  onTap: () => _showDialog(context, 'Performance Analytics',
                      'Here you can view detailed analytics of your sports performance including speed trends, power output, and swing analysis.'),
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.history,
                  title: "Session History",
                  subtitle: "View past training sessions",
                  onTap: () => _showDialog(context, 'Session History',
                      'View your past training sessions, compare performances, and track your improvement over time.'),
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.palette,
                  title: "Theme",
                  subtitle: _themeModeLabel(themeMode),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeSelector(context),
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.developer_board,
                  title: "Developer Mode",
                  subtitle: "Enable developer mode",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeveloperPage(),
                      ),
                    );
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  subtitle: "Get help and contact support",
                  onTap: () => _showDialog(context, 'Help & Support',
                      'Need help? Contact our support team or check out our FAQ section for common questions.'),
                ),
                _buildProfileOption(
                  context: context,
                  icon: Icons.logout,
                  title: "Logout",
                  subtitle: "Sign out of your account",
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logged out successfully')),
                              );
                            },
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}