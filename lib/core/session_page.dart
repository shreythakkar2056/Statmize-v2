// session_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SessionPage extends StatefulWidget {
  final String selectedSport;
  
  const SessionPage({
    super.key,
    required this.selectedSport,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final String deviceName = "ESP32_IMU";
  final String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  final String characteristicUuid = "abcdef01-1234-5678-1234-56789abcdef0";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notificationStream;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  double speed = 0.0;
  double angle = 0.0;
  double power = 0.0;
  String direction = "Unknown";

  bool isConnecting = false;
  bool isConnected = false;
  bool isScanning = false;
  String debugMessage = "";
  DateTime? lastDataReceived;
  DateTime? sessionStartTime;
  
  // Session stats
  double maxSpeed = 0.0;
  double maxPower = 0.0;
  int swingCount = 0;
  
  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();
    startScan();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _disconnect() {
    _notificationStream?.cancel();
    _stateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _device?.disconnect();
    setState(() {
      isConnected = false;
      isConnecting = false;
      _device = null;
      _characteristic = null;
    });
  }

  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      debugMessage = "Scanning for ${widget.selectedSport} tracker...";
    });

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: Platform.isAndroid,
      );

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          String foundDeviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;

          bool isTargetDevice = foundDeviceName == deviceName ||
              foundDeviceName.contains("ESP32") ||
              result.advertisementData.advName == deviceName ||
              result.advertisementData.advName.contains("ESP32");

          if (isTargetDevice) {
            _device = result.device;
            FlutterBluePlus.stopScan();
            setState(() {
              debugMessage = "Found device: $foundDeviceName";
              isScanning = false;
            });
            connectToDevice(_device!);
            return;
          }
        }
      });

      Timer(const Duration(seconds: 15), () {
        if (isScanning) {
          FlutterBluePlus.stopScan();
          setState(() {
            isScanning = false;
            debugMessage = "Device not found. Please check your tracker.";
          });
        }
      });
    } catch (e) {
      setState(() {
        debugMessage = "Scan error: $e";
        isScanning = false;
      });
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      isScanning = false;
      debugMessage = "Connecting to ${widget.selectedSport} tracker...";
    });

    try {
      await device.connect(
        timeout: Duration(seconds: Platform.isIOS ? 15 : 10),
        autoConnect: false,
      );

      _stateSubscription = device.connectionState.listen((state) async {
        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
        });

        if (state == BluetoothConnectionState.connected) {
          setState(() {
            debugMessage = "Connected! Setting up ${widget.selectedSport} tracking...";
          });
          await _setupServices(device);
        } else if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            debugMessage = "Tracker disconnected";
            isConnecting = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        debugMessage = "Connection failed: $e";
        isConnecting = false;
      });
    }
  }

  Future<void> _setupServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _characteristic = char;

              if (!char.properties.notify) {
                setState(() {
                  debugMessage = "Tracker doesn't support live data";
                });
                return;
              }

              await char.setNotifyValue(true);

              _notificationStream = char.lastValueStream.listen(
                (value) => handleNotification(value),
                onError: (error) {
                  setState(() {
                    debugMessage = "Data stream error: $error";
                  });
                },
              );

              setState(() {
                debugMessage = "${widget.selectedSport} session started!";
                isConnecting = false;
              });
              return;
            }
          }
        }
      }

      setState(() {
        debugMessage = "Tracker service not found";
        isConnecting = false;
      });
    } catch (e) {
      setState(() {
        debugMessage = "Setup failed: $e";
        isConnecting = false;
      });
    }
  }

  void handleNotification(List<int> data) {
    try {
      String decoded = utf8.decode(data);
      List<String> parts = decoded.trim().split(",");

      if (parts.length >= 4) {
        setState(() {
          speed = double.tryParse(parts[0]) ?? 0.0;
          angle = double.tryParse(parts[1]) ?? 0.0;
          power = double.tryParse(parts[2]) ?? 0.0;
          direction = parts[3].trim();
          lastDataReceived = DateTime.now();

          // Update session stats
          if (speed > maxSpeed) maxSpeed = speed;
          if (power > maxPower) maxPower = power;
          if (speed > 1.0) swingCount++; // Count as swing if speed > 1 m/s
        });
      }
    } catch (e) {
      setState(() {
        debugMessage = "Data error: $e";
      });
    }
  }

  Widget _buildConnectionStatus() {
    IconData icon;
    String status;
    Color color;

    if (isConnected) {
      icon = Icons.bluetooth_connected;
      status = "Connected & Tracking";
      color = Colors.green;
    } else if (isConnecting) {
      icon = Icons.bluetooth_searching;
      status = "Connecting...";
      color = Colors.orange;
    } else if (isScanning) {
      icon = Icons.bluetooth_searching;
      status = "Scanning for Tracker";
      color = Colors.blue;
    } else {
      icon = Icons.bluetooth_disabled;
      status = "Not Connected";
      color = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        widget.selectedSport,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isScanning || isConnecting) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
            if (debugMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                debugMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "${widget.selectedSport} Session",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isScanning ? Icons.stop : Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              if (isScanning) {
                FlutterBluePlus.stopScan();
                setState(() {
                  isScanning = false;
                });
              } else {
                startScan();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Connection Status
            _buildConnectionStatus(),

            // Real-time Data Grid
            if (isConnected) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Live Data",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _buildDataCard("Speed", "${speed.toStringAsFixed(1)} m/s", Icons.speed, Colors.blue),
                        _buildDataCard("Power", "${power.toStringAsFixed(0)} W", Icons.bolt, Colors.orange),
                        _buildDataCard("Angle", "${angle.toStringAsFixed(1)}°", Icons.rotate_right, Colors.green),
                        _buildDataCard("Direction", direction, Icons.navigation, Colors.purple),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Session Stats
                    Text(
                      "Session Stats",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        _buildDataCard("Max Speed", "${maxSpeed.toStringAsFixed(1)} m/s", Icons.flash_on, Colors.red),
                        _buildDataCard("Max Power", "${maxPower.toStringAsFixed(0)} W", Icons.fitness_center, Colors.deepOrange),
                        _buildDataCard("Swings", "$swingCount", Icons.sports_tennis, Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // Save session and return to dashboard
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "End Session",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}