import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../demo_data.dart';
import '../match_engine.dart';
import '../models.dart';

/// The team sheets the app knows about: the two teams in this match first, then
/// any other teams in the data file. Read only: the teams come from
/// assets/demo/demo_data.json (edit that file and restart the app to change them).
class TeamSheetsScreen extends StatelessWidget {
  const TeamSheetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();

    final others = [
      for (final t in engine.teamLibrary)
        if (!identical(t.sheet, engine.homeTeamSheet) &&
            !identical(t.sheet, engine.awayTeamSheet))
          t,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Team sheets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionTitle('Playing this match'),
          _TeamCard(
            sheet: engine.homeTeamSheet,
            officials: engine.officials[Team.home] ?? const [],
            badge: 'HOME',
            badgeColor: Colors.blueAccent,
            startOpen: true,
          ),
          _TeamCard(
            sheet: engine.awayTeamSheet,
            officials: engine.officials[Team.away] ?? const [],
            badge: 'AWAY',
            badgeColor: Colors.redAccent,
          ),
          if (others.isNotEmpty) ...[
            const _SectionTitle('Other teams in the data file'),
            for (final t in others) _TeamCard(sheet: t.sheet, officials: t.officials),
          ],
          const SizedBox(height: 16),
          const Text(
            'These come from assets/demo/demo_data.json. To change a team or who '
            'is playing, edit that file and restart the app.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.sheet,
    required this.officials,
    this.badge,
    this.badgeColor = Colors.white54,
    this.startOpen = false,
  });

  final TeamSheet sheet;
  final List<Official> officials;
  final String? badge;
  final Color badgeColor;
  final bool startOpen;

  static const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];

  @override
  Widget build(BuildContext context) {
    final lineup = [
      for (var i = 0; i < sheet.startingLineup.length && i < _roman.length; i++)
        '${_roman[i]} #${sheet.startingLineup[i]}',
    ].join('   ');

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Theme(
        // Hide the divider lines Flutter draws around an expanded tile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: startOpen,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              Flexible(
                child: Text(
                  sheet.teamName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: badgeColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${sheet.roster.length} players',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Starting line-up (service order)',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(lineup, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 10),
            const Text('Players', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            for (final p in sheet.roster)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#${p.number}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(p.name, style: const TextStyle(color: Colors.white)),
                    ),
                    Text(
                      p.position,
                      style: TextStyle(
                        color: sheet.startingLineup.contains(p.number)
                            ? Colors.greenAccent
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (officials.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Officials', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              for (final o in officials)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${o.role}: ${o.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Green = in the starting line-up',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
