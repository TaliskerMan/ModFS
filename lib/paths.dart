/// Default exclusions and checks for the folders ModFS indexes.
library;

import 'dart:io';

/// Folders that are always excluded from the index (system, virtual and
/// cache locations). They can't be removed in Settings.
List<String> defaultExcludes(String home) => <String>[
  '/proc',
  '/sys',
  '/dev',
  '/run',
  '/var/run',
  '/tmp',
  '/var/tmp',
  '$home/.gvfs',
  '$home/.cache',
  '/var/lib/docker',
];

/// Checks a folder typed into Settings before it is added.
///
/// Returns an error message, or `null` if [input] can be added to
/// [existing]. Include paths must exist ([mustExist]); exclude paths may name
/// a folder that isn't there yet (for example a drive that isn't mounted).
String? validatePathToAdd(
  String input,
  List<String> existing, {
  required bool mustExist,
  bool Function(String path)? directoryExists,
}) {
  final path = input.trim();
  if (path.isEmpty) return 'Enter a folder path.';
  if (!path.startsWith('/')) {
    return 'Use a full path that starts with / (for example /Users/you/Documents).';
  }
  if (existing.contains(path)) return 'That folder is already in the list.';
  final exists = directoryExists ?? (p) => Directory(p).existsSync();
  if (mustExist && !exists(path)) return "That folder doesn't exist.";
  return null;
}

/// The include paths in [includes] that don't exist (or aren't folders), so
/// the user can be told they were skipped.
List<String> missingIncludes(
  List<String> includes, {
  bool Function(String path)? directoryExists,
}) {
  final exists = directoryExists ?? (p) => Directory(p).existsSync();
  return includes.where((p) => !exists(p)).toList();
}
