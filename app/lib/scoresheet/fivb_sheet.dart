import 'scoresheet_layout.dart';

/// A scoresheet laid out like the FIVB international scoresheet, drawn by the
/// app instead of printed on paper.
///
/// [FivbSheet.build] works out the position of every box once and returns
/// two things from the same numbers: the printed form itself (lines, labels
/// and circles, see [FormMark]) and a [SheetLayout] saying where each value
/// is written. The same painter that fills in the BVA sheet then fills this
/// one, so both sheets record a match the same way.
///
/// The page is A3 landscape. Normal sets go two to a row (set 1 and 2, then
/// 3 and 4), each split into a half for the team on the left and a half for
/// the team on the right. The deciding set runs across the page in three
/// sections: the team that started on the left, the team on the right, and
/// the left-hand team again after the change of courts. The teams, officials
/// and approval signatures are on the right; sanctions, results and remarks
/// under the sets.
///
/// All positions are in PDF points from the top-left of the page.

/// One thing printed on the blank form.
sealed class FormMark {
  const FormMark();
}

class FormRect extends FormMark {
  final double x0, y0, x1, y1, width;

  /// Grey level 0 (black) to 1 (white) to fill with, or null for no fill.
  final double? fill;
  const FormRect(this.x0, this.y0, this.x1, this.y1,
      {this.width = 0.5, this.fill});
}

class FormLine extends FormMark {
  final double x0, y0, x1, y1, width;
  const FormLine(this.x0, this.y0, this.x1, this.y1, {this.width = 0.4});
}

enum FormAlign { left, center, right }

class FormText extends FormMark {
  final String text;
  final double x, baseline, size;
  final bool bold;
  final FormAlign align;
  const FormText(this.text, this.x, this.baseline, this.size,
      {this.bold = false, this.align = FormAlign.left});
}

class FormCircle extends FormMark {
  final double cx, cy, r, width;
  const FormCircle(this.cx, this.cy, this.r, {this.width = 0.5});
}

class FivbForm {
  final SheetLayout layout;
  final List<FormMark> marks;
  const FivbForm(this.layout, this.marks);
}

const List<String> _roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];

class FivbSheet {
  static const double pageWidth = 1190.55; // A3 landscape
  static const double pageHeight = 841.89;
  static const double _m = 18; // page margin

  // Set panels.
  static const double _setsRight = 778;
  static const double _panelW = 376;
  static const double _panelH = 142;
  static const double _titleH = 13;

  // The team column on the right.
  static const double _colX0 = 786;
  static const double _colX1 = pageWidth - _m;

  /// The form for a match of [maxSets] sets (3 or 5). The last set is the
  /// deciding set.
  static FivbForm build({int maxSets = 5}) =>
      _Builder(maxSets).build();
}

class _Builder {
  _Builder(this.maxSets) : decidingSet = maxSets;

  final int maxSets;
  final int decidingSet;
  final marks = <FormMark>[];

  final blocks = <String, BlockLayout>{};
  final setTimes = <int, SetTimesLayout>{};
  final matchInfo = <String, List<double>>{};
  final signatures = <String, List<double>>{};

  // ------------------------------------------------------------- primitives
  void rect(double x0, double y0, double x1, double y1,
          {double width = 0.5, double? fill}) =>
      marks.add(FormRect(x0, y0, x1, y1, width: width, fill: fill));

  void line(double x0, double y0, double x1, double y1, {double width = 0.4}) =>
      marks.add(FormLine(x0, y0, x1, y1, width: width));

  void text(String s, double x, double baseline, double size,
          {bool bold = false, FormAlign align = FormAlign.left}) =>
      marks.add(FormText(s, x, baseline, size, bold: bold, align: align));

  void circle(double cx, double cy, double r, {double width = 0.5}) =>
      marks.add(FormCircle(cx, cy, r, width: width));

  /// A grey title strip with a bold label.
  void strip(double x0, double y0, double x1, String label,
      {double h = 12, double size = 7.5}) {
    rect(x0, y0, x1, y0 + h, fill: 0.85);
    text(label, x0 + 4, y0 + h / 2 + 0.36 * size, size, bold: true);
  }

  /// A box with a small caption in its top-left corner. Returns the area the
  /// value is written in (below the caption).
  List<double> field(String caption, double x0, double y0, double x1, double y1) {
    rect(x0, y0, x1, y1);
    text(caption, x0 + 2, y0 + 5.2, 4.8);
    return [x0, y0 + 6, x1, y1];
  }

  /// A labelled tick box. Returns the box.
  List<double> tick(String label, double x, double y) {
    text(label, x, y + 6.2, 6.5);
    final bx = x + label.length * 0.62 * 6.5 + 4;
    final box = [bx, y, bx + 8, y + 8];
    rect(box[0], box[1], box[2], box[3]);
    return box;
  }

  /// Printed colon of a "hh:mm" or "own:opp" pair.
  void colon(double x, double cy, [double size = 7]) =>
      text(':', x, cy + 0.36 * size, size, bold: true, align: FormAlign.center);

  // ----------------------------------------------------------------- header
  late SheetCircle _headLeft, _headRight;
  late List<double> _headLeftX, _headRightX;
  late double _headBaseline;

  void header() {
    const m = FivbSheet._m;
    const right = FivbSheet.pageWidth - m;
    text('VOLLEYBALL SCORESHEET', m, 30, 13, bold: true);
    text('International (FIVB) layout', right, 30, 7, align: FormAlign.right);

    // Row 1: competition details.
    const y0 = 36.0, y1 = 56.0;
    matchInfo['competition'] = field('Name of the competition', m, y0, 470, y1);
    matchInfo['venue'] = field('City / Hall', 474, y0, 720, y1);
    matchInfo['matchType'] = field('Pool / Phase', 724, y0, 860, y1);
    matchInfo['matchNumber'] = field('Match No.', 864, y0, 930, y1);
    matchInfo['division'] = field('Division', 934, y0, right, y1);

    // Row 2: the teams, date, time and category.
    const r0 = 58.0, r1 = 80.0;
    rect(m, r0, 700, r1);
        _headLeft = const SheetCircle(m + 16, 70, 7);
    _headRight = const SheetCircle(688, 70, 7);
    circle(_headLeft.cx, _headLeft.cy, _headLeft.r);
    circle(_headRight.cx, _headRight.cy, _headRight.r);
    _headLeftX = [m + 28, 340];
    _headRightX = [380, 676];
    _headBaseline = 73;
    line(_headLeftX[0], 75, _headLeftX[1], 75, width: 0.3);
    line(_headRightX[0], 75, _headRightX[1], 75, width: 0.3);
    text('vs', 360, 73, 8, bold: true, align: FormAlign.center);

    rect(704, r0, 860, r1);
    text('Date', 706, r0 + 5.2, 4.8);
    for (final (key, label, x) in [('day', 'D', 730.0), ('month', 'M', 774.0), ('year', 'Y', 818.0)]) {
      text(label, x - 4, r0 + 15, 5, align: FormAlign.right);
      matchInfo[key] = [x, r0 + 5, x + 36, r1 - 3];
      rect(x, r0 + 5, x + 36, r1 - 3, width: 0.3);
    }
    matchInfo['time'] = field('Time', 864, r0, 930, r1);

    rect(934, r0, right, r1);
    text('Category', 936, r0 + 5.2, 4.8);
    matchInfo['men'] = tick('Men', 940, r0 + 9);
    matchInfo['women'] = tick('Women', 990, r0 + 9);
    matchInfo['mixed'] = tick('Mixed', 1050, r0 + 9);
    matchInfo['juniors'] = tick('Junior', 1108, r0 + 9);
  }

  // -------------------------------------------------------- one team block
  /// Draws one team section of a set and records its boxes as block [name].
  void block({
    required String name,
    required int set,
    required String side,
    required double x,
    required double y,
    required double width,
    required double colW,
    required int pointCols,
    required int pointsPerCol,
    bool hasName = true,
    bool hasServeCircles = true,
    bool hasChangeBox = false,
  }) {
    rect(x, y, x + width, y + 128, width: 0.6);

    // Header row: S / R circles, team letter, team name.
    const hh = 16.0;
    line(x, y + hh, x + width, y + hh);
    SheetCircle? srS, srR;
    if (hasServeCircles) {
      srS = SheetCircle(x + 8, y + 8, 4.5);
      srR = SheetCircle(x + 20, y + 8, 4.5);
      for (final (c, l) in [(srS, 'S'), (srR, 'R')]) {
        circle(c.cx, c.cy, c.r, width: 0.4);
        text(l, c.cx, c.cy + 2, 5.5, align: FormAlign.center);
      }
    }
    final letter = SheetCircle(x + (hasServeCircles ? 36 : 10), y + 8, 6);
    circle(letter.cx, letter.cy, letter.r);
    List<double>? nameBox;
    if (hasName) {
      nameBox = [letter.cx + 9, y + 2, x + width - 3, y + 14];
      line(nameBox[0], y + 13.5, nameBox[2], y + 13.5, width: 0.3);
    }
    ChangeBox? changeBox;
    if (hasChangeBox) {
      final lx = letter.cx + 10;
      text('POINTS AT CHANGE OF COURTS', lx, y + 10, 5.2, bold: true);
      final bx = lx + 92;
      rect(bx, y + 3, bx + 34, y + 13, width: 0.4);
      changeBox = ChangeBox(bx + 17, y + 8);
      colon(bx + 17, y + 8, 6.4);
    }

    // Service order columns.
    final cx0 = x + 22;
    final cols = [
      for (var k = 0; k < 6; k++) [cx0 + k * colW, cx0 + (k + 1) * colW]
    ];
    final colsRight = cols.last[1];
    final roman = [y + hh, y + hh + 9];
    final starters = [y + hh + 9, y + hh + 24];
    final subNum = [y + hh + 24, y + hh + 36];
    final score1 = [y + hh + 36, y + hh + 45];
    final score2 = [y + hh + 45, y + hh + 54];
    final roundsTop = y + hh + 54;
    const roundH = 11.0;
    final roundsBottom = roundsTop + 4 * roundH;
    final toTop = roundsBottom;
    final toBottom = y + 128;

    for (final c in cols) {
      line(c[0], roman[0], c[0], roundsBottom);
    }
    line(colsRight, roman[0], colsRight, roundsBottom);
    for (final yy in [roman[1], starters[1], subNum[1], score1[1], score2[1], roundsBottom]) {
      line(x, yy, colsRight, yy);
    }
    for (var r = 1; r < 4; r++) {
      line(cx0, roundsTop + r * roundH, colsRight, roundsTop + r * roundH, width: 0.25);
    }

    // Row captions in the strip on the left.
    void caption(String s, List<double> row) =>
        text(s, x + 2, (row[0] + row[1]) / 2 + 1.6, 4.4);
    caption('Service', roman);
    caption('Start', starters);
    caption('Subst.', subNum);
    caption('Score', score1);
    text('Service', x + 2, roundsTop + 19, 4.4);
    text('rounds', x + 2, roundsTop + 24, 4.4);
    text('T', x + 2, (toTop + toBottom) / 2 + 2, 6, bold: true);

    final rounds = <List<List<double>>>[];
    final scoreColons = <List<List<double>>>[[], []];
    for (var k = 0; k < 6; k++) {
      final c = cols[k];
      final mid = (c[0] + c[1]) / 2;
      text(_roman[k], mid, roman[1] - 2.2, 5.8, bold: true, align: FormAlign.center);
      colon(mid, (score1[0] + score1[1]) / 2, 5.6);
      colon(mid, (score2[0] + score2[1]) / 2, 5.6);
      scoreColons[0].add([mid, (score1[0] + score1[1]) / 2]);
      scoreColons[1].add([mid, (score2[0] + score2[1]) / 2]);

      // Eight service-round boxes, two per line: 1 2 / 3 4 / 5 6 / 7 8.
      line(mid, roundsTop, mid, roundsBottom, width: 0.25);
      final cells = <List<double>>[];
      for (var n = 0; n < 8; n++) {
        final cx = n.isEven ? c[0] : mid;
        final cy = roundsTop + (n ~/ 2) * roundH;
        cells.add([cx, cy, n.isEven ? mid : c[1], cy + roundH]);
        text('${n + 1}', cx + 1, cy + 3.6, 3.4);
      }
      rounds.add(cells);
    }

    // Points column: numbers in [pointCols] columns, top to bottom.
    final px0 = colsRight + 4;
    const pw = 9.5;
    final py0 = y + hh + 2;
    final ph = (roundsBottom - py0) / pointsPerCol;
    rect(px0, py0, px0 + pointCols * pw, py0 + pointsPerCol * ph, width: 0.4);
    final grid = <int, List<double>>{};
    for (var c = 0; c < pointCols; c++) {
      if (c > 0) line(px0 + c * pw, py0, px0 + c * pw, py0 + pointsPerCol * ph, width: 0.25);
      for (var r = 0; r < pointsPerCol; r++) {
        final n = c * pointsPerCol + r + 1;
        const size = 5.2;
        final w = '$n'.length * 0.556 * size;
        final cx = px0 + c * pw + pw / 2;
        final cy = py0 + r * ph + ph / 2;
        text('$n', cx, cy + 0.36 * size, size, align: FormAlign.center);
        grid[n] = [cx - w / 2, cy - 0.36 * size, cx + w / 2, cy + 0.36 * size];
      }
    }
    text('POINTS', px0 + pointCols * pw / 2, py0 - 1, 3.8, align: FormAlign.center);

    // Two time-out boxes.
    final timeouts = <TimeoutCell>[];
    for (var i = 0; i < 2; i++) {
      final bx = cx0 + i * 56;
      rect(bx, toTop + 2, bx + 50, toBottom - 2, width: 0.4);
      final c = TimeoutCell(bx + 25, (toTop + toBottom) / 2);
      colon(c.colonX, c.cy, 6.4);
      timeouts.add(c);
    }

    blocks[name] = BlockLayout(
      set: set,
      side: side,
      printedLetter: null,
      cols: cols,
      rows: {
        'starters': starters,
        'subNum': subNum,
        'score1': score1,
        'score2': score2,
      },
      rounds: rounds,
      scoreColons: scoreColons,
      grid: grid,
      timeouts: timeouts,
      nameBox: nameBox,
      letterCircle: letter,
      srS: srS,
      srR: srR,
      changeBox: changeBox,
    );
  }

  /// The title strip of a set: "SET n" with its START and END times.
  void setTitle(int set, double x0, double y, double x1, {String extra = ''}) {
    strip(x0, y, x1, 'SET $set$extra', h: FivbSheet._titleH, size: 8);
    final base = y + 9.6;
    final startLabel = x1 - 200;
    text('START TIME', startLabel, base, 5.5, bold: true);
    rect(startLabel + 36, y + 2, startLabel + 76, y + 11, width: 0.4, fill: 1);
    colon(startLabel + 56, y + 6.5);
    text('END TIME', startLabel + 92, base, 5.5, bold: true);
    rect(startLabel + 122, y + 2, startLabel + 162, y + 11, width: 0.4, fill: 1);
    colon(startLabel + 142, y + 6.5);
    setTimes[set] =
        SetTimesLayout(startLabel + 56, startLabel + 142, y + 9.0);
  }

  double sets() {
    const m = FivbSheet._m;
    const pw = FivbSheet._panelW;
    const ph = FivbSheet._panelH;
    var y = 86.0;
    final normal = maxSets - 1;
    for (var n = 1; n <= normal; n++) {
      final x = n.isOdd ? m : m + pw + 8;
      setTitle(n, x, y, x + pw);
      final by = y + FivbSheet._titleH;
      for (final (side, bx) in [('L', x), ('R', x + pw / 2)]) {
        block(
          name: 'S$n$side',
          set: n,
          side: side,
          x: bx,
          y: by,
          width: pw / 2,
          colW: 20,
          pointCols: 4,
          pointsPerCol: 12,
        );
      }
      if (n.isEven || n == normal) y += ph + 6;
    }

    // Deciding set across the page.
    const w = (FivbSheet._setsRight - m) / 3;
    final n = decidingSet;
    setTitle(n, m, y, FivbSheet._setsRight, extra: '  (deciding set)');
    final by = y + FivbSheet._titleH;
    block(name: 'S${n}L', set: n, side: 'L', x: m, y: by, width: w,
        colW: 24, pointCols: 3, pointsPerCol: 10);
    block(name: 'S${n}R', set: n, side: 'R', x: m + w, y: by, width: w,
        colW: 24, pointCols: 3, pointsPerCol: 10);
    block(name: 'S${n}C', set: n, side: 'C', x: m + 2 * w, y: by, width: w,
        colW: 24, pointCols: 3, pointsPerCol: 10,
        hasName: false, hasServeCircles: false, hasChangeBox: true);
    line(m + 2 * w, by, m + 2 * w, by + 128, width: 1.4);
    return y + ph + 6;
  }

  // ---------------------------------------------------- sanctions, results
  void sanctions(double y0, double y1) {
    const x0 = FivbSheet._m, x1 = 250.0;
    strip(x0, y0, x1, 'SANCTIONS');
    rect(x0, y0, x1, y1, width: 0.6);
    final heads = ['Warning', 'Penalty', 'Expulsion', 'Disqual.', 'A or B', 'Set', 'Score'];
    final colW = (x1 - x0) / heads.length;
    final hy = y0 + 12;
    for (var i = 0; i < heads.length; i++) {
      final cx = x0 + i * colW;
      if (i > 0) line(cx, hy, cx, y1 - 16);
      text(heads[i], cx + colW / 2, hy + 7, 5, bold: true, align: FormAlign.center);
    }
    for (var yy = hy + 10; yy < y1 - 16; yy += 11) {
      line(x0, yy, x1, yy, width: 0.3);
    }
    line(x0, y1 - 16, x1, y1 - 16);
    text('IMPROPER REQUEST', x0 + 4, y1 - 5, 6, bold: true);
    tick('A', x0 + 100, y1 - 12);
    tick('B', x0 + 130, y1 - 12);
  }

  late ResultsLayout results;

  void resultsBox(double y0) {
    const x0 = 258.0, x1 = 560.0;
    strip(x0, y0, x1, 'RESULTS');
    // Team A: T S W P | SET (duration) | Team B: P W S T
    const cw = 18.0;
    final aCols = <String, List<double>>{};
    final bCols = <String, List<double>>{};
    const keys = ['T', 'S', 'W', 'P'];
    for (var i = 0; i < 4; i++) {
      aCols[keys[i]] = [x0 + i * cw, x0 + (i + 1) * cw];
      bCols[keys[3 - i]] = [x1 - (4 - i) * cw, x1 - (3 - i) * cw];
    }
    final midX0 = x0 + 4 * cw, midX1 = x1 - 4 * cw;

    final nameRow = [y0 + 12, y0 + 26];
    final teamABox = [x0 + 14, nameRow[0], (x0 + x1) / 2 - 2, nameRow[1]];
    final teamBBox = [(x0 + x1) / 2 + 14, nameRow[0], x1 - 2, nameRow[1]];
    final aCircle = SheetCircle(x0 + 7, (nameRow[0] + nameRow[1]) / 2, 5);
    final bCircle = SheetCircle((x0 + x1) / 2 + 7, aCircle.cy, 5);
    circle(aCircle.cx, aCircle.cy, aCircle.r);
    text('A', aCircle.cx, aCircle.cy + 2.2, 6, bold: true, align: FormAlign.center);
    circle(bCircle.cx, bCircle.cy, bCircle.r);
    text('B', bCircle.cx, bCircle.cy + 2.2, 6, bold: true, align: FormAlign.center);
    line(x0, nameRow[1], x1, nameRow[1]);
    line((x0 + x1) / 2, nameRow[0], (x0 + x1) / 2, nameRow[1]);

    final headRow = [nameRow[1], nameRow[1] + 10];
    const heads = {'T': 'T', 'S': 'S', 'W': 'W', 'P': 'P'};
    for (final k in keys) {
      for (final c in [aCols[k]!, bCols[k]!]) {
        text(heads[k]!, (c[0] + c[1]) / 2, headRow[1] - 2.5, 6, bold: true, align: FormAlign.center);
      }
    }
    text('SET (Duration)', (midX0 + midX1) / 2, headRow[1] - 2.5, 6,
        bold: true, align: FormAlign.center);

    const rh = 13.0;
    final setRows = <List<double>>[];
    var y = headRow[1];
    final durX = [midX1 - 46, midX1 - 10];
    for (var s = 1; s <= maxSets; s++) {
      setRows.add([y, y + rh]);
      final base = y + rh / 2 + 2.2;
      text('Set $s', midX0 + 8, base, 6.5, bold: true);
      text('(', durX[0] - 2, base, 7);
      text("')", durX[1], base, 7);
      y += rh;
    }
    final totalRow = [y, y + rh];
    text('Total', midX0 + 4, y + rh / 2 + 2.2, 6.5, bold: true);
    text('(', durX[0] - 2, y + rh / 2 + 2.2, 7);
    text("')", durX[1], y + rh / 2 + 2.2, 7);
    y += rh;

    rect(x0, y0, x1, y, width: 0.6);
    line(x0, headRow[1], x1, headRow[1], width: 0.3);
    for (final r in setRows) {
      line(x0, r[1], x1, r[1], width: 0.3);
    }
    line(x0, totalRow[0], x1, totalRow[0], width: 0.7);
    for (final c in [...aCols.values, ...bCols.values]) {
      line(c[0], headRow[0], c[0], y, width: 0.3);
      line(c[1], headRow[0], c[1], y, width: 0.3);
    }

    // Match times.
    final timesTop = y;
    final timeBase = y + 11;
    text('Match starts', x0 + 4, timeBase, 6, bold: true);
    final startColon = x0 + 66.0;
    colon(startColon, timeBase - 2.5);
    text('Match ends', x0 + 96, timeBase, 6, bold: true);
    final endColon = x0 + 152.0;
    colon(endColon, timeBase - 2.5);
    text('Duration', x0 + 180, timeBase, 6, bold: true);
    final hRight = x0 + 238.0;
    text('h', hRight + 1.5, timeBase, 6);
    final mRight = x0 + 270.0;
    text('mn', mRight + 1.5, timeBase, 6);
    y += 15;
    rect(x0, timesTop, x1, y, width: 0.6);

    // Winner.
    final winTop = y;
    final winBase = y + 13;
    text('WINNER', x0 + 4, winBase, 8, bold: true);
    final winX = [x0 + 50, x1 - 46];
    line(winX[0], winBase + 2, winX[1], winBase + 2, width: 0.3);
    final needed = (maxSets + 1) ~/ 2;
    final sx = x1 - 40;
    text('$needed :', sx, winBase, 10, bold: true);
    y += 18;
    rect(x0, winTop, x1, y, width: 0.6);

    results = ResultsLayout(
      teamANameBox: teamABox,
      teamBNameBox: teamBBox,
      teamACols: aCols,
      teamBCols: bCols,
      setRows: setRows,
      totalRow: totalRow,
      winnerNameX: winX,
      winnerTextBaselineY: winBase,
      printedWinnerSets: [sx, winBase - 7, sx + 13, winBase],
      setDurationX: durX,
      totalSetDurationX: durX,
      timeBaselineY: timeBase,
      startColonX: startColon,
      endColonX: endColon,
      durationHoursRightX: hRight,
      durationMinutesRightX: mRight,
    );
    _resultsBottom = y;
  }

  double _resultsBottom = 0;

  /// Captains sign after the match, below the results.
  void captainsAfter(double y0, double y1) {
    const x0 = 258.0, x1 = 560.0;
    strip(x0, y0, x1, "CAPTAINS' SIGNATURES AFTER THE MATCH");
    rect(x0, y0, x1, y1, width: 0.6);
    const mid = (x0 + x1) / 2;
    line(mid, y0 + 12, mid, y1);
    text('Team A captain', x0 + 3, y0 + 18, 5);
    text('Team B captain', mid + 3, y0 + 18, 5);
    signatures['approvalCaptainA'] = [x0 + 3, y0 + 20, mid - 3, y1 - 2];
    signatures['approvalCaptainB'] = [mid + 3, y0 + 20, x1 - 3, y1 - 2];
  }

  late List<List<double>> remarksRows;

  void remarks(double y0, double y1) {
    const x0 = 568.0, x1 = FivbSheet._setsRight;
    strip(x0, y0, x1, 'REMARKS');
    rect(x0, y0, x1, y1, width: 0.6);
    remarksRows = [];
    for (var b = y0 + 24; b <= y1 - 3; b += 11) {
      line(x0 + 3, b, x1 - 3, b, width: 0.25);
      remarksRows.add([x0 + 3, x1 - 3, b]);
    }
  }

  // -------------------------------------------------------------- the teams
  late PlayersLayout players;
  late OfficialsLayout officials;

  double teams(double y0) {
    const x0 = FivbSheet._colX0, x1 = FivbSheet._colX1;
    strip(x0, y0, x1, 'TEAMS');
    const mid = (x0 + x1) / 2;
    final halves = [
      [x0, mid - 2],
      [mid + 2, x1]
    ];

    var y = y0 + 12;
    final headRow = [y, y + 16];
    final circles = <SheetCircle>[];
    final nameBoxes = <List<double>>[];
    for (final h in halves) {
      final c = SheetCircle(h[0] + 10, (headRow[0] + headRow[1]) / 2, 6);
      circle(c.cx, c.cy, c.r);
      circles.add(c);
      nameBoxes.add([h[0] + 19, headRow[0] + 2, h[1] - 2, headRow[1] - 2]);
      line(h[0] + 19, headRow[1] - 2.5, h[1] - 2, headRow[1] - 2.5, width: 0.3);
    }
    y = headRow[1];

    final numXs = [for (final h in halves) [h[0], h[0] + 22]];
    final nameXs = [for (final h in halves) [h[0] + 22, h[1]]];

    void table(String title, List<List<double>> rows, String numHead, String nameHead) {
      for (final h in halves) {
        rect(h[0], rows.first[0] - 9, h[1], rows.last[1], width: 0.5);
        line(h[0], rows.first[0], h[1], rows.first[0], width: 0.4);
        text(numHead, h[0] + 11, rows.first[0] - 2.5, 5, bold: true, align: FormAlign.center);
        text(nameHead, h[0] + 25, rows.first[0] - 2.5, 5, bold: true);
        line(h[0] + 22, rows.first[0] - 9, h[0] + 22, rows.last[1], width: 0.3);
        for (final r in rows.skip(1)) {
          line(h[0], r[0], h[1], r[0], width: 0.25);
        }
      }
      text(title, mid, rows.first[0] - 2.5, 5, bold: true, align: FormAlign.center);
    }

    List<List<double>> rowsFrom(double top, int n, double h) =>
        [for (var i = 0; i < n; i++) [top + i * h, top + (i + 1) * h]];

    final playerRows = rowsFrom(y + 9, 14, 10);
    table('', playerRows, 'No.', 'Name of the player');
    y = playerRows.last[1] + 3;

    final liberoRows = rowsFrom(y + 9, 2, 10);
    table('', liberoRows, 'L', 'Libero players');
    y = liberoRows.last[1] + 3;

    final officialRows = rowsFrom(y + 9, 4, 10);
    table('', officialRows, '', 'Officials (C, AC, T, M)');
    y = officialRows.last[1] + 3;

    players = PlayersLayout(
      rows: playerRows,
      liberoRows: liberoRows,
      leftNumX: numXs[0],
      leftNameX: nameXs[0],
      rightNumX: numXs[1],
      rightNameX: nameXs[1],
      leftCircle: circles[0],
      rightCircle: circles[1],
      leftNameBox: nameBoxes[0],
      rightNameBox: nameBoxes[1],
    );
    officials = OfficialsLayout(
      rows: officialRows,
      leftRoleX: numXs[0],
      leftNameX: nameXs[0],
      rightRoleX: numXs[1],
      rightNameX: nameXs[1],
    );

    // Signatures before the match: captain and coach of each team.
    strip(x0, y, x1, 'SIGNATURES (before the match)', h: 10, size: 6);
    y += 10;
    final sigTop = y, sigBottom = y + 26;
    for (final (i, h) in halves.indexed) {
      final side = i == 0 ? 'Left' : 'Right';
      final hm = (h[0] + h[1]) / 2;
      rect(h[0], sigTop, h[1], sigBottom, width: 0.5);
      line(hm, sigTop, hm, sigBottom, width: 0.3);
      text('Captain', h[0] + 2, sigTop + 5.5, 4.8);
      text('Coach', hm + 2, sigTop + 5.5, 4.8);
      signatures['captain$side'] = [h[0] + 2, sigTop + 6, hm - 2, sigBottom - 1];
      signatures['coach$side'] = [hm + 2, sigTop + 6, h[1] - 2, sigBottom - 1];
    }
    return sigBottom;
  }

  double approval(double y0) {
    const x0 = FivbSheet._colX0, x1 = FivbSheet._colX1;
    strip(x0, y0, x1, 'APPROVAL');
    var y = y0 + 12;
    const roleW = 74.0, nameW = 150.0;
    text('Name', x0 + roleW + 3, y + 7, 5, bold: true);
    text('Signature', x0 + roleW + nameW + 3, y + 7, 5, bold: true);
    y += 9;
    final rows = [
      ('ref1', '1st Referee'),
      ('ref2', '2nd Referee'),
      ('scorer', 'Scorer'),
      ('assistantScorer', 'Assistant scorer'),
      ('lineJudge1', 'Line judge 1'),
      ('lineJudge2', 'Line judge 2'),
      ('lineJudge3', 'Line judge 3'),
      ('lineJudge4', 'Line judge 4'),
    ];
    const rh = 17.0;
    final top = y;
    for (final (key, label) in rows) {
      text(label, x0 + 3, y + rh / 2 + 2, 6, bold: true);
      signatures[key] = [x0 + roleW + nameW + 2, y + 1, x1 - 2, y + rh - 1];
      y += rh;
      line(x0, y, x1, y, width: 0.3);
    }
    rect(x0, y0, x1, y, width: 0.6);
    line(x0, top, x1, top, width: 0.4);
    line(x0 + roleW, top - 9, x0 + roleW, y, width: 0.3);
    line(x0 + roleW + nameW, top - 9, x0 + roleW + nameW, y, width: 0.3);
    return y;
  }

  // ---------------------------------------------------------------- whole
  FivbForm build() {
    header();
    final lowerTop = sets();
    const bottom = FivbSheet.pageHeight - FivbSheet._m;

    sanctions(lowerTop, bottom);
    resultsBox(lowerTop);
    final capTop = _resultsBottom + 6;
    captainsAfter(capTop, capTop + 40 > bottom ? bottom : capTop + 40);
    remarks(lowerTop, bottom);

    final teamsBottom = teams(86);
    approval(teamsBottom + 8);

    final layout = SheetLayout(
      pageWidth: FivbSheet.pageWidth,
      pageHeight: FivbSheet.pageHeight,
      blocks: blocks,
      header: HeaderLayout(
        leftCircle: _headLeft,
        rightCircle: _headRight,
        leftNameX: _headLeftX,
        rightNameX: _headRightX,
        nameBaselineY: _headBaseline,
      ),
      players: players,
      results: results,
      signatures: signatures,
      matchInfo: matchInfo,
      officials: officials,
      remarksRows: remarksRows,
      setTimes: setTimes,
    );
    return FivbForm(layout, List.unmodifiable(marks));
  }
}
