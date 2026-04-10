import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/modfs.log');
      if (!await _logFile!.exists()) await _logFile!.create(recursive: true);
    } catch (_) {}
  }

  static void log(String message) {
    debugPrint(message);
    if (_logFile != null) {
      final timestamp = DateTime.now().toIso8601String();
      try {
        _logFile!.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
      } catch (_) {}
    }
  }
}
