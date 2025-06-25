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

  // Data storage for real-time analysis
  List<SensorData> sensorBuffer = [];
  List<SwingAnalysis> swingHistory = [];
  
  // Analysis parameters
  static const int maxBufferSize = 1000;
  static const double swingDetectionThreshold = 15.0;
  static const double powerThreshold = 800.0;
  
  // Real-time analysis state
  bool isAnalyzing = false;
  SwingPhase currentPhase = SwingPhase.idle;
  DateTime? swingStartTime;
  List<SensorData> currentSwingData = [];

  // Shot detection thresholds (updated for ESP32 data)
  static const double SHOT_THRESHOLD = 700.0; // Match ESP32 ACCEL_THRESHOLD
  static const double COOLDOWN_PERIOD = 2.0; // Match ESP32 2s capture window
  DateTime? _lastShotTime;

  // Shot type thresholds (updated for better detection)
  static const double SMASH_THRESHOLD = 1000.0;
  static const double DRIVE_THRESHOLD = 800.0;
  static const double LIFT_THRESHOLD = 600.0;
  static const double DROP_THRESHOLD = 400.0;
  static const double CLEAR_THRESHOLD = 900.0;

  // Angle thresholds (can be adjusted based on testing)
  static const double OVERHEAD_ANGLE_THRESHOLD = 20.0; // Pitch > 20° for overhead shots
  static const double LOW_ANGLE_THRESHOLD = -30.0; // Pitch < -30° for low shots
  static const double SIDE_ANGLE_THRESHOLD = 30.0; // Roll > 30° for side shots
  static const double VERTICAL_ACC_THRESHOLD = 500.0; // Vertical acceleration threshold
  static const double HORIZONTAL_ACC_THRESHOLD = 500.0; // Horizontal acceleration threshold
  static const double HIGH_SPEED_THRESHOLD = 50.0; // High swing speed threshold
  static const double LOW_SPEED_THRESHOLD = 20.0; // Low swing speed threshold
  static const double ROTATION_THRESHOLD = 10.0; // Rotation speed threshold

  // Public method to analyze shots from ESP32 data
  Future<void> analyzeShot(String esp32Data) async {
    try {
      // Check if enough time has passed since last shot (cooldown)
      final now = DateTime.now();
      if (_lastShotTime != null && 
          now.difference(_lastShotTime!).inMilliseconds < COOLDOWN_PERIOD * 1000) {
        debugPrint('⏰ Shot analysis skipped - cooldown period');
        return;
      }
      debugPrint('🎾 Analyzing ESP32 data: $esp32Data');
      
      // Parse ESP32 data format: "ACC:x,y,z GYR:x,y,z MAG:x,y,z PITCH:p ROLL:r YAW:y"
      SensorData? sensorData = _parseESP32Data(esp32Data);
      
      if (sensorData != null) {
        _addToBuffer(sensorData);
        _analyzeRealTime(sensorData);
        
        _lastShotTime = now;
        _analyzeShot(sensorData);
      } else {
        debugPrint('❌ Failed to parse ESP32 data');
      }
    } catch (e) {
      debugPrint('Error analyzing shot: $e');
    }
  }

  // Parse ESP32 data format
  SensorData? _parseESP32Data(String data) {
    try {
      // Parse format: "ACC:x,y,z GYR:x,y,z MAG:x,y,z PITCH:p ROLL:r YAW:y"
      Map<String, List<double>> values = {};
      List<String> parts = data.split(' ');
      
      for (String part in parts) {
        if (part.contains(':')) {
          List<String> keyValue = part.split(':');
          String key = keyValue[0];
          String valueStr = keyValue[1];
          
          if (key == 'PITCH' || key == 'ROLL' || key == 'YAW') {
            values[key] = [double.parse(valueStr)];
          } else {
            values[key] = valueStr.split(',').map((e) => double.parse(e)).toList();
          }
        }
      }
      
      return SensorData(
        timestamp: DateTime.now(),
        accelerometer: Vector3(
          values['ACC']![0], 
          values['ACC']![1], 
          values['ACC']![2]
        ),
        gyroscope: Vector3(
          values['GYR']![0], 
          values['GYR']![1], 
          values['GYR']![2]
        ),
        magnetometer: Vector3(
          values['MAG']![0], 
          values['MAG']![1], 
          values['MAG']![2]
        ),
        pitch: values['PITCH']![0],
        roll: values['ROLL']![0],
        yaw: values['YAW']![0],
      );
    } catch (e) {
      debugPrint('❌ Parse error: $e');
      return null;
    }
  }

  // Add data to circular buffer
  void _addToBuffer(SensorData data) {
    sensorBuffer.add(data);
    if (sensorBuffer.length > maxBufferSize) {
      sensorBuffer.removeAt(0);
    }
  }

  // Real-time swing analysis
  void _analyzeRealTime(SensorData data) {
    double totalAcceleration = data.accelerometer.magnitude;
    double angularVelocity = data.gyroscope.magnitude;
    
    switch (currentPhase) {
      case SwingPhase.idle:
        if (totalAcceleration > swingDetectionThreshold) {
          _startSwingDetection(data);
        }
        break;
        
      case SwingPhase.backswing:
        currentSwingData.add(data);
        if (_detectImpact(data)) {
          currentPhase = SwingPhase.impact;
        }
        break;
        
      case SwingPhase.impact:
        currentSwingData.add(data);
        if (_detectFollowThrough(data)) {
          currentPhase = SwingPhase.followThrough;
        }
        break;
        
      case SwingPhase.followThrough:
        currentSwingData.add(data);
        if (_isSwingComplete(data)) {
          _completeSwingAnalysis();
        }
        break;
    }
  }

  void _startSwingDetection(SensorData data) {
    currentPhase = SwingPhase.backswing;
    swingStartTime = data.timestamp;
    currentSwingData = [data];
    debugPrint('🎾 Swing detected - Starting analysis');
  }

  bool _detectImpact(SensorData data) {
    // Look for sudden acceleration spike indicating ball contact
    if (currentSwingData.length < 3) return false;
    
    double currentMag = data.accelerometer.magnitude;
    double avgPrevious = currentSwingData
        .skip(currentSwingData.length - 3)
        .map((d) => d.accelerometer.magnitude)
        .reduce((a, b) => a + b) / 3;
    
    return currentMag > avgPrevious * 2 && currentMag > powerThreshold;
  }

  bool _detectFollowThrough(SensorData data) {
    // Detect when acceleration starts decreasing after impact
    if (currentSwingData.length < 5) return false;
    
    List<double> recentMagnitudes = currentSwingData
        .skip(currentSwingData.length - 5)
        .map((d) => d.accelerometer.magnitude)
        .toList();
    
    // Check if acceleration is consistently decreasing
    bool decreasing = true;
    for (int i = 1; i < recentMagnitudes.length; i++) {
      if (recentMagnitudes[i] > recentMagnitudes[i-1]) {
        decreasing = false;
        break;
      }
    }
    
    return decreasing && data.accelerometer.magnitude < powerThreshold * 0.3;
  }

  bool _isSwingComplete(SensorData data) {
    // Swing complete when motion settles down
    if (currentSwingData.length < 10) return false;
    
    DateTime? startTime = swingStartTime;
    if (startTime == null) return false;
    
    Duration swingDuration = data.timestamp.difference(startTime);
    double currentMagnitude = data.accelerometer.magnitude;
    
    return swingDuration.inMilliseconds > 1500 || 
           currentMagnitude < swingDetectionThreshold * 0.5;
  }

  void _completeSwingAnalysis() {
    if (currentSwingData.isEmpty) return;
    
    SwingAnalysis analysis = _analyzeSwingData(currentSwingData);
    swingHistory.add(analysis);
    
    debugPrint('🎾 Swing Analysis Complete:');
    debugPrint('   Power: ${analysis.power.toStringAsFixed(1)}');
    debugPrint('   Speed: ${analysis.swingSpeed.toStringAsFixed(1)} rad/s');
    debugPrint('   Type: ${analysis.swingType}');
    debugPrint('   Rating: ${analysis.technique}/10');
    
    // Reset for next swing
    currentPhase = SwingPhase.idle;
    currentSwingData.clear();
    swingStartTime = null;
  }

  SwingAnalysis _analyzeSwingData(List<SensorData> swingData) {
    if (swingData.isEmpty) {
      return SwingAnalysis.empty();
    }

    // Calculate key metrics
    double maxAcceleration = swingData
        .map((d) => d.accelerometer.magnitude)
        .reduce((a, b) => a > b ? a : b);
    
    double maxAngularVelocity = swingData
        .map((d) => d.gyroscope.magnitude)
        .reduce((a, b) => a > b ? a : b);
    
    // Determine swing type based on motion pattern
    SwingType swingType = _classifySwingType(swingData);
    
    // Calculate timing metrics
    Duration swingDuration = swingData.last.timestamp
        .difference(swingData.first.timestamp);
    
    // Calculate power (combination of acceleration and angular velocity)
    double power = (maxAcceleration * 0.7) + (maxAngularVelocity * 0.3);
    
    // Technique score based on smoothness and consistency
    double technique = _calculateTechniqueScore(swingData);
    
    return SwingAnalysis(
      timestamp: swingData.first.timestamp,
      swingType: swingType,
      power: power,
      swingSpeed: maxAngularVelocity,
      technique: technique,
      duration: swingDuration,
      maxAcceleration: maxAcceleration,
      swingData: List.from(swingData),
    );
  }

  SwingType _classifySwingType(List<SensorData> data) {
    if (data.length < 5) return SwingType.unknown;
    
    // Analyze swing trajectory and orientation changes
    double maxPitchChange = 0;
    double maxRollChange = 0;
    
    for (int i = 1; i < data.length; i++) {
      double pitchChange = (data[i].pitch - data[i-1].pitch).abs();
      double rollChange = (data[i].roll - data[i-1].roll).abs();
      
      if (pitchChange > maxPitchChange) maxPitchChange = pitchChange;
      if (rollChange > maxRollChange) maxRollChange = rollChange;
    }
    
    // Classification logic based on motion patterns
    if (maxPitchChange > 30 && maxRollChange < 20) {
      return SwingType.forehand;
    } else if (maxRollChange > 25 && maxPitchChange > 20) {
      return SwingType.backhand;
    } else if (maxPitchChange > 40) {
      return SwingType.serve;
    } else {
      return SwingType.volley;
    }
  }

  double _calculateTechniqueScore(List<SensorData> data) {
    if (data.length < 5) return 0.0;
    
    // Calculate smoothness (lower variation = better technique)
    List<double> accelerations = data.map((d) => d.accelerometer.magnitude).toList();
    double mean = accelerations.reduce((a, b) => a + b) / accelerations.length;
    double variance = accelerations
        .map((a) => pow(a - mean, 2))
        .reduce((a, b) => a + b) / accelerations.length;
    double smoothness = 1.0 / (1.0 + sqrt(variance) / mean);
    
    // Calculate consistency in swing plane
    List<double> pitchValues = data.map((d) => d.pitch).toList();
    double pitchVariance = _calculateVariance(pitchValues);
    double consistency = 1.0 / (1.0 + pitchVariance / 100);
    
    // Combine metrics for overall technique score (0-10)
    return ((smoothness * 0.6 + consistency * 0.4) * 10).clamp(0.0, 10.0);
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    return values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
  }

  // Private method for actual shot analysis (updated for ESP32 data)
  void _analyzeShot(SensorData sensorData) async {
    final acc = [sensorData.accelerometer.x, sensorData.accelerometer.y, sensorData.accelerometer.z];
    final gyr = [sensorData.gyroscope.x, sensorData.gyroscope.y, sensorData.gyroscope.z];
    final mag = [sensorData.magnetometer.x, sensorData.magnetometer.y, sensorData.magnetometer.z];
    final pitch = sensorData.pitch;
    final roll = sensorData.roll;
    final yaw = sensorData.yaw;

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

    // Updated shot detection thresholds for ESP32 data
    final bool isSignificantMovement = accMagnitude > SHOT_THRESHOLD;
    final bool isVerticalShot = verticalAcc > VERTICAL_ACC_THRESHOLD && verticalAcc > horizontalAcc * 1.2;
    final bool isHorizontalShot = horizontalAcc > HORIZONTAL_ACC_THRESHOLD && horizontalAcc > verticalAcc * 1.2;
    final bool isHighSpeed = swingSpeed > HIGH_SPEED_THRESHOLD;
    final bool isLowSpeed = swingSpeed < LOW_SPEED_THRESHOLD;
    final bool hasTopspin = rotationSpeed > ROTATION_THRESHOLD && gyr[1] > 0;
    final bool hasBackspin = rotationSpeed > ROTATION_THRESHOLD && gyr[1] < 0;
    final bool isOverhead = pitch > OVERHEAD_ANGLE_THRESHOLD;
    final bool isLowAngle = pitch < LOW_ANGLE_THRESHOLD;
    final bool isSideAngle = roll.abs() > SIDE_ANGLE_THRESHOLD;
    final bool isNetShot = accMagnitude < DROP_THRESHOLD && gyrMagnitude < 30.0;

    // Debug logging for angle analysis
    debugPrint('📐 Angle Analysis: Pitch=${pitch.toStringAsFixed(1)}°, Roll=${roll.toStringAsFixed(1)}°, Yaw=${yaw.toStringAsFixed(1)}°');
    debugPrint('🎯 Shot Detection: Overhead=$isOverhead, LowAngle=$isLowAngle, SideAngle=$isSideAngle');
    debugPrint('⚡ Movement: Significant=$isSignificantMovement, HighSpeed=$isHighSpeed, LowSpeed=$isLowSpeed');

    if (isSignificantMovement) {
      String shotType;
      double intensity = accMagnitude * gyrMagnitude / 1000.0; // Adjusted for ESP32 scale
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
      } else if (isHighSpeed && verticalAcc > 600) {
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

      debugPrint('🎾 Shot detected: $shotType (Intensity: ${intensity.toStringAsFixed(1)})');

      // Save analyzed shot data to CSV
      await _csvService.saveSensorData(
        sport: 'Tennis',
        acc: acc,
        gyr: gyr,
        mag: mag,
        swingType: shotType,
        timestamp: DateTime.now(),
        accMagnitude: accMagnitude,
        gyrMagnitude: gyrMagnitude,
        magMagnitude: magMagnitude,
        verticalAcc: verticalAcc,
        horizontalAcc: horizontalAcc,
        rotationSpeed: rotationSpeed,
        swingSpeed: swingSpeed,
        pitch: pitch,
        roll: roll,
        intensity: intensity,
        suggestions: suggestions,
      );

      // Update shot counts
      _shotCounts[shotType] = (_shotCounts[shotType] ?? 0) + 1;

      // Update average intensity
      _avgIntensity[shotType] = ((_avgIntensity[shotType] ?? 0) * (_shotCounts[shotType]! - 1) + intensity) / _shotCounts[shotType]!;

      // Notify listeners
      _shotsController.add(_shots);
      _shotCountsController.add(_shotCounts);
      _avgIntensityController.add(_avgIntensity);
      
      debugPrint('📊 UI updated with new shot data. Total shots: ${_shots.length}');
    }
  }

  // Get analysis statistics
  Map<String, dynamic> getStatistics() {
    if (swingHistory.isEmpty) {
      return {
        'totalSwings': 0,
        'averagePower': 0.0,
        'averageTechnique': 0.0,
        'swingTypes': <String, int>{},
      };
    }

    Map<SwingType, int> swingTypeCounts = {};
    double totalPower = 0;
    double totalTechnique = 0;

    for (SwingAnalysis swing in swingHistory) {
      swingTypeCounts[swing.swingType] = 
          (swingTypeCounts[swing.swingType] ?? 0) + 1;
      totalPower += swing.power;
      totalTechnique += swing.technique;
    }

    return {
      'totalSwings': swingHistory.length,
      'averagePower': totalPower / swingHistory.length,
      'averageTechnique': totalTechnique / swingHistory.length,
      'swingTypes': swingTypeCounts.map((k, v) => MapEntry(k.toString(), v)),
      'lastSwing': swingHistory.isNotEmpty ? swingHistory.last : null,
    };
  }

  void dispose() {
    _shotsController.close();
    _shotCountsController.close();
    _avgIntensityController.close();
  }
}

// Data classes for enhanced analysis
class SensorData {
  final DateTime timestamp;
  final Vector3 accelerometer;
  final Vector3 gyroscope;
  final Vector3 magnetometer;
  final double pitch;
  final double roll;
  final double yaw;

  SensorData({
    required this.timestamp,
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.pitch,
    required this.roll,
    required this.yaw,
  });
}

class Vector3 {
  final double x, y, z;
  
  Vector3(this.x, this.y, this.z);
  
  double get magnitude => sqrt(x*x + y*y + z*z);
}

class SwingAnalysis {
  final DateTime timestamp;
  final SwingType swingType;
  final double power;
  final double swingSpeed;
  final double technique;
  final Duration duration;
  final double maxAcceleration;
  final List<SensorData> swingData;

  SwingAnalysis({
    required this.timestamp,
    required this.swingType,
    required this.power,
    required this.swingSpeed,
    required this.technique,
    required this.duration,
    required this.maxAcceleration,
    required this.swingData,
  });

  factory SwingAnalysis.empty() {
    return SwingAnalysis(
      timestamp: DateTime.now(),
      swingType: SwingType.unknown,
      power: 0.0,
      swingSpeed: 0.0,
      technique: 0.0,
      duration: Duration.zero,
      maxAcceleration: 0.0,
      swingData: [],
    );
  }
}

enum SwingType { forehand, backhand, serve, volley, unknown }
enum SwingPhase { idle, backswing, impact, followThrough } 