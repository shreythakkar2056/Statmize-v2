// session_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/tennis_analysis_service.dart';
import 'package:app/services/csv_service.dart';

// Add this new class for shot analysis
class ShotAnalysis {
  final String shotType;
  final double intensity;
  final List<String> suggestions;

  ShotAnalysis({
    required this.shotType,
    required this.intensity,
    required this.suggestions,
  });

  factory ShotAnalysis.fromJson(Map<String, dynamic> json) {
    return ShotAnalysis(
      shotType: json['Shot'] as String,
      intensity: (json['Intensity'] as num).toDouble(),
      suggestions: List<String>.from(json['Suggestions'] as List),
    );
  }
}
class ShotAnalysisWidget extends StatefulWidget {
  final List<ShotAnalysis> shots;
  final Map<String, int> shotCounts;
  final Map<String, double> avgIntensity;

  const ShotAnalysisWidget({
    super.key,
    required this.shots,
    required this.shotCounts,
    required this.avgIntensity,
  });

  @override
  State<ShotAnalysisWidget> createState() => _ShotAnalysisWidgetState();
}

class _ShotAnalysisWidgetState extends State<ShotAnalysisWidget> {
  int? expandedShotIndex;

  Color _getIntensityColor(double intensity) {
    if (intensity >= 180) return Colors.red;
    if (intensity >= 160) return Colors.orange;
    if (intensity >= 140) return Colors.yellow[700]!;
    return Colors.green;
  }

  void _toggleShotExpansion(int index) {
    setState(() {
      expandedShotIndex = expandedShotIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Shot Analysis (${widget.shots.length} shots)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Divider(
              height: 20,
              thickness: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            
            // Shot List with expandable rows
            if (widget.shots.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "No shots analyzed yet",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.shots.length,
                itemBuilder: (context, index) {
                  final shot = widget.shots[widget.shots.length - 1 - index]; // Show newest first
                  final shotNumber = widget.shots.length - index;
                  final isExpanded = expandedShotIndex == index;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: Column(
                      children: [
                        // Shot Summary Row
                        InkWell(
                          onTap: () => _toggleShotExpansion(index),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Shot Number Badge
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      shotNumber.toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Shot Info - UPDATED SECTION
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shot.shotType,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text("Intensity: ", style: TextStyle(fontSize: 14)),
                                              Text(
                                                (shot.intensity ?? 0.0).toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getIntensityColor(shot.intensity),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "${shot.suggestions.length} tips",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Expand/Collapse Icon
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Expanded Suggestions Section
                        if (isExpanded)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Improvement Suggestions:",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...shot.suggestions.map((suggestion) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class SessionPage extends StatefulWidget {
  final String selectedSport;
  
  const SessionPage({
    super.key,
    required this.selectedSport,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final BLEService bleService = BLEService();
  final TennisAnalysisService tennisService = TennisAnalysisService();
  final CSVService csvService = CSVService();
  Map<String, dynamic> latestData = {
    'speed': 0.0,
    'angle': 0.0,
    'power': 0.0,
    'direction': 'Unknown',
  };
  String debugMessage = '';
  DateTime? sessionStartTime;
  
  // Session stats
  double maxSpeed = 0.0;
  double maxPower = 0.0;
  int swingCount = 0;

  // Shot analysis data
  List<ShotAnalysis> shots = [];
  Map<String, int> shotCounts = {};
  Map<String, double> avgIntensity = {};

  StreamSubscription? _dataSubscription;
  StreamSubscription? _debugSubscription;
  StreamSubscription? _shotsSubscription;
  StreamSubscription? _shotCountsSubscription;
  StreamSubscription? _avgIntensitySubscription;
  
  DateTime? lastShotTime;
  
  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();
    _initializeBLE();
    if (widget.selectedSport == "Tennis") {
      _initializeTennisAnalysis();
    }
  }

  void _initializeTennisAnalysis() {
    _shotsSubscription = tennisService.shotsStream.listen((newShots) {
      if (mounted) {
        setState(() {
          shots = newShots;
        });
      }
    });

    _shotCountsSubscription = tennisService.shotCountsStream.listen((newCounts) {
      if (mounted) {
        setState(() {
          shotCounts = newCounts;
        });
      }
    });

    _avgIntensitySubscription = tennisService.avgIntensityStream.listen((newIntensity) {
      if (mounted) {
        setState(() {
          avgIntensity = newIntensity;
        });
      }
    });
  }

  Future<void> _initializeBLE() async {
    // Listen to data stream
    _dataSubscription = bleService.dataStream.listen((data) async {
      if (mounted) {
        // 1. Update UI state
        setState(() {
          // Process raw sensor data
          final acc = data['raw']['acc'] as List<double>;
          final gyr = data['raw']['gyr'] as List<double>;
          final mag = data['raw']['mag'] as List<double>;

          // Use ESP32-provided speed
          final peakSpeed = data['peakSpeed'] as double? ?? 0.0;

          // Calculate power (simplified model)
          final gyrMagnitude = sqrt(
            pow(gyr[0], 2) + pow(gyr[1], 2) + pow(gyr[2], 2)
          );
          final accMagnitude = sqrt(
            pow(acc[0], 2) + pow(acc[1], 2) + pow(acc[2], 2)
          );
          final power = accMagnitude * gyrMagnitude / 1000;

          // Use ESP32-provided angles (more accurate than calculated)
          final pitch = data['raw']['pitch'] as double;
          final roll = data['raw']['roll'] as double;
          final yaw = data['raw']['yaw'] as double;

          // Determine direction based on gyroscope data
          String direction = "Unknown";
          final yawRate = gyr[2]; // Z-axis rotation
          if (yawRate.abs() > 50) {
            direction = yawRate > 0 ? "Clockwise" : "Counter-Clockwise";
          }

          // Update latest data
          latestData = {
            'peakSpeed': peakSpeed,
            'angle': pitch, // Use ESP32 pitch angle
            'power': power,
            'direction': direction,
            'raw': data['raw'],
          };

          // Update session stats
          if (peakSpeed > maxSpeed) maxSpeed = peakSpeed;
          if (power > maxPower) maxPower = power;
          
          // Only count as swing if peakSpeed is significant
          if (peakSpeed > 1.0) {
            if (lastShotTime == null || DateTime.now().difference(lastShotTime!) > Duration(milliseconds: 500)) {
            swingCount++;
              lastShotTime = DateTime.now();
            }
          }
        });
        
        // 2. Analyze tennis shot if applicable - Pass ESP32 data string directly
        if (widget.selectedSport == "Tennis") {
          // Get the original ESP32 data string from BLE service
          final esp32DataString = _getESP32DataString(data);
          if (esp32DataString != null) {
            tennisService.analyzeShot(esp32DataString);
          }
        }
        
        // 3. Save data (outside setState)
        print('Received BLE data: ' + data.toString());
        final acc = data['raw']['acc'] as List<double>;
        final gyr = data['raw']['gyr'] as List<double>;
        final mag = data['raw']['mag'] as List<double>;
        final accMagnitude = sqrt(
          pow(acc[0], 2) + pow(acc[1], 2) + pow(acc[2], 2)
        );
        final gyrMagnitude = sqrt(
          pow(gyr[0], 2) + pow(gyr[1], 2) + pow(gyr[2], 2)
        );
        final magMagnitude = sqrt(
          pow(mag[0], 2) + pow(mag[1], 2) + pow(mag[2], 2)
        );
        final verticalAcc = acc[1].abs();
        final horizontalAcc = sqrt(pow(acc[0], 2) + pow(acc[2], 2));
        final rotationSpeed = gyr[1].abs();
        final swingSpeed = gyrMagnitude;
        
        // Use ESP32-provided angles (more accurate)
        final pitch = data['raw']['pitch'] as double;
        final roll = data['raw']['roll'] as double;
        final yaw = data['raw']['yaw'] as double;
        
        await csvService.saveSensorData(
          sport: widget.selectedSport,
          timestamp: DateTime.now(),
          acc: acc,
          gyr: gyr,
          mag: mag,
          accMagnitude: accMagnitude,
          gyrMagnitude: gyrMagnitude,
          magMagnitude: magMagnitude,
          verticalAcc: verticalAcc,
          horizontalAcc: horizontalAcc,
          rotationSpeed: rotationSpeed,
          swingSpeed: swingSpeed,
          pitch: pitch,
          roll: roll,
          intensity: 0.0,
          swingType: null,
          suggestions: null,
          rawData: data['raw'],
        );
      }
    });

    // Listen to debug messages
    _debugSubscription = bleService.debugStream.listen((message) {
      if (mounted) {
        setState(() {
          debugMessage = message;
        });
      }
    });

    // If already connected, update the UI
    if (bleService.isConnected) {
      setState(() {
        debugMessage = "${widget.selectedSport} session started!";
      });
    }
  }

  // Helper method to reconstruct ESP32 data string from processed data
  String? _getESP32DataString(Map<String, dynamic> data) {
    try {
      final raw = data['raw'];
      if (raw == null) return null;
      
      final acc = raw['acc'] as List<double>;
      final gyr = raw['gyr'] as List<double>;
      final mag = raw['mag'] as List<double>?;
      final pitch = raw['pitch'] as double;
      final roll = raw['roll'] as double;
      final yaw = raw['yaw'] as double; // Use the YAW value from ESP32
      final speed = raw['speed'] as double? ?? 0.0;
      final peakSpeed = raw['peakSpeed'] as double? ?? 0.0;
      // Reconstruct ESP32 format: "ACC:x,y,z GYR:x,y,z MAG:x,y,z PITCH:p ROLL:r YAW:y SPEED:s PEAK_SPEED:ps"
      return "ACC: {acc[0].toStringAsFixed(1)},${acc[1].toStringAsFixed(1)},${acc[2].toStringAsFixed(1)} "
             "GYR:${gyr[0].toStringAsFixed(1)},${gyr[1].toStringAsFixed(1)},${gyr[2].toStringAsFixed(1)} "
             "MAG:${mag != null ? mag[0].toStringAsFixed(1) : '0.0'},${mag != null ? mag[1].toStringAsFixed(1) : '0.0'},${mag != null ? mag[2].toStringAsFixed(1) : '0.0'} "
             "PITCH:${pitch.toStringAsFixed(1)} ROLL:${roll.toStringAsFixed(1)} YAW:${yaw.toStringAsFixed(1)} "
             "SPEED:${speed.toStringAsFixed(2)} PEAK_SPEED:${peakSpeed.toStringAsFixed(2)}";
    } catch (e) {
      print('Error reconstructing or format of data ESP32 data string: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _debugSubscription?.cancel();
    _shotsSubscription?.cancel();
    _shotCountsSubscription?.cancel();
    _avgIntensitySubscription?.cancel();
    super.dispose();
  }

  Widget _buildConnectionStatus() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bleService.connectionStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    bleService.isConnected ? Icons.bluetooth_connected : 
                    bleService.isScanning ? Icons.bluetooth_searching :
                    bleService.isConnecting ? Icons.bluetooth_searching :
                    Icons.bluetooth_disabled,
                    color: bleService.connectionStatusColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bleService.isConnected ? "Connected & Tracking" : 
                        bleService.isScanning ? "Scanning for Tracker" :
                        bleService.isConnecting ? "Connecting..." :
                        "Not Connected",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: bleService.connectionStatusColor,
                        ),
                      ),
                      Text(
                        widget.selectedSport,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bleService.isScanning || bleService.isConnecting) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: bleService.connectionStatusColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(bleService.connectionStatusColor),
              ),
            ],
            if (debugMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                debugMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionCard(String direction, IconData icon, Color color) {
    // Shorten direction text for display
    String displayDirection = direction;
    if (direction == "Clockwise") {
      displayDirection = "CW";
    } else if (direction == "Counter-Clockwise") {
      displayDirection = "CCW";
    }

    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              displayDirection,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              ),
            ),
            Text(
              "Direction",
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShotAnalysisSection() {
    if (widget.selectedSport != "Tennis" || shots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Shot Analysis",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).cardColor,
          child: ShotAnalysisWidget(
            shots: shots,
            shotCounts: shotCounts,
            avgIntensity: avgIntensity,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSessionStats() {
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight < 700 ? 90.0 : 100.0;
    final cardWidth = (MediaQuery.of(context).size.width - 32 - 8) / 2;
    final aspectRatio = cardWidth / cardHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Session Stats",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          children: [
            _buildDataCard("Max Peak Speed", "${maxSpeed.toStringAsFixed(1)} m/s", Icons.flash_on, Colors.red),
            _buildDataCard("Max Power", "${maxPower.toStringAsFixed(0)} W", Icons.fitness_center, Colors.deepOrange),
            _buildDataCard("Swings", "$swingCount", Icons.sports_tennis, Colors.teal),
            _buildDataCard("Duration", _getSessionDuration(), Icons.timer, Colors.blue),
          ],
        ),
      ],
    );
  }

  String _getSessionDuration() {
    if (sessionStartTime == null) return "0:00";
    final duration = DateTime.now().difference(sessionStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "${widget.selectedSport} Session",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              bleService.isScanning ? Icons.stop : Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              if (bleService.isScanning) {
                bleService.disconnect();
              } else {
                bleService.startScan();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Connection Status
            _buildConnectionStatus(),

            // Real-time Data Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Live Data",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final screenHeight = MediaQuery.of(context).size.height;
                    // Give cards a bit more height on smaller screens to prevent overflow
                    final cardHeight = screenHeight < 700 ? 95.0 : 100.0;
                    // Calculate width based on screen size, padding, and spacing
                    final cardWidth = (MediaQuery.of(context).size.width - 32 - 8) / 2;
                    final aspectRatio = cardWidth / cardHeight;

                    return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                      childAspectRatio: aspectRatio,
                    children: [
                      _buildDataCard("Peak Speed", "${(latestData['peakSpeed'] ?? 0.0).toStringAsFixed(1)} m/s", Icons.speed, Colors.blue),
                      _buildDataCard("Power", "${(latestData['power'] ?? 0.0).toStringAsFixed(0)} W", Icons.bolt, Colors.orange),
                    ],
                    );
                  }),
                  
                  const SizedBox(height: 24),
                  
                  // Shot Analysis (only for Tennis)
                  _buildShotAnalysisSection(),
                  
                  // Session Stats
                  _buildSessionStats(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // Save session and return to dashboard
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "End Session",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}