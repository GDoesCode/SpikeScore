import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/lite/match_summary.dart';
import 'package:spikescore/lite/match_summary_screen.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_format.dart';
import 'package:spikescore/screens/home_screen.dart';
import 'package:spikescore/screens/settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  var now = DateTime(2026, 11, 27, 19, 0);
  DateTime clock() => now;

  Future<MatchEngine> lite() async => MatchEngine(
      prefs: await SharedPreferences.getInstance(), lite: true, clock: clock);

  Future<void> winSet(MatchEngine e, Team team) async {
    while (!e.isSetComplete) {
      now = now.add(const Duration(seconds: 30));
      await e.scorePoint(team);
    }
  }

  group('Lite engine', () {
    test('teams are Home and Away, with shirt numbers 1 to 14 and no names', () async {
      final e = await lite();
      expect(e.homeTeamSheet.teamName, 'Home');
      expect(e.awayTeamSheet.teamName, 'Away');
      for (final t in Team.values) {
        final sheet = e.sheetOf(t);
        expect(sheet.roster.map((p) => p.number), [for (var n = 1; n <= 14; n++) n]);
        expect(sheet.roster.every((p) => p.name.isEmpty), isTrue);
        expect(sheet.startingLineup, [1, 2, 3, 4, 5, 6]);
        expect(e.officials[t], isEmpty);
      }
    });

    test('play does not wait for signatures', () async {
      final e = await lite();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      expect(e.awaitingPreMatchSignatures, isFalse);
      await e.scorePoint(Team.home);
      expect(e.homeScore, 1);
    });

    test('nothing locks at the end of the match', () async {
      final e = await lite();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      await winSet(e, Team.home);
      await e.startNewSet();
      await winSet(e, Team.home);
      expect(e.isMatchComplete, isTrue);
      expect(e.isSignedOff, isFalse);
      expect(e.canUndo, isTrue);
    });

    test('the full version still waits for the captains', () async {
      final e = MatchEngine(prefs: await SharedPreferences.getInstance(), lite: false);
      expect(e.isLite, isFalse);
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      expect(e.awaitingPreMatchSignatures, isTrue);
    });

    test('the practice match is a finished match with time-outs and subs', () async {
      final e = await lite();
      await e.loadPracticeMatch();
      expect(e.isMatchComplete, isTrue);
      expect(e.events.where((x) => x.type == EventType.sub), isNotEmpty);
      expect(e.events.where((x) => x.type == EventType.timeout), isNotEmpty);
      expect(e.events.every((x) => x.at != null), isTrue);

      // The same match every time, and it survives a restart.
      final first = e.events.map((x) => x.toJson()).toList();
      final again = await lite();
      expect(again.events.map((x) => x.toJson()).toList(), first);
      await again.loadPracticeMatch();
      expect(again.events.length, first.length);
    });

    test('the practice match also works with 5 sets', () async {
      final e = await lite();
      await e.setScoresheetFormat(ScoresheetFormat.fivb);
      await e.loadPracticeMatch();
      expect(e.isMatchComplete, isTrue);
      final s = MatchSummary.of(e);
      expect(s.sets.length, greaterThanOrEqualTo(3));
      expect(s.setsWon[s.winner], 3);
    });
  });

  group('Match summary', () {
    test('set scores, sets won and durations', () async {
      now = DateTime(2026, 11, 27, 19, 0);
      final e = await lite();
      await e.chooseSides(Team.home);
      await e.chooseFirstServe(Team.home);
      await e.takeTimeout(Team.away);
      await winSet(e, Team.home); // 25-0, 25 rallies 30 s apart
      now = now.add(const Duration(minutes: 3));
      await e.startNewSet();
      await e.scorePoint(Team.home);
      await winSet(e, Team.away);

      final s = MatchSummary.of(e);
      expect(s.sets.length, 2);
      expect((s.sets[0].homeScore, s.sets[0].awayScore), (25, 0));
      expect(s.sets[0].timeOuts[Team.away], 1);
      expect(s.sets[0].duration, const Duration(seconds: 25 * 30));
      expect(s.sets[0].winner, Team.home);
      expect(s.sets[0].biggestLead(Team.home), 25);
      expect(s.sets[1].homeScore, 1);
      expect(s.sets[1].awayScore, 25);
      expect(s.sets[1].progression.length, 27);
      expect(s.setsWon, {Team.home: 1, Team.away: 1});
      expect(s.winner, isNull); // best of 3, so a third set is needed
      expect(s.asText(), contains('Set 1: 25-0'));
      expect(s.asText(), contains('not an official scoresheet'));
    });

    test('the practice match summary agrees with the engine', () async {
      final e = await lite();
      await e.loadPracticeMatch();
      final s = MatchSummary.of(e);
      // The engine counts the last set's win once it is over.
      final last = e.winningTeam!;
      expect(s.setsWon[Team.home], e.homeSetsWon + (last == Team.home ? 1 : 0));
      expect(s.setsWon[Team.away], e.awaySetsWon + (last == Team.away ? 1 : 0));
      expect(s.winner, last);
      expect(s.sets.length, e.currentSet);
      expect(s.sets.every((x) => x.finished), isTrue);
      expect(s.duration, isNotNull);
    });
  });

  group('Lite screens', () {
    Widget app(MatchEngine e, Widget home) => ChangeNotifierProvider<MatchEngine>.value(
          value: e,
          child: MaterialApp(home: home),
        );

    testWidgets('the home screen has no team sheets, signatures or PDF', (t) async {
      t.view.physicalSize = const Size(1200, 2000);
      addTearDown(t.view.reset);
      final e = await lite();
      await t.pumpWidget(app(e, const HomeScreen()));
      expect(find.text('SpikeScore Lite'), findsOneWidget);
      expect(find.text('Team sheets'), findsNothing);
      expect(find.text('Team sheet signatures'), findsNothing);
      expect(find.text('Scoresheet (PDF)'), findsNothing);
      expect(find.text('Match summary'), findsOneWidget);
      expect(find.text('Practice match'), findsOneWidget);
      expect(find.text('Full version'), findsOneWidget);
      expect(find.text('Send feedback'), findsOneWidget);
    });

    testWidgets('the full home screen is unchanged', (t) async {
      t.view.physicalSize = const Size(1200, 2000);
      addTearDown(t.view.reset);
      final e = MatchEngine(prefs: await SharedPreferences.getInstance(), lite: false);
      await t.pumpWidget(app(e, const HomeScreen()));
      expect(find.text('SpikeScore'), findsOneWidget);
      expect(find.text('Team sheets'), findsOneWidget);
      expect(find.text('Scoresheet (PDF)'), findsOneWidget);
      expect(find.text('Practice match'), findsNothing);
    });

    testWidgets('the practice match opens its summary', (t) async {
      t.view.physicalSize = const Size(1200, 2000);
      addTearDown(t.view.reset);
      final e = await lite();
      await t.pumpWidget(app(e, const HomeScreen()));
      await t.tap(find.text('Practice match'));
      await t.pumpAndSettle();
      expect(find.byType(MatchSummaryScreen), findsOneWidget);
      final s = MatchSummary.of(e);
      expect(find.text('${s.setsWon[Team.home]} – ${s.setsWon[Team.away]}'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Not an official scoresheet'), 300);
      expect(find.text('Not an official scoresheet'), findsOneWidget);
    });

    testWidgets('Lite settings choose 3 or 5 sets without a scoresheet', (t) async {
      final e = await lite();
      await t.pumpWidget(app(e, const SettingsScreen()));
      expect(find.byKey(const Key('scoresheet-format')), findsNothing);
      await t.tap(find.text('5 sets'));
      await t.pump();
      expect(e.maxSets, 5);
    });
  });
}
