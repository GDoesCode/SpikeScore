import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

enum MatchMode { localLeague3Set, nationalLeague5Set }

class MatchEvent {
  final String type; // "Point", "Timeout", "Sub", "NewSet"
  final String team; // "Home", "Away"
  final int? playerOff;
  final int? playerOn;

  MatchEvent(this.type, this.team, {this.playerOff, this.playerOn});
}

class MatchEngine extends ChangeNotifier {
  late SharedPreferences _prefs;

  MatchMode matchMode = MatchMode.localLeague3Set;
  int currentSet = 1;
  int _homeScore = 0;
  int _awayScore = 0;
  int _homeSetsWon = 0;
  int _awaySetsWon = 0;
  int _homeTimeOuts = 0;
  int _awayTimeOuts = 0;
  int _homeSubCount = 0;
  int _awaySubCount = 0;

  final List<String> setHistory = [];

  int get homeScore => _homeScore;
  int get awayScore => _awayScore;
  int get homeSetsWon => _homeSetsWon;
  int get awaySetsWon => _awaySetsWon;
  int get homeTimeOuts => _homeTimeOuts;
  int get awayTimeOuts => _awayTimeOuts;
  int get homeSubCount => _homeSubCount;
  int get awaySubCount => _awaySubCount;

  late TeamSheet homeTeamSheet;
  late TeamSheet awayTeamSheet;

  List<int> homeOnCourt = [];
  List<int> awayOnCourt = [];

  final Map<String, Map<int, int>> _subPairs = {
    "Home": {},
    "Away": {},
  };

  final Map<String, Map<int, int>> _pairSubCounts = {
    "Home": {},
    "Away": {},
  };

  final List<MatchEvent> _eventHistory = [];
  bool get canUndo => _eventHistory.isNotEmpty;

  MatchEngine() {
    _initDefaultTeams();
    _initStorage();
  }

  void _initDefaultTeams() {
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

    homeOnCourt = List.from(homeTeamSheet.startingLineup);
    awayOnCourt = List.from(awayTeamSheet.startingLineup);
  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();
    await loadState();
  }

  Future<void> _saveState() async {
    await _prefs.setInt('currentSet', currentSet);
    await _prefs.setInt('homeScore', _homeScore);
    await _prefs.setInt('awayScore', _awayScore);
    await _prefs.setInt('homeTO', _homeTimeOuts);
    await _prefs.setInt('awayTO', _awayTimeOuts);
    await _prefs.setInt('homeSubs', _homeSubCount);
    await _prefs.setInt('awaySubs', _awaySubCount);
  }

  Future<void> loadState() async {
    currentSet = _prefs.getInt('currentSet') ?? 1;
    _homeScore = _prefs.getInt('homeScore') ?? 0;
    _awayScore = _prefs.getInt('awayScore') ?? 0;
    _homeTimeOuts = _prefs.getInt('homeTO') ?? 0;
    _awayTimeOuts = _prefs.getInt('awayTO') ?? 0;
    _homeSubCount = _prefs.getInt('homeSubs') ?? 0;
    _awaySubCount = _prefs.getInt('awaySubs') ?? 0;
    notifyListeners();
  }

  void setMatchMode(MatchMode mode) {
    matchMode = mode;
    notifyListeners();
  }

  bool get isDecidingSet {
    int maxSets = matchMode == MatchMode.localLeague3Set ? 3 : 5;
    return currentSet == maxSets;
  }

  int get targetPoints {
    return isDecidingSet ? 15 : 25;
  }

  bool get isSetComplete {
    int target = targetPoints;
    return (_homeScore >= target || _awayScore >= target) && (_homeScore - _awayScore).abs() >= 2;
  }

  String? get winningTeam {
    if (!isSetComplete) return null;
    return _homeScore > _awayScore ? "Home" : "Away";
  }

  /// Required set wins to win the match (2 wins for 3-set, 3 wins for 5-set)
  int get requiredSetsToWin {
    return matchMode == MatchMode.localLeague3Set ? 2 : 3;
  }

  /// Total sets played so far in this match
  bool get isMatchComplete {
    if (!isSetComplete) {
      // Check if earlier sets already clinched the match
      return homeSetsWon >= requiredSetsToWin || awaySetsWon >= requiredSetsToWin;
    }
    
    // Check if adding the current set's winner completes the match
    int currentHomeWins = homeSetsWon + (winningTeam == "Home" ? 1 : 0);
    int currentAwayWins = awaySetsWon + (winningTeam == "Away" ? 1 : 0);

    return currentHomeWins >= requiredSetsToWin || currentAwayWins >= requiredSetsToWin;
  }

  Future<void> scorePoint(String team) async {
    // Prevent scoring if the set is already complete
    if (isSetComplete) return;

    if (team == "Home") {
      _homeScore++;
    } else {
      _awayScore++;
    }

    _eventHistory.add(MatchEvent("Point", team));
    await _saveState();
    notifyListeners();
  }

  Future<bool> takeTimeout(String team) async {
    int currentTOs = team == "Home" ? _homeTimeOuts : _awayTimeOuts;
    if (currentTOs >= 2) return false;

    if (team == "Home") {
      _homeTimeOuts++;
    } else {
      _awayTimeOuts++;
    }

    _eventHistory.add(MatchEvent("Timeout", team));
    await _saveState();
    notifyListeners();
    return true;
  }

  // --- SUBSTITUTION LOGIC ---
  bool canTakeSub(String team) {
    int count = team == "Home" ? _homeSubCount : _awaySubCount;
    return count < 6;
  }

  List<Player> getOnCourtPlayers(String team) {
    final sheet = team == "Home" ? homeTeamSheet : awayTeamSheet;
    final onCourtNums = team == "Home" ? homeOnCourt : awayOnCourt;
    return sheet.roster.where((p) => onCourtNums.contains(p.number)).toList();
  }

  int getSubCountForPlayer(String team, int playerNum) {
    return _pairSubCounts[team]![playerNum] ?? 0;
  }

  bool isPositionExhausted(String team, int playerNum) {
    return getSubCountForPlayer(team, playerNum) >= 2;
  }

  Player? getLockedSubPartner(String team, int playerOffNum) {
    final pairs = _subPairs[team]!;
    if (pairs.containsKey(playerOffNum)) {
      int partnerNum = pairs[playerOffNum]!;
      final sheet = team == "Home" ? homeTeamSheet : awayTeamSheet;
      return sheet.roster.firstWhere((p) => p.number == partnerNum);
    }
    return null;
  }

  List<Player> getEligibleBenchPlayers(String team, int playerOffNum) {
    final sheet = team == "Home" ? homeTeamSheet : awayTeamSheet;
    final onCourtNums = team == "Home" ? homeOnCourt : awayOnCourt;

    Player? lockedPartner = getLockedSubPartner(team, playerOffNum);
    if (lockedPartner != null && getSubCountForPlayer(team, playerOffNum) == 1) {
      return [lockedPartner];
    }

    return sheet.roster.where((p) => !onCourtNums.contains(p.number)).toList();
  }

  Future<void> executeSubstitution(String team, int playerOffNum, int playerOnNum) async {
    List<int> onCourtNums = team == "Home" ? homeOnCourt : awayOnCourt;

    int index = onCourtNums.indexOf(playerOffNum);
    if (index != -1) {
      onCourtNums[index] = playerOnNum;
    } else {
      onCourtNums.remove(playerOffNum);
      onCourtNums.add(playerOnNum);
    }

    _subPairs[team]![playerOffNum] = playerOnNum;
    _subPairs[team]![playerOnNum] = playerOffNum;

    int existingCount = _pairSubCounts[team]![playerOffNum] ?? 0;
    int newPairSubs = existingCount + 1;

    _pairSubCounts[team]![playerOffNum] = newPairSubs;
    _pairSubCounts[team]![playerOnNum] = newPairSubs;

    if (team == "Home") {
      _homeSubCount++;
    } else {
      _awaySubCount++;
    }

    _eventHistory.add(MatchEvent("Sub", team, playerOff: playerOffNum, playerOn: playerOnNum));
    await _saveState();
    notifyListeners();
  }

  // --- SET & MATCH RESET LOGIC ---

  Future<void> startNewSet() async {
    // Record set winner before clearing scores
    if (winningTeam == "Home") {
      _homeSetsWon++;
    } else if (winningTeam == "Away") {
      _awaySetsWon++;
    }

    setHistory.add("Set $currentSet: Home $_homeScore - $_awayScore Away");

    // Advance set counter and reset set metrics
    currentSet++;
    _homeScore = 0;
    _awayScore = 0;
    _homeTimeOuts = 0;
    _awayTimeOuts = 0;
    _homeSubCount = 0;
    _awaySubCount = 0;

    _subPairs["Home"]!.clear();
    _subPairs["Away"]!.clear();
    _pairSubCounts["Home"]!.clear();
    _pairSubCounts["Away"]!.clear();

    homeOnCourt = List.from(homeTeamSheet.startingLineup);
    awayOnCourt = List.from(awayTeamSheet.startingLineup);

    _eventHistory.add(MatchEvent("NewSet", "Match"));
    await _saveState();
    notifyListeners();
  }

  Future<void> resetMatch() async {
    _homeScore = 0;
    _awayScore = 0;
    _homeTimeOuts = 0;
    _awayTimeOuts = 0;
    _homeSubCount = 0;
    _awaySubCount = 0;
    currentSet = 1;
    _homeSetsWon = 0;
    _awaySetsWon = 0;

    setHistory.clear();
    _eventHistory.clear();

    _subPairs["Home"]!.clear();
    _subPairs["Away"]!.clear();
    _pairSubCounts["Home"]!.clear();
    _pairSubCounts["Away"]!.clear();

    homeOnCourt = List.from(homeTeamSheet.startingLineup);
    awayOnCourt = List.from(awayTeamSheet.startingLineup);

    await _prefs.clear();
    await _saveState();
    notifyListeners();
  }

  Future<void> undo() async {
    if (!canUndo) return;
    var lastEvent = _eventHistory.removeLast();

    if (lastEvent.type == "Point") {
      if (lastEvent.team == "Home" && _homeScore > 0) _homeScore--;
      if (lastEvent.team == "Away" && _awayScore > 0) _awayScore--;
    } else if (lastEvent.type == "NewSet") {
      // Revert set transition
      if (setHistory.isNotEmpty) {
        setHistory.removeLast();
      }
      if (currentSet > 1) currentSet--;

      // Adjust sets won counts
      if (_homeSetsWon > 0 && _homeSetsWon > _awaySetsWon) {
        _homeSetsWon--;
      } else if (_awaySetsWon > 0 && _awaySetsWon > _homeSetsWon) {
        _awaySetsWon--;
      }
    } else if (lastEvent.type == "Timeout") {
      if (lastEvent.team == "Home" && _homeTimeOuts > 0) _homeTimeOuts--;
      if (lastEvent.team == "Away" && _awayTimeOuts > 0) _awayTimeOuts--;
    } else if (lastEvent.type == "Sub") {
      List<int> onCourtNums = lastEvent.team == "Home" ? homeOnCourt : awayOnCourt;

      int pOff = lastEvent.playerOff!;
      int pOn = lastEvent.playerOn!;

      int index = onCourtNums.indexOf(pOn);
      if (index != -1) {
        onCourtNums[index] = pOff;
      }

      int newCount = (_pairSubCounts[lastEvent.team]![pOff] ?? 1) - 1;
      _pairSubCounts[lastEvent.team]![pOff] = newCount;
      _pairSubCounts[lastEvent.team]![pOn] = newCount;

      if (newCount == 0) {
        _subPairs[lastEvent.team]!.remove(pOff);
        _subPairs[lastEvent.team]!.remove(pOn);
      }

      if (lastEvent.team == "Home") {
        _homeSubCount--;
      } else {
        _awaySubCount--;
      }
    }

    await _saveState();
    notifyListeners();
  }
}