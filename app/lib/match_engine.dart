import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'models.dart';

enum MatchMode { localLeague3Set, nationalLeague5Set }

enum Team {
  home,
  away;

  Team get other => this == Team.home ? Team.away : Team.home;
  String get label => this == Team.home ? 'Home' : 'Away';
}

enum EventType { sides, firstServe, point, timeout, sub, newSet }

/// One thing that happened in the match. The event list is the single source
/// of truth: everything else (score, sets, subs, lineups, who is serving) is
/// derived from it.
class MatchEvent {
  final EventType type;
  final Team? team; // null for newSet
  final int? playerOff;
  final int? playerOn;

  const MatchEvent(this.type, {this.team, this.playerOff, this.playerOn});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (team != null) 'team': team!.name,
        if (playerOff != null) 'off': playerOff,
        if (playerOn != null) 'on': playerOn,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        EventType.values.byName(json['type'] as String),
        team: json['team'] == null
            ? null
            : Team.values.byName(json['team'] as String),
        playerOff: json['off'] as int?,
        playerOn: json['on'] as int?,
      );
}

/// One service round (a team's run of serving), as written on the scoresheet.
///
/// A round starts when a team gains the serve and ends when the opponent wins
/// a rally (or the set ends). [startOwn] is the team's score when it gained
/// the serve, including the point that gave it the serve. [endOwn] is its
/// score when the round ended, so [pointsWon] counts only points won while
/// serving. The opponent can't score during a round, so [opponentScore] is
/// constant for its whole length.
class ServiceRound {
  static const romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI'];

  final int setNumber;
  final Team team;

  /// Service-order slot 1 to 6 (I to VI): whose turn it is, counting from the
  /// first server of the set (I). The receiving team's first round is II.
  final int position;

  /// Jersey numbers who served in this round, in order. Normally one; more
  /// if the server was substituted mid-round.
  final List<int> servers;

  final int startOwn;
  final int endOwn;
  final int opponentScore;

  /// True while the round is in progress.
  final bool isOpen;

  /// Total points scored by both teams in the set at the moment this round
  /// ended (before the side-out point, if that is what ended it). Null while
  /// the round is open. The scoresheet uses it to tell which rounds ended
  /// before or after the change of sides in a deciding set.
  final int? closedAtTotal;

  const ServiceRound({
    required this.setNumber,
    required this.team,
    required this.position,
    required this.servers,
    required this.startOwn,
    required this.endOwn,
    required this.opponentScore,
    required this.isOpen,
    this.closedAtTotal,
  });

  int get pointsWon => endOwn - startOwn;
  String get positionLabel => romanNumerals[position - 1];
}

/// Mutable version used while replaying events.
class _Round {
  final int setNumber;
  final Team team;
  final int position;
  final List<int> servers;
  final int startOwn;
  final int opponentScore;
  int endOwn;
  bool open = true;
  int? closeTotal;

  void close(int totalPoints) {
    open = false;
    closeTotal = totalPoints;
  }

  _Round({
    required this.setNumber,
    required this.team,
    required this.position,
    required int server,
    required this.startOwn,
    required this.opponentScore,
  })  : servers = [server],
        endOwn = startOwn;

  ServiceRound toPublic() => ServiceRound(
        setNumber: setNumber,
        team: team,
        position: position,
        servers: List.unmodifiable(servers),
        startOwn: startOwn,
        endOwn: endOwn,
        opponentScore: opponentScore,
        isOpen: open,
        closedAtTotal: closeTotal,
      );
}

/// One team's numbers for the current set, computed by replaying events.
class _TeamState {
  int score = 0;
  int setsWon = 0;
  int timeOuts = 0;
  int subCount = 0;

  /// How many times this team has rotated this set. Decides whose turn it is
  /// in the service order (see [serviceSlot]).
  int rotations = 0;

  /// Jersey numbers in court-position order: index 0 is position I (the
  /// server), then II, III, IV, V, VI.
  List<int> onCourt;

  /// player -> the player they swapped with (stored in both directions).
  final Map<int, int> subPairs = {};

  /// player -> how many swaps that starter/sub pair has made (shared by both).
  final Map<int, int> pairSubCounts = {};

  _TeamState(List<int> lineup) : onCourt = List.of(lineup);

  void startSet(List<int> lineup) {
    score = 0;
    timeOuts = 0;
    subCount = 0;
    subPairs.clear();
    pairSubCounts.clear();
    rotations = 0;
    onCourt = List.of(lineup);
  }

  /// Clockwise rotation: position II moves to I, I moves to VI.
  void rotate() {
    onCourt.add(onCourt.removeAt(0));
    rotations++;
  }

  /// 0 to 5: which starter's turn it is in the service order. After k
  /// rotations the server is the starter who began in position k + 1.
  int get serviceSlot => rotations % 6;
}

class _Derived {
  int currentSet = 1;

  /// null until the first serve of the set has been chosen.
  Team? servingTeam;

  /// The team on the left of the scoreboard right now. Defaults to home until
  /// the scorer chooses.
  Team leftTeam = Team.home;

  /// False at the start of the first set and the deciding set (the coin
  /// tosses) until the scorer chooses which team is on the left.
  bool sidesChosen = false;

  /// Deciding set only: true once the teams have changed ends at 8 points.
  bool changeDone = false;

  /// Set number -> the team that was on the left when the set started.
  final Map<int, Team> startLeft = {};

  /// Set number -> the team that served first in that set.
  final Map<int, Team> firstServers = {};

  final Map<Team, _TeamState> teams;
  final List<String> setHistory = [];

  /// Every service round of the match, in order, across all sets.
  final List<_Round> rounds = [];

  /// The round in progress, or null between rounds (e.g. set over).
  _Round? openRound;

  _Derived(this.teams);
}

class MatchEngine extends ChangeNotifier {
  static const _storageKey = 'spikescore_match_v4';

  /// In the deciding set the teams change ends when a team reaches this score.
  static const int changeSidesAt = 8;

  SharedPreferences? _prefs;
  MatchMode _matchMode = MatchMode.localLeague3Set;
  final List<MatchEvent> _events = [];
  late _Derived _s;

  /// Drawn signatures by slot id (see SignatureSlots). Each is a list of
  /// strokes; each stroke a list of [x, y] points where x and y run 0 to 1
  /// across a pad whose width is [signaturePadAspect] times its height.
  final Map<String, List<List<List<double>>>> _signatures = {};

  /// Width / height of the signature pad. Strokes are stored relative to it.
  static const double signaturePadAspect = 4.0;

  String _notes = '';

  late TeamSheet homeTeamSheet;
  late TeamSheet awayTeamSheet;

  /// Where the editable teams / match details file lives in the app.
  static const String demoDataAsset = 'assets/demo/demo_data.json';

  /// Competition, venue, date and so on for the sheet header (from the demo
  /// data file; blank if there isn't one).
  MatchInfo matchInfo = const MatchInfo();

  /// Coaches and other team officials for the sheet (from the demo data file).
  Map<Team, List<Official>> officials = {Team.home: [], Team.away: []};

  /// Set when the demo data file exists but couldn't be used. The screen shows
  /// it so a typo in the file isn't silently ignored.
  String? demoDataError;

  /// Pass [prefs] to load synchronously (tests, or if you await
  /// SharedPreferences.getInstance() in main). Without it the engine loads
  /// in the background and is usable immediately. [homeTeam] and [awayTeam]
  /// replace the built-in teams (used by tests).
  MatchEngine({
    SharedPreferences? prefs,
    TeamSheet? homeTeam,
    TeamSheet? awayTeam,
  }) {
    _prefs = prefs;
    _initDefaultTeams();
    if (homeTeam != null) homeTeamSheet = homeTeam;
    if (awayTeam != null) awayTeamSheet = awayTeam;
    _s = _replay();
    if (prefs != null) {
      _restore(prefs);
    } else {
      _loadAsync();
    }
  }

  // ---------------------------------------------------------------------------
  // Setup & persistence
  // ---------------------------------------------------------------------------

  void _initDefaultTeams() {
    // The order of startingLineup is the court order: position I (server)
    // first, then II, III, IV, V, VI.
    homeTeamSheet = TeamSheet(
      teamName: "Home Team",
      roster: [
        Player(number: 1, name: "A. Smith", position: "Setter"),
        Player(number: 3, name: "B. Jones", position: "Outside Hitter"),
        Player(number: 5, name: "C. Davies", position: "Middle Blocker"),
        Player(number: 7, name: "D. Evans", position: "Opposite"),
        Player(number: 9, name: "E. Taylor", position: "Outside Hitter"),
        Player(number: 11, name: "F. Thomas", position: "Middle Blocker"),
        Player(number: 13, name: "G. Roberts", position: "Setter"),
        Player(number: 15, name: "H. Walker", position: "Outside Hitter"),
      ],
      startingLineup: [1, 3, 5, 7, 9, 11],
    );

    awayTeamSheet = TeamSheet(
      teamName: "Away Team",
      roster: [
        Player(number: 2, name: "J. Wilson", position: "Setter"),
        Player(number: 4, name: "K. Wright", position: "Outside Hitter"),
        Player(number: 6, name: "L. Thompson", position: "Middle Blocker"),
        Player(number: 8, name: "M. White", position: "Opposite"),
        Player(number: 10, name: "N. Hughes", position: "Outside Hitter"),
        Player(number: 12, name: "O. Edwards", position: "Middle Blocker"),
        Player(number: 14, name: "P. Green", position: "Setter"),
        Player(number: 16, name: "Q. Hall", position: "Outside Hitter"),
      ],
      startingLineup: [2, 4, 6, 8, 10, 12],
    );
  }

  TeamSheet sheetOf(Team team) =>
      team == Team.home ? homeTeamSheet : awayTeamSheet;

  /// Replace the team sheets. Only allowed before the match starts.
  /// (Team sheets are not saved yet: after a restart the defaults are used.)
  void setTeams(TeamSheet home, TeamSheet away) {
    if (matchStarted) return;
    homeTeamSheet = home;
    awayTeamSheet = away;
    _s = _replay();
    notifyListeners();
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    // The teams must be in place before the saved match is replayed on them.
    await _loadDemoData();
    // If the scorer already tapped before loading finished, keep what they
    // did rather than overwriting it with older saved data.
    if (_events.isEmpty) {
      _restore(prefs);
    }
    notifyListeners();
  }

  /// Reads assets/demo/demo_data.json: teams, players, officials and the
  /// match details. No file means the built-in teams are used.
  Future<void> _loadDemoData() async {
    final String source;
    try {
      source = await rootBundle.loadString(demoDataAsset);
    } on FlutterError {
      debugPrint('SpikeScore: no $demoDataAsset, using the built-in teams');
      return;
    }

    try {
      final data = DemoData.parse(source);
      if (_events.isNotEmpty) return; // never swap teams in the middle of a match
      homeTeamSheet = data.home.sheet;
      awayTeamSheet = data.away.sheet;
      matchInfo = data.info;
      officials = {Team.home: data.home.officials, Team.away: data.away.officials};
      _s = _replay();
      demoDataError = null;
    } catch (e) {
      demoDataError = '$e';
      debugPrint('SpikeScore: could not use $demoDataAsset: $e');
    }
  }

  /// A fingerprint of the two teams. A saved match only makes sense on the
  /// teams it was played with, so it is thrown away if this changes.
  String _teamsKey() {
    Map<String, dynamic> one(TeamSheet t) => {
          'n': t.teamName,
          'l': t.startingLineup,
          'r': [for (final p in t.roster) [p.number, p.name, p.position]],
        };
    return jsonEncode({'h': one(homeTeamSheet), 'a': one(awayTeamSheet)});
  }

  void _restore(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;

    try {
      final saved = (jsonDecode(raw) as Map<String, dynamic>)['teams'];
      if (saved is String && saved != _teamsKey()) {
        debugPrint('SpikeScore: the teams changed, so the saved match was dropped.');
        return;
      }
    } catch (_) {
      // Unreadable data is handled just below.
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _matchMode = MatchMode.values.byName(data['mode'] as String);
      final events = (data['events'] as List)
          .map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      _events
        ..clear()
        ..addAll(events);
      _s = _replay();
    } catch (e) {
      debugPrint('SpikeScore: could not restore saved match: $e');
      _events.clear();
      _s = _replay();
    }

    _signatures.clear();
    _notes = '';
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedNotes = data['notes'];
      if (savedNotes is String) _notes = savedNotes;
      final saved = data['signatures'];
      if (saved is Map<String, dynamic>) {
        saved.forEach((id, strokes) {
          _signatures[id] = (strokes as List)
              .map((stroke) => (stroke as List)
                  .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
                  .toList())
              .toList();
        });
      }
    } catch (e) {
      debugPrint('SpikeScore: could not restore signatures: $e');
      _signatures.clear();
    }
  }

  Future<void> _save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'mode': _matchMode.name,
        'teams': _teamsKey(),
        'events': _events.map((e) => e.toJson()).toList(),
        'signatures': _signatures,
        'notes': _notes,
      }),
    );
  }

  /// Adds an event, updates the screen immediately, then saves in the
  /// background. State is already updated by the time the returned future
  /// completes its first step, so callers don't need to await it to read the
  /// new score.
  Future<void> _record(MatchEvent event) async {
    final closedBefore = _closedRoundCount();
    _events.add(event);
    _s = _replay();
    _logClosedRounds(closedBefore);
    notifyListeners();
    await _save();
  }

  // Rounds always close in order, so the closed ones are a prefix of the list.
  int _closedRoundCount() => _s.rounds.where((r) => !r.open).length;

  /// Debug only: prints one line for every service round that finished since
  /// [alreadyLogged] rounds were closed, laid out like the scoresheet row:
  /// set, team, service-order position (I to VI), the number of the starter
  /// in that position, then the team's score when the round ended, e.g.
  /// "[service] Set 1 Home I #1: 3". If someone else served the round (a
  /// substitute), they are added: "[service] Set 1 Home I #1 (served: #13): 3".
  /// Only runs for newly recorded events, never during replay, undo or restore.
  void _logClosedRounds(int alreadyLogged) {
    if (!kDebugMode) return;
    final closed = _s.rounds.where((r) => !r.open).toList();
    for (var i = alreadyLogged; i < closed.length; i++) {
      final r = closed[i];
      final starter = sheetOf(r.team).startingLineup[r.position - 1];
      final position = ServiceRound.romanNumerals[r.position - 1];
      final servers = r.servers.map((n) => '#$n').join(', ');
      final servedBy =
          (r.servers.length == 1 && r.servers.first == starter) ? '' : ' (served: $servers)';
      debugPrint(
        '[service] Set ${r.setNumber} ${r.team.label} $position #$starter$servedBy: ${r.endOwn}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Replay: events -> state
  // ---------------------------------------------------------------------------

  _Derived _replay() {
    final s = _Derived({
      Team.home: _TeamState(homeTeamSheet.startingLineup),
      Team.away: _TeamState(awayTeamSheet.startingLineup),
    });

    for (final e in _events) {
      final team = e.team;

      switch (e.type) {
        case EventType.sides:
          {
            if (team == null) break;
            s.leftTeam = team;
            s.sidesChosen = true;
            s.startLeft[s.currentSet] = team;
            break;
          }

        case EventType.firstServe:
          {
            s.servingTeam = team;
            if (team != null) {
              s.firstServers[s.currentSet] = team;
              _openRound(s, team);
            }
            break;
          }

        case EventType.point:
          {
            // Defensive: ignore points before the serve is chosen or after
            // the set has ended.
            if (team == null || s.servingTeam == null || _isComplete(s)) break;
            final t = s.teams[team]!;
            final totalBefore =
                s.teams[Team.home]!.score + s.teams[Team.away]!.score;
            t.score++;
            if (team == s.servingTeam) {
              // The serving team keeps serving; its current round grows.
              s.openRound?.endOwn = t.score;
            } else {
              // Side-out: the receiving team wins the rally, gains the serve
              // and rotates. The previous round ended just before this point.
              s.openRound?.close(totalBefore);
              s.servingTeam = team;
              t.rotate();
              _openRound(s, team);
            }
            if (s.currentSet == _maxSets &&
                !s.changeDone &&
                (s.teams[Team.home]!.score >= changeSidesAt ||
                    s.teams[Team.away]!.score >= changeSidesAt)) {
              // Deciding set: the teams change ends when a team reaches 8.
              s.changeDone = true;
              s.leftTeam = s.leftTeam.other;
            }
            if (_isComplete(s)) {
              // The set is over: the last round ends at the final score.
              s.openRound?.close(totalBefore + 1);
              s.openRound = null;
            }
            break;
          }

        case EventType.timeout:
          {
            if (team == null) break;
            s.teams[team]!.timeOuts++;
            break;
          }

        case EventType.sub:
          {
            if (team == null) break;
            final t = s.teams[team]!;
            final off = e.playerOff!;
            final on = e.playerOn!;

            // If the server is replaced mid-round, the substitute serves on.
            final replacesServer = s.servingTeam == team &&
                t.onCourt.isNotEmpty &&
                t.onCourt[0] == off;

            // The replacement takes the court position of the player leaving.
            final index = t.onCourt.indexOf(off);
            if (index != -1) t.onCourt[index] = on;
            if (replacesServer) s.openRound?.servers.add(on);

            t.subPairs[off] = on;
            t.subPairs[on] = off;

            final swaps = (t.pairSubCounts[off] ?? 0) + 1;
            t.pairSubCounts[off] = swaps;
            t.pairSubCounts[on] = swaps;

            t.subCount++;
            break;
          }

        case EventType.newSet:
          {
            final home = s.teams[Team.home]!;
            final away = s.teams[Team.away]!;

            if (_isComplete(s)) {
              if (home.score > away.score) {
                home.setsWon++;
              } else {
                away.setsWon++;
              }
            }
            s.setHistory.add(
              "Set ${s.currentSet}: Home ${home.score} - ${away.score} Away",
            );

            s.currentSet++;
            home.startSet(homeTeamSheet.startingLineup);
            away.startSet(awayTeamSheet.startingLineup);
            s.openRound = null;
            s.changeDone = false;
            final prev = s.currentSet - 1;
            if (s.currentSet == _maxSets) {
              // Deciding set: a new coin toss, so sides and first serve are
              // chosen again.
              s.servingTeam = null;
              s.sidesChosen = false;
              s.leftTeam = s.startLeft[prev] ?? Team.home;
            } else {
              // Any other set: the teams swap sides and the team that did not
              // serve first last set serves first.
              final left = (s.startLeft[prev] ?? Team.home).other;
              final first = (s.firstServers[prev] ?? Team.home).other;
              s.startLeft[s.currentSet] = left;
              s.leftTeam = left;
              s.sidesChosen = true;
              s.firstServers[s.currentSet] = first;
              s.servingTeam = first;
              _openRound(s, first);
            }
            break;
          }
      }
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  int get _maxSets => _matchMode == MatchMode.localLeague3Set ? 3 : 5;

  int _targetFor(int setNumber) => setNumber == _maxSets ? 15 : 25;

  bool _isComplete(_Derived s) {
    final home = s.teams[Team.home]!.score;
    final away = s.teams[Team.away]!.score;
    final target = _targetFor(s.currentSet);
    return (home >= target || away >= target) && (home - away).abs() >= 2;
  }

  /// Starts a new service round for [team], who is about to serve.
  void _openRound(_Derived s, Team team) {
    final t = s.teams[team]!;
    final o = s.teams[team.other]!;
    final round = _Round(
      setNumber: s.currentSet,
      team: team,
      position: t.serviceSlot + 1,
      server: t.onCourt[0],
      startOwn: t.score,
      opponentScore: o.score,
    );
    s.rounds.add(round);
    s.openRound = round;
  }

  MatchMode get matchMode => _matchMode;

  /// True once anything has been recorded; the format is locked from then on.
  bool get matchStarted => _events.isNotEmpty;

  /// Changes the match format. Ignored once the match has started, because it
  /// would change set targets and who has won.
  Future<void> setMatchMode(MatchMode mode) async {
    if (matchStarted) return;
    _matchMode = mode;
    _s = _replay();
    notifyListeners();
    await _save();
  }

  bool get isDecidingSet => _s.currentSet == _maxSets;
  int get targetPoints => _targetFor(_s.currentSet);
  bool get isSetComplete => _isComplete(_s);

  Team? get winningTeam {
    if (!isSetComplete) return null;
    return scoreOf(Team.home) > scoreOf(Team.away) ? Team.home : Team.away;
  }

  /// Set wins needed to win the match (2 for 3-set, 3 for 5-set).
  int get requiredSetsToWin => _matchMode == MatchMode.localLeague3Set ? 2 : 3;

  bool get isMatchComplete {
    final home = setsWonOf(Team.home) + (winningTeam == Team.home ? 1 : 0);
    final away = setsWonOf(Team.away) + (winningTeam == Team.away ? 1 : 0);
    return home >= requiredSetsToWin || away >= requiredSetsToWin;
  }

  // ---------------------------------------------------------------------------
  // Read-only state for the UI
  // ---------------------------------------------------------------------------

  _TeamState _ts(Team team) => _s.teams[team]!;

  int get currentSet => _s.currentSet;

  int scoreOf(Team team) => _ts(team).score;
  int setsWonOf(Team team) => _ts(team).setsWon;
  int timeOutsOf(Team team) => _ts(team).timeOuts;
  int subCountOf(Team team) => _ts(team).subCount;

  int get homeScore => scoreOf(Team.home);
  int get awayScore => scoreOf(Team.away);
  int get homeSetsWon => setsWonOf(Team.home);
  int get awaySetsWon => setsWonOf(Team.away);
  int get homeTimeOuts => timeOutsOf(Team.home);
  int get awayTimeOuts => timeOutsOf(Team.away);
  int get homeSubCount => subCountOf(Team.home);
  int get awaySubCount => subCountOf(Team.away);

  List<String> get setHistory => List.unmodifiable(_s.setHistory);

  bool get canUndo => _events.isNotEmpty;

  /// Everything that has happened so far, in order (read-only).
  List<MatchEvent> get events => List.unmodifiable(_events);

  /// Free-text notes from the Notes screen (printed in the REMARKS box).
  String get notes => _notes;

  /// Saves the notes. Nothing on screen depends on them, so listeners are not
  /// told; that keeps this safe to call while a screen is closing.
  Future<void> setNotes(String text) async {
    _notes = text;
    await _save();
  }

  /// Drawn signatures collected on the sign-off screen, by slot id.
  Map<String, List<List<List<double>>>> get signatures =>
      Map.unmodifiable(_signatures);

  /// Saves a drawn signature for [slotId]. Signatures are not match events,
  /// so undo never touches them.
  Future<void> setSignature(
    String slotId,
    List<List<List<double>>> strokes,
  ) async {
    if (strokes.isEmpty) return;
    _signatures[slotId] = strokes;
    notifyListeners();
    await _save();
  }

  Future<void> clearSignature(String slotId) async {
    if (_signatures.remove(slotId) == null) return;
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Serving & rotation
  // ---------------------------------------------------------------------------

  Team? get servingTeam => _s.servingTeam;

  /// True until the scorer picks who serves first. This only happens at the
  /// first set and the deciding set (the coin tosses): in every other set the
  /// team that didn't serve first last set serves first, automatically.
  /// Points can't be scored until then.
  bool get needsFirstServe => _s.servingTeam == null;

  /// True at the first set and the deciding set until the scorer picks which
  /// team is on the left. Other sets swap sides automatically.
  bool get needsSides => !_s.sidesChosen;

  /// The team on the left of the scoreboard right now. Swaps by itself between
  /// sets, and in the deciding set when a team reaches 8 points.
  Team get leftTeam => _s.leftTeam;
  Team get rightTeam => _s.leftTeam.other;

  /// Set number -> the team that was on the left when that set started.
  Map<int, Team> get startingLeft => Map.unmodifiable(_s.startLeft);

  /// Set number -> the team that served first in that set.
  Map<int, Team> get firstServers => Map.unmodifiable(_s.firstServers);

  /// Choose which team is on the left (first set and deciding set only).
  Future<void> chooseSides(Team leftTeam) async {
    if (!needsSides) return;
    await _record(MatchEvent(EventType.sides, team: leftTeam));
  }

  Player _playerFor(Team team, int number) =>
      sheetOf(team).roster.firstWhere((p) => p.number == number);

  /// The player currently serving (position I of the serving team).
  Player? get currentServer {
    final team = _s.servingTeam;
    if (team == null) return null;
    return _playerFor(team, _ts(team).onCourt[0]);
  }

  /// Who will be serving for [team] if it wins the next rally. For the
  /// serving team that is the current server; for the receiving team it is
  /// the player in position II, who rotates into position I.
  Player? serverIfWins(Team team) {
    final serving = _s.servingTeam;
    if (serving == null) return null;
    return _playerFor(team, _ts(team).onCourt[team == serving ? 0 : 1]);
  }

  /// Every service round of the match so far, in order, across all sets.
  List<ServiceRound> get serviceRounds =>
      [for (final r in _s.rounds) r.toPublic()];

  /// Service rounds for one team in one set (default: the current set), in
  /// the order they happened.
  List<ServiceRound> serviceRoundsFor(Team team, {int? setNumber}) {
    final n = setNumber ?? _s.currentSet;
    return [
      for (final r in _s.rounds)
        if (r.team == team && r.setNumber == n) r.toPublic()
    ];
  }

  /// Choose which team serves first in the current set.
  Future<void> chooseFirstServe(Team team) async {
    if (!needsFirstServe) return;
    await _record(MatchEvent(EventType.firstServe, team: team));
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> scorePoint(Team team) async {
    if (needsFirstServe || isSetComplete) return;
    await _record(MatchEvent(EventType.point, team: team));
  }

  Future<bool> takeTimeout(Team team) async {
    if (timeOutsOf(team) >= 2) return false;
    await _record(MatchEvent(EventType.timeout, team: team));
    return true;
  }

  Future<void> startNewSet() async {
    if (!isSetComplete || isMatchComplete) return;
    await _record(const MatchEvent(EventType.newSet));
  }

  Future<void> undo() async {
    if (_events.isEmpty) return;
    _events.removeLast();
    _s = _replay();
    notifyListeners();
    await _save();
  }

  Future<void> resetMatch() async {
    _events.clear();
    _signatures.clear();
    _notes = '';
    _s = _replay();
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Substitutions
  // ---------------------------------------------------------------------------

  bool canTakeSub(Team team) => subCountOf(team) < 6;

  /// Players on court, in court-position order (I, II, III, IV, V, VI).
  List<Player> getOnCourtPlayers(Team team) =>
      _ts(team).onCourt.map((n) => _playerFor(team, n)).toList();

  int getSubCountForPlayer(Team team, int playerNum) =>
      _ts(team).pairSubCounts[playerNum] ?? 0;

  bool isPositionExhausted(Team team, int playerNum) =>
      getSubCountForPlayer(team, playerNum) >= 2;

  Player? getLockedSubPartner(Team team, int playerOffNum) {
    final partnerNum = _ts(team).subPairs[playerOffNum];
    if (partnerNum == null) return null;
    return _playerFor(team, partnerNum);
  }

  List<Player> getEligibleBenchPlayers(Team team, int playerOffNum) {
    final t = _ts(team);

    // A player who has been subbed once must be replaced by their partner.
    final lockedPartner = getLockedSubPartner(team, playerOffNum);
    if (lockedPartner != null && getSubCountForPlayer(team, playerOffNum) == 1) {
      return [lockedPartner];
    }

    // Otherwise: anyone on the bench who isn't already tied to someone else.
    return sheetOf(team)
        .roster
        .where((p) =>
            !t.onCourt.contains(p.number) && !t.subPairs.containsKey(p.number))
        .toList();
  }

  Future<void> executeSubstitution(
    Team team,
    int playerOffNum,
    int playerOnNum,
  ) async {
    // The engine enforces the rules itself, so a stale or double tap can't
    // record an impossible sub.
    if (!canTakeSub(team)) return;
    if (isPositionExhausted(team, playerOffNum)) return;
    if (!_ts(team).onCourt.contains(playerOffNum)) return;
    final allowed = getEligibleBenchPlayers(team, playerOffNum);
    if (!allowed.any((p) => p.number == playerOnNum)) return;

    await _record(
      MatchEvent(
        EventType.sub,
        team: team,
        playerOff: playerOffNum,
        playerOn: playerOnNum,
      ),
    );
  }
}
