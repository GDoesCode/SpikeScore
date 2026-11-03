import 'dart:convert';

import 'models.dart';

/// Details of the match that go in the header of the scoresheet. Anything left
/// out of the data file stays blank on the sheet.
class MatchInfo {
  final String competition;
  final String matchType;
  final String matchNumber;
  final String venue;
  final String division;

  /// 'men', 'women', 'mixed' or '' (none ticked).
  final String category;
  final bool juniors;

  final int? day;
  final int? month;
  final int? year; // four digits
  final int? hour;
  final int? minute;

  const MatchInfo({
    this.competition = '',
    this.matchType = '',
    this.matchNumber = '',
    this.venue = '',
    this.division = '',
    this.category = '',
    this.juniors = false,
    this.day,
    this.month,
    this.year,
    this.hour,
    this.minute,
  });

  factory MatchInfo.fromJson(Map<String, dynamic> j) {
    String text(String key) => (j[key] ?? '').toString().trim();

    int? day, month, year, hour, minute;
    final date = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text('date'));
    if (date != null) {
      year = int.parse(date.group(1)!);
      month = int.parse(date.group(2)!);
      day = int.parse(date.group(3)!);
    }
    final time = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text('time'));
    if (time != null) {
      hour = int.parse(time.group(1)!);
      minute = int.parse(time.group(2)!);
    }

    final category = text('category').toLowerCase();
    return MatchInfo(
      competition: text('competition'),
      matchType: text('matchType'),
      matchNumber: text('matchNumber'),
      venue: text('venue'),
      division: text('division'),
      category: const ['men', 'women', 'mixed'].contains(category) ? category : '',
      juniors: j['juniors'] == true,
      day: day,
      month: month,
      year: year,
      hour: hour,
      minute: minute,
    );
  }
}

/// A coach, assistant coach, trainer or medical person for the TEAM OFFICIALS
/// rows. [role] is the short code the sheet uses: C, AC, T or M.
class Official {
  final String role;
  final String name;
  const Official(this.role, this.name);
}

class DemoTeam {
  final String id;
  final TeamSheet sheet;
  final List<Official> officials;
  const DemoTeam(this.id, this.sheet, this.officials);
}

/// The contents of assets/demo/demo_data.json: a library of teams, and which
/// two of them are playing, plus the match details for the sheet header.
class DemoData {
  final MatchInfo info;
  final DemoTeam home;
  final DemoTeam away;
  const DemoData(this.info, this.home, this.away);

  /// Throws a [FormatException] with a plain-English message if the file has a
  /// problem the app can't work around.
  static DemoData parse(String source) {
    final dynamic root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('the file is not valid JSON (${e.message})');
    }
    if (root is! Map<String, dynamic>) {
      throw const FormatException('the file must start with { and end with }');
    }

    final match = (root['match'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final rawTeams = root['teams'];
    if (rawTeams is! List) {
      throw const FormatException('"teams" must be a list');
    }
    final teams = [for (final t in rawTeams) _team(t as Map<String, dynamic>)];
    if (teams.length < 2) {
      throw const FormatException('"teams" needs at least two teams');
    }

    DemoTeam pick(Object? id, DemoTeam fallback) =>
        teams.firstWhere((t) => t.id == id, orElse: () => fallback);

    final home = pick(match['home'], teams[0]);
    var away = pick(match['away'], teams[1]);
    if (identical(home, away)) {
      away = teams.firstWhere((t) => !identical(t, home));
    }
    return DemoData(MatchInfo.fromJson(match), home, away);
  }

  static DemoTeam _team(Map<String, dynamic> j) {
    final id = (j['id'] ?? j['name'] ?? '').toString();
    final name = (j['name'] ?? id).toString();
    if (id.isEmpty) {
      throw const FormatException('every team needs an "id" and a "name"');
    }

    final players = <Player>[];
    final seen = <int>{};
    for (final raw in (j['players'] as List? ?? const [])) {
      final p = raw as Map<String, dynamic>;
      final number = p['number'];
      if (number is! num) {
        throw FormatException('$name: every player needs a "number"');
      }
      if (!seen.add(number.toInt())) {
        throw FormatException('$name: shirt number ${number.toInt()} is used twice');
      }
      players.add(Player(
        number: number.toInt(),
        name: (p['name'] ?? '').toString(),
        position: (p['position'] ?? 'Player').toString(),
      ));
    }
    if (players.length < 6) {
      throw FormatException('$name needs at least 6 players');
    }

    // The six starters in service order (I to VI). If the list is missing or
    // wrong, use the first six players who aren't liberos.
    var lineup = [
      for (final n in (j['startingLineup'] as List? ?? const [])) (n as num).toInt()
    ];
    final numbers = players.map((p) => p.number).toSet();
    final valid = lineup.length == 6 &&
        lineup.toSet().length == 6 &&
        lineup.every(numbers.contains);
    if (!valid) {
      lineup = players
          .where((p) => p.position.toLowerCase() != 'libero')
          .take(6)
          .map((p) => p.number)
          .toList();
    }
    if (lineup.length < 6) {
      throw FormatException('$name needs six players who are not liberos');
    }

    final officials = [
      for (final raw in (j['officials'] as List? ?? const []))
        Official(
          ((raw as Map<String, dynamic>)['role'] ?? '').toString(),
          (raw['name'] ?? '').toString(),
        ),
    ];

    return DemoTeam(
      id,
      TeamSheet(teamName: name, roster: players, startingLineup: lineup),
      officials,
    );
  }
}
