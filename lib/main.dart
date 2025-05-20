import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:convert';
import 'dart:math';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'BLE Sports Tracker',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: BLEHome());
  }
}

class BLEHome extends StatefulWidget {
  @override
  _BLEHomeState createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  String sport = "Unknown";
  double speed = 0.0;
  double angle = 0.0;
  double power = 0.0;
  String direction = "Unknown";

  @override
  void initState() {
    super.initState();
    scanAndConnect();
  }

  void scanAndConnect() {
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    var subscription = flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == 'ESP32_IMU') {
          flutterBlue.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
    });

    discoverServices();
  }

  void discoverServices() async {
    if (connectedDevice == null) return;
    List<BluetoothService> services = await connectedDevice!.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
        service.characteristics.forEach((c) {
          if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            characteristic = c;
            c.setNotifyValue(true);
            c.value.listen((value) {
              String data = utf8.decode(value);
              processData(data);
            });
          }
        });
      }
    });
  }

  void processData(String data) {
    List<String> parts = data.split(',');
    if (parts.length != 6) return;

    double ax = double.tryParse(parts[0]) ?? 0.0;
    double ay = double.tryParse(parts[1]) ?? 0.0;
    double az = double.tryParse(parts[2]) ?? 0.0;
    double gx = double.tryParse(parts[3]) ?? 0.0;
    double gy = double.tryParse(parts[4]) ?? 0.0;
    double gz = double.tryParse(parts[5]) ?? 0.0;

    // Compute metrics
    double resultantAccel = sqrt(ax * ax + ay * ay + az * az);
    double resultantGyro = sqrt(gx * gx + gy * gy + gz * gz);

    // Example computations (adjust thresholds as needed)
    if (resultantGyro > 5.0) {
      sport = "Cricket";
      speed = resultantGyro * 10; // Placeholder formula
      angle = atan2(ay, ax) * (180 / pi);
      power = resultantAccel * 5; // Placeholder formula
      direction = gx > 0 ? "Right" : "Left";
    } else if (resultantAccel > 2.0) {
      sport = "Badminton";
      speed = resultantAccel * 8; // Placeholder formula
      angle = atan2(az, ay) * (180 / pi);
      power = resultantGyro * 4; // Placeholder formula
      direction = gy > 0 ? "Forward" : "Backward";
    } else {
      sport = "Lawn Tennis";
      speed = resultantGyro * 6; // Placeholder formula
      angle = atan2(ax, az) * (180 / pi);
      power = resultantAccel * 3; // Placeholder formula
      direction = gz > 0 ? "Upward" : "Downward";
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("BLE Sports Tracker")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: connectedDevice == null
              ? Center(child: Text("Scanning for devices..."))
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Connected to: ${connectedDevice!.name}"),
              SizedBox(height: 20),
              Text("Sport: $sport"),
              Text("Speed: ${speed.toStringAsFixed(2)}"),
              Text("Angle: ${angle.toStringAsFixed(2)}°"),
              Text("Power: ${power.toStringAsFixed(2)}"),
              Text("Direction: $direction"),
            ],
          ),
        ));
  }
}
