import 'package:flutter_test/flutter_test.dart';

// Adjust this path if your test folder isn't next to lib/.
import 'package:spikescore/match_rules.dart';

void main() {
  group('MatchRules', () {
    test('the defaults are the standard BVA rules', () {
      const rules = MatchRules();
      expect(rules.pointsPerSet, 25);
      expect(rules.decidingSetPoints, 15);
      expect(rules.decidingSetWinByTwo, isTrue);
      expect(rules.timeOutsPerSet, 2);
      expect(rules.subsPerSet, 8);
      expect(rules, MatchRules.defaults);
    });

    test('teams change ends at half the deciding set, rounded up', () {
      expect(const MatchRules(decidingSetPoints: 15).changeEndsAt, 8);
      expect(const MatchRules(decidingSetPoints: 11).changeEndsAt, 6);
      expect(const MatchRules(decidingSetPoints: 10).changeEndsAt, 5);
    });

    test('clamped() pulls every value back into range', () {
      expect(
        const MatchRules(
          pointsPerSet: 99,
          decidingSetPoints: 99,
          timeOutsPerSet: 9,
          subsPerSet: 99,
        ).clamped(),
        const MatchRules(
          pointsPerSet: MatchRules.maxPointsPerSet,
          decidingSetPoints: MatchRules.maxDecidingSetPoints,
          timeOutsPerSet: MatchRules.maxTimeOutsPerSet,
          subsPerSet: MatchRules.maxSubsPerSet,
        ),
      );
      expect(
        const MatchRules(
          pointsPerSet: 0,
          decidingSetPoints: 0,
          timeOutsPerSet: -1,
          subsPerSet: -5,
        ).clamped(),
        const MatchRules(
          pointsPerSet: MatchRules.minPointsPerSet,
          decidingSetPoints: MatchRules.minDecidingSetPoints,
          timeOutsPerSet: 0,
          subsPerSet: 0,
        ),
      );
    });

    test('copyWith changes one value and keeps the rest', () {
      final changed = MatchRules.defaults.copyWith(pointsPerSet: 21);
      expect(changed.pointsPerSet, 21);
      expect(changed.decidingSetPoints, 15);
      expect(changed.decidingSetWinByTwo, isTrue);
      expect(changed.timeOutsPerSet, 2);
      expect(changed.subsPerSet, 8);
    });

    test('win by 2 in the tie-break can be switched off and on', () {
      final off = MatchRules.defaults.copyWith(decidingSetWinByTwo: false);
      expect(off.decidingSetWinByTwo, isFalse);
      expect(off.pointsPerSet, 25); // nothing else changed
      expect(off.copyWith(decidingSetWinByTwo: true).decidingSetWinByTwo, isTrue);
      expect(off.clamped().decidingSetWinByTwo, isFalse);
    });

    test('copyWith never goes outside the allowed range', () {
      expect(MatchRules.defaults.copyWith(pointsPerSet: 100).pointsPerSet,
          MatchRules.maxPointsPerSet);
      expect(MatchRules.defaults.copyWith(timeOutsPerSet: 5).timeOutsPerSet,
          MatchRules.maxTimeOutsPerSet);
    });

    test('survives a trip through JSON', () {
      const rules = MatchRules(
        pointsPerSet: 21,
        decidingSetPoints: 11,
        decidingSetWinByTwo: false,
        timeOutsPerSet: 1,
        subsPerSet: 4,
      );
      expect(MatchRules.fromJson(rules.toJson()), rules);
    });

    test('missing or odd JSON falls back to the defaults', () {
      expect(MatchRules.fromJson({}), MatchRules.defaults);
      expect(
        MatchRules.fromJson({
          'pointsPerSet': 'lots',
          'subsPerSet': null,
          'decidingSetWinByTwo': 'maybe',
        }),
        MatchRules.defaults,
      );
    });

    test('out-of-range JSON is clamped', () {
      final rules = MatchRules.fromJson({'pointsPerSet': 500, 'timeOutsPerSet': 50});
      expect(rules.pointsPerSet, MatchRules.maxPointsPerSet);
      expect(rules.timeOutsPerSet, MatchRules.maxTimeOutsPerSet);
    });

    test('equal rules are equal and hash the same', () {
      const a = MatchRules(pointsPerSet: 21);
      const b = MatchRules(pointsPerSet: 21);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(MatchRules.defaults));
      expect(const MatchRules(decidingSetWinByTwo: false), isNot(MatchRules.defaults));
    });
  });
}
