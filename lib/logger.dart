import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A utility class for application logging.
///
/// It supports writing log messages to the console in debug mode and
/// persisting them to a log file within the application's support directory.
class AppLogger {
  static File? _logFile;

  /// Initializes the logging system.
  ///
  /// Locates the application support directory, creates the log file
  /// (`modfs.log`) if it does not already exist, and caches the file reference.
  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/modfs.log');
      if (!await _logFile!.exists()) await _logFile!.create(recursive: true);
    } catch (_) {}
  }

  /// Writes a message to both the debug console and the persistent log file.
  ///
  /// Appends the message along with a current ISO-8601 timestamp to the log file.
  static void log(String message) {
    debugPrint(message);
    // Writes to the log file synchronously if the file is successfully initialized.
    if (_logFile != null) {
      final timestamp = DateTime.now().toIso8601String();
      try {
        _logFile!.writeAsStringSync(
          '[$timestamp] $message\n',
          mode: FileMode.append,
        );
      } catch (_) {}
    }
  }
}
