import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../demo_data.dart';
import '../match_engine.dart';
import '../scoresheet/scoresheet_publisher.dart';
import 'match_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'sign_off_screen.dart';
import 'team_sheets_screen.dart';

/// The page the app opens on. From here you jump into the match, change the
/// settings, look at the team sheets, and so on. Everything is saved as you go,
/// so leaving the match screen and coming back loses nothing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmNewMatch(BuildContext context, MatchEngine engine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Start a new match?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This wipes the scores, sets, time-outs, substitutions, notes and '
          'signatures of the current match. The teams and settings stay.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('New match', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await engine.resetMatch();
  }

  /// Competition, venue and date lines for the header, skipping what is blank.
  List<String> _detailLines(MatchInfo info) {
    String two(int n) => n.toString().padLeft(2, '0');
    final lines = <String>[];

    final where = [info.competition, info.venue].where((t) => t.isNotEmpty).join(' · ');
    if (where.isNotEmpty) lines.add(where);

    final when = <String>[];
    if (info.day != null && info.month != null && info.year != null) {
      when.add('${two(info.day!)}/${two(info.month!)}/${info.year}');
    }
    if (info.hour != null && info.minute != null) {
      when.add('${two(info.hour!)}:${two(info.minute!)}');
    }
    if (when.isNotEmpty) lines.add(when.join('  '));
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    final rules = engine.rules;
    final home = engine.homeTeamSheet.teamName;
    final away = engine.awayTeamSheet.teamName;
    final started = engine.matchStarted;

    final status = !started
        ? 'Not started yet'
        : engine.isMatchComplete
            ? 'Match finished'
            : 'Set ${engine.currentSet}: ${engine.homeScore} – ${engine.awayScore}'
                '   (sets ${engine.homeSetsWon} – ${engine.awaySetsWon})';

    final notes = engine.notes.trim();
    final notesLine = notes.isEmpty ? 'Nothing written yet' : notes.split('\n').first;

    final cards = <Widget>[
      _MenuCard(
        icon: Icons.sports_volleyball,
        title: started ? 'Continue match' : 'Start match',
        subtitle: status,
        accent: Colors.greenAccent,
        onTap: () => _open(context, const MatchScreen()),
      ),
      _MenuCard(
        icon: Icons.tune,
        title: 'Match settings',
        subtitle: '${engine.maxSets} sets · ${rules.pointsPerSet} points · '
            'deciding set ${rules.decidingSetPoints}',
        onTap: () => _open(context, const SettingsScreen()),
      ),
      _MenuCard(
        icon: Icons.groups,
        title: 'Team sheets',
        subtitle: '$home and $away',
        onTap: () => _open(context, const TeamSheetsScreen()),
      ),
      _MenuCard(
        icon: Icons.edit_note,
        title: 'Notes',
        subtitle: notesLine,
        onTap: () => _open(context, const NotesScreen()),
      ),
      _MenuCard(
        icon: Icons.draw,
        title: 'Sign-off',
        subtitle: '${engine.signatures.length} of 14 signed',
        onTap: () => _open(context, const SignOffScreen()),
      ),
      _MenuCard(
        icon: Icons.picture_as_pdf,
        title: 'Scoresheet (PDF)',
        subtitle: 'Build the BVA sheet and share it',
        onTap: () => ScoresheetPublisher.publish(context, engine),
      ),
      _MenuCard(
        icon: Icons.refresh,
        title: 'New match',
        subtitle: 'Wipe the scores and start again',
        accent: Colors.redAccent,
        onTap: () => _confirmNewMatch(context, engine),
      ),
    ];

    final details = _detailLines(engine.matchInfo);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('SpikeScore', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 520 ? 2 : 1);
            final cardWidth = (constraints.maxWidth - 24 - gap * (columns - 1)) / columns;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // This match
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$home  vs  $away',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      for (final line in details)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(line, style: const TextStyle(color: Colors.white70)),
                        ),
                      const SizedBox(height: 8),
                      Text(status, style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    ],
                  ),
                ),
                if (engine.demoDataError != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'demo_data.json problem: ${engine.demoDataError} '
                      '(using the built-in teams)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final card in cards) SizedBox(width: cardWidth, child: card),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = Colors.lightBlueAccent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
