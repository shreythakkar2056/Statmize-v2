import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:app/screens/developer_page.dart';
import 'package:app/screens/settings_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/reusable/floating_navbar.dart';

class ProfileScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;
  final String userName;
  final int selectedNavIndex;
  final Function(int) onNavTap;

  const ProfileScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.userName,
    required this.selectedNavIndex,
    required this.onNavTap,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showDialog(BuildContext context, String title, String content) {
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

  Widget _buildThemeSelectorCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildCapsule(ThemeMode mode, String label, IconData icon) {
      final isSelected = widget.themeMode == mode;
      final color = isSelected
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSurface;

      return Expanded(
        child: GestureDetector(
          onTap: () => widget.onThemeModeChanged(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  buildCapsule(ThemeMode.light, 'Light', Icons.light_mode_outlined),
                  buildCapsule(ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                  buildCapsule(ThemeMode.system, 'System', Icons.brightness_auto_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // bottom padding for nav bar
              child: Column(
                children: [
                  // AppBar content moved here
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          widget.userName,
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
                  _buildProfileOption(
                    context: context,
                    icon: Icons.settings,
                    title: "Settings",
                    subtitle: "App preferences and configurations",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            isDarkMode: widget.themeMode == ThemeMode.dark,
                            themeMode: widget.themeMode,
                            onThemeModeChanged: widget.onThemeModeChanged,
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
                  _buildThemeSelectorCard(context),
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
                    icon: Icons.developer_board,
                    title: "Developer Mode",
                    subtitle: "Enable developer mode",
                    onTap: () {
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
                              onPressed: () async {
                                await supabase.auth.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
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
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingNavBar(
              selectedIndex: widget.selectedNavIndex,
              onTap: widget.onNavTap,
            ),
          ),
        ],
      ),
    );
  }
} 