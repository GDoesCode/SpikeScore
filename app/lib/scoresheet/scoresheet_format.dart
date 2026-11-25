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

  /// The match lengths (most sets) the paper sheet has room for. When there
  /// is only one, the sheet decides the number of sets.
  List<int> get setCounts => switch (this) {
        ScoresheetFormat.bva => const [3],
        ScoresheetFormat.fivb => const [5],
      };

  /// True if this sheet has room for a match of [maxSets] sets.
  bool fits(int maxSets) => setCounts.contains(maxSets);

  /// True if the sheet leaves the number of sets to the scorer.
  bool get setsAreChoosable => setCounts.length > 1;

  /// The first sheet with room for [maxSets] sets (BVA if none has).
  static ScoresheetFormat firstFitting(int maxSets) => ScoresheetFormat.values
      .firstWhere((f) => f.fits(maxSets), orElse: () => ScoresheetFormat.bva);

  static ScoresheetFormat fromName(Object? name) => ScoresheetFormat.values
      .firstWhere((f) => f.name == name, orElse: () => ScoresheetFormat.bva);
}
