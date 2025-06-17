import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class CSVService {
  static final CSVService _instance = CSVService._internal();
  factory CSVService() => _instance;
  CSVService._internal();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    return File('$path/sensor_data_$today.csv');
  }

  Future<void> saveSensorData({
    required double x,
    required double y,
    required double z,
    required String swingType,
    required DateTime timestamp,
    required double accMagnitude,
    required double gyrMagnitude,
    required double magMagnitude,
    required double verticalAcc,
    required double horizontalAcc,
    required double rotationSpeed,
    required double swingSpeed,
    required double pitch,
    required double roll,
    required double intensity,
    List<String>? suggestions,
  }) async {
    try {
      final file = await _localFile;
      final exists = await file.exists();
      
      List<List<dynamic>> rows = [];
      if (!exists) {
        // Add header row if file doesn't exist
        rows.add([
          'Timestamp',
          'X', 'Y', 'Z',
          'Swing Type',
          'Acceleration Magnitude',
          'Gyroscope Magnitude',
          'Magnetic Magnitude',
          'Vertical Acceleration',
          'Horizontal Acceleration',
          'Rotation Speed',
          'Swing Speed',
          'Pitch',
          'Roll',
          'Intensity',
          'Suggestions'
        ]);
      }

      // Add data row
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp),
        x.toStringAsFixed(3),
        y.toStringAsFixed(3),
        z.toStringAsFixed(3),
        swingType,
        accMagnitude.toStringAsFixed(3),
        gyrMagnitude.toStringAsFixed(3),
        magMagnitude.toStringAsFixed(3),
        verticalAcc.toStringAsFixed(3),
        horizontalAcc.toStringAsFixed(3),
        rotationSpeed.toStringAsFixed(3),
        swingSpeed.toStringAsFixed(3),
        pitch.toStringAsFixed(3),
        roll.toStringAsFixed(3),
        intensity.toStringAsFixed(3),
        suggestions?.join('; ') ?? ''
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      
      if (exists) {
        // Append to existing file
        await file.writeAsString('$csv\n', mode: FileMode.append);
      } else {
        // Create new file
        await file.writeAsString(csv);
      }
    } catch (e) {
      print('Error saving sensor data: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> readSensorData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);
      
      // Skip header row
      rowsAsListOfValues.removeAt(0);
      
      return rowsAsListOfValues.map((row) {
        return {
          'timestamp': row[0],
          'x': double.parse(row[1]),
          'y': double.parse(row[2]),
          'z': double.parse(row[3]),
          'swingType': row[4],
          'accMagnitude': double.parse(row[5]),
          'gyrMagnitude': double.parse(row[6]),
          'magMagnitude': double.parse(row[7]),
          'verticalAcc': double.parse(row[8]),
          'horizontalAcc': double.parse(row[9]),
          'rotationSpeed': double.parse(row[10]),
          'swingSpeed': double.parse(row[11]),
          'pitch': double.parse(row[12]),
          'roll': double.parse(row[13]),
          'intensity': double.parse(row[14]),
          'suggestions': row[15].toString().split('; ').where((s) => s.isNotEmpty).toList(),
        };
      }).toList();
    } catch (e) {
      print('Error reading sensor data: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableDates() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = await directory.list().toList();
      return files
          .where((file) => file.path.contains('sensor_data_'))
          .map((file) => file.path.split('_').last.replaceAll('.csv', ''))
          .toList();
    } catch (e) {
      print('Error getting available dates: $e');
      return [];
    }
  }

  Future<void> clearData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }
} 