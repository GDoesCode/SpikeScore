/// The numbers that differ between competitions. The Settings screen edits
/// these, the engine applies them and the PDF follows them.
///
/// Every value is kept inside a range the paper sheet can hold: for example
/// the deciding set can't go past 15 because the sheet's box for the team
/// that changes ends has room for 8 points before the change.
class MatchRules {
  static const int minPointsPerSet = 15;
  static const int maxPointsPerSet = 30;
  static const int minDecidingSetPoints = 10;
  static const int maxDecidingSetPoints = 15;
  static const int maxTimeOutsPerSet = 2; // the sheet has two boxes per team
  static const int maxSubsPerSet = 12; // six positions, two changes each

  /// Points needed to win a normal set.
  final int pointsPerSet;

  /// Points needed to win the deciding set (the tie-break).
  final int decidingSetPoints;

  /// True: every set, the tie-break included, goes on until a team leads by 2.
  /// False: the first team to reach the set's target ([pointsPerSet], or
  /// [decidingSetPoints] in the tie-break) wins it.
  final bool winByTwo;

  /// Time-outs each team may take in a set.
  final int timeOutsPerSet;

  /// Substitutions each team may make in a set.
  final int subsPerSet;

  const MatchRules({
    this.pointsPerSet = 25,
    this.decidingSetPoints = 15,
    this.winByTwo = true,
    this.timeOutsPerSet = 2,
    this.subsPerSet = 8,
  });

  static const MatchRules defaults = MatchRules();

  /// In the deciding set the teams change ends when a team reaches this score:
  /// half the set, rounded up (8 in a set to 15).
  int get changeEndsAt => (decidingSetPoints + 1) ~/ 2;

  static int _limit(int value, int lo, int hi) =>
      value < lo ? lo : (value > hi ? hi : value);

  /// The same rules with every value pulled back into its allowed range.
  MatchRules clamped() => MatchRules(
        pointsPerSet: _limit(pointsPerSet, minPointsPerSet, maxPointsPerSet),
        decidingSetPoints:
            _limit(decidingSetPoints, minDecidingSetPoints, maxDecidingSetPoints),
        winByTwo: winByTwo,
        timeOutsPerSet: _limit(timeOutsPerSet, 0, maxTimeOutsPerSet),
        subsPerSet: _limit(subsPerSet, 0, maxSubsPerSet),
      );

  MatchRules copyWith({
    int? pointsPerSet,
    int? decidingSetPoints,
    bool? winByTwo,
    int? timeOutsPerSet,
    int? subsPerSet,
  }) =>
      MatchRules(
        pointsPerSet: pointsPerSet ?? this.pointsPerSet,
        decidingSetPoints: decidingSetPoints ?? this.decidingSetPoints,
        winByTwo: winByTwo ?? this.winByTwo,
        timeOutsPerSet: timeOutsPerSet ?? this.timeOutsPerSet,
        subsPerSet: subsPerSet ?? this.subsPerSet,
      ).clamped();

  Map<String, dynamic> toJson() => {
        'pointsPerSet': pointsPerSet,
        'decidingSetPoints': decidingSetPoints,
        'winByTwo': winByTwo,
        'timeOutsPerSet': timeOutsPerSet,
        'subsPerSet': subsPerSet,
      };

  /// Missing or odd values fall back to the defaults.
  factory MatchRules.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) {
      final value = json[key];
      return value is num ? value.toInt() : fallback;
    }

    // Older saves called this 'decidingSetWinByTwo'; read that if present.
    final winByTwo = json['winByTwo'] ?? json['decidingSetWinByTwo'];

    return MatchRules(
      pointsPerSet: read('pointsPerSet', defaults.pointsPerSet),
      decidingSetPoints: read('decidingSetPoints', defaults.decidingSetPoints),
      winByTwo: winByTwo is bool ? winByTwo : defaults.winByTwo,
      timeOutsPerSet: read('timeOutsPerSet', defaults.timeOutsPerSet),
      subsPerSet: read('subsPerSet', defaults.subsPerSet),
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      other is MatchRules &&
      other.pointsPerSet == pointsPerSet &&
      other.decidingSetPoints == decidingSetPoints &&
      other.winByTwo == winByTwo &&
      other.timeOutsPerSet == timeOutsPerSet &&
      other.subsPerSet == subsPerSet;

  @override
  int get hashCode => Object.hash(
        pointsPerSet,
        decidingSetPoints,
        winByTwo,
        timeOutsPerSet,
        subsPerSet,
      );

  @override
  String toString() =>
      'MatchRules(points $pointsPerSet, deciding $decidingSetPoints, '
      '${winByTwo ? 'win by 2' : 'first to win'}, '
      'time-outs $timeOutsPerSet, subs $subsPerSet)';
}
