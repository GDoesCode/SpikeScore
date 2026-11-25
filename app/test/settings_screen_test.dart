import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_format.dart';
import 'package:spikescore/screens/settings_screen.dart';

Widget app(MatchEngine e) => ChangeNotifierProvider<MatchEngine>.value(
      value: e,
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MatchEngine> engine() async =>
      MatchEngine(prefs: await SharedPreferences.getInstance());

  SegmentedButton<MatchMode> sets(WidgetTester t) =>
      t.widget(find.byKey(const Key('number-of-sets')));

  testWidgets('the scoresheet and the number of sets share one card',
      (t) async {
    final e = await engine();
    await t.pumpWidget(app(e));
    final card = find.byKey(const Key('sheet-and-format'));
    expect(find.descendant(of: card, matching: find.byKey(const Key('scoresheet-format'))),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const Key('number-of-sets'))),
        findsOneWidget);
  });

  testWidgets('the number of sets is locked to what the sheet holds',
      (t) async {
    final e = await engine();
    await t.pumpWidget(app(e));
    expect(sets(t).onSelectionChanged, isNull);
    expect(sets(t).selected, {MatchMode.localLeague3Set});
    expect(find.textContaining('Set by the BVA scoresheet'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    await t.tap(find.text('FIVB'));
    await t.pumpAndSettle();
    expect(e.scoresheetFormat, ScoresheetFormat.fivb);
    expect(sets(t).selected, {MatchMode.nationalLeague5Set});
    expect(sets(t).onSelectionChanged, isNull);
    expect(find.textContaining('Set by the FIVB scoresheet'), findsOneWidget);
  });
}
