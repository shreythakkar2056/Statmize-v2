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

  Future<File> _getLocalFile(String sport) async {
    final path = await _localPath;
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    return File('$path/sensor_data_${sport}_$today.csv');
  }

  Future<void> saveSensorData({
    required String sport,
    required DateTime timestamp,
    required List<double> acc,
    required List<double> gyr,
    required List<double> mag,
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
    String? swingType,
  }) async {
    try {
      final file = await _getLocalFile(sport);
      final exists = await file.exists();
      List<List<dynamic>> rows = [];
      if (!exists) {
        // Add header row if file doesn't exist
        rows.add([
          'Timestamp',
          'Acc X', 'Acc Y', 'Acc Z',
          'Gyr X', 'Gyr Y', 'Gyr Z',
          'Mag X', 'Mag Y', 'Mag Z',
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
          'Swing Type',
          'Suggestions',
        ]);
      }
      // Add data row
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp),
        acc[0].toStringAsFixed(3), acc[1].toStringAsFixed(3), acc[2].toStringAsFixed(3),
        gyr[0].toStringAsFixed(3), gyr[1].toStringAsFixed(3), gyr[2].toStringAsFixed(3),
        mag[0].toStringAsFixed(3), mag[1].toStringAsFixed(3), mag[2].toStringAsFixed(3),
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
        swingType ?? '',
        suggestions?.join('; ') ?? ''
      ]);
      String csv = const ListToCsvConverter().convert(rows);
      if (exists) {
        await file.writeAsString('$csv\n', mode: FileMode.append);
      } else {
        await file.writeAsString(csv);
      }
    } catch (e) {
      print('Error saving sensor data: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> readSensorData(String sport) async {
    try {
      final file = await _getLocalFile(sport);
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
          'acc': [double.parse(row[1]), double.parse(row[2]), double.parse(row[3])],
          'gyr': [double.parse(row[4]), double.parse(row[5]), double.parse(row[6])],
          'mag': [double.parse(row[7]), double.parse(row[8]), double.parse(row[9])],
          'accMagnitude': double.parse(row[10]),
          'gyrMagnitude': double.parse(row[11]),
          'magMagnitude': double.parse(row[12]),
          'verticalAcc': double.parse(row[13]),
          'horizontalAcc': double.parse(row[14]),
          'rotationSpeed': double.parse(row[15]),
          'swingSpeed': double.parse(row[16]),
          'pitch': double.parse(row[17]),
          'roll': double.parse(row[18]),
          'intensity': double.parse(row[19]),
          'swingType': row[20],
          'suggestions': row[21].toString().split('; ').where((s) => s.isNotEmpty).toList(),
        };
      }).toList();
    } catch (e) {
      print('Error reading sensor data: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableDates(String sport) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = await directory.list().toList();
      return files
          .where((file) => file.path.contains('sensor_data_${sport}_'))
          .map((file) => file.path.split('_').last.replaceAll('.csv', ''))
          .toList();
    } catch (e) {
      print('Error getting available dates: $e');
      return [];
    }
  }

  Future<void> clearData(String sport) async {
    try {
      final file = await _getLocalFile(sport);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }
} 