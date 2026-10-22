class Player {
  final int number;
  final String name;
  final String position; // e.g. "Setter", "Outside Hitter", "Middle Blocker", "Opposite", "Libero"

  Player({
    required this.number,
    required this.name,
    this.position = "Player",
  });
}

class TeamSheet {
  final String teamName;
  final List<Player> roster;       // Full team roster available for the match
  final List<int> startingLineup;   // Jersey numbers of the 6 players on court at set start

  TeamSheet({
    required this.teamName,
    required this.roster,
    required this.startingLineup,
  });
}