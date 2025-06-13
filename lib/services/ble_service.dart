import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class BLEService {
  // Device identifiers
  final String deviceName = "ESP32_IMU";
  final String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  final String characteristicUuid = "abcdef01-1234-5678-1234-56789abcdef0";

  // BLE state variables
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notificationStream;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  List<ScanResult> discoveredDevices = [];

  // State flags
  bool isConnected = false;
  bool isScanning = false;
  bool isConnecting = false;
  bool hasPermissions = false;
  bool isBluetoothOn = false;
  DateTime? lastDataReceived;

  // Data stream controller
  final StreamController<Map<String, dynamic>> _dataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  // Debug message stream
  final StreamController<String> _debugController = StreamController.broadcast();
  Stream<String> get debugStream => _debugController.stream;

  // Initialize Bluetooth
  Future<void> initializeBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      _debugController.add("Bluetooth not supported by this device");
      return;
    }

    if (Platform.isIOS) {
      hasPermissions = true;
      isBluetoothOn = true;
      _debugController.add("iOS: Ready to start scanning");
      Timer(const Duration(seconds: 1), () {
        startScan();
      });
    } else {
      await checkBluetoothStateAndroid();
    }
  }

  // Check Bluetooth state on Android
  Future<void> checkBluetoothStateAndroid() async {
    var state = await FlutterBluePlus.adapterState.first;
    isBluetoothOn = state == BluetoothAdapterState.on;

    if (isBluetoothOn) {
      await requestAndroidPermissions();
    } else {
      _debugController.add("Please turn on Bluetooth");
    }

    FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn = state == BluetoothAdapterState.on;
      if (!isBluetoothOn) {
        _debugController.add("Bluetooth turned off");
        disconnect();
      }
    });
  }

  // Request Android permissions
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
      _debugController.add("Required permissions not granted");
    }
  }

  // Start scanning for devices
  Future<void> startScan() async {
    if (isScanning) return;

    isScanning = true;
    discoveredDevices.clear();
    _debugController.add("Starting BLE scan...");

    try {
      await FlutterBluePlus.stopScan();

      if (Platform.isIOS) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 20),
        );
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          androidUsesFineLocation: true,
        );
      }

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        discoveredDevices = results;

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
            _debugController.add("Found target device: $foundDeviceName");
            isScanning = false;
            connectToDevice(_device!);
            return;
          }
        }

        _debugController.add("Found ${results.length} devices, looking for $deviceName...");
      });

      Timer(Duration(seconds: Platform.isIOS ? 20 : 15), () {
        if (isScanning) {
          FlutterBluePlus.stopScan();
          isScanning = false;
          if (!isConnected) {
            _debugController.add("Could not find $deviceName. Found ${discoveredDevices.length} devices total.");
          }
        }
      });

    } catch (e) {
      _debugController.add("Scan error: $e");
      isScanning = false;
    }
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    isConnecting = true;
    _debugController.add("Attempting to connect to ${device.platformName}...");

    try {
      await device.connect(
        timeout: Duration(seconds: Platform.isIOS ? 15 : 10),
        autoConnect: false,
      );

      _stateSubscription = device.connectionState.listen((state) async {
        isConnected = state == BluetoothConnectionState.connected;

        if (state == BluetoothConnectionState.connected) {
          _debugController.add("Connected! Discovering services...");
          await _setupServices(device);
        } else if (state == BluetoothConnectionState.disconnected) {
          isConnecting = false;
          _debugController.add("Device disconnected");
        }
      });

    } catch (e) {
      _debugController.add("Connection error: $e");
      isConnecting = false;
    }
  }

  // Setup services and characteristics
  Future<void> _setupServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _characteristic = char;

              if (!char.properties.notify) {
                _debugController.add("Characteristic doesn't support notifications");
                return;
              }

              await char.setNotifyValue(true);

              _notificationStream = char.lastValueStream.listen(
                (value) {
                  _handleReceivedData(value);
                },
                onError: (error) {
                  _debugController.add("Notification error: $error");
                },
              );

              _debugController.add("Successfully connected and receiving data!");
              return;
            }
          }
        }
      }

      _debugController.add("Required service or characteristic not found");
      isConnecting = false;

    } catch (e) {
      _debugController.add("Service discovery error: $e");
      isConnecting = false;
    }
  }

  // Handle received data
  void _handleReceivedData(List<int> value) {
    try {
      final dataString = String.fromCharCodes(value);
      final parts = dataString.split(',');

      if (parts.length >= 4) {
        Map<String, dynamic> data = {
          'speed': double.tryParse(parts[0]) ?? 0.0,
          'angle': double.tryParse(parts[1]) ?? 0.0,
          'power': double.tryParse(parts[2]) ?? 0.0,
          'direction': parts[3].trim(),
        };

        lastDataReceived = DateTime.now();
        _dataController.add(data);
      } else {
        _debugController.add("Invalid data format. Expected: speed,angle,power,direction. Got: $dataString");
      }
    } catch (e) {
      _debugController.add("Data parse error: $e");
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    try {
      _notificationStream?.cancel();
      _stateSubscription?.cancel();
      _scanResultsSubscription?.cancel();
      _notificationStream = null;
      _stateSubscription = null;
      _scanResultsSubscription = null;

      await _characteristic?.setNotifyValue(false);
      _characteristic = null;

      await _device?.disconnect();
      _device = null;

      isConnected = false;
      isConnecting = false;
    } catch (e) {
      _debugController.add("Disconnect error: $e");
    }
  }

  // Cleanup resources
  void dispose() {
    disconnect();
    _dataController.close();
    _debugController.close();
  }

  // Getters
  BluetoothDevice? get connectedDevice => _device;
  List<ScanResult> get availableDevices => discoveredDevices;
  Color get connectionStatusColor {
    if (isConnected) return Colors.green;
    if (isConnecting || isScanning) return Colors.orange;
    if (Platform.isAndroid && (!isBluetoothOn || !hasPermissions)) {
      return Colors.red;
    }
    return Colors.blue;
  }
}
// This service handles BLE operations such as scanning, connecting, and receiving data from a specific device.
// It uses Flutter Blue Plus for Bluetooth operations and provides a stream to listen for incoming data.
// It uses Flutter Blue Plus for Bluetooth operations and provides a stream to listen for incoming data.