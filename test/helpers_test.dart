/// Tests for the pure helpers: result-cap wording, path checks, version.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modfs/paths.dart';
import 'package:modfs/search_help.dart';
import 'package:modfs/search_summary.dart';
import 'package:modfs/version.dart';

void main() {
  group('truncationNotice', () {
    test('null when every match is shown', () {
      expect(truncationNotice(folders: 200, files: 500), isNull);
      expect(truncationNotice(folders: 0, files: 3), isNull);
    });

    test('says how many were found when files are cut off', () {
      expect(
        truncationNotice(folders: 10, files: 12345),
        'Showing 500 of 12,345 files. '
        'Type more of the name, or use a filter, to narrow it down.',
      );
    });

    test('mentions both when both are cut off', () {
      final notice = truncationNotice(folders: 201, files: 501)!;
      expect(notice, contains('200 of 201 folders and 500 of 501 files'));
    });
  });

  test('formatCount', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1000), '1,000');
    expect(formatCount(1234567), '1,234,567');
  });

  test('formatIndexTime', () {
    expect(formatIndexTime(DateTime(2026, 3, 4, 5, 6)), '2026-03-04 05:06');
  });

  group('validatePathToAdd', () {
    bool exists(String p) => p == '/Users/me/Documents';

    test('accepts an existing absolute folder', () {
      expect(
        validatePathToAdd(' /Users/me/Documents ', [], mustExist: true, directoryExists: exists),
        isNull,
      );
    });

    test('rejects empty, relative, duplicate and missing paths', () {
      expect(validatePathToAdd('', [], mustExist: true, directoryExists: exists), isNotNull);
      expect(validatePathToAdd('Documents', [], mustExist: true, directoryExists: exists), contains('full path'));
      expect(
        validatePathToAdd('/Users/me/Documents', ['/Users/me/Documents'], mustExist: true, directoryExists: exists),
        contains('already'),
      );
      expect(validatePathToAdd('/nope', [], mustExist: true, directoryExists: exists), contains("doesn't exist"));
    });

    test('exclusions may name a folder that is not there yet', () {
      expect(validatePathToAdd('/Volumes/Backup', [], mustExist: false, directoryExists: exists), isNull);
    });
  });

  test('missingIncludes', () {
    expect(
      missingIncludes(['/a', '/b'], directoryExists: (p) => p == '/a'),
      ['/b'],
    );
  });

  test('default exclusions include the system folders', () {
    expect(defaultExcludes('/Users/me'), containsAll(['/dev', '/Users/me/.cache']));
  });

  test('help lists the filters the docs mention', () {
    final queries = kSearchSyntaxExamples.map((e) => e.query).join(' ');
    for (final word in ['ext:', 'size:', 'regex:', 'folder:', 'file:', 'case:', 'OR', 'NOT']) {
      expect(queries, contains(word));
    }
  });

  test('About screen version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(appVersion, match!.group(1));
  });
}
