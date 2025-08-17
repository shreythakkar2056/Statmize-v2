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

  Future<File> _getLocalFileForDate(String sport, String date) async {
    final path = await _localPath;
    return File('$path/sensor_data_${sport}_$date.csv');
  }

  Future<void> saveSensorData({
    required String sport,
    required DateTime timestamp,
    required List<double> acc,
    required List<double> gyr,
    required double peakSpeed,
  }) async {
    try {
      print('Saving data for $sport at $timestamp: acc=$acc, gyr=$gyr, peakSpeed=$peakSpeed');
      final file = await _getLocalFile(sport);
      final exists = await file.exists();
      
      List<List<dynamic>> rows = [];
      if (!exists) {
        // Create header if file doesn't exist
        rows.add([
          'Timestamp',
          'AccX', 'AccY', 'AccZ',
          'GyroX', 'GyroY', 'GyroZ',
          'PeakSpeed'
        ]);
      }

      // Add data row
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp),
        acc[0], acc[1], acc[2],
        gyr[0], gyr[1], gyr[2],
        peakSpeed
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      if (!exists) {
        await file.writeAsString(csv);
      } else {
        await file.writeAsString(csv + '\n', mode: FileMode.append);
      }
      
      print('✅ CSV data saved successfully to: ${file.path}');
    } catch (e) {
      print('❌ Error saving sensor data: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> readSensorData(String sport, {String? date}) async {
    try {
      final file = date == null
          ? await _getLocalFile(sport)
          : await _getLocalFileForDate(sport, date);
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);
      if (rowsAsListOfValues.isEmpty) return [];
      // Skip header row
      rowsAsListOfValues.removeAt(0);
      return rowsAsListOfValues.map((row) {
        return {
          'timestamp': row[0],
          'acc': [double.parse(row[1]), double.parse(row[2]), double.parse(row[3])],
          'gyr': [double.parse(row[4]), double.parse(row[5]), double.parse(row[6])],
          'peakSpeed': double.parse(row[7]),
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

  // Get the file path for a specific sport and date
  Future<String> getFilePath(String sport, {String? date}) async {
    final file = date == null
        ? await _getLocalFile(sport)
        : await _getLocalFileForDate(sport, date);
    return file.path;
  }

  // Get file info (size, last modified, etc.)
  Future<Map<String, dynamic>> getFileInfo(String sport, {String? date}) async {
    try {
      final file = date == null
          ? await _getLocalFile(sport)
          : await _getLocalFileForDate(sport, date);
      
      if (!await file.exists()) {
        return {
          'exists': false,
          'path': file.path,
          'size': 0,
          'lastModified': null,
          'rowCount': 0,
        };
      }

      final stat = await file.stat();
      final contents = await file.readAsString();
      final lines = contents.split('\n').where((line) => line.trim().isNotEmpty).length;
      
      return {
        'exists': true,
        'path': file.path,
        'size': stat.size,
        'lastModified': stat.modified,
        'rowCount': lines - 1, // Subtract header row
      };
    } catch (e) {
      print('Error getting file info: $e');
      return {
        'exists': false,
        'path': '',
        'size': 0,
        'lastModified': null,
        'rowCount': 0,
        'error': e.toString(),
      };
    }
  }

  // Export CSV to a more accessible location
  Future<String?> exportCSV(String sport, {String? date}) async {
    try {
      final sourceFile = date == null
          ? await _getLocalFile(sport)
          : await _getLocalFileForDate(sport, date);
      
      if (!await sourceFile.exists()) {
        print('❌ Source CSV file does not exist');
        return null;
      }

      // Get downloads directory or documents directory
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (e) {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final today = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'sensor_data_${sport}_${date ?? today}_export.csv';
      final targetFile = File('${targetDir!.path}/$fileName');

      // Copy the file
      await sourceFile.copy(targetFile.path);
      
      print('✅ CSV exported to: ${targetFile.path}');
      return targetFile.path;
    } catch (e) {
      print('❌ Error exporting CSV: $e');
      return null;
    }
  }

  // Validate CSV format
  Future<bool> validateCSV(String sport, {String? date}) async {
    try {
      final file = date == null
          ? await _getLocalFile(sport)
          : await _getLocalFileForDate(sport, date);
      
      if (!await file.exists()) {
        print('❌ CSV file does not exist');
        return false;
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        print('❌ CSV file is empty');
        return false;
      }

      // Try to parse the CSV
      List<List<dynamic>> rows = const CsvToListConverter().convert(contents);
      
      if (rows.isEmpty) {
        print('❌ CSV has no rows');
        return false;
      }

      // Check header
      if (rows[0].length < 20) {
        print('❌ CSV header is incomplete (expected 20+ columns, got ${rows[0].length})');
        return false;
      }

      print('✅ CSV format is valid. Rows: ${rows.length}, Columns: ${rows[0].length}');
      return true;
    } catch (e) {
      print('❌ CSV validation failed: $e');
      return false;
    }
  }
}
