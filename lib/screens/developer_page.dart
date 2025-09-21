import 'package:flutter/material.dart';
import 'package:app/widgets/connection_card.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/csv_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  final BLEService bleService = BLEService();
  final CSVService csvService = CSVService();
  String debugMessage = '';
  List<dynamic> nearbyDevices = [];

  // For CSV file listing
  List<String> sports = ["Cricket", "Tennis", "Badminton"];
  String selectedSport = "Cricket";
  List<String> availableDates = [];
  String? selectedDate;
  List<Map<String, dynamic>>? fileContent;
  Map<String, dynamic>? fileInfo;
  bool isValidating = false;
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    _loadAvailableDates();
  }

  void _initializeBLE() {
    bleService.debugStream.listen((message) {
      setState(() {
        debugMessage = message;
      });
    });

    bleService.devicesStream.listen((devices) {
      setState(() {
        nearbyDevices = devices;
      });
    });
  }

  Future<void> _loadAvailableDates() async {
    final dates = await csvService.getAvailableDates(selectedSport);
    setState(() {
      availableDates = dates;
      selectedDate = dates.isNotEmpty ? dates.first : null;
      fileContent = null;
    });
  }

  Future<void> _loadFileContent() async {
    if (selectedDate == null) {
      setState(() {
        fileContent = null;
        fileInfo = null;
        isValid = false;
      });
      return;
    }
    final content = await csvService.readSensorData(selectedSport, date: selectedDate);
    final info = await csvService.getFileInfo(selectedSport, date: selectedDate);
    setState(() {
      fileContent = content;
      fileInfo = info;
    });
  }

  Future<void> _validateCSV() async {
    if (selectedDate == null) return;
    
    setState(() {
      isValidating = true;
    });
    
    try {
      final valid = await csvService.validateCSV(selectedSport, date: selectedDate);
      setState(() {
        isValid = valid;
        isValidating = false;
      });
    } catch (e) {
      setState(() {
        isValid = false;
        isValidating = false;
      });
    }
  }

  Future<void> _exportCSV() async {
    if (selectedDate == null) return;
    
    try {
      final exportedPath = await csvService.exportCSV(selectedSport, date: selectedDate);
      if (exportedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ CSV exported to: $exportedPath'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to export CSV'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper to get the file path for sharing/deleting
  Future<File?> _getSelectedFile() async {
    if (selectedDate == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final sportKey = selectedSport.toLowerCase();
    final filePath = '${dir.path}/sensor_data_${sportKey}_$selectedDate.csv';
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> _shareFile() async {
    final file = await _getSelectedFile();
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], text: 'Sensor data for $selectedSport on $selectedDate');
    }
  }

  Future<void> _deleteFile() async {
    final file = await _getSelectedFile();
    if (file != null) {
      await file.delete();
      await _loadAvailableDates();
      setState(() {
        fileContent = null;
      });
    }
  }

  Future<void> _generateSampleRow() async {
    // Generate a single row to help test CSV without hardware
    try {
      await csvService.saveSensorData(
        sport: selectedSport,
        timestamp: DateTime.now(),
        acc: [0.1, 0.2, 0.3],
        gyr: [1.1, 1.2, 1.3],
        peakSpeed: 9.5,
        shotCount: 1,
        power: 3.1,
      );
      await _loadAvailableDates();
      if (selectedDate != null) {
        await _loadFileContent();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sample CSV row generated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to generate sample row: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode'),
        actions: [
          IconButton(
            icon: Icon(
              bleService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => bleService.startScan(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Card
              ConnectionCard(
                isConnected: bleService.isConnected,
                isScanning: bleService.isScanning,
                isConnecting: bleService.isConnecting,
                lastDataReceived: bleService.lastDataReceived,
                getConnectionStatusColor: () => bleService.connectionStatusColor,
              ),
              const SizedBox(height: 20),
              
              // Debug Information Card
              Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Debug Information",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        debugMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Nearby devices found: ${nearbyDevices.length}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (nearbyDevices.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: nearbyDevices.length,
                          itemBuilder: (context, index) {
                            final device = nearbyDevices[index];
                            final name = device.device.platformName.isNotEmpty
                                ? device.device.platformName
                                : device.advertisementData.advName;
                            final id = device.device.remoteId.toString();
                            final rssi = device.rssi;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                "$name  |  ID: $id  |  RSSI: $rssi",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // CSV File Access Section
              Text(
                "Sensor Data Files",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Sport: "),
                  DropdownButton<String>(
                    value: selectedSport,
                    items: sports.map((sport) => DropdownMenuItem(
                      value: sport,
                      child: Text(sport),
                    )).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() {
                          selectedSport = value;
                        });
                        await _loadAvailableDates();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (availableDates.isNotEmpty)
                Row(
                  children: [
                    const Text("Date: "),
                    DropdownButton<String>(
                      value: selectedDate,
                      items: availableDates.map((date) => DropdownMenuItem(
                        value: date,
                        child: Text(date),
                      )).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            selectedDate = value;
                          });
                          await _loadFileContent();
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _loadFileContent,
                      child: const Text("View Data"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _generateSampleRow,
                      icon: const Icon(Icons.add),
                      label: const Text("Generate sample"),
                    ),
                  ],
                ),
              if (availableDates.isEmpty)
                const Text("No files found for this sport."),
              const SizedBox(height: 10),
              
              // File Info and Actions
              if (fileInfo != null) ...[
                Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "File Information",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (fileInfo!['exists']) ...[
                          Text("Path: ${fileInfo!['path']}"),
                          Text("Size: ${(fileInfo!['size'] / 1024).toStringAsFixed(2)} KB"),
                          Text("Rows: ${fileInfo!['rowCount']}"),
                          Text("Last Modified: ${fileInfo!['lastModified']}"),
                        ] else ...[
                          Text("File does not exist", style: TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: isValidating ? null : _validateCSV,
                              icon: isValidating 
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(isValid ? Icons.check_circle : Icons.verified),
                              label: Text(isValidating ? "Validating..." : "Validate CSV"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isValid ? Colors.green : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _exportCSV,
                              icon: const Icon(Icons.download),
                              label: const Text("Export"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _shareFile,
                              icon: const Icon(Icons.share),
                              label: const Text("Share"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _deleteFile,
                              icon: const Icon(Icons.delete),
                              label: const Text("Delete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (fileContent != null && fileContent!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "File Preview (${fileContent!.length} rows):",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share),
                            tooltip: 'Share',
                            onPressed: _shareFile,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete',
                            onPressed: _deleteFile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Table/grid preview
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            ...fileContent!.isNotEmpty
                              ? (fileContent![0].keys.map((k) => DataColumn(label: Text(k.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))))).toList()
                              : []
                          ],
                          rows: fileContent!.take(5).map((row) {
                            return DataRow(
                              cells: row.values.map((v) => DataCell(Text(v.toString(), style: const TextStyle(fontSize: 12)))).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                      if (fileContent!.length > 5)
                        const Text("... (showing first 5 rows) ...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              if (fileContent != null && fileContent!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "No data available for this file.",
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 