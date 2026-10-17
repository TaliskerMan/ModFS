/// The search-syntax help shown from the "?" button next to the search box.
library;

import 'package:flutter/material.dart';

/// One example search and what it finds.
class SearchSyntaxExample {
  /// Creates an example.
  const SearchSyntaxExample(this.query, this.meaning);

  /// What to type.
  final String query;

  /// What it finds.
  final String meaning;
}

/// Examples of FSearch's search syntax, all checked against the ModFS engine.
const List<SearchSyntaxExample> kSearchSyntaxExamples = [
  SearchSyntaxExample('report', 'Names containing "report" (not case-sensitive)'),
  SearchSyntaxExample('report 2026', 'Names containing both "report" and "2026"'),
  SearchSyntaxExample('*.pdf', 'Names ending in .pdf (wildcards * and ?)'),
  SearchSyntaxExample('ext:pdf;docx', 'Files with the extension .pdf or .docx'),
  SearchSyntaxExample('invoice ext:pdf', 'PDFs with "invoice" in the name'),
  SearchSyntaxExample('folder:projects', 'Folders only, containing "projects"'),
  SearchSyntaxExample('file:notes', 'Files only, containing "notes"'),
  SearchSyntaxExample('size:>100mb', 'Items larger than 100 MB'),
  SearchSyntaxExample('dm:today', 'Items modified today'),
  SearchSyntaxExample('path:notes', 'Match against the full path, not just the name'),
  SearchSyntaxExample('case:README', 'Case-sensitive match'),
  SearchSyntaxExample(r'regex:^IMG_[0-9]+\.jpg$', 'Names matching a regular expression'),
  SearchSyntaxExample('photo OR image', 'Names containing either word'),
  SearchSyntaxExample('!tmp   or   NOT tmp', 'Leave out names containing "tmp"'),
];

/// Shows the search-syntax help dialog.
Future<void> showSearchHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final mono = Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
      );
      return AlertDialog(
        title: const Text('Search syntax'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final example in kSearchSyntaxExamples)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 200,
                          child: SelectableText(example.query, style: mono),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(example.meaning)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Results come from the index as it was when you last clicked '
                  'Rebuild DB; it does not update by itself. Folders are listed '
                  'first, then files, in name order.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
