/// Which paper scoresheet the PDF is drawn on.
enum ScoresheetFormat {
  /// The Berkshire Volleyball Association 3-set sheet (the default).
  bva,

  /// The official FIVB international scoresheet (2013 edition, A3), for
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
          'The official FIVB international scoresheet. 5-set matches only.',
      };

  /// The blank sheet (a picture) and where every box is on it.
  String get backgroundAsset => 'assets/scoresheet/${_file}_blank.jpg';
  String get layoutAsset => 'assets/scoresheet/${_file}_layout.json';

  String get _file => switch (this) {
        ScoresheetFormat.bva => 'bva_3set',
        ScoresheetFormat.fivb => 'fivb_5set',
      };

  /// True if this sheet has room for a match of [maxSets] sets.
  bool fits(int maxSets) => switch (this) {
        ScoresheetFormat.bva => maxSets == 3,
        ScoresheetFormat.fivb => maxSets == 5,
      };

  static ScoresheetFormat fromName(Object? name) => ScoresheetFormat.values
      .firstWhere((f) => f.name == name, orElse: () => ScoresheetFormat.bva);
}
