import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';
import 'match_summary.dart';
import 'upgrade_screen.dart';

const _homeColor = Colors.blueAccent;
const _awayColor = Colors.redAccent;

/// SpikeScore Lite's stand-in for the official scoresheet: the result, each
/// set's score and length, time-outs and subs, and a chart of the score
/// rally by rally. Clearly marked as not an official sheet.
class MatchSummaryScreen extends StatelessWidget {
  const MatchSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    final summary = MatchSummary.of(engine);
    final home = engine.homeTeamSheet.teamName;
    final away = engine.awayTeamSheet.teamName;

    final result = summary.winner == null
        ? (summary.sets.isEmpty ? 'Not started yet' : 'In progress')
        : '${summary.winner == Team.home ? home : away} win';
    final d = summary.duration;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Match summary'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            key: const Key('copy-summary'),
            tooltip: 'Copy as text',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: summary.asText(home: home, away: away)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Summary copied')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: _TeamName(home, _homeColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${summary.setsWon[Team.home]} – ${summary.setsWon[Team.away]}',
                        key: const Key('summary-sets'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Flexible(child: _TeamName(away, _awayColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  d == null ? result : '$result · ${formatDuration(d)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (summary.sets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Play a few rallies, or load the practice match from the main menu, '
                'and the summary fills in here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          for (final s in summary.sets) _SetCard(s, home: home, away: away),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Not an official scoresheet',
                  style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SpikeScore Lite is for trying the app out. The full version fills in '
                  'and signs your league\'s official scoresheet.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpgradeScreen())),
                  child: const Text('What the full version adds'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
      );
}

class _SetCard extends StatelessWidget {
  const _SetCard(this.set, {required this.home, required this.away});
  final SetSummary set;
  final String home;
  final String away;

  @override
  Widget build(BuildContext context) {
    final d = set.duration;
    const label = TextStyle(color: Colors.white54, fontSize: 12);
    const value = TextStyle(color: Colors.white, fontSize: 13);

    Widget row(String name, String h, String a) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(child: Text(name, style: label)),
              SizedBox(width: 40, child: Text(h, textAlign: TextAlign.center, style: value)),
              SizedBox(width: 40, child: Text(a, textAlign: TextAlign.center, style: value)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Set ${set.number}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text('${set.homeScore} – ${set.awayScore}',
                  style: TextStyle(
                      color: set.winner == null
                          ? Colors.white
                          : (set.winner == Team.home ? _homeColor : _awayColor),
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                [
                  if (!set.finished) 'in progress',
                  if (d != null) formatDuration(d),
                ].join(' · '),
                style: label,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(painter: _ProgressionPainter(set.progression)),
          ),
          const SizedBox(height: 8),
          row('', home, away),
          row('Time-outs', '${set.timeOuts[Team.home]}', '${set.timeOuts[Team.away]}'),
          row('Substitutions', '${set.subs[Team.home]}', '${set.subs[Team.away]}'),
          row('Biggest lead', '${set.biggestLead(Team.home)}', '${set.biggestLead(Team.away)}'),
        ],
      ),
    );
  }
}

/// Both teams' scores, rally by rally, as two step lines.
class _ProgressionPainter extends CustomPainter {
  _ProgressionPainter(this.points);
  final List<(int, int)> points;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    var top = 0;
    for (final (h, a) in points) {
      if (h > top) top = h;
      if (a > top) top = a;
    }
    if (top < 5) top = 5;
    final rallies = points.length - 1 < 1 ? 1 : points.length - 1;

    for (var y = 5; y <= top; y += 5) {
      final dy = size.height - size.height * y / top;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    void line(int Function((int, int)) pick, Color color) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 1; i < points.length; i++) {
        final x = size.width * i / rallies;
        final y = size.height - size.height * pick(points[i]) / top;
        final prevY = size.height - size.height * pick(points[i - 1]) / top;
        path
          ..lineTo(x, prevY)
          ..lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    line((p) => p.$1, _homeColor);
    line((p) => p.$2, _awayColor);
  }

  @override
  bool shouldRepaint(_ProgressionPainter old) => old.points != points;
}
