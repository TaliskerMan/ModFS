/// Limits and wording for how many search results ModFS shows.
library;

/// Most folders shown for one search.
const int kMaxFolders = 200;

/// Most files shown for one search.
const int kMaxFiles = 500;

/// Formats [value] with thousands separators, e.g. 12345 -> "12,345".
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// Returns a notice when a search found more than ModFS shows, or `null`
/// when every match is listed. [folders] and [files] are the full counts.
String? truncationNotice({required int folders, required int files}) {
  final parts = <String>[];
  if (folders > kMaxFolders) {
    parts.add('$kMaxFolders of ${formatCount(folders)} folders');
  }
  if (files > kMaxFiles) {
    parts.add('$kMaxFiles of ${formatCount(files)} files');
  }
  if (parts.isEmpty) return null;
  return 'Showing ${parts.join(' and ')}. '
      'Type more of the name, or use a filter, to narrow it down.';
}

/// Formats [time] as "YYYY-MM-DD HH:MM" in local time.
String formatIndexTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final t = time.toLocal();
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
