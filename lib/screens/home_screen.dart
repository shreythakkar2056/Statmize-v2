import 'package:flutter/material.dart';
import 'package:app/widgets/connection_card.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/widgets/profile_modal.dart';
import 'package:app/core/session_page.dart';
import 'package:app_settings/app_settings.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeToggle;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BLEService bleService = BLEService();
  Map<String, dynamic> latestData = {
    'speed': 0.0,
    'angle': 0.0,
    'power': 0.0,
    'direction': 'Unknown',
  };
  String debugMessage = '';
  String selectedSport = "Cricket";
  List<dynamic> nearbyDevices = [];
  String selectedAction = "Start Session";

  // Add stats for each sport
  final Map<String, Map<String, dynamic>> sportStats = {
    "Cricket": {
      "duration": "45 minutes",
      "stats": [
        StatItem(label: "Speed", value: "85"),
        StatItem(label: "Power", value: "78"),
        StatItem(label: "Accuracy", value: "92%"),
      ],
      "gradientColors": [
        Colors.pink,
        Colors.pink.shade50,
      ],
    },
    "Tennis": {
      "duration": "38 minutes",
      "stats": [
        StatItem(label: "Speed", value: "72"),
        StatItem(label: "Power", value: "65"),
        StatItem(label: "Accuracy", value: "88%"),
      ],
      "gradientColors": [
        Colors.blue,
        Colors.blue.shade50,
      ],
    },
    "Badminton": {
      "duration": "52 minutes",
      "stats": [
        StatItem(label: "Speed", value: "91"),
        StatItem(label: "Power", value: "80"),
        StatItem(label: "Accuracy", value: "95%"),
      ],
      "gradientColors": [
        Colors.purple,
        Colors.purple.shade50,
      ],
    },
  };

  // Add weekly progress data for each sport
  final Map<String, Map<String, dynamic>> weeklyProgressData = {
    "Cricket": {
      "date": "19 November",
      "percent": 0.87,
      "percentLabel": "87%",
      "goalLabel": "Goal Achievement",
      "gradientColors": [
        Colors.blue.shade300,
        Colors.purple.shade100,
      ],
    },
    "Tennis": {
      "date": "19 November",
      "percent": 0.75,
      "percentLabel": "75%",
      "goalLabel": "Goal Achievement",
      "gradientColors": [
        Colors.green.shade300,
        Colors.teal.shade100,
      ],
    },
    "Badminton": {
      "date": "19 November",
      "percent": 0.93,
      "percentLabel": "93%",
      "goalLabel": "Goal Achievement",
      "gradientColors": [
        Colors.purple.shade300,
        Colors.pink.shade100,
      ],
    },
  };

  // Add action card data for each sport
  final Map<String, Map<String, dynamic>> actionCardData = {
    "Cricket": {
      "Start Session": {
        "icon": Icons.show_chart,
        "iconBg": Color(0xFFD6F5E6),
        "iconColor": Color(0xFF34C759),
        "title": "Start Session",
        "subtitle": "Begin training",
      },
      "Analytics": {
        "icon": Icons.bar_chart,
        "iconBg": Color(0xFFE6F0FF),
        "iconColor": Color(0xFF2979FF),
        "title": "Analytics",
        "subtitle": "View detailed stats",
      },
    },
    "Tennis": {
      "Start Session": {
        "icon": Icons.sports_tennis,
        "iconBg": Color(0xFFD6F5E6),
        "iconColor": Color(0xFF34C759),
        "title": "Start Session",
        "subtitle": "Begin training",
      },
      "Analytics": {
        "icon": Icons.bar_chart,
        "iconBg": Color(0xFFE6F0FF),
        "iconColor": Color(0xFF2979FF),
        "title": "Analytics",
        "subtitle": "View detailed stats",
      },
    },
    "Badminton": {
      "Start Session": {
        "icon": Icons.sports_tennis,
        "iconBg": Color(0xFFD6F5E6),
        "iconColor": Color(0xFF34C759),
        "title": "Start Session",
        "subtitle": "Begin training",
      },
      "Analytics": {
        "icon": Icons.bar_chart,
        "iconBg": Color(0xFFE6F0FF),
        "iconColor": Color(0xFF2979FF),
        "title": "Analytics",
        "subtitle": "View detailed stats",
      },
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeBLE();
  }

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileModal(
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
      ),
    );
  }

  void _startNewSession() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSessionTypeModal(),
    );
  }

  Widget _buildSessionTypeModal() {
    final double modalHeight = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(
        maxHeight: modalHeight,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
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
              SizedBox(
                height: 340, // More space for the grid
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.1,
                  children: [
                    _buildSportCard("Cricket", Icons.sports_cricket, Colors.green),
                    _buildSportCard("Tennis", Icons.sports_tennis, Colors.blue),
                    _buildSportCard("Badminton", Icons.sports_tennis, Colors.orange),
                    _buildSportCard("Custom", Icons.sports, Colors.purple),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportCard(String sport, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionPage(selectedSport: sport),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$sport session started!'),
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
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                sport,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeBLE() async {
    await bleService.initializeBluetooth();
    bleService.dataStream.listen((data) {
      setState(() {
        latestData = data;
      });
    });
    bleService.debugStream.listen((message) {
      setState(() {
        debugMessage = message;
      });
      print('Debug: $message');
      // Show snackbar if location needs to be turned on
      if (message.toLowerCase().contains('turn on location')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please turn on Location Services (GPS) to scan for BLE devices.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                try {
                  AppSettings.openAppSettings(type: AppSettingsType.location);
                } catch (e) {}
              },
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    });
    bleService.devicesStream.listen((devices) {
      print("UI received "+devices.length.toString()+" devices");
      setState(() {
        nearbyDevices = devices;
      });
    });
  }

  @override
  void dispose() {
    bleService.dispose();
    super.dispose();
  }

  Color _getConnectionStatusColor() {
    return bleService.connectionStatusColor;
  }

  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
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
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedConnectionCard() {
    // Card at the top showing Bluetooth connection status
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
                    bleService.isConnected ? Icons.bluetooth_connected : 
                    bleService.isScanning ? Icons.bluetooth_searching :
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
                        bleService.isConnected ? "Device Connected" : 
                        bleService.isScanning ? "Scanning for Device" :
                        bleService.isConnecting ? "Connecting..." :
                        "Device Disconnected",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getConnectionStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bleService.isConnected ? "ESP32_IMU • Ready to receive data" :
                        bleService.isScanning ? "Looking for ESP32_IMU..." :
                        bleService.isConnecting ? "Establishing connection..." :
                        "Bluetooth device not found",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (bleService.isConnected)
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
            if (bleService.isScanning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: _getConnectionStatusColor().withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(_getConnectionStatusColor()),
              ),
            ],
            if (bleService.lastDataReceived != null && bleService.isConnected) ...[
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
                    "Last update: "+
                      "${DateTime.now().difference(bleService.lastDataReceived!).inSeconds}s ago",
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
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 200,
        leading: GestureDetector(
          onTap: _showProfileModal,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hello, user!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              bleService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => bleService.startScan(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: Theme.of(context).colorScheme.onSurface,
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Sport Selection Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _enhancedSportTab(
                      label: "Cricket",
                      icon: Icons.sports_cricket,
                      isSelected: selectedSport == "Cricket",
                      onTap: () {
                        setState(() {
                          selectedSport = "Cricket";
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      unselectedColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 12),
                    _enhancedSportTab(
                      label: "Tennis",
                      icon: Icons.sports_tennis,
                      isSelected: selectedSport == "Tennis",
                      onTap: () {
                        setState(() {
                          selectedSport = "Tennis";
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      unselectedColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.grey.shade100,
                    ),
                    const SizedBox(width: 12),
                    _enhancedSportTab(
                      label: "Badminton",
                      icon: Icons.sports_tennis,
                      isSelected: selectedSport == "Badminton",
                      onTap: () {
                        setState(() {
                          selectedSport = "Badminton";
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      unselectedColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.grey.shade100,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Show only one stat card for the selected sport
              SessionStatCard(
                title: "Today's Session",
                duration: sportStats[selectedSport]!['duration'],
                stats: List<StatItem>.from(sportStats[selectedSport]!['stats']),
                gradientColors: List<Color>.from(sportStats[selectedSport]!['gradientColors']),
                isFullWidth: true,
              ),
              const SizedBox(height: 20),
              // Show only one weekly progress card for the selected sport
              WeeklyProgressCard(
                title: "Weekly Progress",
                date: weeklyProgressData[selectedSport]!['date'],
                percent: weeklyProgressData[selectedSport]!['percent'],
                percentLabel: weeklyProgressData[selectedSport]!['percentLabel'],
                goalLabel: weeklyProgressData[selectedSport]!['goalLabel'],
                gradientColors: List<Color>.from(weeklyProgressData[selectedSport]!['gradientColors']),
              ),
              const SizedBox(height: 20),
              // Action Cards Row (side by side)
              SizedBox(
                height: 110,
                child: ActionCard(
                  icon: actionCardData[selectedSport]!['Analytics']["icon"],
                  iconBg: actionCardData[selectedSport]!['Analytics']["iconBg"],
                  iconColor: actionCardData[selectedSport]!['Analytics']["iconColor"],
                  title: actionCardData[selectedSport]!['Analytics']["title"],
                  subtitle: actionCardData[selectedSport]!['Analytics']["subtitle"],
                ),
              ),
              const SizedBox(height: 20),
              _buildEnhancedConnectionCard(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _startNewSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A0E25)
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          "Start New Session",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (debugMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
                Card(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Debug Information",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          debugMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        // Always show the count for debugging
                        Text(
                          "Nearby devices found: "+nearbyDevices.length.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (nearbyDevices.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: nearbyDevices.length,
                            itemBuilder: (context, index) {
                              final device = nearbyDevices[index];
                              final name = device.device.platformName.isNotEmpty
                                  ? device.device.platformName
                                  : device.advertisementData.advName;
                              final id = device.device.remoteId.toString();
                              final rssi = device.rssi;
                              print('Device in UI: $name | ID: $id | RSSI: $rssi');
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  "$name  |  ID: $id  |  RSSI: $rssi",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _enhancedSportTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkBlue = const Color(0xFF0A0E25);
    final softWhite = const Color(0xFFEFEDE6);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? (isSelected ? darkBlue : softWhite)
                  : (isSelected ? Colors.white : Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? (isSelected ? darkBlue : softWhite)
                    : (isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionStatCard extends StatelessWidget {
  final String title;
  final String duration;
  final List<StatItem> stats;
  final List<Color> gradientColors;
  final bool isFullWidth;

  const SessionStatCard({
    super.key,
    required this.title,
    required this.duration,
    required this.stats,
    required this.gradientColors,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isFullWidth ? double.infinity : 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  gradientColors[0].withOpacity(0.35),
                  gradientColors[1].withOpacity(0.18),
                ]
              : gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 14,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Play button removed
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stats.map((stat) => stat).toList(),
          ),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  const StatItem({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class WeeklyProgressCard extends StatelessWidget {
  final String title;
  final String date;
  final double percent;
  final String percentLabel;
  final String goalLabel;
  final List<Color> gradientColors;

  const WeeklyProgressCard({
    super.key,
    required this.title,
    required this.date,
    required this.percent,
    required this.percentLabel,
    required this.goalLabel,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  gradientColors[0].withOpacity(0.32),
                  gradientColors[1].withOpacity(0.16),
                ]
              : gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 14,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percentLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goalLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.13)
                  : Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.blue.shade200 : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  const ActionCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF23263A) : const Color(0xFFF7F7FA);
    final textColor = isDark ? const Color(0xFFEFEDE6) : const Color(0xFF0A0E25);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: const Color(0xFFB0B3C7), size: 26),
        ],
      ),
    );
  }
}

// This screen serves as the main dashboard for the app, displaying the connection status and live data from the BLE device.
// It uses the BLEService to manage Bluetooth operations and updates the UI based on the connection state and received data.