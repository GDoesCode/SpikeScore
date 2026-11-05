import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adjust these paths if your test folder isn't next to lib/.
import 'package:spikescore/demo_data.dart';
import 'package:spikescore/match_engine.dart';
import 'package:spikescore/models.dart';

/// A team as it would appear in demo_data.json.
Map<String, dynamic> teamJson(
  String id, {
  List<int> numbers = const [1, 2, 3, 4, 5, 6, 7],
  Object? lineup,
  String liberoNumber = '',
}) =>
    {
      'id': id,
      'name': 'Team $id',
      'players': [
        for (final n in numbers)
          {
            'number': n,
            'name': 'P$n',
            'position': n.toString() == liberoNumber ? 'Libero' : 'Outside Hitter',
          },
      ],
      'startingLineup': ?lineup,
    };

String fileJson({
  Map<String, dynamic> match = const {},
  List<Map<String, dynamic>>? teams,
}) =>
    jsonEncode({
      'match': match,
      'teams': teams ?? [teamJson('a'), teamJson('b'), teamJson('c')],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DemoData.parse', () {
    test('the shipped demo file is valid and fits the sheet', () {
      final text = File('assets/demo/demo_data.json').readAsStringSync();
      final data = DemoData.parse(text);

      for (final team in [data.home, data.away]) {
        expect(team.sheet.roster.length, inInclusiveRange(6, 13),
            reason: '${team.sheet.teamName}: the sheet has room for 13 players');
        expect(team.sheet.startingLineup.length, 6);
        expect(team.officials.length, lessThanOrEqualTo(4));
      }
      expect(data.home.id, isNot(data.away.id));
      expect(data.info.competition, isNotEmpty);
    });

    test('every team in the shipped file can be chosen', () {
      final raw = jsonDecode(File('assets/demo/demo_data.json').readAsStringSync())
          as Map<String, dynamic>;
      final ids = [for (final t in raw['teams'] as List) (t as Map)['id'] as String];
      expect(ids.length, greaterThanOrEqualTo(2));

      for (final id in ids) {
        raw['match'] = {...raw['match'] as Map<String, dynamic>, 'home': id, 'away': ids.firstWhere((x) => x != id)};
        final data = DemoData.parse(jsonEncode(raw));
        expect(data.home.id, id);
      }
    });

    test('reads the match details', () {
      final data = DemoData.parse(fileJson(match: {
        'competition': 'League',
        'venue': 'Hall',
        'matchNumber': 7,
        'division': '2',
        'category': 'Mixed',
        'juniors': true,
        'date': '2026-11-14',
        'time': '19:30',
        'home': 'a',
        'away': 'b',
      }));

      expect(data.info.competition, 'League');
      expect(data.info.venue, 'Hall');
      expect(data.info.matchNumber, '7');
      expect(data.info.category, 'mixed');
      expect(data.info.juniors, isTrue);
      expect([data.info.year, data.info.month, data.info.day], [2026, 11, 14]);
      expect([data.info.hour, data.info.minute], [19, 30]);
    });

    test('missing or odd details stay blank', () {
      final data = DemoData.parse(fileJson(match: {
        'date': 'next Saturday',
        'time': 'evening',
        'category': 'all sorts',
      }));

      expect(data.info.competition, '');
      expect(data.info.day, isNull);
      expect(data.info.hour, isNull);
      expect(data.info.category, '');
      expect(data.info.juniors, isFalse);
    });

    test('picks the teams named in the match, otherwise the first two', () {
      final named = DemoData.parse(fileJson(match: {'home': 'c', 'away': 'a'}));
      expect([named.home.id, named.away.id], ['c', 'a']);

      final unnamed = DemoData.parse(fileJson());
      expect([unnamed.home.id, unnamed.away.id], ['a', 'b']);

      final unknown = DemoData.parse(fileJson(match: {'home': 'nope', 'away': 'nada'}));
      expect([unknown.home.id, unknown.away.id], ['a', 'b']);
    });

    test('the same team can not play itself', () {
      final data = DemoData.parse(fileJson(match: {'home': 'b', 'away': 'b'}));
      expect(data.home.id, 'b');
      expect(data.away.id, isNot('b'));
    });

    test('uses the starting lineup from the file when it is valid', () {
      final data = DemoData.parse(fileJson(teams: [
        teamJson('a', lineup: [7, 6, 5, 4, 3, 2]),
        teamJson('b'),
      ]));
      expect(data.home.sheet.startingLineup, [7, 6, 5, 4, 3, 2]);
    });

    test('a missing or wrong lineup falls back to the first six non-liberos', () {
      final data = DemoData.parse(fileJson(teams: [
        teamJson('a', numbers: [4, 5, 6, 7, 8, 9, 10], liberoNumber: '4'),
        teamJson('b', lineup: [1, 1, 2, 3, 4, 5]), // repeats a number
      ]));
      expect(data.home.sheet.startingLineup, [5, 6, 7, 8, 9, 10]);
      expect(data.away.sheet.startingLineup, [1, 2, 3, 4, 5, 6]);
    });

    test('reads the officials', () {
      final a = teamJson('a')
        ..['officials'] = [
          {'role': 'C', 'name': 'M. Turner'},
          {'role': 'AC', 'name': 'P. Singh'},
        ];
      final data = DemoData.parse(fileJson(teams: [a, teamJson('b')]));
      expect(data.home.officials.map((o) => '${o.role}:${o.name}'), ['C:M. Turner', 'AC:P. Singh']);
      expect(data.away.officials, isEmpty);
    });

    test('rejects a repeated shirt number, with the team named', () {
      expect(
        () => DemoData.parse(fileJson(teams: [
          teamJson('a', numbers: [1, 2, 3, 4, 5, 6, 6]),
          teamJson('b'),
        ])),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Team a'))),
      );
    });

    test('rejects too few teams or players', () {
      expect(() => DemoData.parse(fileJson(teams: [teamJson('a')])), throwsFormatException);
      expect(
        () => DemoData.parse(fileJson(teams: [teamJson('a', numbers: [1, 2, 3]), teamJson('b')])),
        throwsFormatException,
      );
    });

    test('rejects text that is not JSON, in plain English', () {
      expect(
        () => DemoData.parse('{ "match": '),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('not valid JSON'))),
      );
    });
  });

  group('saved match vs. team changes', () {
    test('a saved match is dropped when the teams change, and kept when they do not', () async {
      final prefs = await SharedPreferences.getInstance();

      final a = MatchEngine(prefs: prefs);
      await a.chooseFirstServe(Team.home);
      await a.scorePoint(Team.home);
      await a.scorePoint(Team.home);
      expect(a.homeScore, 2);

      // Same teams: the match comes back.
      final same = MatchEngine(prefs: prefs);
      expect(same.homeScore, 2);

      // A different home team: the old match no longer fits, so it is dropped.
      final other = TeamSheet(
        teamName: 'Someone Else',
        roster: a.homeTeamSheet.roster,
        startingLineup: a.homeTeamSheet.startingLineup,
      );
      final changed = MatchEngine(prefs: prefs, homeTeam: other);
      expect(changed.homeScore, 0);
      expect(changed.canUndo, isFalse);
    });
  });
}
