import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A utility class for application logging.
///
/// It supports writing log messages to the console in debug mode and
/// persisting them to a log file within the application's support directory.
class AppLogger {
  static File? _logFile;
  static const int _maxLogBytes = 5 * 1024 * 1024;

  /// Sanitizes a log message by replacing CR/LF control characters to prevent log injection.
  static String sanitize(String message) {
    return message.replaceAll('\r', ' ').replaceAll('\n', ' ');
  }

  /// Initializes the logging system.
  ///
  /// Locates the application support directory, creates the log file
  /// (`modfs.log`) if it does not already exist, and caches the file reference.
  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/modfs.log');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', _logFile!.path]);
      }
    } catch (_) {}
  }

  /// Writes a message to both the debug console and the persistent log file.
  ///
  /// Appends the message along with a current ISO-8601 timestamp to the log file.
  static void log(String message) {
    final safeMessage = sanitize(message);
    debugPrint(safeMessage);
    // Writes to the log file synchronously if the file is successfully initialized.
    if (_logFile != null) {
      final timestamp = DateTime.now().toIso8601String();
      try {
        if (_logFile!.existsSync() && _logFile!.lengthSync() > _maxLogBytes) {
          _logFile!.renameSync('${_logFile!.path}.1');
        }
        _logFile!.writeAsStringSync(
          '[$timestamp] $safeMessage\n',
          mode: FileMode.append,
        );
      } catch (_) {}
    }
  }
}
