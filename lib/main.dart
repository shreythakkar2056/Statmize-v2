import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

  String debugMessage = "";

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    var locationStatus = await Permission.location.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();

    hasPermissions = locationStatus.isGranted &&
        bluetoothScanStatus.isGranted &&
        bluetoothConnectStatus.isGranted;

    if (hasPermissions) {
      startScan();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
              'Bluetooth and Location permissions are required for this app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
  }

  @override
  void dispose() {
    _notificationStream?.cancel();
    _stateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  Future<void> startScan() async {
    if (!hasPermissions || isScanning) return;

    setState(() {
      isScanning = true;
      sport = "Scanning...";
      discoveredDevices.clear();
    });

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanResultsSubscription =
          FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          discoveredDevices = results;
        });

        for (var result in results) {
          if (result.device.platformName == deviceName) {
            _device = result.device;
            FlutterBluePlus.stopScan();
            connectToDevice(_device!);
            break;
          }
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
      sport = "Connecting...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 5));

      _stateSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          isConnected = true;
          List<BluetoothService> services = await device.discoverServices();
          for (var service in services) {
            if (service.uuid.toString() == serviceUuid) {
              for (var char in service.characteristics) {
                if (char.uuid.toString() == characteristicUuid) {
                  _characteristic = char;
                  await char.setNotifyValue(true);
                  _notificationStream = char.lastValueStream.listen((value) {
                    handleNotification(value);
                  });
                  setState(() {
                    sport = "Connected";
                    isConnecting = false;
                  });
                  break;
                }
              }
            }
          }
        } else {
          isConnected = false;
          setState(() {
            sport = "Disconnected";
            isConnecting = false;
          });
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
      List<String> parts = decoded.split(",");
      if (parts.length >= 4) {
        setState(() {
          speed = double.tryParse(parts[0]) ?? 0.0;
          angle = double.tryParse(parts[1]) ?? 0.0;
          power = double.tryParse(parts[2]) ?? 0.0;
          direction = parts[3];
        });
      }
    } catch (e) {
      setState(() {
        debugMessage = "Notification parse error: $e";
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
            onPressed: startScan,
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
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Status: $sport",
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isScanning) const LinearProgressIndicator(),
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
            if (debugMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Debug: $debugMessage",
                    style: TextStyle(color: Colors.red.shade900),
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

