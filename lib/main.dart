import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
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
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
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

  @override
  void initState() {
    super.initState();
    initializeBluetooth();
  }

  Future<void> initializeBluetooth() async {
    // Check if Bluetooth is available
    if (await FlutterBluePlus.isAvailable == false) {
      setState(() {
        debugMessage = "Bluetooth not available on this device";
      });
      return;
    }

    // Listen to Bluetooth adapter state
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        isBluetoothOn = state == BluetoothAdapterState.on;
        if (!isBluetoothOn) {
          sport = "Bluetooth is off";
          debugMessage = "Please turn on Bluetooth";
        }
      });

      if (isBluetoothOn && hasPermissions) {
        startScan();
      }
    });

    // Request permissions
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};

    if (Platform.isIOS) {
      // iOS permissions
      statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetooth,
      ].request();
    } else {
      // Android permissions
      statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    }

    bool allGranted = statuses.values.every((status) => status.isGranted);

    setState(() {
      hasPermissions = allGranted;
      if (!allGranted) {
        debugMessage = "Permissions denied: ${statuses.toString()}";
      }
    });

    if (hasPermissions && isBluetoothOn) {
      startScan();
    } else if (!allGranted) {
      showPermissionDialog();
    }
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'Bluetooth and Location permissions are required for this app to work properly.'),
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
    _notificationStream?.cancel();
    _stateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _device?.disconnect();
    super.dispose();
  }

  Future<void> startScan() async {
    if (!hasPermissions || !isBluetoothOn || isScanning) return;

    setState(() {
      isScanning = true;
      sport = "Scanning...";
      discoveredDevices.clear();
      debugMessage = "Looking for $deviceName...";
    });

    try {
      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      // Wait a moment before starting new scan
      await Future.delayed(const Duration(milliseconds: 500));

      // Start scan with timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          discoveredDevices = results;
          debugMessage = "Found ${results.length} devices";
        });

        // Look for specific device
        for (var result in results) {
          String deviceNameFound = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;

          print("Found device: $deviceNameFound (${result.device.remoteId})");

          if (deviceNameFound == deviceName) {
            setState(() {
              debugMessage = "Found target device: $deviceName";
            });
            _device = result.device;
            FlutterBluePlus.stopScan();
            connectToDevice(_device!);
            break;
          }
        }
      });

      // Auto-stop scanning after timeout
      Timer(const Duration(seconds: 15), () {
        if (isScanning && !isConnected) {
          FlutterBluePlus.stopScan();
          setState(() {
            isScanning = false;
            if (discoveredDevices.isEmpty) {
              debugMessage = "No devices found. Make sure $deviceName is powered on and nearby.";
              sport = "No devices found";
            } else {
              debugMessage = "Target device '$deviceName' not found among ${discoveredDevices.length} devices";
              sport = "Device not found";
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
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      sport = "Connecting...";
      isScanning = false;
    });

    try {
      // Connect with timeout
      await device.connect(timeout: const Duration(seconds: 10));

      _stateSubscription = device.connectionState.listen((state) async {
        print("Connection state: $state");

        if (state == BluetoothConnectionState.connected) {
          setState(() {
            isConnected = true;
            isConnecting = false;
            sport = "Discovering services...";
          });

          try {
            // Discover services
            List<BluetoothService> services = await device.discoverServices();
            print("Found ${services.length} services");

            bool serviceFound = false;
            for (var service in services) {
              print("Service UUID: ${service.uuid}");

              if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
                serviceFound = true;
                print("Target service found!");

                for (var char in service.characteristics) {
                  print("Characteristic UUID: ${char.uuid}");

                  if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
                    _characteristic = char;

                    // Enable notifications
                    await char.setNotifyValue(true);

                    _notificationStream = char.lastValueStream.listen((value) {
                      handleNotification(value);
                    });

                    setState(() {
                      sport = "Connected & Ready";
                      debugMessage = "Successfully connected to $deviceName";
                    });
                    return;
                  }
                }
              }
            }

            if (!serviceFound) {
              setState(() {
                debugMessage = "Service UUID $serviceUuid not found on device";
                sport = "Service not found";
              });
            }

          } catch (e) {
            setState(() {
              debugMessage = "Service discovery error: $e";
              sport = "Service discovery failed";
            });
          }

        } else if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            isConnected = false;
            isConnecting = false;
            sport = "Disconnected";
            debugMessage = "Device disconnected";
          });

          // Clean up
          _characteristic = null;
          _notificationStream?.cancel();
        }
      });

    } catch (e) {
      setState(() {
        debugMessage = "Connection error: $e";
        isConnecting = false;
        sport = "Connection Failed";
      });
    }
  }

  void handleNotification(List<int> data) {
    try {
      String decoded = utf8.decode(data);
      print("Received data: $decoded");

      List<String> parts = decoded.split(",");
      if (parts.length >= 4) {
        setState(() {
          speed = double.tryParse(parts[0]) ?? 0.0;
          angle = double.tryParse(parts[1]) ?? 0.0;
          power = double.tryParse(parts[2]) ?? 0.0;
          direction = parts[3];
          debugMessage = "Data received: $decoded";
        });
      }
    } catch (e) {
      setState(() {
        debugMessage = "Data parse error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Sports Tracker"),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? null : startScan,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected
                              ? Icons.bluetooth_connected
                              : isBluetoothOn
                              ? Icons.bluetooth
                              : Icons.bluetooth_disabled,
                          color: isConnected
                              ? Colors.green
                              : isBluetoothOn
                              ? Colors.blue
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Status: $sport",
                          style: TextStyle(
                            color: isConnected
                                ? Colors.green
                                : isBluetoothOn
                                ? Colors.blue
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isScanning || isConnecting)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
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
                        String name = result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : result.advertisementData.advName.isNotEmpty
                            ? result.advertisementData.advName
                            : "Unknown";
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          subtitle: Text(result.device.remoteId.toString()),
                          trailing: Text("${result.rssi} dBm"),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
            if (debugMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: debugMessage.contains("error") || debugMessage.contains("failed")
                    ? Colors.red.shade100
                    : Colors.blue.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Debug: $debugMessage",
                    style: TextStyle(
                      color: debugMessage.contains("error") || debugMessage.contains("failed")
                          ? Colors.red.shade900
                          : Colors.blue.shade900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}