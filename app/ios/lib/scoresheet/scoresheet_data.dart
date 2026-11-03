import '../match_engine.dart';
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
  const SheetRound(this.position, this.endOwn, this.afterChange, this.servers);
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

  SheetSet(this.number);
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

  const ScoresheetData({
    required this.teamA,
    required this.teams,
    required this.sets,
    required this.setsWon,
    required this.matchComplete,
    required this.winner,
    required this.signatures,
  });

  /// The BVA sheet in the app is the 3-set one, so only the 3-set format fits.
  static bool isSupported(MatchEngine engine) =>
      engine.matchMode == MatchMode.localLeague3Set;

  static const int _decidingSet = 3;

  static bool _isComplete(int setNumber, int home, int away) {
    final target = setNumber == _decidingSet ? 15 : 25;
    return (home >= target || away >= target) && (home - away).abs() >= 2;
  }

  factory ScoresheetData.fromEngine(MatchEngine engine) {
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
            score[team!] = score[team]! + 1;
            final home = score[Team.home]!;
            final away = score[Team.away]!;
            cur.score[Team.home] = home;
            cur.score[Team.away] = away;
            if (setNo == _decidingSet &&
                cur.change == null &&
                (home >= MatchEngine.changeSidesAt ||
                    away >= MatchEngine.changeSidesAt)) {
              cur.change = SheetChange(
                {Team.home: home, Team.away: away},
                home + away,
                {for (final t in Team.values) t: List<int>.of(slots[t]!)},
              );
            }
            if (_isComplete(setNo, home, away)) {
              cur.complete = true;
              cur.winner = home > away ? Team.home : Team.away;
            }
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
    );
  }
}
