/// Lays free-text notes out on the ruled lines of the REMARKS box.
///
/// The box has six lines of different widths (the first one is shorter
/// because of the "REMARKS" label). Text is wrapped at spaces, a word that is
/// wider than a line is split, blank lines are kept, and if everything won't
/// fit the text shrinks, and as a last resort is cut off with "...".
library;

typedef TextMeasure = double Function(String text, double size);

class RemarksFit {
  final double size;
  final List<String> lines;

  /// True if the notes were too long even at the smallest size.
  final bool truncated;

  const RemarksFit(this.size, this.lines, this.truncated);
}

/// Wraps [text] into lines no wider than the matching entry of [rowWidths]
/// (the last width is reused for any lines beyond the list).
List<String> wrapLines(
  String text,
  List<double> rowWidths,
  double size,
  TextMeasure measure,
) {
  final lines = <String>[];

  double limit() =>
      rowWidths[lines.length < rowWidths.length ? lines.length : rowWidths.length - 1];

  for (final paragraph in text.replaceAll('\r', '').split('\n')) {
    var current = '';
    for (final word in paragraph.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      var rest = word;
      while (rest.isNotEmpty) {
        final candidate = current.isEmpty ? rest : '$current $rest';
        if (measure(candidate, size) <= limit()) {
          current = candidate;
          rest = '';
        } else if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        } else {
          // One word wider than the whole line: split it.
          var cut = rest.length;
          while (cut > 1 && measure(rest.substring(0, cut), size) > limit()) {
            cut--;
          }
          lines.add(rest.substring(0, cut));
          rest = rest.substring(cut);
        }
      }
    }
    lines.add(current); // end of paragraph; an empty one is a blank line
  }

  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// Finds the largest text size (down to [minSize]) at which [text] fits on the
/// available rows.
RemarksFit fitRemarks(
  String text,
  List<double> rowWidths,
  TextMeasure measure, {
  double maxSize = 6.5,
  double minSize = 4.0,
}) {
  if (text.trim().isEmpty) return RemarksFit(maxSize, const [], false);

  for (var size = maxSize; size >= minSize; size -= 0.25) {
    final lines = wrapLines(text, rowWidths, size, measure);
    if (lines.length <= rowWidths.length) return RemarksFit(size, lines, false);
  }

  // Still too long at the smallest size: keep what fits and mark the cut.
  final lines =
      wrapLines(text, rowWidths, minSize, measure).take(rowWidths.length).toList();
  final lastRow = lines.length - 1;
  var last = lines[lastRow];
  while (last.isNotEmpty && measure('$last...', minSize) > rowWidths[lastRow]) {
    last = last.substring(0, last.length - 1);
  }
  lines[lastRow] = '$last...';
  return RemarksFit(minSize, lines, true);
}

/// The REMARKS box with referee overrides: the notes first, then each override
/// starting on a new line. [signatureRows] gives, for each override, the row
/// whose right-hand end holds the referee's signature (absent if it didn't
/// fit).
class RemarksWithOverrides {
  final double size;
  final List<String> lines;
  final Map<int, int> signatureRows;
  final bool truncated;
  const RemarksWithOverrides(
      this.size, this.lines, this.signatureRows, this.truncated);
}

/// Lays out [notes] and then each of [overrides] on the rows of the REMARKS
/// box. Override lines are kept [signatureWidth] short of the row's end, to
/// leave room for the signature.
RemarksWithOverrides fitRemarksWithOverrides(
  String notes,
  List<String> overrides,
  List<double> rowWidths,
  double signatureWidth,
  TextMeasure measure, {
  double maxSize = 6.5,
  double minSize = 4.0,
}) {
  if (overrides.isEmpty) {
    final fit = fitRemarks(notes, rowWidths, measure,
        maxSize: maxSize, minSize: minSize);
    return RemarksWithOverrides(fit.size, fit.lines, const {}, fit.truncated);
  }

  RemarksWithOverrides layout(double size) {
    final lines = <String>[];
    final sigRows = <int, int>{};
    if (notes.trim().isNotEmpty) {
      lines.addAll(wrapLines(notes, rowWidths, size, measure));
    }
    for (var i = 0; i < overrides.length; i++) {
      final start = lines.length;
      final widths = [
        for (var r = start; r < start + rowWidths.length; r++)
          rowWidths[r < rowWidths.length ? r : rowWidths.length - 1] -
              signatureWidth
      ];
      final wrapped = wrapLines(overrides[i], widths, size, measure);
      if (wrapped.isEmpty) wrapped.add('');
      lines.addAll(wrapped);
      sigRows[i] = lines.length - 1;
    }
    return RemarksWithOverrides(size, lines, sigRows, false);
  }

  for (var size = maxSize; size >= minSize; size -= 0.25) {
    final l = layout(size);
    if (l.lines.length <= rowWidths.length) return l;
  }

  // Too long even at the smallest size: keep the rows that fit.
  final l = layout(minSize);
  final lines = l.lines.take(rowWidths.length).toList();
  final last = lines.length - 1;
  lines[last] = '${lines[last]}...';
  return RemarksWithOverrides(
    minSize,
    lines,
    {
      for (final e in l.signatureRows.entries)
        if (e.value < rowWidths.length) e.key: e.value
    },
    true,
  );
}
