import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool dataSyncEnabled = false;
  String? appVersion;
  ThemeMode? _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = info.version;
    });
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
                selected: _themeMode == ThemeMode.light,
                onTap: () {
                  setState(() {
                    _themeMode = ThemeMode.light;
                  });
                  widget.onThemeModeChanged(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark'),
                selected: _themeMode == ThemeMode.dark,
                onTap: () {
                  setState(() {
                    _themeMode = ThemeMode.dark;
                  });
                  widget.onThemeModeChanged(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                selected: _themeMode == ThemeMode.system,
                onTap: () {
                  setState(() {
                    _themeMode = ThemeMode.system;
                  });
                  widget.onThemeModeChanged(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Edit Profile'),
              onTap: () {
                // TODO: Implement edit profile
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change Password'),
              onTap: () {
                // TODO: Implement change password
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Change Password coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: widget.onLogout,
            ),
          ),
          const SizedBox(height: 24),

          // Preferences Section
          Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Theme'),
              subtitle: Text(_themeModeLabel(_themeMode ?? ThemeMode.system)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English'),
              onTap: () {
                // TODO: Implement language selection
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Language selection coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Units'),
              subtitle: const Text('Metric'),
              onTap: () {
                // TODO: Implement units selection
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Units selection coming soon!')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Notifications Section
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Enable Notifications'),
              value: notificationsEnabled,
              onChanged: (val) {
                setState(() {
                  notificationsEnabled = val;
                });
              },
              secondary: const Icon(Icons.notifications_active),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Notification Preferences'),
              onTap: () {
                // TODO: Implement notification preferences
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification preferences coming soon!')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Data & Privacy Section
          Text('Data & Privacy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Export Data'),
              subtitle: const Text('Export your data as CSV'),
              onTap: () {
                // TODO: Implement export logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Import Data'),
              subtitle: const Text('Import previous backups'),
              onTap: () {
                // TODO: Implement import logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import feature coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear All Data'),
              subtitle: const Text('Wipe all app data'),
              onTap: () {
                // TODO: Implement clear data logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clear data feature coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              onTap: () {
                // TODO: Open privacy policy
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy Policy coming soon!')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Support Section
          Text('Support', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & FAQ'),
              onTap: () {
                // TODO: Open help/FAQ
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & FAQ coming soon!')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Contact Support'),
              onTap: () {
                // TODO: Open support
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact Support coming soon!')),
                );
              },
            ),
          ),
          if (appVersion != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: Text('App Version: $appVersion', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
        ],
      ),
    );
  }
} 