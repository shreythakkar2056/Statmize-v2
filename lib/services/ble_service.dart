import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter/material.dart';
import 'package:app/constants/ble_constants.dart';
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
      final dataString = String.fromCharCodes(value);
      print("Decoded data: $dataString");
      
      // Parse ACC, GYR, MAG, PITCH, ROLL, and YAW values
      Map<String, dynamic> sensorData = {};
      
      // Split into sensor groups (ACC, GYR, MAG, PITCH, ROLL, YAW)
      List<String> sensorGroups = dataString.split(' ');
      for (String group in sensorGroups) {
        List<String> parts = group.split(':');
        if (parts.length == 2) {
          String sensorType = parts[0];
          String valueStr = parts[1];
          
          if (sensorType == 'PITCH' || sensorType == 'ROLL' || sensorType == 'YAW') {
            // Single value for angles
            sensorData[sensorType] = double.tryParse(valueStr) ?? 0.0;
          } else {
            // Multiple values for sensors (ACC, GYR, MAG)
            List<double> values = valueStr.split(',')
                .map((s) => double.tryParse(s) ?? 0.0)
                .toList();
            sensorData[sensorType] = values;
          }
        }
      }

      if (sensorData.containsKey('ACC') && 
          sensorData.containsKey('GYR') && 
          sensorData.containsKey('MAG') &&
          sensorData.containsKey('PITCH') &&
          sensorData.containsKey('ROLL') &&
          sensorData.containsKey('YAW')) {
        
        // Calculate speed from acceleration
        double accMagnitude = sqrt(
          pow(sensorData['ACC'][0], 2) +
          pow(sensorData['ACC'][1], 2) +
          pow(sensorData['ACC'][2], 2)
        );
        
        // Use the angles provided by ESP32
        double pitch = sensorData['PITCH'];
        double roll = sensorData['ROLL'];
        double yaw = sensorData['YAW'];
        
        // Calculate power (simplified model based on acceleration and angular velocity)
        double gyrMagnitude = sqrt(
          pow(sensorData['GYR'][0], 2) +
          pow(sensorData['GYR'][1], 2) +
          pow(sensorData['GYR'][2], 2)
        );
        double power = accMagnitude * gyrMagnitude / 1000; // Simplified power calculation
        
        // Determine direction based on gyroscope data
        String direction = "Unknown";
        double yawRate = sensorData['GYR'][2]; // Z-axis rotation
        if (yawRate.abs() > 50) {
          direction = yawRate > 0 ? "Clockwise" : "Counter-Clockwise";
        }

        Map<String, dynamic> processedData = {
          'speed': accMagnitude / 100, // Scale down for more reasonable values
          'angle': pitch, // Using pitch as the primary angle
          'power': power,
          'direction': direction,
          'raw': {
            'acc': sensorData['ACC'],
            'gyr': sensorData['GYR'],
            'mag': sensorData['MAG'],
            'pitch': pitch,
            'roll': roll,
            'yaw': yaw
          }
        };

        lastDataReceived = DateTime.now();
        _dataController.add(processedData);
        _debugController.add("Data processed successfully");
      } else {
        _debugController.add("Invalid data format. Expected ACC, GYR, MAG, PITCH, ROLL, and YAW values");
      }
    } catch (e) {
      _debugController.add("Data parse error: $e");
      print("Data parsing error: $e");
    }
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