import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/signature_slots.dart';
import 'package:spikescore/screen_orientation.dart';
import 'package:spikescore/screens/match_screen.dart';
import 'package:spikescore/screens/referee_override.dart';
import 'package:spikescore/screens/sign_off_screen.dart';

const ink = <List<List<double>>>[
  [
    [0.1, 0.2],
    [0.5, 0.6],
  ],
];

/// A typical phone held sideways, as the match screen is used.
void landscapePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1080);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Widget app(MatchEngine e, Widget home) => ChangeNotifierProvider<MatchEngine>.value(
      value: e,
      child: MaterialApp(home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('before the match only the captains and coaches are shown',
      (tester) async {
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await tester.pumpWidget(app(e, const SignOffScreen()));
    expect(find.text('Confirm team sheets'), findsOneWidget);
    expect(find.text('Open team sheets'), findsOneWidget);
    expect(find.text('Home Team captain'), findsOneWidget);
    expect(find.text('1st referee'), findsNothing);
    expect(find.text('Line judge 1'), findsNothing);
  });

  testWidgets('after the match the approval table is shown', (tester) async {
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await e.setSignature(SignatureSlots.captain(Team.home), ink);
    await tester.pumpWidget(
        app(e, const SignOffScreen(stage: SignOffStage.postMatch)));
    expect(find.text('Sign the scoresheet'), findsOneWidget);
    expect(find.text('1st referee'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Line judge 4'), 100);
    expect(find.text('Line judge 4'), findsOneWidget);
  });

  testWidgets('the coin toss brings up the team sheet signatures', (tester) async {
    landscapePhone(tester);
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await tester.pumpWidget(app(e, const MatchScreen()));
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    await tester.pumpAndSettle();
    expect(find.text('Confirm team sheets'), findsOneWidget);

    await e.setSignature(SignatureSlots.captain(Team.home), ink);
    await e.setSignature(SignatureSlots.captain(Team.away), ink);
    await tester.pump();
    await tester.ensureVisible(find.text('Start the match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start the match'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm team sheets'), findsNothing);
    expect(find.text('Waiting for the team sheet signatures'), findsNothing);
  });

  testWidgets('without signatures the scoreboard stays locked', (tester) async {
    landscapePhone(tester);
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await tester.pumpWidget(app(e, const MatchScreen()));
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Waiting for the team sheet signatures'), findsOneWidget);
  });

  testWidgets('a captain picks the other team\'s MVP, then signs', (tester) async {
    landscapePhone(tester);
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    for (var set = 1; set <= 2; set++) {
      if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
      while (!e.isSetComplete) {
        await e.scorePoint(Team.home);
      }
      if (!e.isMatchComplete) await e.startNewSet();
    }
    await tester.pumpWidget(
        app(e, const SignOffScreen(stage: SignOffStage.postMatch)));
    final tile = find.text('Home Team captain');
    await tester.scrollUntilVisible(tile, 100);
    await tester.pumpAndSettle();
    expect(find.textContaining('MVP for Away Team: not picked yet'), findsOneWidget);

    ScreenOrientation.set(ScreenOrientation.landscape); // as from the match
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('MVP for Away Team'), findsOneWidget);
    expect(ScreenOrientation.current, ScreenOrientation.portrait);
    expect(find.text('#16  Q. Hall'), findsNothing); // never played
    await tester.scrollUntilVisible(find.text('#8  M. White'), 60,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('#8  M. White'));
    await tester.pumpAndSettle();
    expect(e.mvpOf(Team.away), 8);
    expect(ScreenOrientation.current, ScreenOrientation.landscape);
    expect(find.text('Home Team captain: sign to confirm'), findsNothing);
    expect(find.text('Sign with your finger in the white box.'), findsOneWidget);
  });

  testWidgets('the signatures page says Continue match once play has started',
      (tester) async {
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    await e.setSignature(SignatureSlots.captain(Team.home), ink);
    await e.setSignature(SignatureSlots.captain(Team.away), ink);
    await tester.pumpWidget(app(e, const SignOffScreen()));
    expect(find.text('Start the match'), findsOneWidget);

    await e.scorePoint(Team.home);
    await tester.pump();
    expect(find.text('Start the match'), findsNothing);
    expect(find.text('Continue match'), findsOneWidget);
  });

  testWidgets('a finished set can always get its pop-up back', (tester) async {
    landscapePhone(tester);
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    await e.waivePreMatchSignatures(referee: '1st referee');
    while (!e.isSetComplete) {
      await e.scorePoint(Team.home);
    }
    await tester.pumpWidget(app(e, const MatchScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Next set'), findsOneWidget);

    await tester.tap(find.text('Next set'));
    await tester.pumpAndSettle();
    expect(find.text('Set 1 Complete!'), findsOneWidget);
  });

  testWidgets('the referee score editor fits a sideways phone', (tester) async {
    // A smaller phone than landscapePhone: 780 x 360 points.
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3; // larger text setting
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final e = MatchEngine(prefs: await SharedPreferences.getInstance());
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.home);
    await tester.pumpWidget(app(e, Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showRefereeOverride(context),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Change the score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change the score'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1st referee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st referee'));
    await tester.pumpAndSettle();
    // The signature pad is the CustomPaint that fills its box.
    final pad = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == Size.infinite);
    await tester.drag(pad, const Offset(80, 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Set 1: change the score'), findsOneWidget);
    expect(find.text('Away Team'), findsWidgets);
    // Any overflow would have failed the test with a layout error.
  });
}
