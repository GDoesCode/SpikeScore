import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/demo_data.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_layout.dart';
import 'package:spikescore/scoresheet/scoresheet_data.dart';
import 'package:spikescore/scoresheet/scoresheet_format.dart';
import 'package:spikescore/scoresheet/scoresheet_pdf.dart';
import 'package:spikescore/scoresheet/scoresheet_publisher.dart';
import 'package:spikescore/scoresheet/signature_slots.dart';

Future<MatchEngine> newEngine() async =>
    MatchEngine(prefs: await SharedPreferences.getInstance());

Future<void> score(MatchEngine e, Team team, int n) async {
  for (var i = 0; i < n; i++) {
    await e.scorePoint(team);
  }
}

Future<void> playSet(MatchEngine e,
    {required Team winner, int loserPoints = 10}) async {
  if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
  await score(e, winner.other, loserPoints);
  await score(e, winner, e.targetPoints);
}

/// A full 5-set match, 3:2, with subs, time-outs and a change of ends.
Future<MatchEngine> fiveSetMatch() async {
  final e = await newEngine();
  await e.setScoresheetFormat(ScoresheetFormat.fivb);
  e.matchInfo = const MatchInfo(
    competition: 'National League',
    matchType: 'Pool B',
    matchNumber: '12',
    venue: 'Reading Sports Centre',
    division: 'Premier',
    category: 'women',
    day: 25,
    month: 11,
    year: 2026,
    hour: 19,
    minute: 30,
  );
  e.officials = {
    Team.home: [const Official('C', 'M. Turner'), const Official('AC', 'P. Singh'),
      const Official('M', 'Dr K. Shah')],
    Team.away: [const Official('C', 'D. Whitfield'), const Official('Physio', 'R. Lowe')],
  };
  await e.chooseSides(Team.home);
  await e.chooseFirstServe(Team.home);
  for (var i = 0; i < 9; i++) {
    await e.scorePoint(Team.home);
    await e.scorePoint(Team.away);
  }
  final starter = e.homeTeamSheet.startingLineup[2];
  final bench = e.homeTeamSheet.roster
      .map((p) => p.number)
      .firstWhere((n) => !e.homeTeamSheet.startingLineup.contains(n));
  await e.executeSubstitution(Team.home, starter, bench);
  await e.takeTimeout(Team.away);
  await score(e, Team.home, 16);
  await e.startNewSet();
  await playSet(e, winner: Team.away, loserPoints: 21);
  await e.startNewSet();
  await playSet(e, winner: Team.home, loserPoints: 23);
  await e.startNewSet();
  await playSet(e, winner: Team.away, loserPoints: 18);
  await e.startNewSet();
  await e.chooseSides(Team.away);
  await e.chooseFirstServe(Team.away);
  for (var i = 0; i < 7; i++) {
    await e.scorePoint(Team.home);
    await e.scorePoint(Team.away);
  }
  await score(e, Team.home, 8);
  await e.setNotes('Set 4 started 5 minutes late (floor wet).');
  await e.setMvp(Team.home, e.homeTeamSheet.startingLineup.first);
  await e.setMvp(Team.away, e.awayTeamSheet.startingLineup.first);
  final ink = <List<List<double>>>[
    [
      [0.05, 0.6],
      [0.2, 0.2],
      [0.35, 0.7],
      [0.6, 0.3],
      [0.9, 0.5],
    ],
  ];
  for (final id in [
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
  ]) {
    await e.setSignature(id, ink);
  }
  return e;
}

/// Writes [bytes] to $SPIKESCORE_PDF_OUT/[name] when that is set, so the
/// sheet can be looked at.
void keep(String name, List<int> bytes) {
  final dir = Platform.environment['SPIKESCORE_PDF_OUT'];
  if (dir != null) File('$dir/$name').writeAsBytesSync(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final background = File('assets/scoresheet/fivb_5set_blank.jpg');
  final layoutFile = File('assets/scoresheet/fivb_5set_layout.json');
  SheetLayout layout() => SheetLayout.fromJsonString(layoutFile.readAsStringSync());

  Future<List<int>> buildFivb(ScoresheetData data) => ScoresheetPdf.build(
        data,
        background: background.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );

  group('FIVB layout file', () {
    test('has two blocks per normal set and three for set 5', () {
      final l = layout();
      for (final n in [1, 2, 3, 4]) {
        expect(l.blocks.keys, containsAll(['S${n}L', 'S${n}R']));
        expect(l.block('S${n}L').maxPoint, 48);
        expect(l.block('S${n}L').rounds.every((c) => c.length == 8), isTrue);
      }
      // The left team only reaches 8 before the change of courts.
      expect(l.block('S5L').maxPoint, 8);
      expect(l.block('S5R').maxPoint, 30);
      expect(l.block('S5C').maxPoint, 30);
      expect(l.block('S5L').rounds.every((c) => c.length == 6), isTrue);
      expect(l.block('S5C').changeBox, isNotNull);
      expect(l.blocks.length, 11);
      expect(l.results.setRows.length, 5);
      expect(l.setTimes.keys, containsAll([1, 2, 3, 4, 5]));
      expect(l.officials.roleRows.keys, containsAll(['C', 'AC1', 'AC2', 'T', 'M']));
      expect(l.players.rows.length, 14);
    });

    test('sets 1 to 4 have the team letters printed, set 5 has blank circles', () {
      final l = layout();
      expect(l.block('S1L').printedLetter, 'A');
      expect(l.block('S2L').printedLetter, 'B');
      expect(l.block('S3L').printedLetter, 'A');
      expect(l.block('S4L').printedLetter, 'B');
      expect(l.block('S5L').printedLetter, isNull);
    });

    test('every box is on the page and every signature slot has a box', () {
      final l = layout();
      void onPage(List<double> b, String what) {
        expect(b[0] >= 0 && b[2] <= l.pageWidth, isTrue, reason: what);
        expect(b[1] >= 0 && b[3] <= l.pageHeight, isTrue, reason: what);
        expect(b[0] < b[2] && b[1] < b[3], isTrue, reason: what);
      }

      l.signatures.forEach((k, b) => onPage(b, 'signature $k'));
      for (final b in l.blocks.values) {
        for (final col in b.rounds) {
          for (final cell in col) {
            onPage(cell, 'round box of ${b.set}${b.side}');
          }
        }
        b.grid.forEach((n, box) => onPage(box, 'point $n'));
      }
      for (final key in [
        'captainLeft', 'coachLeft', 'captainRight', 'coachRight',
        'ref1', 'ref2', 'scorer', 'assistantScorer',
        'lineJudge1', 'lineJudge2', 'lineJudge3', 'lineJudge4',
        'approvalCaptainA', 'approvalCaptainB',
      ]) {
        expect(l.signatures.containsKey(key), isTrue, reason: key);
      }
      expect(l.remarksRows.length, greaterThanOrEqualTo(6));
    });
  });

  group('ScoresheetFormat', () {
    test('BVA fits 3 sets only, FIVB 5 sets only', () {
      expect(ScoresheetFormat.bva.fits(3), isTrue);
      expect(ScoresheetFormat.bva.fits(5), isFalse);
      expect(ScoresheetFormat.fivb.fits(3), isFalse);
      expect(ScoresheetFormat.fivb.fits(5), isTrue);
    });

    test('BVA is the default and the choice is saved', () async {
      final e = await newEngine();
      expect(e.scoresheetFormat, ScoresheetFormat.bva);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      final again = await newEngine();
      expect(again.scoresheetFormat, ScoresheetFormat.fivb);
    });

    test('choosing a sheet sets the number of sets it has room for', () async {
      final e = await newEngine();
      expect(e.maxSets, 3);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      expect(e.matchMode, MatchMode.nationalLeague5Set);
      expect(e.maxSets, 5);
      await e.setScoresheetFormat(ScoresheetFormat.bva);
      expect(e.matchMode, MatchMode.localLeague3Set);
      expect(e.maxSets, 3);
    });

    test('the number of sets cannot be changed away from the sheet', () async {
      final e = await newEngine();
      await e.setMatchMode(MatchMode.nationalLeague5Set); // BVA: 3 only
      expect(e.maxSets, 3);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      await e.setMatchMode(MatchMode.localLeague3Set); // FIVB: 5 only
      expect(e.maxSets, 5);
      expect(ScoresheetFormat.bva.setsAreChoosable, isFalse);
      expect(ScoresheetFormat.fivb.setsAreChoosable, isFalse);
    });

    test('during a match only a sheet with room for it can be chosen', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      expect(e.canUseScoresheet(ScoresheetFormat.bva), isTrue);
      expect(e.canUseScoresheet(ScoresheetFormat.fivb), isFalse);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      expect(e.scoresheetFormat, ScoresheetFormat.bva);
      expect(e.maxSets, 3);
    });

    test('old settings with a sheet that does not fit get a sheet that does',
        () async {
      SharedPreferences.setMockInitialValues({
        'spikescore_settings_v1':
            '{"mode":"nationalLeague5Set","rules":{},"sheet":"bva"}',
      });
      final e = await newEngine();
      expect(e.maxSets, 5); // the number of sets is kept
      expect(e.scoresheetFormat, ScoresheetFormat.fivb);
    });
  });

  group('ScoresheetData for 5 sets', () {
    test('set 5 is the deciding set, with a change of ends at 8', () async {
      final e = await fiveSetMatch();
      final data = ScoresheetData.fromEngine(e);
      expect(data.decidingSet, 5);
      expect(data.sets.length, 5);
      expect(data.sets[2].change, isNull); // set 3 is a normal set here
      expect(data.sets[4].change, isNotNull);
      expect(data.sets[4].change!.score[Team.home], 8);
      expect(data.sets[4].change!.score[Team.away], 7);
      expect(data.setsWon[Team.home], 3);
      expect(data.matchComplete, isTrue);
      expect(data.winner, Team.home);
    });

    test('two sets won is not a 5-set match win', () async {
      final e = await newEngine();
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      await playSet(e, winner: Team.home);
      await e.startNewSet();
      await playSet(e, winner: Team.home);
      final data = ScoresheetData.fromEngine(e);
      expect(data.matchComplete, isFalse);
      expect(data.winner, isNull);
    });
  });

  group('ScoresheetPdf.buildFivb', () {
    test('builds an empty 5-set sheet', () async {
      final e = await newEngine();
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      final bytes = await buildFivb(ScoresheetData.fromEngine(e));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      keep('fivb_blank.pdf', bytes);
    });

    test('builds a full 5-set match', () async {
      final e = await fiveSetMatch();
      final bytes = await buildFivb(ScoresheetData.fromEngine(e));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      keep('fivb_5set.pdf', bytes);
    });

    test('the publisher uses the sheet chosen in settings', () async {
      final e = await fiveSetMatch();
      final fivb = await ScoresheetPublisher.buildPdf(e);
      expect(String.fromCharCodes(fivb.take(5)), '%PDF-');
      expect(fivb.length, greaterThan(1000000)); // the FIVB sheet picture

      final bva = await newEngine();
      await bva.setScoresheetFormat(ScoresheetFormat.bva);
      await bva.setMatchMode(MatchMode.localLeague3Set);
      await bva.resetMatch();
      await playSet(bva, winner: Team.home);
      final bytes = await ScoresheetPublisher.buildPdf(bva);
      expect(bytes.length, greaterThan(100000)); // the BVA sheet picture
      expect(bytes.length, lessThan(fivb.length));
    });
  });
}
