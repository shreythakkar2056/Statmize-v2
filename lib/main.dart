import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Sports Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final flutterReactiveBle = FlutterReactiveBle();

  final deviceName = "ESP32_IMU";
  final serviceUuid = Uuid.parse("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final characteristicUuid = Uuid.parse("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  DiscoveredDevice? _foundDevice;
  StreamSubscription<DiscoveredDevice>? _scanStream;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _notificationStream;

  String sport = "Unknown";
  double speed = 0.0;
  double angle = 0.0;
  double power = 0.0;
  String direction = "Unknown";

  bool isConnecting = false;
  bool isConnected = false;

  String? selectedSport;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    _scanStream?.cancel();
    _connection?.cancel();
    _notificationStream?.cancel();
    super.dispose();
  }

  void startScan() {
    _scanStream = flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      if (device.name == deviceName) {
        _foundDevice = device;
        _scanStream?.cancel();
        connectToDevice(device);
        setState(() {});
      }
    }, onError: (error) {
      print("Scan error: $error");
    });
  }

  void connectToDevice(DiscoveredDevice device) {
    if (isConnecting || isConnected) return;

    setState(() {
      isConnecting = true;
    });

    _connection = flutterReactiveBle
        .connectToDevice(id: device.id, connectionTimeout: const Duration(seconds: 5))
        .listen((connectionState) {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        setState(() {
          isConnecting = false;
          isConnected = true;
        });
        subscribeToCharacteristic(device.id);
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        setState(() {
          isConnected = false;
          isConnecting = false;
          sport = "Disconnected";
        });
        startScan();
      }
    }, onError: (error) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        sport = "Connection Error";
      });
      print("Connection error: $error");
      startScan();
    });
  }

  void subscribeToCharacteristic(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
      deviceId: deviceId,
    );

    _notificationStream = flutterReactiveBle.subscribeToCharacteristic(characteristic).listen(
          (data) {
        String decodedData = utf8.decode(data);
        processData(decodedData);
      },
      onError: (error) {
        print("Notification error: $error");
      },
    );
  }

  void processData(String data) {
    // Data format: "ax,ay,az,gx,gy,gz"
    List<String> parts = data.trim().split(',');
    if (parts.length != 6) return;

    double ax = double.tryParse(parts[0]) ?? 0.0;
    double ay = double.tryParse(parts[1]) ?? 0.0;
    double az = double.tryParse(parts[2]) ?? 0.0;
    double gx = double.tryParse(parts[3]) ?? 0.0;
    double gy = double.tryParse(parts[4]) ?? 0.0;
    double gz = double.tryParse(parts[5]) ?? 0.0;

    double resultantAccel = sqrt(ax * ax + ay * ay + az * az);
    double resultantGyro = sqrt(gx * gx + gy * gy + gz * gz);

    if (selectedSport == null) {
      sport = "Select a sport";
      speed = 0.0;
      angle = 0.0;
      power = 0.0;
      direction = "Unknown";
    } else {
      sport = selectedSport!;
      switch (selectedSport) {
        case 'Cricket':
          speed = resultantGyro * 10;
          angle = atan2(ay, ax) * (180 / pi);
          power = resultantAccel * 5;
          direction = gx > 0 ? "Right" : "Left";
          break;
        case 'Badminton':
          speed = resultantAccel * 8;
          angle = atan2(az, ay) * (180 / pi);
          power = resultantGyro * 4;
          direction = gy > 0 ? "Forward" : "Backward";
          break;
        case 'Lawn Tennis':
          speed = resultantGyro * 6;
          angle = atan2(ax, az) * (180 / pi);
          power = resultantAccel * 3;
          direction = gz > 0 ? "Upward" : "Downward";
          break;
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("STATmize")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _foundDevice == null
            ? const Center(child: Text("Scanning for devices..."))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Found Device: ${_foundDevice!.name}"),
            const SizedBox(height: 10),
            Text("Status: ${isConnecting ? "Connecting..." : (isConnected ? "Connected" : "Disconnected")}"),
            const SizedBox(height: 20),
            const Text("Select Sport:"),
            DropdownButton<String>(
              hint: const Text("Select Sport"),
              value: selectedSport,
              items: ['Cricket', 'Badminton', 'Lawn Tennis'].map((sport) {
                return DropdownMenuItem(
                  value: sport,
                  child: Text(sport),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedSport = val;
                });
              },
            ),
            const SizedBox(height: 20),
            Text("Sport: $sport"),
            Text("Speed: ${speed.toStringAsFixed(2)}"),
            Text("Angle: ${angle.toStringAsFixed(2)}°"),
            Text("Power: ${power.toStringAsFixed(2)}"),
            Text("Direction: $direction"),
          ],
        ),
      ),
    );
  }
}


