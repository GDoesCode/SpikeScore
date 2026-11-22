import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikescore/match_engine.dart';
import 'package:spikescore/scoresheet/scoresheet_data.dart';
import 'package:spikescore/scoresheet/scoresheet_layout.dart';
import 'package:spikescore/scoresheet/scoresheet_pdf.dart';

/// A clock the test moves by hand.
class FakeClock {
  DateTime now;
  FakeClock(this.now);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

Future<void> score(MatchEngine e, Team team, int n) async {
  for (var i = 0; i < n; i++) {
    await e.scorePoint(team);
  }
}

/// Plays a set that [winner] wins: the first rally is scored at the clock's
/// current time, the winning rally [minutes] later.
Future<void> playSet(
  MatchEngine e,
  FakeClock clock, {
  required Team winner,
  required int minutes,
  int loserPoints = 10,
}) async {
  if (e.needsFirstServe) await e.chooseFirstServe(Team.home);
  await score(e, winner.other, loserPoints);
  await score(e, winner, e.targetPoints - 1);
  clock.advance(Duration(minutes: minutes));
  await e.scorePoint(winner);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MatchEngine> engineAt(FakeClock clock) async => MatchEngine(
        prefs: await SharedPreferences.getInstance(),
        clock: clock.call,
      );

  test('every recorded event is stamped with the time', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 30));
    final e = await engineAt(clock);
    await e.chooseFirstServe(Team.home);
    clock.advance(const Duration(seconds: 40));
    await e.scorePoint(Team.home);

    expect(e.events[0].at, DateTime(2026, 11, 22, 19, 30));
    expect(e.events[1].at, DateTime(2026, 11, 22, 19, 30, 40));
  });

  test('event times survive saving and restoring', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 30, 15));
    final e = await engineAt(clock);
    await e.chooseFirstServe(Team.home);
    await e.scorePoint(Team.away);

    final restored = await engineAt(FakeClock(DateTime(2030)));
    expect(restored.events.length, 2);
    expect(restored.events[1].at, DateTime(2026, 11, 22, 19, 30, 15));
  });

  test('events saved without a time (older app versions) still load', () {
    final old = MatchEvent.fromJson(
        jsonDecode('{"type":"point","team":"home"}') as Map<String, dynamic>);
    expect(old.at, isNull);
    expect(old.toJson().containsKey('at'), isFalse);
  });

  test('a set runs from its first rally to its winning rally', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 0));
    final e = await engineAt(clock);
    await e.chooseFirstServe(Team.home);
    clock.advance(const Duration(minutes: 5)); // warm-up: not counted
    await playSet(e, clock, winner: Team.home, minutes: 22);

    final set1 = ScoresheetData.fromEngine(e).sets.single;
    expect(set1.start, DateTime(2026, 11, 22, 19, 5));
    expect(set1.end, DateTime(2026, 11, 22, 19, 27));
    expect(set1.durationMinutes, 22);
  });

  test('a set in progress has a start but no duration', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 0));
    final e = await engineAt(clock);
    await e.chooseFirstServe(Team.home);
    await score(e, Team.home, 3);

    final data = ScoresheetData.fromEngine(e);
    expect(data.sets.single.start, DateTime(2026, 11, 22, 19, 0));
    expect(data.sets.single.durationMinutes, isNull);
    expect(data.matchStart, DateTime(2026, 11, 22, 19, 0));
    expect(data.matchEnd, isNull);
    expect(data.matchDurationMinutes, isNull);
    expect(data.totalSetMinutes, isNull);
  });

  test('undoing the winning rally clears the set end', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 0));
    final e = await engineAt(clock);
    await playSet(e, clock, winner: Team.home, minutes: 20);
    await e.undo();
    expect(ScoresheetData.fromEngine(e).sets.single.durationMinutes, isNull);

    clock.advance(const Duration(minutes: 1));
    await e.scorePoint(Team.home);
    expect(ScoresheetData.fromEngine(e).sets.single.durationMinutes, 21);
  });

  test('a full match: start, end, set durations and totals', () async {
    final clock = FakeClock(DateTime(2026, 11, 22, 19, 58, 30));
    final e = await engineAt(clock);
    await playSet(e, clock, winner: Team.home, minutes: 24);
    clock.advance(const Duration(minutes: 3)); // interval between sets
    await e.startNewSet();
    await playSet(e, clock, winner: Team.away, minutes: 27);
    clock.advance(const Duration(minutes: 3));
    await e.startNewSet();
    await e.chooseSides(Team.home);
    await e.chooseFirstServe(Team.away);
    await playSet(e, clock, winner: Team.home, minutes: 15);

    final data = ScoresheetData.fromEngine(e);
    expect(data.matchComplete, isTrue);
    expect([for (final s in data.sets) s.durationMinutes], [24, 27, 15]);
    expect(data.totalSetMinutes, 66);
    expect(data.matchStart, DateTime(2026, 11, 22, 19, 58, 30));
    expect(data.matchEnd, DateTime(2026, 11, 22, 21, 10, 30));
    // 19:58 to 21:10, including the two intervals.
    expect(data.matchDurationMinutes, 72);
  });

  test('durations follow the clock minutes written on the sheet', () {
    // 19:59:50 to 20:00:10 is written 19:59 to 20:00: one minute.
    expect(
      minutesBetween(DateTime(2026, 1, 1, 19, 59, 50),
          DateTime(2026, 1, 1, 20, 0, 10)),
      1,
    );
    // Past midnight.
    expect(
      minutesBetween(DateTime(2026, 1, 1, 23, 50), DateTime(2026, 1, 2, 0, 35)),
      45,
    );
  });

  group('PDF', () {
    final background = File('assets/scoresheet/bva_3set_blank.jpg');
    final layoutFile = File('assets/scoresheet/bva_3set_layout.json');

    test('the layout has the duration and time boxes', () {
      final r = SheetLayout.fromJsonString(layoutFile.readAsStringSync()).results;
      expect(r.setDurationX, isNotNull);
      expect(r.totalSetDurationX, isNotNull);
      expect(r.timeBaselineY, isNotNull);
      expect(r.startColonX, isNotNull);
      expect(r.endColonX, isNotNull);
      expect(r.durationHoursRightX, isNotNull);
      expect(r.durationMinutesRightX, isNotNull);
    });

    test('builds a PDF with the match times filled in', () async {
      final clock = FakeClock(DateTime(2026, 11, 22, 19, 58));
      final e = await engineAt(clock);
      await playSet(e, clock, winner: Team.home, minutes: 24);
      await e.startNewSet();
      await playSet(e, clock, winner: Team.home, minutes: 25);

      final bytes = await ScoresheetPdf.build(
        ScoresheetData.fromEngine(e),
        background: background.readAsBytesSync(),
        layoutJson: layoutFile.readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
