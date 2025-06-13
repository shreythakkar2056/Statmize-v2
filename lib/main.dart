// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';  
import 'package:app/core/theme.dart';

// Removed unused import: 'pages/home_page.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkTheme = false;

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkTheme = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Statmize',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: BLEHome(isDarkMode: _isDarkTheme, onThemeToggle: _toggleTheme),
    );
  }
}

class BLEHome extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeToggle;

  const BLEHome({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<BLEHome> createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {  // Device names and UUIDs
  final String deviceName = "ESP32_IMU"; // or "ESP32" if that's what shows up in scanning
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"; // ESP32 default GATT service UUID
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // ESP32 default characteristic UUID

  // Acceleration state variables
  double currentAcceleration = 0.0;
  double accX = 0.0, accY = 0.0, accZ = 0.0;
  int todaySessions = 3;
  int weeklySessions = 12;
  bool isSessionActive = false;
  DateTime? sessionStartTime;
  String currentSessionType = "Cricket";
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notificationStream;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  List<ScanResult> discoveredDevices = [];

void _startNewSession() {
  // User taps 'Start New Session' button
  // → A modal bottom sheet appears with sport options
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _buildSessionTypeModal(),
  );
}
  String sport = "Unknown";
  double speed = 0.0;
  double angle = 0.0;
  double power = 0.0;
  String direction = "Unknown";

  bool isConnecting = false;
  bool isConnected = false;
  bool hasPermissions = false;
  bool isScanning = false;
  bool isBluetoothOn = false;
  bool isDeveloperMode = false;

  String debugMessage = "";
  DateTime? lastDataReceived;

  // Profile Modal Methods
  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProfileModal(),
    );
  }
Widget _buildSessionTypeModal() {
  // This modal lets the user pick a sport to start a session
  // User sees a grid of sport cards (Cricket, Tennis, Badminton, Custom)
  return Container(
    height: MediaQuery.of(context).size.height * 0.6,
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.only(
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
        
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Start New Session",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose your sport to begin tracking",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              
              // Sport Selection Grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildSportCard("Cricket", Icons.sports_cricket, Colors.green),
                  _buildSportCard("Tennis", Icons.sports_tennis, Colors.blue),
                  _buildSportCard("Badminton", Icons.sports_tennis, Colors.orange),
                  _buildSportCard("Custom", Icons.sports, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Add this method to your _BLEHomeState class
// Widget to build a sport selection card in the session type modal
// User sees a card with an icon and sport name. Tapping it starts a new session for that sport.
Widget _buildSportCard(String sport, IconData icon, Color color) {
  // Each card represents a sport option in the modal
  // User sees a large icon and sport name
  // Tapping a card starts a session and shows a snackbar
  return Card(
    elevation: 4, // Card shadow
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Rounded corners
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // When user taps a sport card:
        // - The modal closes
        // - The session state is updated to active
        // - The selected sport is set as current
        // - The session start time is set
        // - The session count for today is incremented
        // - A snackbar appears at the bottom: "<Sport> session started!"
        Navigator.pop(context);
        setState(() {
          isSessionActive = true;
          sessionStartTime = DateTime.now();
          currentSessionType = sport;
          todaySessions++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sport session started!'), // User sees this message at the bottom
            backgroundColor: color,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ), // User sees a large sport icon
            const SizedBox(height: 8),
            Text(
              sport,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ), // User sees the sport name
          ],
        ),
      ),
    ),
  );
}

// Add this method to your _BLEHomeState class
void _endSession() {
  // User taps 'End Session' button
  // → A confirmation dialog appears
  // User can cancel or confirm ending the session
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('End Session'),
      content: Text('End your ${currentSessionType.toLowerCase()} session?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              isSessionActive = false;
              sessionStartTime = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session ended successfully')),
            );
          },
          child: const Text('End Session', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}



// Add this method to your _BLEHomeState class
Widget _buildStatItem(String label, String value, IconData icon) {
  // Used to show a stat (like speed, power, etc.) with an icon
  // User sees this in the stats section
  return Column(
    children: [
      Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    ],
  );
}

// Add this method to your _BLEHomeState class
Widget _buildStartSessionButton() {
  // Main button for starting or ending a session
  // User sees 'Start New Session' or 'End Session' depending on state
  // Button color and icon change based on session state
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      onPressed: isSessionActive ? _endSession : _startNewSession,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSessionActive ? Colors.red : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSessionActive ? Icons.stop : Icons.play_arrow,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            isSessionActive ? "End Session" : "Start New Session",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildProfileModal() {
    // User taps their avatar in the app bar
    // → A modal appears with profile info and settings
    // User sees their name, avatar, and menu options (Settings, Analytics, History, Theme, Help, Logout)
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
                  "Rownok",
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
                  icon: Icons.settings,
                  title: "Settings",
                  subtitle: "App preferences and configurations",
                  onTap: () => _showSettingsDialog(),
                ),
                _buildProfileOption(
                  icon: Icons.analytics,
                  title: "Performance Analytics",
                  subtitle: "View your sports performance data",
                  onTap: () => _showPerformanceDialog(),
                ),
                _buildProfileOption(
                  icon: Icons.history,
                  title: "Session History",
                  subtitle: "View past training sessions",
                  onTap: () => _showHistoryDialog(),
                ),
                _buildProfileOption(
                  icon: Icons.palette,
                  title: "Theme",
                  subtitle: "Light/Dark mode",
                  trailing: Switch(
                    value: widget.isDarkMode,
                    onChanged: widget.onThemeToggle,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildProfileOption(
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  subtitle: "Get help and contact support",
                  onTap: () => _showHelpDialog(),
                ),
                _buildProfileOption(
                  icon: Icons.logout,
                  title: "Logout",
                  subtitle: "Sign out of your account",
                  onTap: () => _showLogoutDialog(),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    // Each option in the profile modal (Settings, Analytics, etc.)
    // User sees an icon, title, subtitle, and optional switch or arrow
    // Tapping an option opens a dialog or toggles a setting
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isDestructive
                  ? Colors.red.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            icon,
            color:
                isDestructive
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color:
                isDestructive
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
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
        onTap: onTap,
      ),
    );
  }

  // Dialog Methods
  void _showSettingsDialog() {
    // User sees a dialog for app settings (not yet implemented)
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Settings'),
            content: const Text(
              'Settings panel will be implemented here with options for notifications, data sync, and app preferences.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showPerformanceDialog() {
    // User sees a dialog with performance analytics info
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Performance Analytics'),
            content: const Text(
              'Here you can view detailed analytics of your sports performance including speed trends, power output, and swing analysis.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showHistoryDialog() {
    // User sees a dialog with session history info
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Session History'),
            content: const Text(
              'View your past training sessions, compare performances, and track your improvement over time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showAISuggestionsDialog() {
    // User sees a dialog with AI training suggestions
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('AI Suggestions'),
            content: const Text(
              'Get personalized training recommendations based on your performance data:\n\n• Improve your swing angle by 5°\n• Increase power output gradually\n• Focus on consistency in direction',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showDevelopertDialog() {
    // User sees a dialog for developer/debug mode
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Developer Mode'),
            content: const Text(
              'This mode provides advanced debugging options:\n\n• View debug messages\n• Monitor Bluetooth scan results\n• Enable/disable developer features',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showEquipmentDialog() {
    // User sees a dialog for equipment setup
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Equipment Setup'),
            content: const Text(
              'Configure your sports equipment:\n\n• Cricket Bat\n• Tennis Racquet\n• Badminton Racquet\n• Custom Equipment',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showHelpDialog() {
    // User sees a dialog for help and support
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Help & Support'),
            content: const Text(
              'Need help? Contact our support team or check out our FAQ section for common questions.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog() {
    // User sees a dialog to confirm logout
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  // Implement logout logic here
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
  }

  // Single _buildDataRow method with optional icon parameter
 Widget _buildDataRow(String label, String value, [IconData? icon]) {
  // Used in the real-time data card to show a label, value, and optional icon
  // User sees rows like 'Speed: 12.3 m/s', 'Angle: 45°', etc.
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon, 
            size: 20, 
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          "$label:", 
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}
  @override
  void initState() {
    super.initState();
    initializeBluetooth();
  }

  Future<void> initializeBluetooth() async {
    // Called on app start
    // Checks if Bluetooth is supported and permissions are granted
    // User sees status updates in the connection card and debug info
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      setState(() {
        debugMessage = "Bluetooth not supported by this device";
        sport = "Not Supported";
      });
      return;
    }

    if (Platform.isIOS) {
      // On iOS, directly proceed - permissions are handled automatically
      setState(() {
        hasPermissions = true;
        isBluetoothOn = true;
        sport = "Ready to scan";
        debugMessage = "iOS: Ready to start scanning";
      });

      // Small delay then start scanning
      Timer(const Duration(seconds: 1), () {
        if (mounted) startScan();
      });
    } else {
      // Android: Check Bluetooth state first
      await checkBluetoothStateAndroid();
    }
  }

  Future<void> checkBluetoothStateAndroid() async {
    // Checks Bluetooth state on Android
    // User sees status if Bluetooth is off
    var state = await FlutterBluePlus.adapterState.first;
    setState(() {
      isBluetoothOn = state == BluetoothAdapterState.on;
    });

    if (isBluetoothOn) {
      requestAndroidPermissions();
    } else {
      setState(() {
        sport = "Bluetooth is off";
        debugMessage = "Please turn on Bluetooth";
      });
    }

    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        isBluetoothOn = state == BluetoothAdapterState.on;
        if (!isBluetoothOn) {
          sport = "Bluetooth is off";
          debugMessage = "Bluetooth turned off";
          _disconnect();
        }
      });
    });
  }

  Future<void> requestAndroidPermissions() async {
    // Requests Bluetooth/location permissions on Android
    // User sees a dialog if permissions are missing
    Map<Permission, PermissionStatus> permissions =
        await [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();

    hasPermissions = permissions.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );

    if (hasPermissions) {
      startScan();
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    // User sees a dialog explaining why permissions are needed
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'Bluetooth and Location permissions are required for this app to connect to your sports tracker.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    // Cleans up BLE connections and subscriptions when the app is closed
    _disconnect();
    super.dispose();
  }
  Future<void> _disconnect() async {
    // Disconnects from BLE device and resets state
    // User sees connection status update
    await _notificationStream?.cancel();
    await _stateSubscription?.cancel();
    await _scanResultsSubscription?.cancel();
    await _device?.disconnect();
    setState(() {
      isConnected = false;
      isConnecting = false;
      _device = null;
      _characteristic = null;
    });
  }

  Future<void> startScan() async {
    // Starts BLE scan for ESP32 device
    // User sees scanning status and discovered devices (in developer mode)
    if (isScanning) return;

    setState(() {
      isScanning = true;
      sport = "Scanning...";
      discoveredDevices.clear();
      debugMessage = "Starting BLE scan...";
    });

    try {
      await FlutterBluePlus.stopScan();

      // Start scanning with optimized settings for each platform
      if (Platform.isIOS) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 20),
          withServices: [], // Scan for all services initially
        );
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          androidUsesFineLocation: true,
        );
      }

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          discoveredDevices = results;
        });

        // Enhanced device discovery with debugging
        for (var result in results) {
          String platformName = result.device.platformName.toLowerCase();
          String advName = result.advertisementData.advName.toLowerCase();
          String deviceId = result.device.remoteId.toString();
          
          // Detailed logging for device discovery
          print("=== Device Found ===");
          print("Platform Name: '$platformName'");
          print("Advertisement Name: '$advName'");
          print("Device ID: $deviceId");
          print("RSSI: ${result.rssi}");
          print("Manufacturer Data: ${result.advertisementData.manufacturerData}");
          print("Service UUIDs: ${result.advertisementData.serviceUuids}");
          print("==================");
          
          // More comprehensive device matching
          bool isTargetDevice = false;
          if (platformName.contains("esp32") || 
              advName.contains("esp32") ||
              (result.advertisementData.serviceUuids.isNotEmpty &&
               result.advertisementData.serviceUuids.any((uuid) => 
                 uuid.toString() == serviceUuid))) {
            isTargetDevice = true;
            print("Potential ESP32 device found!");
            print("Match criteria: Platform: $platformName, Adv: $advName");
            print("Service UUIDs: ${result.advertisementData.serviceUuids}");
          }

          if (isTargetDevice && result.rssi >= -80) { // Only connect to devices with good signal strength
            print("Attempting to connect to ESP32 device...");
            _device = result.device;
            FlutterBluePlus.stopScan();
            setState(() {
              debugMessage = "Found ESP32 device! Name: ${platformName.isNotEmpty ? platformName : advName}";
              isScanning = false;
            });
            connectToDevice(_device!);
            return;
          }
        }

        setState(() {
          debugMessage = "Found ${results.length} devices, looking for ESP32...";
        });
      });

      // Auto-stop scanning after timeout with more informative messaging
      Timer(Duration(seconds: Platform.isIOS ? 20 : 15), () {
        if (isScanning) {
          FlutterBluePlus.stopScan();
          setState(() {
            isScanning = false;
            if (!isConnected) {
              sport = "Device not found";
              debugMessage = "Could not find ESP32 device. Please ensure it's powered on and nearby.";
            }
          });
        }
      });
    } catch (e) {
      print("Scan error: $e");
      setState(() {
        debugMessage = "Scan error: $e";
        isScanning = false;
        sport = "Scan failed";
      });
    }
  }
  // Attempts to connect to the given Bluetooth device
Future<void> connectToDevice(BluetoothDevice device) async {
  // If already connected or connecting, disconnect first
  if (isConnected || isConnecting) {
    print("Already connected or connecting, disconnecting first...");
    await _disconnect();
  }

  // Update UI to show connecting state
  setState(() {
    isConnecting = true;
    isScanning = false;
    sport = "Connecting...";
    debugMessage = "Attempting to connect to ESP32 device...";
  });

  try {
    // Start connection attempt
    print("Starting connection attempt to "+device.platformName+"...");
    await device.connect(
      timeout: Duration(seconds: Platform.isIOS ? 15 : 10), // Set platform-specific timeout
      autoConnect: false, // Do not auto-connect
    ).timeout(
      const Duration(seconds: 35), // Overall connection timeout
      onTimeout: () {
        throw TimeoutException('Connection attempt timed out');
      },
    );

    // Listen for connection state changes
    _stateSubscription = device.connectionState.listen((state) async {
      print("Connection state changed: $state");

      // Update connection state in UI
      setState(() {
        isConnected = state == BluetoothConnectionState.connected;
      });

      if (state == BluetoothConnectionState.connected) {
        // Connected: proceed to discover services
        setState(() {
          debugMessage = "Connected! Discovering services...";
        });
        await _setupServices(device);
      } else if (state == BluetoothConnectionState.disconnected) {
        // Disconnected: update UI
        setState(() {
          sport = "Disconnected";
          isConnecting = false;
          debugMessage = "Device disconnected";
        });
      }
    });
  } catch (e) {
    // Handle connection errors
    setState(() {
      debugMessage = "Connection error: $e";
      isConnecting = false;
      sport = "Connection Failed";
    });
    print("iOS Connection Error: $e");
  }
}  Future<void> _setupServices(BluetoothDevice device) async {
    // Discovers services and characteristics after connecting
    // User sees 'Connected & Ready' if successful, or error if not
    try {
      print("Starting service discovery...");
      List<BluetoothService> services = await device.discoverServices()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Service discovery timed out'),
          );

      _logAllServicesAndCharacteristics(services);

      // First try exact UUID match
      // Ensure case-insensitive UUID comparisons in _setupServices
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _characteristic = char;

              // Check if characteristic supports notifications
              if (!char.properties.notify) {
                setState(() {
                  debugMessage = "Characteristic doesn't support notifications";
                });
                return;
              }

              // Enable notifications
              await char.setNotifyValue(true);

              // Start listening for data
              _notificationStream = char.lastValueStream.listen(
                (value) {
                  print("Received data: $value");
                  _handleReceivedData(value);
                },
                onError: (error) {
                  print("Notification error: $error");
                  setState(() {
                    debugMessage = "Notification error: $error";
                  });
                },
              );

              setState(() {
                sport = "Connected & Ready";
                isConnecting = false;
                debugMessage = "Successfully connected and receiving data!";
              });
              return;
            }
          }
        }
      }

      setState(() {
        debugMessage = "No suitable characteristic found";
        sport = "Setup Failed";
        isConnecting = false;
      });
    } catch (e) {
      print("Service Discovery Error: $e");
      setState(() {
        debugMessage = "Service discovery error: $e";
        isConnecting = false;
        sport = "Setup failed";
      });
    }
  }

  void handleNotification(List<int> data) {
    // Handles incoming BLE data for speed, angle, power, direction
    // User sees real-time updates in the data card
    try {
      String decoded = utf8.decode(data);
      print("Decoded data: $decoded");

      List<String> parts = decoded.trim().split(",");

      if (parts.length >= 4) {
        setState(() {
          speed = double.tryParse(parts[0]) ?? 0.0;
          angle = double.tryParse(parts[1]) ?? 0.0;
          power = double.tryParse(parts[2]) ?? 0.0;
          direction = parts[3].trim();
          lastDataReceived = DateTime.now();

          // Clear any previous error messages when data is received successfully
          if (debugMessage.contains("parse error") ||
              debugMessage.contains("No data")) {
            debugMessage = "Data received successfully";
          }
        });
      } else {
        setState(() {
          debugMessage =
              "Invalid data format. Expected: speed,angle,power,direction. Got: $decoded";
        });
      }
    } catch (e) {
      setState(() {
        debugMessage = "Data parse error: $e";
      });
      print("Data parsing error: $e");
    }
  }

  void _handleReceivedData(List<int> value) {
    // Handles incoming BLE data for accelerometer/IMU
    // User sees real-time updates in the data card
    try {
      final dataString = utf8.decode(value);
      final parts = dataString.split(',');
      
      if (parts.length >= 6) {
        setState(() {
          // Update accelerometer values
          accX = double.parse(parts[0]);
          accY = double.parse(parts[1]);
          accZ = double.parse(parts[2]);
          
          // Calculate total acceleration magnitude
          currentAcceleration = sqrt(accX * accX + accY * accY + accZ * accZ);
          
          // Send data to backend if needed
          _sendDataToBackend();
        });
      }
    } catch (e) {
      print('Error processing data: $e');
    }
  }

  void _sendDataToBackend() {
    // TODO: Implement backend data sending
    // This function will be used to send processed data to your backend
    // You might want to use HTTP POST requests or WebSocket here
  }

  Color _getConnectionStatusColor() {
    // Returns color for connection status (green, orange, red, blue)
    // User sees this color in the connection card
    if (isConnected) return Colors.green;
    if (isConnecting || isScanning) return Colors.orange;
    if (Platform.isAndroid && (!isBluetoothOn || !hasPermissions)) {
      return Colors.red;
    }
    return Colors.blue;
  }

  // New enhanced connection card
  Widget _buildEnhancedConnectionCard() {
    // Card at the top showing Bluetooth connection status
    // User sees if device is connected, scanning, or disconnected
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getConnectionStatusColor().withOpacity(0.1),
              _getConnectionStatusColor().withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getConnectionStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected ? Icons.bluetooth_connected : 
                    isScanning ? Icons.bluetooth_searching :
                    Icons.bluetooth_disabled,
                    color: _getConnectionStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? "Device Connected" : 
                        isScanning ? "Scanning for Device" :
                        isConnecting ? "Connecting..." :
                        "Device Disconnected",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getConnectionStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected ? "ESP32_IMU • Ready to receive data" :
                        isScanning ? "Looking for ESP32_IMU..." :
                        isConnecting ? "Establishing connection..." :
                        "Bluetooth device not found",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "LIVE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (isScanning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: _getConnectionStatusColor().withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(_getConnectionStatusColor()),
              ),
            ],
            
            if (lastDataReceived != null && isConnected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.update,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Last update: ${DateTime.now().difference(lastDataReceived!).inSeconds}s ago",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Main app UI
    // User sees:
    // - App bar with profile avatar and Bluetooth status
    // - Sport selection tabs
    // - Connection status card (shows if device is connected, scanning, etc.)
    // - Start/End session button
    // - Real-time data card (shows speed, angle, power, etc.)
    // - Debug info and discovered devices (if developer mode is enabled)
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 200, // Increased from 150 to 200 for more space
        leading: GestureDetector(
          onTap: _showProfileModal,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.person, 
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(  // Added Expanded to handle text overflow
                  child: Text(
                    'Hello, Rownok!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,  // Added text overflow handling
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isScanning ? Icons.bluetooth_searching : Icons.bluetooth_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              if (Platform.isIOS) {
                startScan();
              } else {
                if (isBluetoothOn && hasPermissions) startScan();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport Selection Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSportTab("Cricket", Icons.sports_cricket, currentSessionType == "Cricket"),
                  const SizedBox(width: 12),
                  _buildSportTab("Tennis", Icons.sports_tennis, currentSessionType == "Tennis"),
                  const SizedBox(width: 12),
                  _buildSportTab("Badminton", Icons.sports_tennis, currentSessionType == "Badminton"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildEnhancedConnectionCard(),
            const SizedBox(height: 20),
            _buildStartSessionButton(),
            const SizedBox(height: 20),
            // Real-time Data Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Makes the column fit its content
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Real-time Data",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 20,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    ),
                    const SizedBox(height: 8),
                    _buildDataRow(
                      "Speed",
                      "${speed.toStringAsFixed(2)} m/s",
                      Icons.flash_on,
                    ),
                    _buildDataRow(
                      "Angle",
                      "${angle.toStringAsFixed(2)}°",
                      Icons.rotate_right,
                    ),
                    _buildDataRow(
                      "Power",
                      "${power.toStringAsFixed(2)} W",
                      Icons.bolt,
                    ),
                    _buildDataRow(
                      "Direction", 
                      direction, 
                      Icons.navigation
                    ),
                    _buildDataRow(
                      "Acceleration",
                      "${currentAcceleration.toStringAsFixed(2)} m/s²",
                      Icons.speed,
                    ),
                  ],
                ),
              ),
            ),

            // Debug Messages (only show if developer mode is enabled)
            if (isDeveloperMode && debugMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color:
                    debugMessage.contains("error") ||
                            debugMessage.contains("failed")
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Debug Information",
                        style: TextStyle(
                          color:
                              debugMessage.contains("error") ||
                                      debugMessage.contains("failed")
                                  ? Colors.red.shade900
                                  : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        debugMessage,
                        style: TextStyle(
                          color:
                              debugMessage.contains("error") ||
                                      debugMessage.contains("failed")
                                  ? Colors.red.shade900
                                  : Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Discovered Devices (only show if developer mode is enabled)
            if (isDeveloperMode && discoveredDevices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Discovered Devices (${discoveredDevices.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...discoveredDevices.take(5).map((result) {
                        final name =
                            result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : result.advertisementData.advName.isNotEmpty
                                ? result.advertisementData.advName
                                : "Unknown Device";
                        return ListTile(
                          title: Text(name),
                          subtitle: Text("RSSI: ${result.rssi}"),
                          dense: true,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add this method to your _BLEHomeState class
  Widget _buildSportTab(String sport, IconData icon, bool isSelected) {
    // Tab for selecting sport type (Cricket, Tennis, Badminton)
    // User sees a pill-shaped tab with icon and sport name
    // Selected tab is highlighted
    return InkWell(
      onTap: () {
        setState(() {
          currentSessionType = sport;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              sport,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCharacteristicProperties(BluetoothCharacteristic char) {
    // Returns a string describing BLE characteristic properties
    // User does not see this directly (for debugging)
    List<String> props = [];
    if (char.properties.broadcast) props.add('broadcast');
    if (char.properties.read) props.add('read');
    if (char.properties.writeWithoutResponse) props.add('writeWithoutResponse');
    if (char.properties.write) props.add('write');
    if (char.properties.notify) props.add('notify');
    if (char.properties.indicate) props.add('indicate');
    if (char.properties.authenticatedSignedWrites) props.add('authenticatedSignedWrites');
    return props.join(', ');
  }

  void _logAllServicesAndCharacteristics(List<BluetoothService> services) {
    // Prints all BLE services/characteristics to console for debugging
    // User does not see this directly
    print("\n========== DETECTED BLE SERVICES ==========");
    for (var service in services) {
      print("\nService UUID: \\${service.uuid}");
      print("Characteristics:");
      for (var char in service.characteristics) {
        print("  → UUID: \\${char.uuid}");
        print("    Properties: \\${_getCharacteristicProperties(char)}");
      }
    }
    print("=========================================");
  }
}
