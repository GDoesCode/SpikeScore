/// Which paper scoresheet the PDF is drawn on.
enum ScoresheetFormat {
  /// The Berkshire Volleyball Association 3-set sheet (the default).
  bva,

  /// A sheet laid out like the FIVB international scoresheet: sets 1 to 4
  /// in two rows, the deciding set in three sections across the page, and
  /// the teams, results and approval boxes beside them. Works for 3-set and
  /// 5-set matches.
  fivb;

  String get label => switch (this) {
        ScoresheetFormat.bva => 'BVA',
        ScoresheetFormat.fivb => 'FIVB',
      };

  String get description => switch (this) {
        ScoresheetFormat.bva =>
          'The Berkshire Volleyball Association sheet. 3-set matches only.',
        ScoresheetFormat.fivb =>
          'Laid out like the FIVB international scoresheet. 3 or 5 sets.',
      };

  /// True if this sheet has room for a match of [maxSets] sets.
  bool fits(int maxSets) => switch (this) {
        ScoresheetFormat.bva => maxSets == 3,
        ScoresheetFormat.fivb => maxSets == 3 || maxSets == 5,
      };

  static ScoresheetFormat fromName(Object? name) => ScoresheetFormat.values
      .firstWhere((f) => f.name == name, orElse: () => ScoresheetFormat.bva);
}
