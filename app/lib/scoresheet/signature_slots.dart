import '../match_engine.dart' show Team;

/// Ids of the 14 signature slots. The sign-off screen collects a drawing for
/// each id and the PDF places it in the matching box on the sheet.
class SignatureSlots {
  // Signed before the match: the SIGNATURES box (captain and coach per team).
  static String captain(Team team) => 'captain:${team.name}';
  static String coach(Team team) => 'coach:${team.name}';

  // Signed after the match: the APPROVAL table.
  static const String ref1 = 'ref1';
  static const String ref2 = 'ref2';
  static const String scorer = 'scorer';
  static const String assistantScorer = 'assistantScorer';
  static const List<String> lineJudges = [
    'lineJudge1',
    'lineJudge2',
    'lineJudge3',
    'lineJudge4',
  ];
  static String approvalCaptain(Team team) => 'approvalCaptain:${team.name}';
}
