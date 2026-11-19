/// Small RFC 4180 CSV reader and writer.
///
/// Handles quoted fields, escaped quotes, line breaks inside quotes, CRLF /
/// LF / CR line endings, a leading UTF-8 byte order mark and the semicolon or
/// tab delimiters that spreadsheet apps use in some regions.
class CsvCodec {
  const CsvCodec._();

  /// Guesses the delimiter from the first line (outside quotes).
  static String detectDelimiter(String text) {
    var inQuotes = false;
    final counts = <String, int>{',': 0, ';': 0, '\t': 0};
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == '\n' || ch == '\r') break;
        if (counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
      }
    }
    var best = ',';
    var bestCount = counts[','] ?? 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// Parses [text] into rows of cells. Completely empty lines are skipped.
  static List<List<String>> parse(String text, {String? delimiter}) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final sep = delimiter ?? detectDelimiter(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var cellWasQuoted = false;

    void endCell() {
      row.add(cell.toString());
      cell.clear();
      cellWasQuoted = false;
    }

    void endRow() {
      endCell();
      final isBlank = row.length == 1 && row.first.isEmpty && !cellWasQuoted;
      if (!isBlank) rows.add(row);
      row = <String>[];
    }

    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
        } else {
          cell.write(ch);
        }
        i++;
        continue;
      }
      if (ch == '"' && cell.isEmpty) {
        inQuotes = true;
        cellWasQuoted = true;
      } else if (ch == sep) {
        endCell();
      } else if (ch == '\r') {
        endRow();
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
      } else if (ch == '\n') {
        endRow();
      } else {
        cell.write(ch);
      }
      i++;
    }
    if (cell.isNotEmpty || row.isNotEmpty || cellWasQuoted) endRow();
    return rows;
  }

  /// Writes rows as CSV with CRLF line endings.
  ///
  /// [escapeFormulas] prefixes text that starts with = + - @ with an
  /// apostrophe so spreadsheet apps do not run it as a formula. Plain numbers
  /// such as -5 are left untouched.
  static String encode(
    List<List<String>> rows, {
    bool bom = false,
    bool escapeFormulas = true,
  }) {
    final out = StringBuffer();
    if (bom) out.write('﻿');
    for (final row in rows) {
      out.write(row.map((c) => _encodeCell(c, escapeFormulas)).join(','));
      out.write('\r\n');
    }
    return out.toString();
  }

  static String _encodeCell(String value, bool escapeFormulas) {
    var text = value;
    if (escapeFormulas && text.isNotEmpty && '=+-@'.contains(text[0])) {
      final isNumber = double.tryParse(text) != null;
      if (!isNumber) text = "'$text";
    }
    final needsQuotes =
        text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r') ||
        text.startsWith(' ') ||
        text.endsWith(' ');
    if (!needsQuotes) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
