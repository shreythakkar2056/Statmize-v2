import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  final String targetDeviceName = "ESP32_IMU";
  final Guid serviceUUID = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid characteristicUUID = Guid("abcdef01-1234-5678-1234-56789abcdef0");

  late BluetoothDevice connectedDevice;
  late BluetoothCharacteristic notifyChar;
  StreamController<Map<String, dynamic>> dataStream = StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => dataStream.stream;

  Future<void> startScanAndConnect() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == targetDeviceName) {
          await FlutterBluePlus.stopScan();
          connectedDevice = r.device;
          await connectedDevice.connect();
          discoverServices();
          break;
        }
      }
    });
  }

  Future<void> discoverServices() async {
    List<BluetoothService> services = await connectedDevice.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUUID) {
        for (var char in service.characteristics) {
          if (char.uuid == characteristicUUID) {
            notifyChar = char;
            await notifyChar.setNotifyValue(true);
            notifyChar.lastValueStream.listen((value) {
              String raw = String.fromCharCodes(value);
              _parseAndAddToStream(raw);
            });
            return;
          }
        }
      }
    }
  }

  void _parseAndAddToStream(String raw) {
    try {
      final accRegex = RegExp(r'ACC:\s*(-?\d+\.\d+),(-?\d+\.\d+),(-?\d+\.\d+)');
      final gyrRegex = RegExp(r'GYR:\s*(-?\d+\.\d+),(-?\d+\.\d+),(-?\d+\.\d+)');

      final accMatch = accRegex.firstMatch(raw);
      final gyrMatch = gyrRegex.firstMatch(raw);

      if (accMatch != null && gyrMatch != null) {
        double accX = double.parse(accMatch.group(1)!);
        double accY = double.parse(accMatch.group(2)!);
        double accZ = double.parse(accMatch.group(3)!);

        double accMagnitude = (accX * accX + accY * accY + accZ * accZ).sqrt();

        dataStream.add({
          "accX": accX,
          "accY": accY,
          "accZ": accZ,
          "accMagnitude": accMagnitude,
        });
      }
    } catch (e) {
      print("Parsing failed: $e");
    }
  }

  void dispose() {
    dataStream.close();
  }
}
