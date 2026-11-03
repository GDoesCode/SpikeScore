import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import '../match_engine.dart' show MatchEngine, Team;
import '../models.dart';
import 'scoresheet_data.dart';
import 'scoresheet_layout.dart';
import 'signature_slots.dart';

/// Draws a match onto the blank BVA 3-set scoresheet.
///
/// The blank sheet is embedded as a picture (so the page looks exactly like the
/// original) and everything the app knows is written on top of it at the
/// positions in the layout file. Anything the app doesn't know is left blank.
///
/// Team A = Home, Team B = Away.
class ScoresheetPdf {
  static Future<Uint8List> build(
    ScoresheetData data, {
    required Uint8List background,
    required String layoutJson,
  }) async {
    final layout = SheetLayout.fromJsonString(layoutJson);
    final doc = PdfDocument();
    final page = PdfPage(
      doc,
      pageFormat: PdfPageFormat(layout.pageWidth, layout.pageHeight),
    );
    final g = page.getGraphics();
    final image = PdfImage.file(doc, bytes: background);
    g.drawImage(image, 0, 0, layout.pageWidth, layout.pageHeight);

    _Painter(doc, g, layout).draw(data);
    return doc.save();
  }
}

enum _Align { left, center, right }

enum _Segment { all, before, after }

// Helvetica advance widths (1/1000 em) for ASCII 32..126, used to centre and
// shrink text to fit the small boxes.
const List<int> _regularWidths = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278,
    278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584,
    584, 556, 1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556,
    833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278,
    278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222,
    500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500,
    500, 334, 260, 334, 584
];

const List<int> _boldWidths = [
    278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278,
    278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584,
    584, 611, 975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611,
    833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333,
    278, 333, 584, 556, 333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278,
    556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556,
    500, 389, 280, 389, 584
];

class _Painter {
  _Painter(this.doc, this.g, this.layout)
      : regular = PdfFont.helvetica(doc),
        bold = PdfFont.helveticaBold(doc) {
    g.setStrokeColor(_ink);
    g.setFillColor(_ink);
  }

  // Dark blue, like a pen on the printed sheet.
  static final PdfColor _ink = PdfColor(0.07, 0.18, 0.62);

  final PdfDocument doc;
  final PdfGraphics g;
  final SheetLayout layout;
  final PdfFont regular;
  final PdfFont bold;

  // --------------------------------------------------------------- helpers
  double _y(double top) => layout.pageHeight - top;

  String _clean(String s) =>
      String.fromCharCodes(s.codeUnits.map((c) => c > 255 ? 63 : c));

  double _width(String s, bool isBold, double size) {
    final table = isBold ? _boldWidths : _regularWidths;
    var w = 0;
    for (final c in s.codeUnits) {
      final i = c - 32;
      w += (i >= 0 && i < table.length) ? table[i] : 556;
    }
    return w * size / 1000.0;
  }

  double _fit(String s, double maxW, double size, double minSize, bool isBold) {
    var sz = size;
    while (sz > minSize && _width(s, isBold, sz) > maxW) {
      sz -= 0.25;
    }
    return sz;
  }

  void _text(
    String? s,
    double x,
    double baseline,
    double size, {
    bool isBold = false,
    _Align align = _Align.left,
  }) {
    if (s == null || s.isEmpty) return;
    final text = _clean(s);
    final w = _width(text, isBold, size);
    var px = x;
    if (align == _Align.center) {
      px -= w / 2;
    } else if (align == _Align.right) {
      px -= w;
    }
    g.drawString(isBold ? bold : regular, size, text, px, _y(baseline));
  }

  void _textInBox(
    String? s,
    List<double> box,
    double size, {
    bool isBold = false,
    _Align align = _Align.center,
    double pad = 1.2,
    double minSize = 3.5,
  }) {
    if (s == null || s.isEmpty) return;
    final text = _clean(s);
    final fitted = _fit(text, (box[2] - box[0]) - 2 * pad, size, minSize, isBold);
    final baseline = (box[1] + box[3]) / 2 + 0.36 * fitted;
    if (align == _Align.center) {
      _text(text, (box[0] + box[2]) / 2, baseline, fitted,
          isBold: isBold, align: _Align.center);
    } else {
      _text(text, box[0] + pad, baseline, fitted, isBold: isBold);
    }
  }

  /// "own:opp" written either side of a printed colon.
  void _scorePair(int own, int opp, double colonX, double cy,
      [double size = 6.4]) {
    final baseline = cy + 0.36 * size;
    _text('$own', colonX - 1.4, baseline, size, align: _Align.right);
    _text('$opp', colonX + 1.4, baseline, size);
  }

  void _circle(double cx, double cy, double r, double width) {
    g.setLineWidth(width);
    g.drawEllipse(cx, _y(cy), r, r);
    g.strokePath();
  }

  void _line(double x0, double y0, double x1, double y1, double width) {
    g.setLineWidth(width);
    g.drawLine(x0, _y(y0), x1, _y(y1));
    g.strokePath();
  }

  // ------------------------------------------------------------ point grids
  void _slash(List<double> b) =>
      _line(b[0] - 0.7, b[3] + 0.7, b[2] + 0.7, b[1] - 0.7, 0.55);

  void _ring(List<double> b) {
    final cx = (b[0] + b[2]) / 2;
    final cy = (b[1] + b[3]) / 2;
    final w = b[2] - b[0];
    final h = b[3] - b[1];
    _circle(cx, cy, (w > h ? w : h) / 2 + 1.1, 0.6);
  }

  /// Vertical strike with a T-bar through each run of unused numbers.
  void _cancel(Map<int, List<double>> grid, int from, int to) {
    final maxN = grid.keys.reduce((a, b) => a > b ? a : b);
    final rowsPerCol = maxN == 48 ? 12 : (maxN == 30 ? 10 : maxN);

    // Column centre = mean centre of every printed number in that column.
    double columnCentre(int col) {
      var sum = 0.0;
      var count = 0;
      for (var n = col * rowsPerCol + 1; n <= (col + 1) * rowsPerCol; n++) {
        final b = grid[n];
        if (b == null) continue;
        sum += (b[0] + b[2]) / 2;
        count++;
      }
      return count == 0 ? 0.0 : sum / count;
    }

    final byColumn = <int, List<List<double>>>{};
    for (var n = from; n <= to; n++) {
      final b = grid[n];
      if (b == null) continue;
      byColumn.putIfAbsent((n - 1) ~/ rowsPerCol, () => []).add(b);
    }
    byColumn.forEach((col, boxes) {
      boxes.sort((a, b) => a[1].compareTo(b[1]));
      final cx = columnCentre(col);
      final top = boxes.first[1] - 0.6;
      final bottom = boxes.last[3] + 0.6;
      _line(cx, top, cx, bottom, 0.5);
      _line(cx - 2.6, top, cx + 2.6, top, 0.5);
    });
  }

  /// Slash lo+1..upTo, ring [finalPoint], strike through cancelFrom..cancelTo.
  void _markPoints(
    Map<int, List<double>> grid,
    int upTo, {
    int lo = 0,
    int? finalPoint,
    int? cancelFrom,
    int? cancelTo,
  }) {
    for (var n = lo + 1; n <= upTo; n++) {
      final b = grid[n];
      if (b != null) _slash(b);
    }
    if (finalPoint != null) {
      final b = grid[finalPoint];
      if (b != null) _ring(b);
    }
    if (cancelFrom != null && cancelTo != null && cancelTo >= cancelFrom) {
      _cancel(grid, cancelFrom, cancelTo);
    }
  }

  // -------------------------------------------------------------- one block
  void _drawBlock(
    String blockName,
    Team team,
    SheetSet sd,
    ScoresheetData data,
    _Segment segment,
  ) {
    final b = layout.block(blockName);
    final sheet = data.teams[team]!;
    final afterOnly = segment == _Segment.after;

    bool keep(bool afterChange) =>
        segment == _Segment.all || afterChange == afterOnly;

    // Team name (not repeated in the third block of the deciding set).
    if (b.nameBox != null && !afterOnly) {
      _textInBox(sheet.name, b.nameBox!, 7.0,
          isBold: true, align: _Align.left);
    }

    // Letter in the blank circles (set 3).
    final letter = team == data.teamA ? 'A' : 'B';
    if (b.printedLetter == null && b.letterCircle != null) {
      final lc = b.letterCircle!;
      _text(letter, lc.cx, lc.cy + 0.36 * 9.5, 9.5,
          isBold: true, align: _Align.center);
    }

    // S (served first) or R (received first).
    if (b.srS != null && b.srR != null && sd.firstServe != null) {
      final c = sd.firstServe == team ? b.srS! : b.srR!;
      _circle(c.cx, c.cy, c.r + 0.9, 1.1);
    }

    // Starting players in service order.
    var lineup = sheet.starters;
    if (afterOnly && sd.change != null) {
      lineup = sd.change!.lineup[team]!;
    }
    final startRow = b.rows['starters']!;
    for (var k = 0; k < 6; k++) {
      final col = b.cols[k];
      _textInBox('${lineup[k]}', [col[0], startRow[0], col[1], startRow[1]], 8.5,
          isBold: true);
    }

    // Substitutions: first change in a column = number + score, return = score.
    final perSlot = <int, int>{};
    for (final s in sd.subs[team]!) {
      if (!keep(s.afterChange)) continue;
      final n = perSlot[s.slot] ?? 0;
      perSlot[s.slot] = n + 1;
      if (n == 0) {
        final col = b.cols[s.slot];
        final row = b.rows['subNum']!;
        _textInBox('${s.playerIn}', [col[0], row[0], col[1], row[1]], 8.0);
        final c = b.scoreColons[0][s.slot];
        _scorePair(s.own, s.opp, c[0], c[1]);
      } else if (n == 1) {
        final c = b.scoreColons[1][s.slot];
        _scorePair(s.own, s.opp, c[0], c[1]);
      }
    }

    // Time-outs.
    var tn = 0;
    for (final t in sd.timeouts[team]!) {
      if (!keep(t.afterChange) || tn >= b.timeouts.length) continue;
      final tc = b.timeouts[tn];
      _scorePair(t.own, t.opp, tc.colonX, tc.cy);
      tn++;
    }

    // Service rounds: the team's score when each round ended, in the cell for
    // that position's 1st, 2nd, ... round. The team's last round of a finished
    // set is circled.
    final allRounds = sd.rounds[team]!;
    final lastOverall = allRounds.isEmpty ? null : allRounds.last;
    final perPos = <int, int>{};
    for (final r in allRounds) {
      if (!keep(r.afterChange)) continue;
      final idx = perPos[r.position] ?? 0;
      perPos[r.position] = idx + 1;
      final cells = b.rounds[r.position - 1];
      if (idx >= cells.length) continue;
      final cb = cells[idx];
      final cx = (cb[0] + cb[2]) / 2 + 0.3;
      _text('${r.endOwn}', cx, cb[3] - 2.1, 6.0, align: _Align.center);
      if (sd.complete && identical(r, lastOverall)) {
        _circle(cx, cb[3] - 2.1 - 2.2, 4.4, 0.6);
      }
    }

    // Points: slash each point, ring the last one, strike out unused numbers.
    final grid = b.grid;
    final maxN = b.maxPoint;
    final score = sd.score[team]!;
    final complete = sd.complete;
    if (segment == _Segment.all) {
      _markPoints(
        grid,
        score < maxN ? score : maxN,
        finalPoint: complete && score > 0 ? score : null,
        cancelFrom: complete ? score + 1 : null,
        cancelTo: maxN,
      );
    } else if (segment == _Segment.before) {
      final at = sd.change?.score[team] ?? score;
      final a = at < maxN ? at : maxN;
      _markPoints(
        grid,
        a,
        finalPoint: (complete && score <= maxN && score == a && score > 0)
            ? score
            : null,
        cancelFrom: sd.change != null ? a + 1 : null,
        cancelTo: maxN,
      );
    } else {
      final a = sd.change?.score[team] ?? 0;
      _markPoints(
        grid,
        score,
        lo: a,
        finalPoint: (complete && score > a) ? score : null,
        cancelFrom: complete ? score + 1 : null,
        cancelTo: maxN,
      );
    }

    // "Points at change" box in the third block of the deciding set.
    if (afterOnly && sd.change != null && b.changeBox != null) {
      final cb = b.changeBox!;
      _scorePair(sd.change!.score[team]!, sd.change!.score[team.other]!,
          cb.colonX, cb.cy);
    }
  }

  // -------------------------------------------------------------- whole page
  void draw(ScoresheetData data) {
    final t = data.teams;
    final hd = layout.header;

    // Page header: team letters and names.
    _text('A', hd.leftCircle.cx, hd.leftCircle.cy + 0.36 * 11, 11,
        isBold: true, align: _Align.center);
    _text('B', hd.rightCircle.cx, hd.rightCircle.cy + 0.36 * 11, 11,
        isBold: true, align: _Align.center);

    final nameA = _clean(t[data.teamA]!.name);
    final sizeA = _fit(nameA, hd.leftNameX[1] - hd.leftNameX[0], 9, 5, true);
    _text(nameA, hd.leftNameX[0], hd.nameBaselineY, sizeA, isBold: true);

    final nameB = _clean(t[data.teamB]!.name);
    final sizeB = _fit(nameB, hd.rightNameX[1] - hd.rightNameX[0], 9, 5, true);
    _text(nameB, hd.rightNameX[1], hd.nameBaselineY, sizeB,
        isBold: true, align: _Align.right);

    for (final sd in data.sets) {
      switch (sd.number) {
        case 1:
          {
            // Team A starts on the left.
            _drawBlock('S1A', data.teamA, sd, data, _Segment.all);
            _drawBlock('S1B', data.teamB, sd, data, _Segment.all);
            break;
          }
        case 2:
          {
            // The teams swap sides.
            _drawBlock('S2L', data.teamB, sd, data, _Segment.all);
            _drawBlock('S2R', data.teamA, sd, data, _Segment.all);
            break;
          }
        case 3:
          {
            // New coin toss: whichever team was chosen to start on the left.
            final left = sd.leftAtStart ?? data.teamA;
            final right = left.other;
            if (sd.change != null) {
              _drawBlock('S3L', left, sd, data, _Segment.before);
              _drawBlock('S3C', left, sd, data, _Segment.after);
            } else {
              _drawBlock('S3L', left, sd, data, _Segment.all);
            }
            _drawBlock('S3R', right, sd, data, _Segment.all);
            break;
          }
        default:
          break; // the 3-set sheet has no room for more
      }
    }

    _drawPlayers(data);
    _drawResults(data);
    _drawSignatures(data);
  }

  // ------------------------------------------------------------- signatures
  /// Draws one signature, scaled to fit its box and centred. The ink's own
  /// bounding box is used, so a small signature still fills the box.
  void _drawInk(List<List<List<double>>> strokes, List<double> box) {
    const aspect = MatchEngine.signaturePadAspect;
    const pad = 0.8;

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final stroke in strokes) {
      for (final p in stroke) {
        final x = p[0] * aspect;
        final y = p[1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (minX == double.infinity) return; // nothing drawn

    final bw = (maxX - minX) < 1e-6 ? 1e-6 : (maxX - minX);
    final bh = (maxY - minY) < 1e-6 ? 1e-6 : (maxY - minY);
    final availW = (box[2] - box[0]) - 2 * pad;
    final availH = (box[3] - box[1]) - 2 * pad;
    final sx = availW / bw;
    final sy = availH / bh;
    final scale = sx < sy ? sx : sy;
    final ox = box[0] + pad + (availW - bw * scale) / 2 - minX * scale;
    final oy = box[1] + pad + (availH - bh * scale) / 2 - minY * scale;

    g.setLineWidth(0.5);
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      g.moveTo(stroke.first[0] * aspect * scale + ox,
          _y(stroke.first[1] * scale + oy));
      for (var i = 1; i < stroke.length; i++) {
        g.lineTo(stroke[i][0] * aspect * scale + ox,
            _y(stroke[i][1] * scale + oy));
      }
      g.strokePath();
    }
  }

  void _drawSignatures(ScoresheetData data) {
    final boxes = layout.signatures;

    void put(String slotId, String boxKey) {
      final ink = data.signatures[slotId];
      final box = boxes[boxKey];
      if (ink == null || box == null) return;
      _drawInk(ink, box);
    }

    // Left-hand boxes belong to Team A, right-hand boxes to Team B.
    final a = data.teamA;
    final b = data.teamB;
    put(SignatureSlots.captain(a), 'captainLeft');
    put(SignatureSlots.coach(a), 'coachLeft');
    put(SignatureSlots.captain(b), 'captainRight');
    put(SignatureSlots.coach(b), 'coachRight');

    put(SignatureSlots.ref1, 'ref1');
    put(SignatureSlots.ref2, 'ref2');
    put(SignatureSlots.scorer, 'scorer');
    put(SignatureSlots.assistantScorer, 'assistantScorer');
    for (final id in SignatureSlots.lineJudges) {
      put(id, id);
    }
    put(SignatureSlots.approvalCaptain(a), 'approvalCaptainA');
    put(SignatureSlots.approvalCaptain(b), 'approvalCaptainB');
  }

  void _drawPlayers(ScoresheetData data) {
    final p = layout.players;
    _drawPlayerSide(data.teams[data.teamA]!, 'A', p.leftCircle, p.leftNameBox,
        p.leftNumX, p.leftNameX, p);
    _drawPlayerSide(data.teams[data.teamB]!, 'B', p.rightCircle, p.rightNameBox,
        p.rightNumX, p.rightNameX, p);
  }

  void _drawPlayerSide(
    SheetTeam sheet,
    String letter,
    SheetCircle? circle,
    List<double> nameBox,
    List<double> numX,
    List<double> nameX,
    PlayersLayout p,
  ) {
    if (circle != null) {
      _text(letter, circle.cx, circle.cy + 0.36 * 9.5, 9.5,
          isBold: true, align: _Align.center);
    }
    _textInBox(sheet.name, nameBox, 7.0, isBold: true, align: _Align.left);

    void row(Player pl, List<double> yy) {
      final fit = (yy[1] - yy[0]) * 0.78;
      final size = fit < 8.0 ? fit : 8.0;
      _textInBox('${pl.number}', [numX[0], yy[0], numX[1], yy[1]], size,
          isBold: true);
      _textInBox(pl.name, [nameX[0], yy[0], nameX[1], yy[1]], size,
          align: _Align.left, pad: 2.0);
    }

    final roster = sheet.roster;
    for (var i = 0; i < roster.length && i < p.rows.length; i++) {
      row(roster[i], p.rows[i]);
    }
    final liberos =
        roster.where((x) => x.position.toLowerCase() == 'libero').toList();
    for (var i = 0; i < liberos.length && i < p.liberoRows.length; i++) {
      row(liberos[i], p.liberoRows[i]);
    }
  }

  void _drawResults(ScoresheetData data) {
    final r = layout.results;
    final t = data.teams;
    _textInBox(t[data.teamA]!.name, r.teamANameBox, 6.5,
        isBold: true, align: _Align.left);
    _textInBox(t[data.teamB]!.name, r.teamBNameBox, 6.5,
        isBold: true, align: _Align.left);

    final totals = {
      Team.home: {'T': 0, 'S': 0, 'W': 0, 'P': 0},
      Team.away: {'T': 0, 'S': 0, 'W': 0, 'P': 0},
    };
    final colsFor = {data.teamA: r.teamACols, data.teamB: r.teamBCols};

    for (final sd in data.sets) {
      final i = sd.number - 1;
      if (i > 2) continue;
      final row = r.setRows[i];
      for (final team in Team.values) {
        final vals = <String, int?>{
          'T': sd.timeouts[team]!.length,
          'S': sd.subs[team]!.length,
          'W': sd.winner == team ? 1 : null,
          'P': sd.score[team],
        };
        vals.forEach((k, v) {
          if (v == null) return;
          totals[team]![k] = totals[team]![k]! + v;
          final c = colsFor[team]![k]!;
          _textInBox('$v', [c[0], row[0], c[1], row[1]], 7.0);
        });
      }
    }

    for (final team in Team.values) {
      totals[team]!.forEach((k, v) {
        final c = colsFor[team]![k]!;
        _textInBox('$v', [c[0], r.totalRow[0], c[1], r.totalRow[1]], 7.0,
            isBold: true);
      });
    }

    final winner = data.winner;
    if (data.matchComplete && winner != null) {
      final name = _clean(t[winner]!.name);
      final x0 = r.winnerNameX[0];
      final size = _fit(name, r.winnerNameX[1] - x0, 10, 5, true);
      _text(name, x0, r.winnerTextBaselineY, size, isBold: true);
      _text('${data.setsWon[winner.other]}', r.printedWinnerSets[2] + 3.0,
          r.winnerTextBaselineY, 10,
          isBold: true);
    }
  }
}
