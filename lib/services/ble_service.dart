import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter/material.dart';
import 'package:app/constants/ble_constants.dart';
import 'package:app/services/csv_service.dart';  // Added missing import
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
  final String commandCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // From ESP32 code

  // BLE state variables
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  BluetoothCharacteristic? _commandCharacteristic;
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
  int _bytesReceived = 0;
  Timer? _dataRateTimer;

  // Data stream controller
  final StreamController<Map<String, dynamic>> _dataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  // Debug message stream
  final StreamController<String> _debugController = StreamController.broadcast();
  Stream<String> get debugStream => _debugController.stream;

  // Data rate stream
  final StreamController<double> _dataRateController = StreamController.broadcast();
  Stream<double> get dataRateStream => _dataRateController.stream;

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
        _log("Bluetooth not supported by this device");
        return;
      }

      if (Platform.isIOS) {
        // Check if location services are enabled on iOS
        loc.Location location = loc.Location();
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          _log("Please turn on Location Services (GPS) to scan for BLE devices");
          return;
        }
        hasPermissions = true;
        isBluetoothOn = true;
        _log("iOS: Ready to start scanning");
        Timer(const Duration(seconds: 1), () {
          startScan();
        });
      } else {
        await checkBluetoothStateAndroid();
      }
    } catch (e) {
      _log("Bluetooth initialization error: $e");
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
        _log("Please turn on Bluetooth");
      }

      FlutterBluePlus.adapterState.listen((state) {
        isBluetoothOn = state == BluetoothAdapterState.on;
        if (!isBluetoothOn) {
          _log("Bluetooth turned off");
          disconnect();
        }
      });
    } catch (e) {
      _log("Bluetooth state check error: $e");
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
          _log("Please turn on Location Services (GPS) to scan for BLE devices");
          return;
        }
        startScan();
      } else {
        _log("Required permissions not granted");
      }
    } catch (e) {
      _log("Permission request error: $e");
    }
  }

  // Start scanning for devices
  Future<void> startScan() async {
    if (isScanning) return;

    isScanning = true;
    discoveredDevices.clear();
    _log("Starting BLE scan...");

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
        debugPrint("Nearby devices updated: ${results.length}");

        // Debug logging for iOS
        if (Platform.isIOS) {
          debugPrint("=== iOS BLE Scan Results ===");
          for (var result in results) {
            debugPrint("Device: ${result.device.platformName}");
            debugPrint("Adv Name: ${result.advertisementData.advName}");
            debugPrint("Device ID: ${result.device.remoteId}");
            debugPrint("RSSI: ${result.rssi}");
            debugPrint("---");
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
            _log("Found target device: $foundDeviceName");
            isScanning = false;
            connectToDevice(_device!);
            return;
          }
        }

        _log("Found ${results.length} devices, looking for $deviceName...");
      });

      Timer(Duration(seconds: BLEConstants.SCAN_TIMEOUT_SECONDS), () {
        if (isScanning) {
          FlutterBluePlus.stopScan();
          isScanning = false;
          if (!isConnected) {
            _log("Could not find $deviceName. Found ${discoveredDevices.length} devices total.");
          }
        }
      });

    } catch (e) {
      _log("Scan error: $e");
      isScanning = false;
      debugPrint("iOS Scan Error: $e");
    }
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected || isConnecting) return;

    isConnecting = true;
    _log("Attempting to connect to ${device.platformName}...");

    try {
      await device.connect(
        timeout: Duration(seconds: Platform.isIOS ? BLEConstants.IOS_TIMEOUT_SECONDS : BLEConstants.ANDROID_TIMEOUT_SECONDS),
        autoConnect: false,
      );

      _stateSubscription = device.connectionState.listen((state) {
        _onConnectionStateChanged(state, device);
      });

    } catch (e) {
      _log("Connection error: $e");
      isConnecting = false;
      debugPrint("iOS Connection Error: $e");
    }
  }

  // Setup services and characteristics
  Future<void> _setupServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      debugPrint("=== Discovered Services ===");
      for (var service in services) {
        debugPrint("Service UUID: ${service.uuid}");
        for (var char in service.characteristics) {
          debugPrint("  Characteristic UUID: ${char.uuid}");
        }
      }

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _characteristic = char;

              if (!char.properties.notify) {
                _log("Characteristic doesn't support notifications");
                return;
              }

              await char.setNotifyValue(true);

              _notificationStream = char.lastValueStream.listen(
                (value) {
                  debugPrint("Received data: $value");
                              _bytesReceived += value.length;
                  _handleReceivedData(value);
                },
                onError: (error) {
                  debugPrint("Notification error: $error");
                  _log("Notification error: $error");
                },
              );

              _log("Data characteristic configured!");
            } else if (char.uuid.toString().toLowerCase() == commandCharacteristicUuid.toLowerCase()) {
              _commandCharacteristic = char;
              _log("Command characteristic found!");
            }
          }

          // After iterating all characteristics, check if we are ready
          if (_characteristic != null && _commandCharacteristic != null) {
            _log("Successfully connected and all services configured!");
            isConnecting = false;

            // Send confirmation message to ESP32
            await sendCommand([0x02]); // Using 0x02 for "software to hardware paired"
            _log("Sent 'software to hardware paired' confirmation.");
            _startDataRateLogging();
            return;
          }
        }
      }

      _log("Required service or characteristic not found");
      isConnecting = false;

    } catch (e) {
      _log("Service discovery error: $e");
      isConnecting = false;
      debugPrint("iOS Service Discovery Error: $e");
    }
  }

  // Handle received data
  void _handleReceivedData(List<int> value) {
    try {
      final dataString = String.fromCharCodes(value).trim();
      debugPrint("Decoded data: $dataString");
      
      // Initialize default motion data
      Map<String, dynamic> motionData = {
        'timestamp': DateTime.now(),
        'acc': [0.0, 0.0, 0.0],
        'gyr': [0.0, 0.0, 0.0],
        'peakSpeed': 0.0,
        'shotCount': 0,
        'power': 0.0,
      };

      // Try to parse as JSON first (new format from ESP32)
      if (dataString.startsWith('{') && dataString.endsWith('}')) {
        try {
          final jsonData = json.decode(dataString);
          
          // Parse acceleration array
          if (jsonData['acc'] is List && (jsonData['acc'] as List).length >= 3) {
            motionData['acc'] = [
              (jsonData['acc'][0] as num).toDouble(),
              (jsonData['acc'][1] as num).toDouble(),
              (jsonData['acc'][2] as num).toDouble(),
            ];
          }
          
          // Parse gyroscope array
          if (jsonData['gyr'] is List && (jsonData['gyr'] as List).length >= 3) {
            motionData['gyr'] = [
              (jsonData['gyr'][0] as num).toDouble(),
              (jsonData['gyr'][1] as num).toDouble(),
              (jsonData['gyr'][2] as num).toDouble(),
            ];
          }
          
          // Parse scalar values
          if (jsonData['peakSpeed'] != null) {
            motionData['peakSpeed'] = (jsonData['peakSpeed'] as num).toDouble();
          }
          if (jsonData['shotCount'] != null) {
            motionData['shotCount'] = (jsonData['shotCount'] as num).toInt();
          }
          if (jsonData['power'] != null) {
            motionData['power'] = (jsonData['power'] as num).toDouble();
          }
          
          debugPrint("Successfully parsed JSON data");
        } catch (jsonError) {
          debugPrint("JSON parse error, falling back to custom format: $jsonError");
          _parseCustomFormat(dataString, motionData);
        }
      } else {
        // Fall back to custom format parsing
        _parseCustomFormat(dataString, motionData);
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
        power: motionData['power'],
      );

      _log(
          "Data processed successfully | shotCount=${motionData['shotCount']} power=${(motionData['power'] as double).toStringAsFixed(2)} speed=${(motionData['peakSpeed'] as double).toStringAsFixed(2)}");
    } catch (e, stackTrace) {
      _log("Data parse error: $e");
      debugPrint("Data parsing error: $e");
      debugPrint("Stack trace: $stackTrace");
      debugPrint("Raw data: ${String.fromCharCodes(value)}");
    }
  }

  // Helper method to parse custom format (fallback)
  void _parseCustomFormat(String dataString, Map<String, dynamic> motionData) {
    try {
      var parts = dataString.split(',');
      String currentKey = '';
      List<double> currentValues = [];

      for (var part in parts) {
        if (part.contains(':')) {
          if (currentKey.isNotEmpty && currentValues.isNotEmpty) {
            motionData[currentKey] = currentValues;
            currentValues = [];
          }

          var keyValue = part.split(':');
          var rawKey = keyValue[0].trim();
          var valueStr = keyValue.length > 1 ? keyValue[1].trim() : '';

          var keyLower = rawKey.toLowerCase();
          if (keyLower == 'acc' || keyLower == 'gyr') {
            currentKey = keyLower;
            currentValues = [double.tryParse(valueStr) ?? 0.0];
          } else {
            String canonicalKey;
            if (keyLower == 'peakspeed' || keyLower == 'peak_speed' || keyLower == 'speed') {
              canonicalKey = 'peakSpeed';
            } else if (keyLower == 'shotcount' || keyLower == 'shots' || keyLower == 'shot' || keyLower == 'count') {
              canonicalKey = 'shotCount';
            } else if (keyLower == 'power') {
              canonicalKey = 'power';
            } else {
              canonicalKey = rawKey;
            }

            currentKey = canonicalKey;
            if (currentKey == 'shotCount') {
              final shotVal = int.tryParse(valueStr) ?? double.tryParse(valueStr)?.toInt() ?? 0;
              motionData['shotCount'] = shotVal;
            } else if (currentKey == 'peakSpeed' || currentKey == 'power') {
              motionData[currentKey] = double.tryParse(valueStr) ?? 0.0;
            }
          }
        } else {
          if (currentKey == 'acc' || currentKey == 'gyr') {
            currentValues.add(double.tryParse(part.trim()) ?? 0.0);
          }
        }
      }

      if (currentKey.isNotEmpty && currentValues.isNotEmpty &&
          (currentKey == 'acc' || currentKey == 'gyr')) {
        motionData[currentKey] = currentValues;
      }
      
      debugPrint("Successfully parsed custom format data");
    } catch (e) {
      debugPrint("Custom format parse error: $e");
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

  // Handle connection state changes
  void _onConnectionStateChanged(BluetoothConnectionState state, BluetoothDevice device) async {
    debugPrint("Connection state changed: $state");
    isConnected = state == BluetoothConnectionState.connected;

    if (state == BluetoothConnectionState.connected) {
      _log("Connected! Discovering services...");
      await _setupServices(device);
    } else if (state == BluetoothConnectionState.disconnected) {
      _log("Device disconnected. Cleaning up...");
      await disconnect(); // Centralized cleanup
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    try {
      // Cancel all subscriptions
      await _notificationStream?.cancel();
      await _stateSubscription?.cancel();
      await _scanResultsSubscription?.cancel();
      _notificationStream = null;
      _stateSubscription = null;
      _scanResultsSubscription = null;

      if (_device != null) {
        // Check if the device is still connected before disconnecting
        final isDeviceConnected = _device!.connectionState.first == BluetoothConnectionState.connected;
        if (isDeviceConnected) {
          await _device!.disconnect();
        }
      }

      // Clear all state variables
      _device = null;
      _characteristic = null;
      _commandCharacteristic = null;
      isConnected = false;
      isConnecting = false;
      lastDataReceived = null;
      _stopDataRateLogging();
      _log("Disconnected successfully and resources cleaned up.");

    } catch (e) {
      _log("Disconnect error: $e");
    }
  }

  // Cleanup resources
    // Safely add a message to the debug stream
  void _log(String message) {
    if (!_debugController.isClosed) {
      _debugController.add(message);
    }
  }

  // Send a command to the device
  Future<void> sendCommand(List<int> command) async {
    if (_commandCharacteristic == null) {
      _log("Command characteristic not available.");
      return;
    }

    try {
      await _commandCharacteristic!.write(command, withoutResponse: true);
      _log("Sent command: $command");
    } catch (e) {
      _log("Error sending command: $e");
    }
  }

  // Cleanup resources
  // Data rate logging
  void _startDataRateLogging() {
    _bytesReceived = 0;
    _dataRateTimer?.cancel();
    _dataRateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final dataRate = _bytesReceived / 2;
      _dataRateController.add(dataRate);
      _log("Data Rate: ${dataRate.toStringAsFixed(2)} bytes/sec");
      _bytesReceived = 0;
    });
  }

  void _stopDataRateLogging() {
    _dataRateTimer?.cancel();
    _dataRateTimer = null;
  }

  // Cleanup resources
  void dispose() {
    disconnect();
    _dataController.close();
    _debugController.close();
    _devicesController.close();
    _dataRateController.close();
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