// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // Enable verbose logging for debugging
  FlutterBluePlus.setLogLevel(LogLevel.verbose);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Sports Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BLEHome(),
    );
  }
}

class BLEHome extends StatefulWidget {
  const BLEHome({super.key});
  @override
  State<BLEHome> createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {
  final String deviceName = "ESP32_IMU";
  final String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  final String characteristicUuid = "abcdef01-1234-5678-1234-56789abcdef0";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notificationStream;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  List<ScanResult> discoveredDevices = [];

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

  String debugMessage = "";
  DateTime? lastDataReceived;

  @override
  void initState() {
    super.initState();
    initializeBluetooth();
  }

  Future<void> initializeBluetooth() async {
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
    Map<Permission, PermissionStatus> permissions = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    hasPermissions = permissions.values.every((status) =>
    status == PermissionStatus.granted || status == PermissionStatus.limited);

    if (hasPermissions) {
      startScan();
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'Bluetooth and Location permissions are required for this app to connect to your sports tracker.'),
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
      sport = "Scanning...";
      discoveredDevices.clear();
      debugMessage = "Starting BLE scan...";
    });

    try {
      await FlutterBluePlus.stopScan();

      // Start scanning with platform-specific settings
      if (Platform.isIOS) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 20),
          // iOS doesn't need androidUsesFineLocation
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

        // Debug logging for iOS
        if (Platform.isIOS) {
          print("=== iOS BLE Scan Results ===");
          for (var result in results) {
            print("Device: ${result.device.platformName}");
            print("Adv Name: ${result.advertisementData.advName}");
            print("Device ID: ${result.device.remoteId}");
            print("RSSI: ${result.rssi}");
            print("---");
          }
        }

        // Look for target device with flexible matching
        for (var result in results) {
          String foundDeviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;

          // More flexible matching for iOS
          bool isTargetDevice = foundDeviceName == deviceName ||
              foundDeviceName.contains("ESP32") ||
              result.advertisementData.advName == deviceName ||
              result.advertisementData.advName.contains("ESP32");

          if (isTargetDevice) {
            _device = result.device;
            FlutterBluePlus.stopScan();
            setState(() {
              debugMessage = "Found target device: $foundDeviceName";
              isScanning = false;
            });
            connectToDevice(_device!);
            return;
          }
        }

        // Update status with number of devices found
        setState(() {
          debugMessage = "Found ${results.length} devices, looking for $deviceName...";
        });
      });

      // Auto-stop scanning after timeout
      Timer(Duration(seconds: Platform.isIOS ? 20 : 15), () {
        if (isScanning) {
          FlutterBluePlus.stopScan();
          setState(() {
            isScanning = false;
            if (!isConnected) {
              sport = "Device not found";
              debugMessage = "Could not find $deviceName. Found ${discoveredDevices.length} devices total.";
            }
          });
        }
      });

    } catch (e) {
      setState(() {
        debugMessage = "Scan error: $e";
        isScanning = false;
        sport = "Scan failed";
      });
      print("iOS Scan Error: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      isScanning = false;
      sport = "Connecting...";
      debugMessage = "Attempting to connect to ${device.platformName}...";
    });

    try {
      // Connect with longer timeout for iOS
      await device.connect(
        timeout: Duration(seconds: Platform.isIOS ? 15 : 10),
        autoConnect: false,
      );

      // Listen for connection state changes
      _stateSubscription = device.connectionState.listen((state) async {
        print("Connection state changed: $state");

        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
        });

        if (state == BluetoothConnectionState.connected) {
          setState(() {
            debugMessage = "Connected! Discovering services...";
          });
          await _setupServices(device);
        } else if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            sport = "Disconnected";
            isConnecting = false;
            debugMessage = "Device disconnected";
          });
        }
      });

    } catch (e) {
      setState(() {
        debugMessage = "Connection error: $e";
        isConnecting = false;
        sport = "Connection Failed";
      });
      print("iOS Connection Error: $e");
    }
  }

  Future<void> _setupServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      print("=== Discovered Services ===");
      for (var service in services) {
        print("Service UUID: ${service.uuid}");
        for (var char in service.characteristics) {
          print("  Characteristic UUID: ${char.uuid}");
        }
      }

      for (var service in services) {
        // Case-insensitive UUID comparison
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
                  handleNotification(value);
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

      // If we get here, service/characteristic not found
      setState(() {
        debugMessage = "Required service ($serviceUuid) or characteristic ($characteristicUuid) not found";
        sport = "Service not found";
        isConnecting = false;
      });

    } catch (e) {
      setState(() {
        debugMessage = "Service discovery error: $e";
        isConnecting = false;
        sport = "Setup failed";
      });
      print("iOS Service Discovery Error: $e");
    }
  }

  void handleNotification(List<int> data) {
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
          if (debugMessage.contains("parse error") || debugMessage.contains("No data")) {
            debugMessage = "Data received successfully";
          }
        });
      } else {
        setState(() {
          debugMessage = "Invalid data format. Expected: speed,angle,power,direction. Got: $decoded";
        });
      }
    } catch (e) {
      setState(() {
        debugMessage = "Data parse error: $e";
      });
      print("Data parsing error: $e");
    }
  }

  String _getConnectionStatusText() {
    if (Platform.isAndroid && !isBluetoothOn) return "Bluetooth Off";
    if (Platform.isAndroid && !hasPermissions) return "No Permissions";
    if (isScanning) return "Scanning...";
    if (isConnecting) return "Connecting...";
    if (isConnected) return "Connected";
    return "Ready to scan";
  }

  Color _getConnectionStatusColor() {
    if (isConnected) return Colors.green;
    if (isConnecting || isScanning) return Colors.orange;
    if (Platform.isAndroid && (!isBluetoothOn || !hasPermissions)) return Colors.red;
    return Colors.blue;
  }

  // Add the missing _buildDataRow method
  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("BLE Sports Tracker"),
          actions: [
            IconButton(
              icon: Icon(isScanning ? Icons.stop : Icons.refresh),
              onPressed: () {
                if (Platform.isIOS) {
                  startScan();
                } else {
                  if (isBluetoothOn && hasPermissions) startScan();
                }
              },
            ),
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Platform Info Card (for debugging)
            Card(
            color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Platform: ${Platform.isIOS ? 'iOS' : 'Android'}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text("Target Device: $deviceName"),
                    Text("Service UUID: $serviceUuid"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _getConnectionStatusColor(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Status: ${_getConnectionStatusText()}",
                          style: TextStyle(
                            color: _getConnectionStatusColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isScanning) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (lastDataReceived != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Last data: ${DateTime.now().difference(lastDataReceived!).inSeconds}s ago",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Real-time Data Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Real-time Data",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDataRow("Speed", "${speed.toStringAsFixed(2)} m/s"),
                    _buildDataRow("Angle", "${angle.toStringAsFixed(2)}°"),
                    _buildDataRow("Power", "${power.toStringAsFixed(2)} W"),
                    _buildDataRow("Direction", direction),
                  ],
                ),
              ),
            ),

            // Debug Messages
            if (debugMessage.isNotEmpty) ...[
        const SizedBox(height: 20),
    Card(
    color: debugMessage.contains("error") || debugMessage.contains("failed")
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
    color: debugMessage.contains("error") || debugMessage.contains("failed")
    ? Colors.red.shade900
        : Colors.green.shade900,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 8),
    Text(
    debugMessage,
    style: TextStyle(
    color: debugMessage.contains("error") || debugMessage.contains("failed")
    ? Colors.red.shade900
        : Colors.green.shade900,
    ),
    ),
    ],
    ),
    ),
    ),
    ],

    // Discovered Devices (for debugging)
    if (discoveredDevices.isNotEmpty) ...[
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
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.advertisementData.advName.isNotEmpty
        ? result.advertisementData.advName
        : "Unknown Device";
    return ListTile(
    title: Text(name),
    subtitle: Text("RSSI: ${result.rssi}"),
    dense: true,
    );
    }).toList(),
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
}

