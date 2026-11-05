import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adjust these paths if your test folder isn't next to lib/.
import 'package:spikescore/demo_data.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_data.dart';
import 'package:spikescore/scoresheet/scoresheet_pdf.dart';
import 'package:spikescore/scoresheet/scoresheet_publisher.dart';
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

/// Plays a whole set that [winner] wins (home serves first if not chosen yet).
Future<void> playSet(MatchEngine e, {required Team winner, int loserPoints = 10}) async {
  if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
  await score(e, winner.other, loserPoints);
  await score(e, winner, e.targetPoints);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScoresheetData', () {
    test('only the 3-set format is supported', () async {
      final e = await newEngine();
      expect(ScoresheetData.isSupported(e), isTrue);
      await e.setMatchMode(MatchMode.nationalLeague5Set);
      expect(ScoresheetData.isSupported(e), isFalse);
    });

    test('an empty match gives one blank set', () async {
      final e = await newEngine();
      final data = ScoresheetData.fromEngine(e);

      expect(data.sets.length, 1);
      expect(data.sets.single.number, 1);
      expect(data.sets.single.firstServe, isNull);
      expect(data.matchComplete, isFalse);
      expect(data.winner, isNull);
      expect(data.teams[Team.home]!.starters, [1, 3, 5, 7, 9, 11]);
    });

    test('time-outs and subs are recorded with the score at the time', () async {
      final e = await newEngine();
      await e.chooseFirstServe(Team.home);
      await score(e, Team.home, 2);
      await e.takeTimeout(Team.away); // 0:2 from away's side
      await e.executeSubstitution(Team.home, 3, 13); // 2:0
      await e.scorePoint(Team.away);
      await e.executeSubstitution(Team.home, 13, 3); // 2:1, the starter returns

      final set1 = ScoresheetData.fromEngine(e).sets.single;
      expect(set1.firstServe, Team.home);

      final to = set1.timeouts[Team.away]!.single;
      expect(to.own, 0);
      expect(to.opp, 2);

      final subs = set1.subs[Team.home]!;
      expect(subs.length, 2);
      expect(subs[0].slot, 1); // 3 started in service-order slot II
      expect(subs[0].playerOut, 3);
      expect(subs[0].playerIn, 13);
      expect([subs[0].own, subs[0].opp], [2, 0]);
      expect(subs[1].slot, 1); // the return happens in the same slot
      expect(subs[1].playerOut, 13);
      expect(subs[1].playerIn, 3);
      expect([subs[1].own, subs[1].opp], [2, 1]);
    });

    test('a finished match has a winner and set count', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.home);

      final data = ScoresheetData.fromEngine(e);
      expect(data.sets.length, 2);
      expect(data.sets.every((s) => s.complete), isTrue);
      expect(data.setsWon[Team.home], 2);
      expect(data.matchComplete, isTrue);
      expect(data.winner, Team.home);
    });

    test('Team A is the team that started set 1 on the left', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.home);

      final data = ScoresheetData.fromEngine(e);
      expect(data.teamA, Team.away);
      expect(data.teamB, Team.home);
      expect(data.sets.single.leftAtStart, Team.away);
      expect(data.sets.single.firstServe, Team.home);
    });

    test('set 2 sides and first serve come from the automatic rules', () async {
      final e = await newEngine();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      await playSet(e, winner: Team.home);
      await e.startNewSet();

      final set2 = ScoresheetData.fromEngine(e).sets[1];
      expect(set2.leftAtStart, Team.away); // swapped
      expect(set2.firstServe, Team.away); // the other team serves first
    });

    test('set 3 uses the sides and serve chosen at its coin toss', () async {
      final e = await newEngine();
      await e.chooseSides(Team.home);
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.away);
      await e.startNewSet();
      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.home);

      final set3 = ScoresheetData.fromEngine(e).sets[2];
      expect(set3.leftAtStart, Team.away);
      expect(set3.firstServe, Team.home);
    });

    test('deciding set: change of sides at 8 splits the rounds', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.away);
      await e.startNewSet();

      // Set 3: away scores 3, then home scores 15 straight.
      await e.chooseFirstServe(Team.home);
      await score(e, Team.away, 3);
      await score(e, Team.home, 8); // home reaches 8 here: teams change ends
      await score(e, Team.home, 7); // ...and goes on to win 15-3

      final data = ScoresheetData.fromEngine(e);
      final set3 = data.sets[2];
      expect(set3.complete, isTrue);
      expect(set3.winner, Team.home);

      final change = set3.change!;
      expect(change.score[Team.home], 8);
      expect(change.score[Team.away], 3);
      expect(change.total, 11);
      expect(change.lineup[Team.home], [1, 3, 5, 7, 9, 11]);

      final home = set3.rounds[Team.home]!;
      expect(home.length, 2);
      expect([home[0].position, home[0].endOwn, home[0].afterChange], [1, 0, false]);
      // Home's second round was still going at the change, so it belongs to
      // the second half of the set.
      expect([home[1].position, home[1].endOwn, home[1].afterChange], [2, 15, true]);

      final away = set3.rounds[Team.away]!;
      expect(away.length, 1);
      expect([away[0].position, away[0].endOwn, away[0].afterChange], [2, 3, false]);

      expect(data.setsWon[Team.home], 2);
      expect(data.matchComplete, isTrue);
    });

    test('sets 1 and 2 never report a change of sides', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);

      final set1 = ScoresheetData.fromEngine(e).sets.single;
      expect(set1.change, isNull);
      expect(set1.rounds[Team.home]!.every((r) => !r.afterChange), isTrue);
    });
  });

  group('ScoresheetPdf', () {
    // These read the real assets: put them in assets/scoresheet/ first.
    final backgroundFile = File('assets/scoresheet/bva_3set_blank.jpg');
    final layoutFile = File('assets/scoresheet/bva_3set_layout.json');

    test('the layout file parses and has every block', () {
      final json = layoutFile.readAsStringSync();
      for (final name in ['S1A', 'S1B', 'S2L', 'S2R', 'S3L', 'S3R', 'S3C']) {
        expect(json.contains('"$name"'), isTrue, reason: 'missing block $name');
      }
    });

    test('builds a PDF for an empty match (everything blank)', () async {
      final e = await newEngine();
      final bytes = await ScoresheetPdf.build(
        ScoresheetData.fromEngine(e),
        background: backgroundFile.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(100000)); // contains the sheet picture
    });

    test('builds a PDF for a full 3-set match', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);
      await e.executeSubstitution(Team.away, 4, 14);
      await e.takeTimeout(Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.away, loserPoints: 22);
      await e.startNewSet();
      await playSet(e, winner: Team.home, loserPoints: 9);

      final bytes = await ScoresheetPdf.build(
        ScoresheetData.fromEngine(e),
        background: backgroundFile.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds a PDF when the away team is Team A', () async {
      final e = await newEngine();
      await e.chooseSides(Team.away);
      await e.chooseFirstServe(Team.away);
      await playSet(e, winner: Team.away, loserPoints: 18);
      await e.startNewSet();
      await playSet(e, winner: Team.home, loserPoints: 21);
      await e.startNewSet();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.away);
      await playSet(e, winner: Team.away, loserPoints: 11);

      final data = ScoresheetData.fromEngine(e);
      expect(data.teamA, Team.away);
      expect(data.winner, Team.away);

      final bytes = await ScoresheetPdf.build(
        data,
        background: backgroundFile.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds a PDF with every signature slot filled', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);

      final ink = <List<List<double>>>[
        [
          [0.05, 0.6],
          [0.2, 0.2],
          [0.35, 0.7],
          [0.6, 0.3],
          [0.9, 0.5],
        ],
        [
          [0.1, 0.92],
          [0.9, 0.9],
        ],
      ];
      final slots = [
        SignatureSlots.captain(Team.home),
        SignatureSlots.coach(Team.home),
        SignatureSlots.captain(Team.away),
        SignatureSlots.coach(Team.away),
        SignatureSlots.ref1,
        SignatureSlots.ref2,
        SignatureSlots.scorer,
        SignatureSlots.assistantScorer,
        ...SignatureSlots.lineJudges,
        SignatureSlots.approvalCaptain(Team.home),
        SignatureSlots.approvalCaptain(Team.away),
      ];
      for (final id in slots) {
        await e.setSignature(id, ink);
      }

      final data = ScoresheetData.fromEngine(e);
      expect(data.signatures.length, 14);

      final bytes = await ScoresheetPdf.build(
        data,
        background: backgroundFile.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds a PDF with match details and team officials', () async {
      final e = await newEngine();
      e.matchInfo = const MatchInfo(
        competition: 'Berkshire Mixed League',
        matchType: 'League',
        matchNumber: '07',
        venue: 'Reading Sports Centre',
        division: '2',
        category: 'mixed',
        juniors: false,
        day: 14,
        month: 11,
        year: 2026,
        hour: 19,
        minute: 30,
      );
      e.officials = {
        Team.home: [const Official('C', 'M. Turner'), const Official('AC', 'P. Singh')],
        Team.away: [const Official('C', 'D. Whitfield')],
      };
      await playSet(e, winner: Team.home);

      final data = ScoresheetData.fromEngine(e);
      expect(data.info.venue, 'Reading Sports Centre');
      expect(data.officials[Team.home]!.length, 2);

      final bytes = await ScoresheetPdf.build(
        data,
        background: backgroundFile.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds a PDF with notes, however long', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);

      for (final notes in [
        'Junior player #7 D. Evans (U16)',
        'Line one\n\nLine three, after a blank line',
        'A very long report. ' * 120,
        'x' * 800,
      ]) {
        await e.setNotes(notes);
        final bytes = await ScoresheetPdf.build(
          ScoresheetData.fromEngine(e),
          background: backgroundFile.readAsBytesSync(),
          layoutJson: layoutFile.readAsStringSync(),
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
      expect(ScoresheetData.fromEngine(e).notes, 'x' * 800);
    });

    test('builds a PDF with notes: short, long, and with odd characters', () async {
      final notes = [
        'Junior player: #7 D. Evans (U16)',
        'Set 2 delayed. ' * 80, // far too long for the box
        'Zoë Müller, naïve café, 日本語, tab\there\r\nnext line',
        '   \n  ', // blank
      ];
      for (final text in notes) {
        final e = await newEngine();
        await playSet(e, winner: Team.home);
        await e.setNotes(text);

        final data = ScoresheetData.fromEngine(e);
        expect(data.notes, text);
        final bytes = await ScoresheetPdf.build(
          data,
          background: backgroundFile.readAsBytesSync(),
          layoutJson: layoutFile.readAsStringSync(),
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
    });

    test('the publisher loads the bundled assets (checks pubspec)', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      final bytes = await ScoresheetPublisher.buildPdf(e);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
