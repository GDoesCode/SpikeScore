import '../demo_data.dart';
import '../match_engine.dart';
import '../match_rules.dart';
import '../models.dart';

/// Everything the paper scoresheet needs, worked out from the engine's
/// recorded events. Anything the app doesn't know is simply absent, and the
/// renderer leaves that part of the sheet blank.

class SheetTeam {
  final String name;
  final List<Player> roster;

  /// The six starters in service order (I to VI).
  final List<int> starters;

  const SheetTeam(this.name, this.roster, this.starters);

  factory SheetTeam.fromSheet(TeamSheet sheet) => SheetTeam(
        sheet.teamName,
        List.unmodifiable(sheet.roster),
        List.unmodifiable(sheet.startingLineup),
      );
}

class SheetTimeout {
  final int own;
  final int opp;
  final bool afterChange;
  const SheetTimeout(this.own, this.opp, this.afterChange);
}

class SheetSub {
  /// Service-order slot 0 to 5 (column I to VI) the change happened in.
  final int slot;
  final int playerOut;
  final int playerIn;
  final int own;
  final int opp;
  final bool afterChange;
  const SheetSub(this.slot, this.playerOut, this.playerIn, this.own, this.opp,
      this.afterChange);
}

class SheetRound {
  /// Service-order position 1 to 6.
  final int position;
  final int endOwn;
  final bool afterChange;
  final List<int> servers;

  /// Which box of that position's column the score goes in, counting from 0
  /// (0 is "1st"). Normally the position's 1st, 2nd, 3rd round in order, but
  /// the team receiving first skips box 0 of position I (see
  /// [SheetSet.receivesFirst]). Filled in when the data is built.
  int cell = 0;

  SheetRound(this.position, this.endOwn, this.afterChange, this.servers);
}

/// The moment teams swap ends in the deciding set (first team to reach 8).
class SheetChange {
  final Map<Team, int> score;
  final int total;

  /// Who was in each service-order slot at that moment.
  final Map<Team, List<int>> lineup;
  const SheetChange(this.score, this.total, this.lineup);
}

class SheetSet {
  final int number;
  bool complete = false;
  Team? firstServe;

  /// The team on the left when the set started (null if never chosen).
  Team? leftAtStart;
  Team? winner;
  SheetChange? change;
  final Map<Team, int> score = {Team.home: 0, Team.away: 0};
  final Map<Team, List<SheetTimeout>> timeouts = {
    Team.home: [],
    Team.away: [],
  };
  final Map<Team, List<SheetSub>> subs = {Team.home: [], Team.away: []};
  final Map<Team, List<SheetRound>> rounds = {Team.home: [], Team.away: []};

  /// When the first rally of the set was scored, and when the set was won.
  /// Null if unknown (not played yet, or recorded by an older app version).
  DateTime? start;
  DateTime? end;

  /// Minutes the set lasted, or null until it is over.
  int? get durationMinutes =>
      (start == null || end == null) ? null : minutesBetween(start!, end!);

  SheetSet(this.number);

  /// True for the team that did not serve first in this set. On the paper
  /// sheet it crosses out box 1 of service order I: that player won't serve
  /// until the whole order has been through once, and their first real service
  /// is written in box 2.
  bool receivesFirst(Team team) => firstServe != null && firstServe != team;
}

/// Whole minutes between two clock times, counted the way the times are
/// written on the sheet (hours and minutes, seconds ignored), so a duration
/// always matches the start and end times printed next to it.
int minutesBetween(DateTime from, DateTime to) {
  DateTime toMinute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);
  final m = toMinute(to).difference(toMinute(from)).inMinutes;
  return m < 0 ? 0 : m;
}

class ScoresheetData {
  /// Team A on the paper sheet is the team that started set 1 on the left, so
  /// the sides chosen at the start of the match decide the letters. B is the
  /// other team.
  final Team teamA;
  Team get teamB => teamA.other;

  final Map<Team, SheetTeam> teams;
  final List<SheetSet> sets;
  final Map<Team, int> setsWon;
  final bool matchComplete;
  final Team? winner;

  /// Drawn signatures by slot id (see SignatureSlots). Empty if none taken.
  final Map<String, List<List<List<double>>>> signatures;

  /// Competition, venue, date and so on for the header. Blank if unknown.
  final MatchInfo info;

  /// Coaches and other officials per team.
  final Map<Team, List<Official>> officials;

  /// Free-text notes from the Notes screen, printed in the REMARKS box.
  final String notes;

  /// When the first rally of the match was scored. Null before that.
  DateTime? get matchStart => sets.isEmpty ? null : sets.first.start;

  /// When the last rally of the match was won. Null until the match is over.
  DateTime? get matchEnd => matchComplete ? sets.last.end : null;

  /// Minutes from the match start to the match end, or null until it's over.
  int? get matchDurationMinutes {
    final from = matchStart, to = matchEnd;
    return (from == null || to == null) ? null : minutesBetween(from, to);
  }

  /// The sum of the finished sets' durations, or null if none is known.
  int? get totalSetMinutes {
    final known = [
      for (final s in sets)
        if (s.durationMinutes != null) s.durationMinutes!
    ];
    return known.isEmpty ? null : known.reduce((a, b) => a + b);
  }

  const ScoresheetData({
    required this.teamA,
    required this.teams,
    required this.sets,
    required this.setsWon,
    required this.matchComplete,
    required this.winner,
    required this.signatures,
    required this.info,
    required this.officials,
    required this.notes,
  });

  /// The BVA sheet in the app is the 3-set one, so only the 3-set format fits.
  static bool isSupported(MatchEngine engine) =>
      engine.matchMode == MatchMode.localLeague3Set;

  static const int _decidingSet = 3;

  static bool _isComplete(int setNumber, int home, int away, MatchRules rules) {
    final deciding = setNumber == _decidingSet;
    final target = deciding ? rules.decidingSetPoints : rules.pointsPerSet;
    final lead = deciding && !rules.decidingSetWinByTwo ? 1 : 2;
    return (home >= target || away >= target) && (home - away).abs() >= lead;
  }

  factory ScoresheetData.fromEngine(MatchEngine engine) {
    final rules = engine.rules;
    final teams = {
      Team.home: SheetTeam.fromSheet(engine.homeTeamSheet),
      Team.away: SheetTeam.fromSheet(engine.awayTeamSheet),
    };

    final sets = <int, SheetSet>{};
    var setNo = 1;
    var cur = sets[1] = SheetSet(1);
    var score = {Team.home: 0, Team.away: 0};
    var slots = {
      for (final t in Team.values) t: List<int>.of(teams[t]!.starters),
    };

    for (final e in engine.events) {
      final team = e.team;
      switch (e.type) {
        case EventType.sides:
        case EventType.firstServe:
          {
            // Handled below from the engine's per-set records (sets other
            // than the first and the deciding set choose these automatically).
            break;
          }

        case EventType.point:
          {
            // The set's clock starts with its first rally.
            cur.start ??= e.at;
            score[team!] = score[team]! + 1;
            final home = score[Team.home]!;
            final away = score[Team.away]!;
            cur.score[Team.home] = home;
            cur.score[Team.away] = away;
            if (setNo == _decidingSet &&
                cur.change == null &&
                (home >= rules.changeEndsAt || away >= rules.changeEndsAt)) {
              cur.change = SheetChange(
                {Team.home: home, Team.away: away},
                home + away,
                {for (final t in Team.values) t: List<int>.of(slots[t]!)},
              );
            }
            if (_isComplete(setNo, home, away, rules)) {
              cur.complete = true;
              cur.winner = home > away ? Team.home : Team.away;
            }
            // The set's clock stops with the winning rally.
            if (cur.complete) cur.end ??= e.at;
            break;
          }

        case EventType.timeout:
          {
            final t = team!;
            cur.timeouts[t]!.add(SheetTimeout(
              score[t]!,
              score[t.other]!,
              cur.change != null,
            ));
            break;
          }

        case EventType.sub:
          {
            final t = team!;
            final slot = slots[t]!.indexOf(e.playerOff!);
            if (slot >= 0) {
              cur.subs[t]!.add(SheetSub(
                slot,
                e.playerOff!,
                e.playerOn!,
                score[t]!,
                score[t.other]!,
                cur.change != null,
              ));
              slots[t]![slot] = e.playerOn!;
            }
            break;
          }

        case EventType.scoreAdjust:
          {
            // A referee's correction: only the numbers change.
            final t = team!;
            final v = score[t]! + (e.delta ?? 0);
            score[t] = v < 0 ? 0 : v;
            final home = score[Team.home]!;
            final away = score[Team.away]!;
            cur.score[Team.home] = home;
            cur.score[Team.away] = away;
            final done = _isComplete(setNo, home, away, rules);
            cur.complete = done;
            cur.winner = done ? (home > away ? Team.home : Team.away) : null;
            cur.end = done ? (cur.end ?? e.at) : null;
            break;
          }

        case EventType.newSet:
          {
            setNo++;
            score = {Team.home: 0, Team.away: 0};
            slots = {
              for (final t in Team.values) t: List<int>.of(teams[t]!.starters),
            };
            cur = sets[setNo] = SheetSet(setNo);
            break;
          }
      }
    }

    for (final s in sets.values) {
      s.firstServe = engine.firstServers[s.number];
      s.leftAtStart = engine.startingLeft[s.number];
    }

    // Service rounds come from the engine. In the deciding set, a round that
    // ended at or after the change of sides belongs to the second half.
    for (final r in engine.serviceRounds) {
      final s = sets[r.setNumber];
      if (s == null) continue;
      final change = s.change;
      final closedAt = r.closedAtTotal;
      final after =
          change != null && (closedAt == null || closedAt >= change.total);
      s.rounds[r.team]!.add(SheetRound(r.position, r.endOwn, after, r.servers));
    }

    // Work out which box each round is written in. Each block of the sheet
    // counts its own rounds: the first half of a set and, in the deciding set,
    // the block after the change of ends.
    for (final s in sets.values) {
      for (final team in Team.values) {
        final rounds = s.rounds[team]!;
        for (final afterChange in const [false, true]) {
          final used = <int, int>{};
          if (!afterChange && s.receivesFirst(team)) {
            used[1] = 1; // box 1 of service order I is crossed out
          }
          for (final r in rounds) {
            if (r.afterChange != afterChange) continue;
            final index = used[r.position] ?? 0;
            used[r.position] = index + 1;
            r.cell = index;
          }
        }
      }
    }

    final setsWon = {Team.home: 0, Team.away: 0};
    for (final s in sets.values) {
      if (s.complete) setsWon[s.winner!] = setsWon[s.winner!]! + 1;
    }
    const needed = 2;
    final matchComplete = setsWon.values.any((v) => v >= needed);
    Team? winner;
    if (matchComplete) {
      winner = setsWon[Team.home]! > setsWon[Team.away]!
          ? Team.home
          : Team.away;
    }

    final ordered = sets.keys.toList()..sort();
    return ScoresheetData(
      teamA: engine.startingLeft[1] ?? Team.home,
      teams: teams,
      sets: [for (final n in ordered) sets[n]!],
      setsWon: setsWon,
      matchComplete: matchComplete,
      winner: winner,
      signatures: engine.signatures,
      info: engine.matchInfo,
      officials: engine.officials,
      notes: engine.notes,
    );
  }
}
