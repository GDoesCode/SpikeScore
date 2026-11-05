import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adjust these paths if your test folder isn't next to lib/.
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/models.dart';

Future<MatchEngine> newEngine() async {
  final prefs = await SharedPreferences.getInstance();
  return MatchEngine(prefs: prefs);
}

Future<void> score(MatchEngine e, Team team, int n) async {
  for (var i = 0; i < n; i++) {
    await e.scorePoint(team);
  }
}

/// Plays a set that [winner] wins. The loser scores first so the set can't
/// finish before the winner has reached the target. Home serves first if
/// the serve hasn't been chosen yet.
Future<void> playSet(
  MatchEngine e, {
  required Team winner,
  int loserPoints = 10,
}) async {
  if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
  await score(e, winner.other, loserPoints);
  await score(e, winner, e.targetPoints);
}

List<int> lineup(MatchEngine e, Team team) =>
    e.getOnCourtPlayers(team).map((p) => p.number).toList();

TeamSheet bigSheet(String name, int firstNumber) {
  final numbers = [for (var n = firstNumber; n < firstNumber + 12; n++) n];
  return TeamSheet(
    teamName: name,
    roster: [for (final n in numbers) Player(number: n, name: 'P$n')],
    startingLineup: numbers.sublist(0, 6),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('scoring', () {
    test('points are ignored until the first serve is chosen', () async {
      final e = await newEngine();
      expect(e.needsFirstServe, isTrue);

      await e.scorePoint(Team.home);
      expect(e.homeScore, 0);

      await e.chooseFirstServe(Team.home);
      expect(e.needsFirstServe, isFalse);

      await e.scorePoint(Team.home);
      expect(e.homeScore, 1);
    });

    test('set ends at 25 with a 2 point lead', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);

      expect(e.homeScore, 25);
      expect(e.awayScore, 20);
      expect(e.isSetComplete, isTrue);
      expect(e.winningTeam, Team.home);
    });

    test('must win by 2', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await score(e, Team.away, 24);
      await score(e, Team.home, 25);
      expect(e.isSetComplete, isFalse); // 25-24

      await e.scorePoint(Team.home);
      expect(e.isSetComplete, isTrue); // 26-24
      expect(e.winningTeam, Team.home);
    });

    test('no scoring after the set is complete', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 5);
      await e.scorePoint(Team.away);

      expect(e.awayScore, 5);
      expect(e.homeScore, 25);
    });
  });

  group('serving and rotation', () {
    test('serving team keeps serving, same server, no rotation', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 3);

      expect(e.servingTeam, Team.home);
      expect(e.currentServer?.number, 1);
      expect(lineup(e, Team.home), [1, 3, 5, 7, 9, 11]);
      expect(e.homeScore, 3);
    });

    test('side-out gives the serve to the receiving team and rotates it', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.scorePoint(Team.away);

      expect(e.servingTeam, Team.away);
      expect(lineup(e, Team.away), [4, 6, 8, 10, 12, 2]);
      expect(e.currentServer?.number, 4);
      // The team that lost the rally does not rotate.
      expect(lineup(e, Team.home), [1, 3, 5, 7, 9, 11]);
    });

    test('serverIfWins: current server for the serving team, position II for the receiver', () async {
      final e = await newEngine();
      expect(e.serverIfWins(Team.home), isNull); // no serve chosen yet

      await e.chooseFirstServe(Team.home);
      expect(e.serverIfWins(Team.home)?.number, 1);
      expect(e.serverIfWins(Team.away)?.number, 4);
    });

    test('undoing a side-out un-rotates and gives the serve back', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.scorePoint(Team.away);
      await e.undo();

      expect(e.servingTeam, Team.home);
      expect(lineup(e, Team.away), [2, 4, 6, 8, 10, 12]);
      expect(e.awayScore, 0);
    });

    test('six side-outs each bring both teams back to the starting rotation', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      for (var i = 0; i < 6; i++) {
        await e.scorePoint(Team.away);
        await e.scorePoint(Team.home);
      }

      expect(e.homeScore, 6);
      expect(e.awayScore, 6);
      expect(lineup(e, Team.home), [1, 3, 5, 7, 9, 11]);
      expect(lineup(e, Team.away), [2, 4, 6, 8, 10, 12]);
    });

    test('a substitute takes over the serving position', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.executeSubstitution(Team.home, 1, 13);

      expect(e.currentServer?.number, 13);
      expect(lineup(e, Team.home), [13, 3, 5, 7, 9, 11]);
    });

    test('set 2 starts from the original lineups', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20); // both teams rotate
      await e.startNewSet();

      expect(lineup(e, Team.home), [1, 3, 5, 7, 9, 11]);
      expect(lineup(e, Team.away), [2, 4, 6, 8, 10, 12]);
      expect(e.homeScore, 0);
      expect(e.awayScore, 0);
    });
  });

  group('sides and first serve order', () {
    /// Plays sets 1 and 2 (home wins the first, away the second) and moves on
    /// to the deciding set.
    Future<void> toDecidingSet(MatchEngine e) async {
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.away);
      await e.startNewSet();
    }

    test('sides are asked once at the start; the default is home on the left', () async {
      final e = await newEngine();
      expect(e.needsSides, isTrue);
      expect(e.leftTeam, Team.home);

      await e.chooseSides(Team.away);
      expect(e.needsSides, isFalse);
      expect(e.leftTeam, Team.away);
      expect(e.rightTeam, Team.home);
      expect(e.startingLeft, {1: Team.away});
    });

    test('choosing sides a second time in the same set is ignored', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.chooseSides(Team.home);
      expect(e.leftTeam, Team.away);
    });

    test('undo takes the sides choice back', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.undo();
      expect(e.needsSides, isTrue);
      expect(e.leftTeam, Team.home);
    });

    test('set 2 swaps sides and the other team serves first, without asking', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.home);
      await playSet(e, winner: Team.home);
      await e.startNewSet();

      expect(e.needsSides, isFalse);
      expect(e.needsFirstServe, isFalse);
      expect(e.leftTeam, Team.home); // swapped
      expect(e.servingTeam, Team.away); // the team that did not serve first
      expect(e.firstServers, {1: Team.home, 2: Team.away});
      expect(e.startingLeft, {1: Team.away, 2: Team.home});

      // Points count straight away.
      await e.scorePoint(Team.away);
      expect(e.awayScore, 1);
    });

    test('undoing the start of set 2 puts sides and serve back', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.home);
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await e.undo();

      expect(e.currentSet, 1);
      expect(e.leftTeam, Team.away);
      expect(e.servingTeam, isNotNull);
      expect(e.firstServers, {1: Team.home});
    });

    test('the deciding set has a new coin toss for sides and for serve', () async {
      final e = await newEngine();
      await e.chooseSides(Team.home);
      await toDecidingSet(e);

      expect(e.currentSet, 3);
      expect(e.needsSides, isTrue);
      expect(e.needsFirstServe, isTrue);
      expect(e.servingTeam, isNull);
      await e.scorePoint(Team.home); // ignored until the toss is done
      expect(e.homeScore, 0);

      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.home);
      expect(e.leftTeam, Team.away);
      expect(e.servingTeam, Team.home);
      expect(e.startingLeft[3], Team.away);
      expect(e.firstServers[3], Team.home);
    });

    test('in the deciding set the teams change ends when a team reaches 8', () async {
      final e = await newEngine();
      await toDecidingSet(e);
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);

      await score(e, Team.away, 3);
      await score(e, Team.home, 7);
      expect(e.leftTeam, Team.home); // 7:3, not yet

      await e.scorePoint(Team.home); // 8:3
      expect(e.leftTeam, Team.away);
      expect(e.rightTeam, Team.home);

      await score(e, Team.home, 3); // they only change once
      expect(e.leftTeam, Team.away);
      expect(e.startingLeft[3], Team.home); // where the set started

      await e.undo();
      await e.undo();
      await e.undo();
      await e.undo(); // back to 7:3
      expect(e.leftTeam, Team.home);
    });

    test('sets 1 and 2 never change ends mid-set', () async {
      final e = await newEngine();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 20);
      expect(e.leftTeam, Team.home);
    });
  });

  group('sets and match', () {
    test('starting a new set credits the winner and resets the set', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);
      await e.takeTimeout(Team.away);
      await e.startNewSet();

      expect(e.currentSet, 2);
      expect(e.homeSetsWon, 1);
      expect(e.awaySetsWon, 0);
      expect(e.homeScore, 0);
      expect(e.awayScore, 0);
      expect(e.awayTimeOuts, 0);
      expect(e.setHistory, ["Set 1: Home 25 - 20 Away"]);
    });

    test('undoing a new set restores the previous set exactly', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);
      await e.takeTimeout(Team.away);
      await e.startNewSet();
      await e.undo();

      expect(e.currentSet, 1);
      expect(e.homeScore, 25);
      expect(e.awayScore, 20);
      expect(e.homeSetsWon, 0);
      expect(e.awayTimeOuts, 1);
      expect(e.setHistory, isEmpty);
      expect(e.needsFirstServe, isFalse);
    });

    test('3-set match: set 3 is played to 15, and 2 set wins end the match', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.away);
      await e.startNewSet();

      expect(e.currentSet, 3);
      expect(e.targetPoints, 15);
      expect(e.isMatchComplete, isFalse);

      await playSet(e, winner: Team.away);
      expect(e.isMatchComplete, isTrue);

      // Can't advance past the end of the match.
      await e.startNewSet();
      expect(e.currentSet, 3);
    });

    test('format is locked once the match has started', () async {
      final e = await newEngine();
      await e.setMatchMode(MatchMode.nationalLeague5Set);
      expect(e.matchMode, MatchMode.nationalLeague5Set);

      await e.chooseFirstServe(Team.home);
      await e.setMatchMode(MatchMode.localLeague3Set);
      expect(e.matchMode, MatchMode.nationalLeague5Set);
    });
  });

  group('timeouts', () {
    test('max two per set, and undo gives one back', () async {
      final e = await newEngine();
      expect(await e.takeTimeout(Team.home), isTrue);
      expect(await e.takeTimeout(Team.home), isTrue);
      expect(await e.takeTimeout(Team.home), isFalse);
      expect(e.homeTimeOuts, 2);

      await e.undo();
      expect(e.homeTimeOuts, 1);
    });
  });

  group('substitutions', () {
    test('a paired player must be replaced by their partner', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);

      expect(lineup(e, Team.home).contains(13), isTrue);
      expect(lineup(e, Team.home).contains(1), isFalse);
      expect(e.homeSubCount, 1);
      expect(e.getLockedSubPartner(Team.home, 13)?.number, 1);

      final options = e.getEligibleBenchPlayers(Team.home, 13);
      expect(options.map((p) => p.number), [1]);
    });

    test('a paired starter is not offered as a sub for someone else', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);

      final options = e.getEligibleBenchPlayers(Team.home, 3);
      expect(options.map((p) => p.number), [15]); // not 1
    });

    test('the engine rejects a sub with a player who is paired with someone else', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);
      await e.executeSubstitution(Team.home, 3, 1); // 1 must come back for 13 only

      expect(lineup(e, Team.home).contains(3), isTrue);
      expect(e.homeSubCount, 1);
    });

    test('after the swap back, that position is exhausted and cannot sub again', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);
      await e.executeSubstitution(Team.home, 13, 1);

      expect(e.homeSubCount, 2);
      expect(e.isPositionExhausted(Team.home, 1), isTrue);
      expect(e.isPositionExhausted(Team.home, 13), isTrue);

      await e.executeSubstitution(Team.home, 1, 15); // rejected
      expect(e.homeSubCount, 2);
      expect(lineup(e, Team.home).contains(1), isTrue);
    });

    test('max six subs per set', () async {
      final e = await newEngine();
      e.setTeams(bigSheet('H', 1), bigSheet('A', 21));

      // Six different starters swap with six different bench players.
      for (var i = 0; i < 6; i++) {
        await e.executeSubstitution(Team.home, 1 + i, 7 + i);
      }
      expect(e.homeSubCount, 6);
      expect(e.canTakeSub(Team.home), isFalse);

      // A seventh (even a legal re-entry) is rejected.
      await e.executeSubstitution(Team.home, 7, 1);
      expect(e.homeSubCount, 6);
      expect(lineup(e, Team.home).contains(7), isTrue);
    });

    test('undoing a sub puts everything back', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);
      await e.undo();

      expect(lineup(e, Team.home).contains(1), isTrue);
      expect(lineup(e, Team.home).contains(13), isFalse);
      expect(e.homeSubCount, 0);
      expect(e.getSubCountForPlayer(Team.home, 1), 0);
      expect(e.getLockedSubPartner(Team.home, 1), isNull);
    });

    test('subs reset for the next set', () async {
      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13);
      await playSet(e, winner: Team.home);
      await e.startNewSet();

      expect(e.homeSubCount, 0);
      expect(lineup(e, Team.home).contains(1), isTrue);
      expect(e.getLockedSubPartner(Team.home, 1), isNull);
    });
  });

  group('service rounds', () {
    List<int> positions(MatchEngine e, Team team) =>
        e.serviceRoundsFor(team).map((r) => r.position).toList();

    test('the first round opens when the first serve is chosen', () async {
      final e = await newEngine();
      expect(e.serviceRounds, isEmpty);

      await e.chooseFirstServe(Team.home);
      final r = e.serviceRounds.single;
      expect(r.team, Team.home);
      expect(r.position, 1);
      expect(r.servers, [1]);
      expect(r.startOwn, 0);
      expect(r.endOwn, 0);
      expect(r.isOpen, isTrue);
    });

    test('points won while serving extend the round', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 3);

      final r = e.serviceRounds.single;
      expect(r.endOwn, 3);
      expect(r.pointsWon, 3);
      expect(r.isOpen, isTrue);
    });

    test('a side-out closes the round and opens one for the other team', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 3);
      await score(e, Team.away, 3); // side-out on the first point, then two more
      await e.scorePoint(Team.home); // side-out back to home

      final home = e.serviceRoundsFor(Team.home);
      final away = e.serviceRoundsFor(Team.away);
      expect(home.length, 2);
      expect(away.length, 1);

      expect(home[0].position, 1);
      expect(home[0].startOwn, 0);
      expect(home[0].endOwn, 3);
      expect(home[0].opponentScore, 0);
      expect(home[0].isOpen, isFalse);

      // The receiving team's first round is II, served by the player who was
      // in position II.
      expect(away[0].position, 2);
      expect(away[0].servers, [4]);
      expect(away[0].startOwn, 1);
      expect(away[0].endOwn, 3);
      expect(away[0].pointsWon, 2);
      expect(away[0].opponentScore, 3);
      expect(away[0].isOpen, isFalse);

      expect(home[1].position, 2);
      expect(home[1].servers, [3]);
      expect(home[1].startOwn, 4);
      expect(home[1].endOwn, 4);
      expect(home[1].opponentScore, 3);
      expect(home[1].isOpen, isTrue);
    });

    test('a substitute serving mid-round is recorded', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.executeSubstitution(Team.home, 3, 15); // not the server
      await e.executeSubstitution(Team.home, 1, 13); // the server

      expect(e.serviceRounds.single.servers, [1, 13]);
    });

    test('service positions cycle I to VI as a team rotates', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      for (var i = 0; i < 6; i++) {
        await e.scorePoint(Team.away);
        await e.scorePoint(Team.home);
      }

      expect(positions(e, Team.home), [1, 2, 3, 4, 5, 6, 1]);
      expect(positions(e, Team.away), [2, 3, 4, 5, 6, 1]);
    });

    test('the last round of a set closes at the final score', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);

      final rounds = e.serviceRounds;
      expect(rounds.every((r) => !r.isOpen), isTrue);
      expect(rounds.last.team, Team.home);
      expect(rounds.last.endOwn, 25);
    });

    test('undo removes or reopens rounds', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.scorePoint(Team.away);
      expect(e.serviceRounds.length, 2);

      await e.undo();
      final rounds = e.serviceRounds;
      expect(rounds.length, 1);
      expect(rounds.single.team, Team.home);
      expect(rounds.single.isOpen, isTrue);
    });

    test('rounds are kept per set', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);
      final set1Count = e.serviceRounds.length;
      await e.startNewSet();

      expect(e.serviceRoundsFor(Team.home), isEmpty); // set 2 hasn't started
      await e.chooseFirstServe(Team.away);

      final r = e.serviceRoundsFor(Team.away).single;
      expect(r.setNumber, 2);
      expect(r.position, 1);
      expect(r.servers, [2]);
      expect(e.serviceRounds.length, set1Count + 1);
      expect(e.serviceRoundsFor(Team.home, setNumber: 1), isNotEmpty);
    });

    test('rounds are rebuilt after a restart', () async {
      final a = await newEngine();
      await a.chooseFirstServe(Team.home);
      await score(a, Team.home, 2);
      await a.scorePoint(Team.away);

      final b = await newEngine();
      expect(b.serviceRounds.length, a.serviceRounds.length);
      expect(b.serviceRoundsFor(Team.away).single.startOwn, 1);
    });

    List<String> captureDebugPrint() {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = original);
      return lines;
    }

    test('a debug line is printed when a round finishes, and only then', () async {
      final lines = captureDebugPrint();

      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.scorePoint(Team.home);
      expect(lines, isEmpty); // home's round is still in progress

      await e.scorePoint(Team.away); // side-out: home's round ends on 1
      expect(lines, ['[service] Set 1 Home I #1: 1']);

      // The receiving team's first round is position II, served by the
      // starter in position II (#4).
      await e.scorePoint(Team.home); // side-out: away's round ends on 1
      expect(lines, [
        '[service] Set 1 Home I #1: 1',
        '[service] Set 1 Away II #4: 1',
      ]);

      await e.undo(); // undo never prints
      expect(lines.length, 2);
    });

    test('the debug line mentions a substitute who served the round', () async {
      final lines = captureDebugPrint();

      final e = await newEngine();
      await e.executeSubstitution(Team.home, 1, 13); // 13 takes position I
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 2);
      await e.scorePoint(Team.away); // ends home's round on 2

      expect(lines, ['[service] Set 1 Home I #1 (served: #13): 2']);
    });
  });

  group('signatures', () {
    final ink = <List<List<double>>>[
      [
        [0.1, 0.2],
        [0.3, 0.6],
        [0.5, 0.3],
      ],
      [
        [0.1, 0.9],
        [0.8, 0.9],
      ],
    ];

    test('can be saved, replaced and cleared', () async {
      final e = await newEngine();
      expect(e.signatures, isEmpty);

      await e.setSignature('ref1', ink);
      expect(e.signatures['ref1'], ink);

      final other = <List<List<double>>>[
        [
          [0.2, 0.2],
          [0.4, 0.4],
        ],
      ];
      await e.setSignature('ref1', other);
      expect(e.signatures['ref1'], other);

      await e.clearSignature('ref1');
      expect(e.signatures, isEmpty);
    });

    test('an empty drawing is not saved', () async {
      final e = await newEngine();
      await e.setSignature('scorer', []);
      expect(e.signatures, isEmpty);
    });

    test('survive a restart', () async {
      final a = await newEngine();
      await a.setSignature('captain:home', ink);
      await a.setSignature('lineJudge3', ink);

      final b = await newEngine();
      expect(b.signatures.keys.toSet(), {'captain:home', 'lineJudge3'});
      expect(b.signatures['captain:home'], ink);
    });

    test('undo leaves them alone, reset clears them', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.setSignature('scorer', ink);

      await e.undo();
      expect(e.signatures['scorer'], ink);

      await e.resetMatch();
      expect(e.signatures, isEmpty);

      final reloaded = await newEngine();
      expect(reloaded.signatures, isEmpty);
    });

    test('they do not lock the match format', () async {
      final e = await newEngine();
      await e.setSignature('ref1', ink);
      expect(e.matchStarted, isFalse);
    });
  });

  group('notes', () {
    test('start empty and can be saved and replaced', () async {
      final e = await newEngine();
      expect(e.notes, '');

      await e.setNotes('Junior player #7');
      expect(e.notes, 'Junior player #7');

      await e.setNotes('Junior player #7, set 2 delayed');
      expect(e.notes, 'Junior player #7, set 2 delayed');
    });

    test('survive a restart', () async {
      final a = await newEngine();
      await a.setNotes('Line 1\nLine 2');

      final b = await newEngine();
      expect(b.notes, 'Line 1\nLine 2');
    });

    test('do not notify listeners, so closing the screen is safe', () async {
      final e = await newEngine();
      var calls = 0;
      e.addListener(() => calls++);
      await e.setNotes('quiet');
      expect(calls, 0);
    });

    test('undo leaves them alone, reset clears them', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.setNotes('keep me');

      await e.undo();
      expect(e.notes, 'keep me');

      await e.resetMatch();
      expect(e.notes, '');
      expect((await newEngine()).notes, '');
    });

    test('they do not lock the match format', () async {
      final e = await newEngine();
      await e.setNotes('hello');
      expect(e.matchStarted, isFalse);
    });
  });

  group('notes', () {
    test('start empty and can be changed', () async {
      final e = await newEngine();
      expect(e.notes, '');
      await e.setNotes('Junior #7 D. Evans');
      expect(e.notes, 'Junior #7 D. Evans');
    });

    test('survive a restart', () async {
      final a = await newEngine();
      await a.setNotes('Set 2 delayed 5 minutes');

      final b = await newEngine();
      expect(b.notes, 'Set 2 delayed 5 minutes');
    });

    test('are not touched by undo, and reset clears them', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await e.setNotes('keep me');
      await e.undo();
      expect(e.notes, 'keep me');

      await e.resetMatch();
      expect(e.notes, '');
      expect((await newEngine()).notes, '');
    });

    test('do not rebuild the screen (safe to save while a page closes)', () async {
      final e = await newEngine();
      var calls = 0;
      e.addListener(() => calls++);
      await e.setNotes('quiet');
      expect(calls, 0);
    });

    test('do not lock the match format', () async {
      final e = await newEngine();
      await e.setNotes('hello');
      expect(e.matchStarted, isFalse);
    });
  });

  group('persistence', () {
    test('the whole match survives a restart', () async {
      final a = await newEngine();
      await playSet(a, winner: Team.home, loserPoints: 20);
      await a.startNewSet();
      await a.chooseFirstServe(Team.away);
      await score(a, Team.away, 3);
      await a.scorePoint(Team.home); // side-out: home serves and rotates
      await a.takeTimeout(Team.away);
      await a.executeSubstitution(Team.home, 3, 13);

      final b = await newEngine(); // reads the same saved prefs

      expect(b.currentSet, 2);
      expect(b.homeSetsWon, 1);
      expect(b.awayScore, 3);
      expect(b.homeScore, 1);
      expect(b.servingTeam, Team.home);
      expect(b.awayTimeOuts, 1);
      expect(lineup(b, Team.home), [13, 5, 7, 9, 11, 1]);
      expect(b.getLockedSubPartner(Team.home, 13)?.number, 3);
      expect(b.setHistory, ["Set 1: Home 25 - 20 Away"]);

      // Undo history survives too.
      await b.undo(); // the sub
      await b.undo(); // the timeout
      expect(lineup(b, Team.home), [3, 5, 7, 9, 11, 1]);
      expect(b.awayTimeOuts, 0);
    });

    test('reset clears the saved match', () async {
      final a = await newEngine();
      await a.chooseFirstServe(Team.home);
      await score(a, Team.home, 5);
      await a.resetMatch();

      final b = await newEngine();
      expect(b.homeScore, 0);
      expect(b.canUndo, isFalse);
      expect(b.needsFirstServe, isTrue);
    });
  });
}
