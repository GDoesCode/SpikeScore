import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/demo_data.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/fivb_sheet.dart';
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
  await e.setMatchMode(MatchMode.nationalLeague5Set);
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

  group('FivbSheet layout', () {
    test('a 5-set sheet has two blocks per normal set and three for set 5', () {
      final l = FivbSheet.build(maxSets: 5).layout;
      for (final n in [1, 2, 3, 4]) {
        expect(l.blocks.keys, containsAll(['S${n}L', 'S${n}R']));
        expect(l.block('S${n}L').maxPoint, 48);
      }
      expect(l.blocks.keys, containsAll(['S5L', 'S5R', 'S5C']));
      expect(l.block('S5L').maxPoint, 30);
      expect(l.block('S5C').changeBox, isNotNull);
      expect(l.blocks.length, 11);
      expect(l.results.setRows.length, 5);
      expect(l.setTimes.keys, [1, 2, 3, 4, 5]);
    });

    test('a 3-set sheet has sets 1 and 2 and the deciding set 3', () {
      final l = FivbSheet.build(maxSets: 3).layout;
      expect(l.blocks.keys.toSet(),
          {'S1L', 'S1R', 'S2L', 'S2R', 'S3L', 'S3R', 'S3C'});
      expect(l.results.setRows.length, 3);
    });

    test('every box is on the page and every signature slot has a box', () {
      for (final sets in [3, 5]) {
        final l = FivbSheet.build(maxSets: sets).layout;
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
      }
    });

    test('set panels do not overlap the boxes below them', () {
      final l = FivbSheet.build(maxSets: 5).layout;
      final lowest = l.blocks.values
          .expand((b) => b.grid.values)
          .map((g) => g[3])
          .reduce((a, b) => a > b ? a : b);
      expect(lowest, lessThan(l.results.setRows.first[0]));
    });
  });

  group('ScoresheetFormat', () {
    test('BVA fits 3 sets only, FIVB fits 3 or 5', () {
      expect(ScoresheetFormat.bva.fits(3), isTrue);
      expect(ScoresheetFormat.bva.fits(5), isFalse);
      expect(ScoresheetFormat.fivb.fits(3), isTrue);
      expect(ScoresheetFormat.fivb.fits(5), isTrue);
    });

    test('BVA is the default and the choice is saved', () async {
      final e = await newEngine();
      expect(e.scoresheetFormat, ScoresheetFormat.bva);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      final again = await newEngine();
      expect(again.scoresheetFormat, ScoresheetFormat.fivb);
    });

    test('the sheet can be changed during a match', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home);
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
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
      await e.setMatchMode(MatchMode.nationalLeague5Set);
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
      await e.setMatchMode(MatchMode.nationalLeague5Set);
      final bytes = await ScoresheetPdf.buildFivb(ScoresheetData.fromEngine(e));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      keep('fivb_blank.pdf', bytes);
    });

    test('builds a full 5-set match', () async {
      final e = await fiveSetMatch();
      final bytes = await ScoresheetPdf.buildFivb(ScoresheetData.fromEngine(e));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      keep('fivb_5set.pdf', bytes);
    });

    test('builds a full 3-set match on the FIVB sheet', () async {
      final e = await newEngine();
      await playSet(e, winner: Team.home, loserPoints: 20);
      await e.startNewSet();
      await playSet(e, winner: Team.away, loserPoints: 22);
      await e.startNewSet();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      await playSet(e, winner: Team.home, loserPoints: 9);
      final data = ScoresheetData.fromEngine(e);
      expect(data.decidingSet, 3);
      final bytes = await ScoresheetPdf.buildFivb(data);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      keep('fivb_3set.pdf', bytes);
    });

    test('the publisher uses the sheet chosen in settings', () async {
      final e = await fiveSetMatch();
      final fivb = await ScoresheetPublisher.buildPdf(e);
      expect(String.fromCharCodes(fivb.take(5)), '%PDF-');
      // The FIVB sheet is drawn, not a picture, so it is far smaller.
      expect(fivb.length, lessThan(100000));

      final bva = await newEngine();
      await bva.setScoresheetFormat(ScoresheetFormat.bva);
      await bva.setMatchMode(MatchMode.localLeague3Set);
      await bva.resetMatch();
      await playSet(bva, winner: Team.home);
      final bytes = await ScoresheetPublisher.buildPdf(bva);
      expect(bytes.length, greaterThan(100000)); // the BVA sheet picture
    });
  });
}
