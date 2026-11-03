import 'dart:convert';

/// Positions of every fillable box on the BVA 3-set scoresheet, in PDF points
/// measured from the TOP-LEFT of the page (the renderer flips y when drawing).
///
/// The numbers come from assets/scoresheet/bva_3set_layout.json, which was
/// measured from the original BVA PDF.

List<double> _nums(dynamic v) =>
    (v as List).map((e) => (e as num).toDouble()).toList();

class SheetCircle {
  final double cx, cy, r;
  const SheetCircle(this.cx, this.cy, this.r);

  static SheetCircle? tryParse(dynamic v) {
    if (v == null) return null;
    final m = v as Map<String, dynamic>;
    return SheetCircle(
      (m['cx'] as num).toDouble(),
      (m['cy'] as num).toDouble(),
      (m['r'] as num).toDouble(),
    );
  }
}

class TimeoutCell {
  final double colonX, cy;
  const TimeoutCell(this.colonX, this.cy);
}

class ChangeBox {
  final double colonX, cy;
  const ChangeBox(this.colonX, this.cy);
}

/// One team block: six service-order columns with everything under them.
class BlockLayout {
  final int set;
  final String side; // 'L', 'R' or 'C' (the third block of set 3)
  final String? printedLetter; // 'A'/'B' if printed on the sheet, else null

  /// 6 columns, each [x0, x1].
  final List<List<double>> cols;

  /// 'starters', 'subNum', 'score1', 'score2' -> [y0, y1].
  final Map<String, List<double>> rows;

  /// rounds[column][cellIndex] -> [x0, y0, x1, y1]. cellIndex 0 is round 1.
  final List<List<List<double>>> rounds;

  /// scoreColons[row 0/1][column] -> [x, y] of the printed colon.
  final List<List<List<double>>> scoreColons;

  /// Printed point numbers: number -> [x0, y0, x1, y1].
  final Map<int, List<double>> grid;

  final List<TimeoutCell> timeouts;
  final List<double>? nameBox;
  final SheetCircle? letterCircle;
  final SheetCircle? srS;
  final SheetCircle? srR;
  final ChangeBox? changeBox;

  BlockLayout({
    required this.set,
    required this.side,
    required this.printedLetter,
    required this.cols,
    required this.rows,
    required this.rounds,
    required this.scoreColons,
    required this.grid,
    required this.timeouts,
    required this.nameBox,
    required this.letterCircle,
    required this.srS,
    required this.srR,
    required this.changeBox,
  });

  int get maxPoint => grid.keys.reduce((a, b) => a > b ? a : b);

  factory BlockLayout.fromJson(Map<String, dynamic> j) {
    final sr = j['sr'] as Map<String, dynamic>?;
    final change = j['changeBox'] as Map<String, dynamic>?;
    return BlockLayout(
      set: j['set'] as int,
      side: j['side'] as String,
      printedLetter: j['printedLetter'] as String?,
      cols: (j['cols'] as List).map(_nums).toList(),
      rows: (j['rows'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, _nums(v))),
      rounds: (j['rounds'] as List)
          .map((col) => (col as List).map(_nums).toList())
          .toList(),
      scoreColons: (j['scoreColons'] as List)
          .map((row) => (row as List).map(_nums).toList())
          .toList(),
      grid: (j['grid'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), _nums(v))),
      timeouts: (j['timeouts'] as List)
          .map((t) => TimeoutCell(
                ((t as Map<String, dynamic>)['colonX'] as num).toDouble(),
                (t['cy'] as num).toDouble(),
              ))
          .toList(),
      nameBox: j['nameBox'] == null ? null : _nums(j['nameBox']),
      letterCircle: SheetCircle.tryParse(j['letterCircle']),
      srS: sr == null ? null : SheetCircle.tryParse(sr['S']),
      srR: sr == null ? null : SheetCircle.tryParse(sr['R']),
      changeBox: change == null
          ? null
          : ChangeBox(
              (change['colonX'] as num).toDouble(),
              (change['cy'] as num).toDouble(),
            ),
    );
  }
}

class PlayersLayout {
  final List<List<double>> rows; // 13 player rows [y0, y1]
  final List<List<double>> liberoRows; // 2 rows
  final List<double> leftNumX, leftNameX, rightNumX, rightNameX;
  final SheetCircle? leftCircle, rightCircle;
  final List<double> leftNameBox, rightNameBox;

  PlayersLayout({
    required this.rows,
    required this.liberoRows,
    required this.leftNumX,
    required this.leftNameX,
    required this.rightNumX,
    required this.rightNameX,
    required this.leftCircle,
    required this.rightCircle,
    required this.leftNameBox,
    required this.rightNameBox,
  });

  factory PlayersLayout.fromJson(Map<String, dynamic> j) {
    final l = j['left'] as Map<String, dynamic>;
    final r = j['right'] as Map<String, dynamic>;
    return PlayersLayout(
      rows: (j['rows'] as List).map(_nums).toList(),
      liberoRows: (j['liberoRows'] as List).map(_nums).toList(),
      leftNumX: _nums(l['numX']),
      leftNameX: _nums(l['nameX']),
      rightNumX: _nums(r['numX']),
      rightNameX: _nums(r['nameX']),
      leftCircle: SheetCircle.tryParse(j['leftCircle']),
      rightCircle: SheetCircle.tryParse(j['rightCircle']),
      leftNameBox: _nums(j['leftNameBox']),
      rightNameBox: _nums(j['rightNameBox']),
    );
  }
}

class ResultsLayout {
  final List<double> teamANameBox, teamBNameBox;
  final Map<String, List<double>> teamACols, teamBCols; // 'T','S','W','P'
  final List<List<double>> setRows; // 3 rows [y0, y1]
  final List<double> totalRow;
  final List<double> winnerNameX; // [x0, x1]
  final double winnerTextBaselineY;
  final List<double> printedWinnerSets; // bbox of the printed "2:"

  ResultsLayout({
    required this.teamANameBox,
    required this.teamBNameBox,
    required this.teamACols,
    required this.teamBCols,
    required this.setRows,
    required this.totalRow,
    required this.winnerNameX,
    required this.winnerTextBaselineY,
    required this.printedWinnerSets,
  });

  factory ResultsLayout.fromJson(Map<String, dynamic> j) {
    Map<String, List<double>> cols(dynamic v) => (v as Map<String, dynamic>)
        .map((k, e) => MapEntry(k, _nums(e)));
    return ResultsLayout(
      teamANameBox: _nums(j['teamANameBox']),
      teamBNameBox: _nums(j['teamBNameBox']),
      teamACols: cols(j['teamACols']),
      teamBCols: cols(j['teamBCols']),
      setRows: (j['setRows'] as List).map(_nums).toList(),
      totalRow: _nums(j['totalRow']),
      winnerNameX: _nums(j['winnerNameX']),
      winnerTextBaselineY: (j['winnerTextBaselineY'] as num).toDouble(),
      printedWinnerSets: _nums(j['printedWinnerSets']),
    );
  }
}

class OfficialsLayout {
  final List<List<double>> rows; // 4 rows [y0, y1]
  final List<double> leftRoleX, leftNameX, rightRoleX, rightNameX;

  OfficialsLayout({
    required this.rows,
    required this.leftRoleX,
    required this.leftNameX,
    required this.rightRoleX,
    required this.rightNameX,
  });

  factory OfficialsLayout.fromJson(Map<String, dynamic> j) {
    final l = j['left'] as Map<String, dynamic>;
    final r = j['right'] as Map<String, dynamic>;
    return OfficialsLayout(
      rows: (j['rows'] as List).map(_nums).toList(),
      leftRoleX: _nums(l['roleX']),
      leftNameX: _nums(l['nameX']),
      rightRoleX: _nums(r['roleX']),
      rightNameX: _nums(r['nameX']),
    );
  }
}

class HeaderLayout {
  final SheetCircle leftCircle, rightCircle;
  final List<double> leftNameX, rightNameX;
  final double nameBaselineY;

  HeaderLayout({
    required this.leftCircle,
    required this.rightCircle,
    required this.leftNameX,
    required this.rightNameX,
    required this.nameBaselineY,
  });

  factory HeaderLayout.fromJson(Map<String, dynamic> j) => HeaderLayout(
        leftCircle: SheetCircle.tryParse(j['leftCircle'])!,
        rightCircle: SheetCircle.tryParse(j['rightCircle'])!,
        leftNameX: _nums(j['leftNameX']),
        rightNameX: _nums(j['rightNameX']),
        nameBaselineY: (j['nameBaselineY'] as num).toDouble(),
      );
}

class SheetLayout {
  final double pageWidth, pageHeight;
  final Map<String, BlockLayout> blocks;
  final HeaderLayout header;
  final PlayersLayout players;
  final ResultsLayout results;

  /// Signature boxes by key: ref1, ref2, scorer, assistantScorer,
  /// lineJudge1..4, approvalCaptainA/B, captainLeft/Right, coachLeft/Right.
  final Map<String, List<double>> signatures;

  /// Match detail boxes by key: competition, matchType, matchNumber, venue,
  /// day, month, year, time, division, and the ticks juniors, men, women, mixed.
  final Map<String, List<double>> matchInfo;

  final OfficialsLayout officials;

  SheetLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.blocks,
    required this.header,
    required this.players,
    required this.results,
    required this.signatures,
    required this.matchInfo,
    required this.officials,
  });

  BlockLayout block(String name) => blocks[name]!;

  factory SheetLayout.fromJsonString(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final page = j['page'] as Map<String, dynamic>;
    return SheetLayout(
      pageWidth: (page['w'] as num).toDouble(),
      pageHeight: (page['h'] as num).toDouble(),
      blocks: (j['blocks'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, BlockLayout.fromJson(v as Map<String, dynamic>)),
      ),
      header: HeaderLayout.fromJson(j['header'] as Map<String, dynamic>),
      players: PlayersLayout.fromJson(j['players'] as Map<String, dynamic>),
      results: ResultsLayout.fromJson(j['results'] as Map<String, dynamic>),
      signatures: (j['signatures'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, _nums(v))),
      matchInfo: (j['matchInfo'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, _nums(v))),
      officials: OfficialsLayout.fromJson(j['officials'] as Map<String, dynamic>),
    );
  }
}
