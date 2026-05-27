import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Documentation for AppLogger.
class AppLogger {
  static File? _logFile;

  /// Documentation for init.
  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/modfs.log');
      if (!await _logFile!.exists()) await _logFile!.create(recursive: true);
    } catch (_) {}
  }

  /// Documentation for log.
  static void log(String message) {
    debugPrint(message);
    /// Documentation for if.
    if (_logFile != null) {
      final timestamp = DateTime.now().toIso8601String();
      try {
        _logFile!.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
      } catch (_) {}
    }
  }
}
