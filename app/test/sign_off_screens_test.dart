import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/signature_slots.dart';
import 'package:spikescore/screens/match_screen.dart';
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
}
