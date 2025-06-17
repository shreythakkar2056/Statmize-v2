import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:app/core/session_page.dart';
import 'package:app/services/csv_service.dart';

class TennisAnalysisService {
  static final TennisAnalysisService _instance = TennisAnalysisService._internal();
  factory TennisAnalysisService() => _instance;
  TennisAnalysisService._internal();

  final StreamController<List<ShotAnalysis>> _shotsController = StreamController.broadcast();
  Stream<List<ShotAnalysis>> get shotsStream => _shotsController.stream;

  final StreamController<Map<String, int>> _shotCountsController = StreamController.broadcast();
  Stream<Map<String, int>> get shotCountsStream => _shotCountsController.stream;

  final StreamController<Map<String, double>> _avgIntensityController = StreamController.broadcast();
  Stream<Map<String, double>> get avgIntensityStream => _avgIntensityController.stream;

  final CSVService _csvService = CSVService();

  List<ShotAnalysis> _shots = [];
  Map<String, int> _shotCounts = {};
  Map<String, double> _avgIntensity = {};

  // Shot detection thresholds
  static const double SHOT_THRESHOLD = 2.0; // Increased threshold
  static const double COOLDOWN_PERIOD = 1.5; // Increased cooldown
  DateTime? _lastShotTime;

  // Shot type thresholds
  static const double SMASH_THRESHOLD = 20.0;
  static const double DRIVE_THRESHOLD = 15.0;
  static const double LIFT_THRESHOLD = 8.0;
  static const double DROP_THRESHOLD = -8.0;
  static const double CLEAR_THRESHOLD = 8.0;

  // Public method to analyze shots
  Future<void> analyzeShot(Map<String, dynamic> sensorData) async {
    try {
      // Check if enough time has passed since last shot
      final now = DateTime.now();
      if (_lastShotTime != null && 
          now.difference(_lastShotTime!).inMilliseconds < COOLDOWN_PERIOD * 1000) {
        return;
      }

      _lastShotTime = now;
      _analyzeShot(sensorData);
    } catch (e) {
      debugPrint('Error analyzing shot: $e');
    }
  }

  // Private method for actual shot analysis
  void _analyzeShot(Map<String, dynamic> data) async {
    final raw = data['raw'];
    if (raw == null) return;

    final acc = raw['acc'] as List<double>;
    final gyr = raw['gyr'] as List<double>;
    final mag = raw['mag'] as List<double>;
    final pitch = raw['pitch'] as double;
    final roll = raw['roll'] as double;

    // Save raw sensor data to CSV
    await _csvService.saveSensorData(
      x: acc[0],
      y: acc[1],
      z: acc[2],
      swingType: 'Raw Data',
      timestamp: DateTime.now(),
    );

    // Calculate magnitudes
    final accMagnitude = sqrt(
      pow(acc[0], 2) + pow(acc[1], 2) + pow(acc[2], 2)
    );
    final gyrMagnitude = sqrt(
      pow(gyr[0], 2) + pow(gyr[1], 2) + pow(gyr[2], 2)
    );
    final magMagnitude = sqrt(
      pow(mag[0], 2) + pow(mag[1], 2) + pow(mag[2], 2)
    );

    // Calculate movement characteristics
    final verticalAcc = acc[1].abs(); // Y-axis acceleration
    final horizontalAcc = sqrt(pow(acc[0], 2) + pow(acc[2], 2)); // X-Z plane acceleration
    final rotationSpeed = gyr[1].abs(); // Y-axis rotation (for topspin/backspin)
    final swingSpeed = gyrMagnitude;

    // Adjusted shot detection thresholds for better sensitivity
    final bool isSignificantMovement = accMagnitude > 1.0 && gyrMagnitude > 1.5; // Lowered threshold
    final bool isVerticalShot = verticalAcc > 1.5 && verticalAcc > horizontalAcc * 1.2; // More sensitive
    final bool isHorizontalShot = horizontalAcc > 1.5 && horizontalAcc > verticalAcc * 1.2;
    final bool isHighSpeed = swingSpeed > 2.0; // Lowered threshold
    final bool isLowSpeed = swingSpeed < 1.5; // Adjusted threshold
    final bool hasTopspin = rotationSpeed > 1.0 && gyr[1] > 0; // More sensitive
    final bool hasBackspin = rotationSpeed > 1.0 && gyr[1] < 0;
    final bool isOverhead = pitch > 3.0; // Lowered angle threshold
    final bool isLowAngle = pitch < -20.0; // Adjusted angle threshold
    final bool isSideAngle = roll.abs() > 20.0; // Lowered angle threshold
    final bool isNetShot = accMagnitude < 2.0 && gyrMagnitude < 2.0; // Added net shot detection

    if (isSignificantMovement) {
      String shotType;
      double intensity = accMagnitude * gyrMagnitude / 10.0;
      List<String> suggestions = [];

      // Determine shot type based on movement characteristics
      if (isOverhead && isHighSpeed) {
        shotType = 'Smash';
        suggestions = [
          'Focus on wrist snap at contact',
          'Keep your eyes on the ball',
          'Follow through towards the target'
        ];
      } else if (isLowAngle && isLowSpeed) {
        shotType = 'Drop';
        suggestions = [
          'Use more wrist action',
          'Keep the shot low over the net',
          'Follow up with a net approach'
        ];
      } else if (isHighSpeed && hasTopspin) {
        shotType = 'Drive';
        suggestions = [
          'Maintain consistent contact point',
          'Keep your swing path straight',
          'Focus on timing and rhythm'
        ];
      } else if (isLowSpeed && hasBackspin) {
        shotType = 'Slice';
        suggestions = [
          'Keep your racket face open',
          'Use a high-to-low swing path',
          'Follow through towards the target'
        ];
      } else if (isSideAngle && isHighSpeed) {
        shotType = 'Cross Court';
        suggestions = [
          'Aim for the corners',
          'Use more topspin for control',
          'Keep the ball deep'
        ];
      } else if (isVerticalShot && isHighSpeed) {
        shotType = 'Lob';
        suggestions = [
          'Get under the ball',
          'Use a high follow-through',
          'Aim for the baseline'
        ];
      } else if (isNetShot) {
        shotType = 'Net';
        suggestions = [
          'Keep your racket face open',
          'Use soft hands',
          'Follow through towards the target'
        ];
      } else if (isHighSpeed && verticalAcc > 2.0) {
        shotType = 'Clear';
        suggestions = [
          'Get under the ball',
          'Use full arm extension',
          'Aim for the back court'
        ];
      } else {
        shotType = 'Groundstroke';
        suggestions = [
          'Focus on footwork',
          'Keep your eyes on the ball',
          'Maintain good balance'
        ];
      }

      // Add shot to history
      _shots.add(ShotAnalysis(
        shotType: shotType,
        intensity: intensity,
        suggestions: suggestions,
      ));

      // Save analyzed shot data to CSV
      await _csvService.saveSensorData(
        x: acc[0],
        y: acc[1],
        z: acc[2],
        swingType: shotType,
        timestamp: DateTime.now(),
      );

      // Update shot counts
      _shotCounts[shotType] = (_shotCounts[shotType] ?? 0) + 1;

      // Update average intensity
      _avgIntensity[shotType] = ((_avgIntensity[shotType] ?? 0) * (_shotCounts[shotType]! - 1) + intensity) / _shotCounts[shotType]!;

      // Notify listeners
      _shotsController.add(_shots);
      _shotCountsController.add(_shotCounts);
      _avgIntensityController.add(_avgIntensity);
    }
  }

  void dispose() {
    _shotsController.close();
    _shotCountsController.close();
    _avgIntensityController.close();
  }
} 