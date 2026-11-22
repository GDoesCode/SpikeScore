import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/demo_data.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_data.dart';
import 'package:spikescore/scoresheet/signature_slots.dart';

Future<MatchEngine> newEngine() async {
  final prefs = await SharedPreferences.getInstance();
  return MatchEngine(prefs: prefs);
}

Future<void> score(MatchEngine e, Team team, int n) async {
  for (var i = 0; i < n; i++) {
    await e.scorePoint(team);
  }
}

const ink = <List<List<double>>>[
  [
    [0.1, 0.2],
    [0.5, 0.6],
  ],
];

Future<void> coinToss(MatchEngine e) async {
  await e.chooseSides(Team.home);
  await e.chooseFirstServe(Team.home);
}

Future<void> playMatch(MatchEngine e) async {
  for (var set = 1; set <= 2; set++) {
    if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
    await score(e, Team.away, 10);
    await score(e, Team.home, e.targetPoints);
    if (!e.isMatchComplete) await e.startNewSet();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pre-match signatures', () {
    test('captains only, or captains and coaches when a team has one', () async {
      final e = await newEngine();
      expect(e.preMatchSlots,
          [SignatureSlots.captain(Team.home), SignatureSlots.captain(Team.away)]);

      e.officials = {
        Team.home: const [Official('C', 'Coach Carter')],
        Team.away: const [Official('AC', 'Assistant only')],
      };
      expect(e.preMatchSlots, [
        SignatureSlots.captain(Team.home),
        SignatureSlots.coach(Team.home),
        SignatureSlots.captain(Team.away),
      ]);
    });

    test('are asked for after sides and first serve, until signed', () async {
      final e = await newEngine();
      expect(e.awaitingPreMatchSignatures, isFalse);
      await e.chooseSides(Team.home);
      expect(e.awaitingPreMatchSignatures, isFalse);
      await e.chooseFirstServe(Team.home);
      expect(e.awaitingPreMatchSignatures, isTrue);

      await e.setSignature(SignatureSlots.captain(Team.home), ink);
      expect(e.awaitingPreMatchSignatures, isTrue);
      await e.setSignature(SignatureSlots.captain(Team.away), ink);
      expect(e.awaitingPreMatchSignatures, isFalse);
    });

    test('a referee can let the match start without them', () async {
      final e = await newEngine();
      await coinToss(e);
      await e.waivePreMatchSignatures(referee: '1st referee');
      expect(e.awaitingPreMatchSignatures, isFalse);
      expect(e.notes, contains('Ref override (1st referee'));
      expect(e.notes, contains('2 missing'));

      final reloaded = await newEngine();
      expect(reloaded.preMatchWaived, isTrue);
      await reloaded.resetMatch();
      expect(reloaded.preMatchWaived, isFalse);
    });

    test('are locked once play starts, but a missing one can still be added',
        () async {
      final e = await newEngine();
      await coinToss(e);
      final home = SignatureSlots.captain(Team.home);
      final away = SignatureSlots.captain(Team.away);
      await e.setSignature(home, ink);
      await e.waivePreMatchSignatures(referee: '2nd referee');
      await e.scorePoint(Team.home);

      expect(e.isSignatureLocked(home), isTrue);
      await e.clearSignature(home);
      expect(e.signatures.containsKey(home), isTrue);

      expect(e.isSignatureLocked(away), isFalse);
      await e.setSignature(away, ink);
      expect(e.signatures.containsKey(away), isTrue);
      expect(e.isSignatureLocked(away), isTrue);
    });
  });

  group('end-of-match signatures', () {
    test('lock scoring, undo, time-outs and subs once anyone signs', () async {
      final e = await newEngine();
      await playMatch(e);
      expect(e.isMatchComplete, isTrue);
      expect(e.isSignedOff, isFalse);
      expect(e.canUndo, isTrue);

      await e.setSignature(SignatureSlots.ref1, ink);
      expect(e.isSignedOff, isTrue);
      expect(e.canUndo, isFalse);

      final events = e.events.length;
      await e.undo();
      expect(await e.takeTimeout(Team.home), isFalse);
      await e.executeSubstitution(Team.away, 4, 14);
      expect(e.events.length, events);
    });

    test('signing before the match is over does not lock anything', () async {
      final e = await newEngine();
      await coinToss(e);
      await e.setSignature(SignatureSlots.ref1, ink);
      expect(e.isSignedOff, isFalse);
      await e.scorePoint(Team.home);
      expect(e.homeScore, 1);
    });

    test('a referee override unlocks it and wipes the approval signatures',
        () async {
      final e = await newEngine();
      await e.setSignature(SignatureSlots.captain(Team.home), ink);
      await playMatch(e);
      await e.setSignature(SignatureSlots.ref1, ink);
      await e.setSignature(SignatureSlots.scorer, ink);

      await e.unlockSignedSheet(referee: '1st referee');
      expect(e.isSignedOff, isFalse);
      expect(e.canUndo, isTrue);
      expect(e.signatures.keys, [SignatureSlots.captain(Team.home)]);
      expect(e.notes, contains('unlocked'));
    });
  });

  group('referee score change', () {
    test('changes the score without a rally', () async {
      final e = await newEngine();
      await coinToss(e);
      await score(e, Team.home, 5);
      await score(e, Team.away, 3);
      final server = e.servingTeam;
      final rounds = e.serviceRounds.length;

      await e.adjustScore(Team.away, -2, referee: '2nd referee');
      expect(e.homeScore, 5);
      expect(e.awayScore, 1);
      expect(e.servingTeam, server);
      expect(e.serviceRounds.length, rounds);
      expect(e.notes, contains('Ref override (2nd referee'));
      expect(e.notes, contains('5:3 -> 5:1'));

      await e.adjustScore(Team.home, 1, referee: '2nd referee');
      expect(e.homeScore, 6);
    });

    test('cannot go below zero', () async {
      final e = await newEngine();
      await coinToss(e);
      await e.adjustScore(Team.home, -1, referee: '1st referee');
      expect(e.homeScore, 0);
      expect(e.events.where((x) => x.type == EventType.scoreAdjust), isEmpty);
    });

    test('can be undone, and survives a restart', () async {
      final e = await newEngine();
      await coinToss(e);
      await score(e, Team.home, 4);
      await e.adjustScore(Team.home, -3, referee: '1st referee');
      expect((await newEngine()).homeScore, 1);
      await e.undo();
      expect(e.homeScore, 4);
    });

    test('on a signed-off match it unlocks the sheet first', () async {
      final e = await newEngine();
      await playMatch(e);
      await e.setSignature(SignatureSlots.ref2, ink);
      expect(e.isSignedOff, isTrue);

      // Home won set 2 25:10. Taking 2 points off reopens the set.
      await e.adjustScore(Team.home, -2, referee: '1st referee');
      expect(e.isSignedOff, isFalse);
      expect(e.homeScore, 23);
      expect(e.isSetComplete, isFalse);
      expect(e.isMatchComplete, isFalse);
      expect(e.signatures, isEmpty);

      await score(e, Team.home, 2);
      expect(e.isMatchComplete, isTrue);
    });

    test('the scoresheet shows the corrected score', () async {
      final e = await newEngine();
      await coinToss(e);
      await score(e, Team.home, 7);
      await score(e, Team.away, 2);
      await e.adjustScore(Team.home, -2, referee: '1st referee');
      final sheet = ScoresheetData.fromEngine(e);
      expect(sheet.sets.first.score[Team.home], 5);
      expect(sheet.sets.first.score[Team.away], 2);
    });
  });
}
