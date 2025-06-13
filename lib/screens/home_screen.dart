import 'package:flutter/material.dart';
import 'package:app/widgets/connection_card.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/widgets/profile_modal.dart';
import 'package:app/core/session_page.dart';

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
                    'Hello, Rownok!',
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
                  _buildSportTab("Cricket", Icons.sports_cricket, selectedSport == "Cricket"),
                  const SizedBox(width: 12),
                  _buildSportTab("Tennis", Icons.sports_tennis, selectedSport == "Tennis"),
                  const SizedBox(width: 12),
                  _buildSportTab("Badminton", Icons.sports_tennis, selectedSport == "Badminton"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildEnhancedConnectionCard(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _startNewSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
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
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      "${latestData['speed'].toStringAsFixed(2)} m/s",
                      Icons.flash_on,
                    ),
                    _buildDataRow(
                      "Angle",
                      "${latestData['angle'].toStringAsFixed(2)}°",
                      Icons.rotate_right,
                    ),
                    _buildDataRow(
                      "Power",
                      "${latestData['power'].toStringAsFixed(2)} W",
                      Icons.bolt,
                    ),
                    _buildDataRow(
                      "Direction", 
                      latestData['direction'], 
                      Icons.navigation
                    ),
                  ],
                ),
              ),
            ),
            if (debugMessage.isNotEmpty) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildSportTab(String sport, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedSport = sport;
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
}

// This screen serves as the main dashboard for the app, displaying the connection status and live data from the BLE device.
// It uses the BLEService to manage Bluetooth operations and updates the UI based on the connection state and received data.