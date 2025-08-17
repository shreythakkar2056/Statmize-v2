import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/csv_service.dart';

class BadmintonAnalysisService {
  static final BadmintonAnalysisService _instance = BadmintonAnalysisService._internal();
  factory BadmintonAnalysisService() => _instance;
  BadmintonAnalysisService._internal();

  final BLEService _bleService = BLEService();
  final CSVService _csvService = CSVService();

  // Stream controllers
  final _motionDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get motionDataStream => _motionDataController.stream;

  // ESP32 matching parameters
  static const double SWING_START_ACC_THRESHOLD = 50.0;
  static const double SWING_START_GYRO_THRESHOLD = 400.0;
  static const double MIN_REALISTIC_SPEED = 2.0;
  static const double MAX_REALISTIC_SPEED = 45.0;
  static const int MAX_SWING_DURATION_MS = 3000;
  static const double STATIONARY_ACC_THRESHOLD = 10.0;
  static const double STATIONARY_GYRO_THRESHOLD = 50.0;

  // Analysis state
  bool _isAnalyzing = false;
  DateTime? _swingStartTime;
  List<Map<String, dynamic>> _currentSwingData = [];

  void initialize() {
    _bleService.motionDataStream.listen(_processMotionData);
  }

  void _processMotionData(Map<String, dynamic> data) {
    try {
      // Forward raw data to listeners
      _motionDataController.add(data);

      // Extract motion components safely
      List<double> acc = data['acc'] ?? [0.0, 0.0, 0.0];
      List<double> gyr = data['gyr'] ?? [0.0, 0.0, 0.0];
      double peakSpeed = data['peakSpeed'] ?? 0.0;

      double accMag = _calculateMagnitude(acc);
      double gyroMag = _calculateMagnitude(gyr);

      // Match ESP32 swing detection logic
      if (!_isAnalyzing && accMag > SWING_START_ACC_THRESHOLD && gyroMag > SWING_START_GYRO_THRESHOLD) {
        _startSwingAnalysis();
      }

      if (_isAnalyzing) {
        _currentSwingData.add({
          'timestamp': data['timestamp'] ?? DateTime.now(),
          'acc': acc,
          'gyr': gyr,
          'peakSpeed': peakSpeed,
        });

        bool isSwingEnd = accMag < SWING_START_ACC_THRESHOLD * 0.5 &&
                         gyroMag < SWING_START_GYRO_THRESHOLD * 0.5;

        bool isTimeout = _swingStartTime != null &&
                        DateTime.now().difference(_swingStartTime!).inMilliseconds > MAX_SWING_DURATION_MS;

        if (isSwingEnd || isTimeout) {
          _finalizeSwingAnalysis();
        }
      }
    } catch (e) {
      debugPrint('Error processing motion data: $e');
    }
  }

  double _calculateMagnitude(List<double> vector) {
    return sqrt(vector.reduce((sum, value) => sum + value * value));
  }

  void _startSwingAnalysis() {
    _isAnalyzing = true;
    _swingStartTime = DateTime.now();
    _currentSwingData.clear();
  }

  void _finalizeSwingAnalysis() {
    if (_currentSwingData.isEmpty) {
      _isAnalyzing = false;
      return;
    }

    try {
      Map<String, dynamic> lastData = _currentSwingData.last;
      double peakSpeed = lastData['peakSpeed'];

      // Validate swing using ESP32 parameters
      bool isValidSwing = peakSpeed >= MIN_REALISTIC_SPEED &&
                         peakSpeed <= MAX_REALISTIC_SPEED;

      if (isValidSwing) {
        _csvService.saveSensorData(
          sport: 'badminton',
          timestamp: lastData['timestamp'],
          acc: lastData['acc'],
          gyr: lastData['gyr'],
          peakSpeed: peakSpeed,
        );
      }
    } catch (e) {
      debugPrint('Error finalizing swing analysis: $e');
    }

    _isAnalyzing = false;
    _swingStartTime = null;
    _currentSwingData.clear();
  }

  void dispose() {
    _motionDataController.close();
  }
}
