import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../demo_data.dart';
import '../edition.dart';
import '../lite/feedback_screen.dart';
import '../lite/match_summary_screen.dart';
import '../lite/upgrade_screen.dart';
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
        content: Text(
          engine.isLite
              ? 'This wipes the scores, sets, time-outs, substitutions and notes '
                  'of the current match. The settings stay.'
              : 'This wipes the scores, sets, time-outs, substitutions, notes and '
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

  /// Lite: replace the match with the example one and show its summary.
  Future<void> _loadPracticeMatch(BuildContext context, MatchEngine engine) async {
    if (engine.matchStarted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text('Load the practice match?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Lite keeps one match at a time, so this replaces the match you are scoring.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace it', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await engine.loadPracticeMatch();
    if (context.mounted) _open(context, const MatchSummaryScreen());
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

    final matchCard = _MenuCard(
      icon: Icons.sports_volleyball,
      title: started ? 'Continue match' : 'Start match',
      subtitle: status,
      accent: Colors.greenAccent,
      onTap: () => _open(context, const MatchScreen()),
    );
    final settingsCard = _MenuCard(
      icon: Icons.tune,
      title: 'Match settings',
      subtitle: '${engine.maxSets} sets · ${rules.pointsPerSet} points · '
          'deciding set ${rules.decidingSetPoints}',
      onTap: () => _open(context, const SettingsScreen()),
    );
    final notesCard = _MenuCard(
      icon: Icons.edit_note,
      title: 'Notes',
      subtitle: notesLine,
      onTap: () => _open(context, const NotesScreen()),
    );
    final newMatchCard = _MenuCard(
      icon: Icons.refresh,
      title: 'New match',
      subtitle: 'Wipe the scores and start again',
      accent: Colors.redAccent,
      onTap: () => _confirmNewMatch(context, engine),
    );

    // Lite: no team sheets, signatures or official scoresheet. A plain
    // summary instead, an example match, and ways to reach us.
    final liteCards = <Widget>[
      matchCard,
      _MenuCard(
        icon: Icons.bar_chart,
        title: 'Match summary',
        subtitle: 'Set scores, times and how each set went',
        onTap: () => _open(context, const MatchSummaryScreen()),
      ),
      _MenuCard(
        icon: Icons.play_circle_outline,
        title: 'Practice match',
        subtitle: 'Load a finished example match to look around',
        accent: Colors.amberAccent,
        onTap: () => _loadPracticeMatch(context, engine),
      ),
      settingsCard,
      notesCard,
      newMatchCard,
      _MenuCard(
        icon: Icons.workspace_premium,
        title: 'Full version',
        subtitle: 'Official scoresheets, real teams and signatures',
        accent: Colors.amberAccent,
        onTap: () => _open(context, const UpgradeScreen()),
      ),
      _MenuCard(
        icon: Icons.feedback_outlined,
        title: 'Send feedback',
        subtitle: 'Report a bug or suggest an idea',
        onTap: () => _open(context, const FeedbackScreen()),
      ),
    ];

    final cards = engine.isLite ? liteCards : <Widget>[
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
        title: engine.isMatchComplete ? 'Sign the scoresheet' : 'Team sheet signatures',
        subtitle: () {
          final ids = engine.isMatchComplete
              ? MatchEngine.postMatchSlots
              : engine.preMatchSlots;
          final n = ids.where(engine.signatures.containsKey).length;
          return '$n of ${ids.length} signed';
        }(),
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
        title: Text(Edition.appName(engine.isLite),
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
