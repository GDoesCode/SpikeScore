import 'package:spikescore/models.dart';

class MockData {
  /// Generate a quick team sheet with custom names and jersey numbers
  static TeamSheet createTeamSheet({
    required String teamName,
    required List<int> jerseyNumbers,
    List<int>? customStartingLineup,
  }) {
    assert(jerseyNumbers.length >= 6, 'A team must have at least 6 players');

    final roster = jerseyNumbers.asMap().entries.map((entry) {
      final idx = entry.key;
      final number = entry.value;

      // Assign realistic volleyball positions
      final positions = [
        'Setter',
        'Outside Hitter',
        'Middle Blocker',
        'Opposite',
        'Outside Hitter',
        'Middle Blocker',
        'Libero',
        'Setter/Opposite',
      ];

      final pos = positions[idx % positions.length];
      return Player(
        number: number,
        name: 'Player $number',
        position: pos,
      );
    }).toList();

    // Default starting lineup is the first 6 players in court order (I -> VI)
    final startingLineup = customStartingLineup ?? jerseyNumbers.sublist(0, 6);

    return TeamSheet(
      teamName: teamName,
      roster: roster,
      startingLineup: startingLineup,
    );
  }

  /// Ready-to-use Preset Teams
  static TeamSheet get readingRocket => createTeamSheet(
        teamName: 'Reading Rockets',
        jerseyNumbers: [1, 3, 5, 7, 9, 11, 13, 15],
        customStartingLineup: [1, 3, 5, 7, 9, 11],
      );

  static TeamSheet get oxfordSpikers => createTeamSheet(
        teamName: 'Oxford Spikers',
        jerseyNumbers: [2, 4, 6, 8, 10, 12, 14, 16],
        customStartingLineup: [2, 4, 6, 8, 10, 12],
      );

  static TeamSheet get londonSpikeopaths => TeamSheet(
        teamName: 'Spikeopaths',
        roster: [
          Player(number: 4, name: 'G. Archer', position: 'Setter'),
          Player(number: 7, name: 'M. Ross', position: 'Outside Hitter'),
          Player(number: 10, name: 'D. Vance', position: 'Middle Blocker'),
          Player(number: 12, name: 'K. Patel', position: 'Opposite'),
          Player(number: 18, name: 'L. Chen', position: 'Outside Hitter'),
          Player(number: 25, name: 'A. Miller', position: 'Middle Blocker'),
          Player(number: 2, name: 'S. Taylor', position: 'Libero'),
          Player(number: 9, name: 'J. Smith', position: 'Setter'),
        ],
        startingLineup: [4, 7, 10, 12, 18, 25],
      );
}