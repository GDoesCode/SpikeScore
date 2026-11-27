import '../match_engine.dart';

/// One set of the Lite match summary.
class SetSummary {
  final int number;

  /// Score after every rally, oldest first, starting at 0-0.
  final List<(int, int)> progression;
  final Map<Team, int> timeOuts;
  final Map<Team, int> subs;

  /// When the set's first serve was chosen (or the set began) and its last
  /// rally. Null for events saved without a time.
  final DateTime? start;
  final DateTime? end;

  /// True once a team has won the set.
  final bool finished;

  const SetSummary({
    required this.number,
    required this.progression,
    required this.timeOuts,
    required this.subs,
    required this.start,
    required this.end,
    required this.finished,
  });

  int get homeScore => progression.last.$1;
  int get awayScore => progression.last.$2;

  Team? get winner => !finished
      ? null
      : (homeScore > awayScore ? Team.home : Team.away);

  Duration? get duration =>
      start == null || end == null || end!.isBefore(start!) ? null : end!.difference(start!);

  /// The biggest lead each team had during the set.
  int biggestLead(Team team) {
    var best = 0;
    for (final (h, a) in progression) {
      final lead = team == Team.home ? h - a : a - h;
      if (lead > best) best = lead;
    }
    return best;
  }
}

/// A plain summary of the match for SpikeScore Lite, in place of the official
/// scoresheet: set scores, how long each set took, time-outs, substitutions
/// and how the score went rally by rally.
class MatchSummary {
  final List<SetSummary> sets;
  final Map<Team, int> setsWon;
  final Team? winner;

  const MatchSummary(this.sets, this.setsWon, this.winner);

  DateTime? get start => sets.isEmpty ? null : sets.first.start;
  DateTime? get end => sets.isEmpty ? null : sets.last.end;

  Duration? get duration =>
      start == null || end == null || end!.isBefore(start!) ? null : end!.difference(start!);

  /// Builds the summary from the engine's event list. Sets that haven't
  /// started (no rally yet, no serve chosen) are left out.
  factory MatchSummary.of(MatchEngine engine) {
    final sets = <SetSummary>[];
    final setsWon = {Team.home: 0, Team.away: 0};

    var number = 1;
    var progression = <(int, int)>[(0, 0)];
    var timeOuts = {Team.home: 0, Team.away: 0};
    var subs = {Team.home: 0, Team.away: 0};
    DateTime? start;
    DateTime? end;
    var started = false;

    void close(bool finished) {
      if (!started) return;
      sets.add(SetSummary(
        number: number,
        progression: progression,
        timeOuts: timeOuts,
        subs: subs,
        start: start,
        end: end,
        finished: finished,
      ));
    }

    bool won((int, int) score) {
      final target = number == engine.maxSets
          ? engine.rules.decidingSetPoints
          : engine.rules.pointsPerSet;
      final (h, a) = score;
      return (h >= target || a >= target) &&
          (h - a).abs() >= (engine.rules.winByTwo ? 2 : 1);
    }

    for (final e in engine.events) {
      final team = e.team;
      switch (e.type) {
        case EventType.sides:
        case EventType.firstServe:
          if (!started) start = e.at;
          started = true;
        case EventType.point:
          if (team == null || won(progression.last)) break;
          final (h, a) = progression.last;
          progression = [...progression, team == Team.home ? (h + 1, a) : (h, a + 1)];
          end = e.at ?? end;
          started = true;
        case EventType.scoreAdjust:
          if (team == null || e.delta == null) break;
          final (h, a) = progression.last;
          int fix(int n) => (n + e.delta!).clamp(0, 999).toInt();
          progression = [...progression, team == Team.home ? (fix(h), a) : (h, fix(a))];
        case EventType.timeout:
          if (team != null) timeOuts = {...timeOuts, team: timeOuts[team]! + 1};
        case EventType.sub:
          if (team != null) subs = {...subs, team: subs[team]! + 1};
        case EventType.newSet:
          final done = won(progression.last);
          if (done) {
            final (h, a) = progression.last;
            final w = h > a ? Team.home : Team.away;
            setsWon[w] = setsWon[w]! + 1;
          }
          close(done);
          number++;
          progression = [(0, 0)];
          timeOuts = {Team.home: 0, Team.away: 0};
          subs = {Team.home: 0, Team.away: 0};
          // Sets after the first start when the previous one is closed off.
          start = e.at;
          end = null;
          started = true;
      }
    }
    final lastDone = won(progression.last);
    if (lastDone) {
      final (h, a) = progression.last;
      final w = h > a ? Team.home : Team.away;
      setsWon[w] = setsWon[w]! + 1;
    }
    close(lastDone);

    final needed = engine.requiredSetsToWin;
    final winner = setsWon[Team.home]! >= needed
        ? Team.home
        : setsWon[Team.away]! >= needed
            ? Team.away
            : null;
    return MatchSummary(sets, setsWon, winner);
  }

  /// The summary as plain text, for pasting into a message.
  String asText({String home = 'Home', String away = 'Away'}) {
    final b = StringBuffer('SpikeScore Lite match summary (not an official scoresheet)\n');
    b.writeln('$home ${setsWon[Team.home]} - ${setsWon[Team.away]} $away'
        '${winner == null ? ' (not finished)' : ''}');
    for (final s in sets) {
      final d = s.duration;
      b.writeln('Set ${s.number}: ${s.homeScore}-${s.awayScore}'
          '${d == null ? '' : ' (${formatDuration(d)})'}'
          '${s.finished ? '' : ' in progress'}');
    }
    final d = duration;
    if (d != null) b.writeln('Match time: ${formatDuration(d)}');
    return b.toString();
  }
}

/// "1 h 05 min", or "23 min" under an hour.
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}
