// session_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/tennis_analysis_service.dart';

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

class ShotAnalysisWidget extends StatelessWidget {
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
                  "Shot Analysis",
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
            // Shot Distribution
            Text(
              "Shot Distribution",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shotCounts.entries.map((entry) {
                return Chip(
                  label: Text("${entry.key}: ${entry.value}"),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Recent Shots
            Text(
              "Recent Shots",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shots.length > 5 ? 5 : shots.length,
              itemBuilder: (context, index) {
                final shot = shots[shots.length - 1 - index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shot.shotType,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "Intensity: ${shot.intensity.toStringAsFixed(1)}",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...shot.suggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
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
    _dataSubscription = bleService.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          // Process raw sensor data
          final acc = data['raw']['acc'] as List<double>;
          final gyr = data['raw']['gyr'] as List<double>;
          final mag = data['raw']['mag'] as List<double>;

          // Calculate speed from acceleration magnitude
          final accMagnitude = sqrt(
            pow(acc[0], 2) + pow(acc[1], 2) + pow(acc[2], 2)
          );
          final speed = accMagnitude / 100; // Scale down for more reasonable values

          // Calculate power (simplified model)
          final gyrMagnitude = sqrt(
            pow(gyr[0], 2) + pow(gyr[1], 2) + pow(gyr[2], 2)
          );
          final power = accMagnitude * gyrMagnitude / 1000;

          // Calculate angle from accelerometer
          final pitch = atan2(acc[1], sqrt(pow(acc[0], 2) + pow(acc[2], 2))) * 180.0 / pi;
          
          // Determine direction based on gyroscope data
          String direction = "Unknown";
          final yawRate = gyr[2]; // Z-axis rotation
          if (yawRate.abs() > 50) {
            direction = yawRate > 0 ? "Clockwise" : "Counter-Clockwise";
          }

          // Update latest data
          latestData = {
            'speed': speed,
            'angle': pitch,
            'power': power,
            'direction': direction,
            'raw': data['raw'],
          };

          // Update session stats
          if (speed > maxSpeed) maxSpeed = speed;
          if (power > maxPower) maxPower = power;
          
          // Only count as swing if speed is significant
          if (speed > 1.0) {
            swingCount++;
          }

          // Analyze tennis shot if applicable
          if (widget.selectedSport == "Tennis") {
            tennisService.analyzeShot(latestData);
          }
        });
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              displayDirection,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              "Direction",
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
          childAspectRatio: 1.5,
          children: [
            _buildDataCard("Max Speed", "${maxSpeed.toStringAsFixed(1)} m/s", Icons.flash_on, Colors.red),
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
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3,
                    children: [
                      _buildDataCard("Speed", "${latestData['speed'].toStringAsFixed(1)} m/s", Icons.speed, Colors.blue),
                      _buildDataCard("Power", "${latestData['power'].toStringAsFixed(0)} W", Icons.bolt, Colors.orange),
                      _buildDataCard("Angle", "${latestData['angle'].toStringAsFixed(1)}°", Icons.rotate_right, Colors.green),
                      _buildDirectionCard(latestData['direction'], Icons.navigation, Colors.purple),
                    ],
                  ),
                  
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