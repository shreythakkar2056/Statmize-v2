import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter/material.dart';
import 'package:app/constants/ble_constants.dart';
import 'package:app/services/csv_service.dart';  // Added missing import
import 'dart:math';
import 'package:location/location.dart' as loc;

class BLEService {
  // Singleton instance
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // Device identifiers from constants
  final String deviceName = BLEConstants.DEVICE_NAME;
  final String serviceUuid = BLEConstants.SERVICE_UUID;
  final String characteristicUuid = BLEConstants.CHARACTERISTIC_UUID;

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

  // Stream for discovered devices
  final StreamController<List<ScanResult>> _devicesController = StreamController.broadcast();
  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;

  // Motion data handling
  final CSVService _csvService = CSVService();
  StreamController<Map<String, dynamic>> _motionDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get motionDataStream => _motionDataController.stream;

  // Initialize Bluetooth
  Future<void> initializeBluetooth() async {
    try {
      // Enable verbose logging for debugging
      FlutterBluePlus.setLogLevel(LogLevel.verbose);
      
      if (await FlutterBluePlus.isSupported == false) {
        _debugController.add("Bluetooth not supported by this device");
        return;
      }

      if (Platform.isIOS) {
        // Check if location services are enabled on iOS
        loc.Location location = loc.Location();
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          _debugController.add("Please turn on Location Services (GPS) to scan for BLE devices");
          return;
        }
        hasPermissions = true;
        isBluetoothOn = true;
        _debugController.add("iOS: Ready to start scanning");
        Timer(const Duration(seconds: 1), () {
          startScan();
        });
      } else {
        await checkBluetoothStateAndroid();
      }
    } catch (e) {
      _debugController.add("Bluetooth initialization error: $e");
    }
  }

  // Check Bluetooth state on Android
  Future<void> checkBluetoothStateAndroid() async {
    try {
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
    } catch (e) {
      _debugController.add("Bluetooth state check error: $e");
    }
  }

  // Request Android permissions
  Future<void> requestAndroidPermissions() async {
    try {
      Map<perm.Permission, perm.PermissionStatus> permissions = await [
        perm.Permission.location,
        perm.Permission.bluetoothScan,
        perm.Permission.bluetoothConnect,
        perm.Permission.bluetoothAdvertise,
      ].request();

      hasPermissions = permissions.values.every((status) =>
          status == perm.PermissionStatus.granted || status == perm.PermissionStatus.limited);

      if (hasPermissions) {
        // Check if location services are enabled
        loc.Location location = loc.Location();
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          _debugController.add("Please turn on Location Services (GPS) to scan for BLE devices");
          return;
        }
        startScan();
      } else {
        _debugController.add("Required permissions not granted");
      }
    } catch (e) {
      _debugController.add("Permission request error: $e");
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
          timeout: Duration(seconds: BLEConstants.SCAN_TIMEOUT_SECONDS),
        );
      } else {
        await FlutterBluePlus.startScan(
          timeout: Duration(seconds: BLEConstants.SCAN_TIMEOUT_SECONDS),
          androidUsesFineLocation: true,
        );
      }

      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        discoveredDevices = results;
        _devicesController.add(results); // Notify listeners of new devices
        print("Nearby devices updated: ${results.length}");

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

      Timer(Duration(seconds: BLEConstants.SCAN_TIMEOUT_SECONDS), () {
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
      print("iOS Scan Error: $e");
    }
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    isConnecting = true;
    _debugController.add("Attempting to connect to ${device.platformName}...");

    try {
      await device.connect(
        timeout: Duration(seconds: Platform.isIOS ? BLEConstants.IOS_TIMEOUT_SECONDS : BLEConstants.ANDROID_TIMEOUT_SECONDS),
        autoConnect: false,
      );

      _stateSubscription = device.connectionState.listen((state) async {
        print("Connection state changed: $state");
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
      print("iOS Connection Error: $e");
    }
  }

  // Setup services and characteristics
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
                  print("Received data: $value");
                  _handleReceivedData(value);
                },
                onError: (error) {
                  print("Notification error: $error");
                  _debugController.add("Notification error: $error");
                },
              );

              _debugController.add("Successfully connected and receiving data!");
              isConnecting = false;
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
      print("iOS Service Discovery Error: $e");
    }
  }

  // Handle received data
  void _handleReceivedData(List<int> value) {
    try {
      final dataString = String.fromCharCodes(value).trim();
      print("Decoded data: $dataString");
      
      // Parse the ESP32's data format: "acc:X,Y,Z,gyr:X,Y,Z,peakSpeed:value,shotCount:value"
      Map<String, dynamic> motionData = {
        'timestamp': DateTime.now(),
        'acc': [0.0, 0.0, 0.0],
        'gyr': [0.0, 0.0, 0.0],
        'peakSpeed': 0.0,
        'shotCount': 0
      };

      // Split data by parts
      var parts = dataString.split(',');
      String currentKey = '';
      List<double> currentValues = [];

      for (var part in parts) {
        if (part.contains(':')) {
          // If we have a key:value pair
          if (currentKey.isNotEmpty && currentValues.isNotEmpty) {
            // Store previous values if we have them
            motionData[currentKey] = currentValues;
            currentValues = [];
          }

          var keyValue = part.split(':');
          currentKey = keyValue[0];
          if (currentKey == 'acc' || currentKey == 'gyr') {
            // Start a new vector
            currentValues = [double.tryParse(keyValue[1]) ?? 0.0];
          } else if (currentKey == 'peakSpeed' || currentKey == 'shotCount') {
            // Handle scalar values
            motionData[currentKey] = double.tryParse(keyValue[1]) ?? 0.0;
          }
        } else {
          // Continue vector
          if (currentKey == 'acc' || currentKey == 'gyr') {
            currentValues.add(double.tryParse(part) ?? 0.0);
          }
        }
      }

      // Store final vector if pending
      if (currentKey.isNotEmpty && currentValues.isNotEmpty &&
          (currentKey == 'acc' || currentKey == 'gyr')) {
        motionData[currentKey] = currentValues;
      }

      // Forward the data
      lastDataReceived = DateTime.now();
      _dataController.add(motionData);
      _motionDataController.add(motionData);

      // Save to CSV
      _csvService.saveSensorData(
        sport: 'badminton',
        timestamp: motionData['timestamp'],
        acc: motionData['acc'],
        gyr: motionData['gyr'],
        peakSpeed: motionData['peakSpeed'],
        shotCount: motionData['shotCount'].toInt(),
      );

      _debugController.add("Data processed successfully");
    } catch (e, stackTrace) {
      _debugController.add("Data parse error: $e");
      print("Data parsing error: $e");
      print("Stack trace: $stackTrace");
      print("Raw data: ${String.fromCharCodes(value)}");
    }
  }

  Future<void> startNotifications() async {
    if (_characteristic != null) {
      await _characteristic!.setNotifyValue(true);
      _notificationStream?.cancel();
      _notificationStream = _characteristic!.lastValueStream.listen(_handleReceivedData);
    }
  }

  Future<void> stopNotifications() async {
    await _characteristic?.setNotifyValue(false);
    await _notificationStream?.cancel();
    _notificationStream = null;
  }

  // Disconnect from device
  Future<void> disconnect() async {
    try {
      if (_characteristic != null) {
        await _characteristic!.setNotifyValue(false);
      }

      _notificationStream?.cancel();
      _stateSubscription?.cancel();
      _scanResultsSubscription?.cancel();
      _notificationStream = null;
      _stateSubscription = null;
      _scanResultsSubscription = null;

      if (_device != null) {
        await _device!.disconnect();
      }

      _device = null;
      _characteristic = null;
      isConnected = false;
      isConnecting = false;
      lastDataReceived = null;
      _debugController.add("Disconnected from device");
    } catch (e) {
      _debugController.add("Disconnect error: $e");
    }
  }

  // Cleanup resources
  void dispose() {
    disconnect();
    _dataController.close();
    _debugController.close();
    _devicesController.close();
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
// It uses Flutter Blue