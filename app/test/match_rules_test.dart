import 'package:flutter_test/flutter_test.dart';

// Adjust this path if your test folder isn't next to lib/.
import 'package:spikescore/match_rules.dart';

void main() {
  group('MatchRules', () {
    test('the defaults are the standard BVA rules', () {
      const rules = MatchRules();
      expect(rules.pointsPerSet, 25);
      expect(rules.decidingSetPoints, 15);
      expect(rules.winByTwo, isTrue);
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
      expect(changed.winByTwo, isTrue);
      expect(changed.timeOutsPerSet, 2);
      expect(changed.subsPerSet, 8);
    });

    test('win by 2 can be switched off and on', () {
      final off = MatchRules.defaults.copyWith(winByTwo: false);
      expect(off.winByTwo, isFalse);
      expect(off.pointsPerSet, 25); // nothing else changed
      expect(off.copyWith(winByTwo: true).winByTwo, isTrue);
      expect(off.clamped().winByTwo, isFalse);
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
        winByTwo: false,
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
          'winByTwo': 'maybe',
        }),
        MatchRules.defaults,
      );
    });

    test('reads win by 2 from the old JSON key', () {
      expect(MatchRules.fromJson({'decidingSetWinByTwo': false}).winByTwo, isFalse);
      expect(MatchRules.fromJson({'decidingSetWinByTwo': true}).winByTwo, isTrue);
      expect(MatchRules.defaults.toJson().containsKey('decidingSetWinByTwo'), isFalse);
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
      expect(const MatchRules(winByTwo: false), isNot(MatchRules.defaults));
    });
  });
}
