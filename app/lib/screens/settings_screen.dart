import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';
import '../match_rules.dart';

/// The format and rules of the match: number of sets, points per set, the
/// deciding set, time-outs and substitutions. They can only be changed before
/// the match starts, because changing them later would change who has won what.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    final rules = engine.rules;
    final locked = engine.matchStarted;

    void change(MatchRules updated) => engine.setRules(updated);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Match settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (locked)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'A match is in progress, so these are locked. To change them, '
                'start a new match first (Main menu, then New match).',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),

          const _SectionTitle('Format'),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Number of sets', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    engine.matchMode == MatchMode.localLeague3Set
                        ? 'Best of 3: the first team to win 2 sets.'
                        : 'Best of 5: the first team to win 3 sets.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<MatchMode>(
                    segments: const [
                      ButtonSegment(value: MatchMode.localLeague3Set, label: Text('3 sets')),
                      ButtonSegment(value: MatchMode.nationalLeague5Set, label: Text('5 sets')),
                    ],
                    selected: {engine.matchMode},
                    onSelectionChanged: locked ? null : (s) => engine.setMatchMode(s.first),
                  ),
                ],
              ),
            ),
          ),

          const _SectionTitle('Points'),
          _StepperTile(
            title: 'Points per set',
            subtitle: 'To win a normal set, by 2 points. '
                '${MatchRules.minPointsPerSet} to ${MatchRules.maxPointsPerSet}.',
            value: rules.pointsPerSet,
            min: MatchRules.minPointsPerSet,
            max: MatchRules.maxPointsPerSet,
            enabled: !locked,
            onChanged: (v) => change(rules.copyWith(pointsPerSet: v)),
          ),
          _StepperTile(
            title: 'Points in the tie-break (deciding set)',
            subtitle: 'The teams change ends at ${rules.changeEndsAt}. '
                '${MatchRules.minDecidingSetPoints} to ${MatchRules.maxDecidingSetPoints}.',
            value: rules.decidingSetPoints,
            min: MatchRules.minDecidingSetPoints,
            max: MatchRules.maxDecidingSetPoints,
            enabled: !locked,
            onChanged: (v) => change(rules.copyWith(decidingSetPoints: v)),
          ),
          _SwitchTile(
            title: 'Win sets by 2 points',
            subtitle: rules.winByTwo
                ? 'On: every set, tie-break included, plays on until one team leads by 2.'
                : 'Off: the first team to reach ${rules.pointsPerSet} '
                    '(${rules.decidingSetPoints} in the tie-break) wins the set.',
            value: rules.winByTwo,
            enabled: !locked,
            onChanged: (v) => change(rules.copyWith(winByTwo: v)),
          ),

          const _SectionTitle('Per team, per set'),
          _StepperTile(
            title: 'Time-outs',
            subtitle: '0 to ${MatchRules.maxTimeOutsPerSet}.',
            value: rules.timeOutsPerSet,
            min: 0,
            max: MatchRules.maxTimeOutsPerSet,
            enabled: !locked,
            onChanged: (v) => change(rules.copyWith(timeOutsPerSet: v)),
          ),
          _StepperTile(
            title: 'Substitutions',
            subtitle: '0 to ${MatchRules.maxSubsPerSet}. Each starting position can '
                'be swapped twice, and only the starter can come back.',
            value: rules.subsPerSet,
            min: 0,
            max: MatchRules.maxSubsPerSet,
            enabled: !locked,
            onChanged: (v) => change(rules.copyWith(subsPerSet: v)),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: locked
                  ? null
                  : () {
                      engine.setMatchMode(MatchMode.localLeague3Set);
                      engine.setRules(MatchRules.defaults);
                    },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to the standard BVA rules'),
            ),
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
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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

/// A row with a title, a short explanation and an on / off switch.
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// A row with a title, a short explanation and a - / + pair around the value.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.white70,
              tooltip: 'Less',
              onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.white70,
              tooltip: 'More',
              onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}
