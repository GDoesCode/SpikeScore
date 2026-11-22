import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';
import 'sign_off_screen.dart';

/// Opens the referee override: things the scorer can only do with the 1st or
/// 2nd referee's say-so. Each one asks a referee to sign on the pad first,
/// and is written into the remarks.
Future<void> showRefereeOverride(BuildContext context) async {
  final engine = context.read<MatchEngine>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF222222),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final e = sheetContext.watch<MatchEngine>();
      final actions = <Widget>[
        if (e.awaitingPreMatchSignatures)
          _ActionTile(
            icon: Icons.play_arrow,
            title: 'Start without the pre-match signatures',
            subtitle: 'For example when a captain has not arrived yet. '
                'Missing signatures can still be added later.',
            onTap: () async {
              Navigator.pop(sheetContext);
              final ref = await _confirmReferee(context, 'Start without signatures');
              if (ref != null) {
                await engine.waivePreMatchSignatures(referee: ref.who, ink: ref.ink);
              }
            },
          ),
        if (e.isSignedOff)
          _ActionTile(
            icon: Icons.lock_open,
            title: 'Unlock the signed scoresheet',
            subtitle: 'Scoring and undo work again. The approval signatures '
                'are wiped and need signing again.',
            onTap: () async {
              Navigator.pop(sheetContext);
              final ref = await _confirmReferee(context, 'Unlock the scoresheet');
              if (ref != null) {
                await engine.unlockSignedSheet(referee: ref.who, ink: ref.ink);
              }
            },
          ),
        if (!e.needsFirstServe)
          _ActionTile(
            icon: Icons.exposure,
            title: 'Change the score',
            subtitle: 'Add or take off points in this set, for example after '
                'an illegal player. Nobody rotates and the serve stays put.',
            onTap: () async {
              Navigator.pop(sheetContext);
              final ref = await _confirmReferee(context, 'Change the score');
              if (ref != null && context.mounted) {
                await showDialog<void>(
                  context: context,
                  builder: (_) => _ScoreEditor(referee: ref.who, ink: ref.ink),
                );
              }
            },
          ),
      ];

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Referee override',
                style: TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Needs the 1st or 2nd referee to sign. Each override is written '
                'in the remarks on the scoresheet, with their signature beside it.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (actions.isEmpty)
                const Text(
                  'Nothing to override yet. Choose who serves first to start.',
                  style: TextStyle(color: Colors.white54),
                )
              else
                ...actions,
            ],
          ),
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF2A2A2A),
        child: ListTile(
          leading: Icon(icon, color: Colors.amberAccent),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: onTap,
        ),
      );
}

/// Asks which referee is authorising [what] and has them sign. Returns who
/// ("1st referee" or "2nd referee") and their signature, which goes beside
/// the override in the REMARKS box; null if cancelled.
Future<({String who, SignatureInk ink})?> _confirmReferee(
    BuildContext context, String what) async {
  if (!context.mounted) return null;
  final who = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF222222),
      title: Text(what, style: const TextStyle(color: Colors.white)),
      content: const Text('Which referee is authorising this?',
          style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, '1st referee'),
          child: const Text('1st referee'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, '2nd referee'),
          child: const Text('2nd referee'),
        ),
      ],
    ),
  );
  if (who == null || !context.mounted) return null;
  final ink = await showDialog<List<List<List<double>>>>(
    context: context,
    builder: (_) => SignaturePadDialog(title: '$who: sign to confirm'),
  );
  if (ink == null || ink.isEmpty) return null;
  return (who: who, ink: ink);
}

/// Plus and minus buttons for each team's score in the current set. Nothing
/// changes until Apply, so a few taps make one entry in the remarks.
class _ScoreEditor extends StatefulWidget {
  const _ScoreEditor({required this.referee, required this.ink});

  final String referee;
  final SignatureInk ink;

  @override
  State<_ScoreEditor> createState() => _ScoreEditorState();
}

class _ScoreEditorState extends State<_ScoreEditor> {
  final Map<Team, int> _delta = {Team.home: 0, Team.away: 0};

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    int shown(Team t) => engine.scoreOf(t) + _delta[t]!;

    Widget row(Team team) => Row(
          children: [
            Expanded(
              child: Text(engine.sheetOf(team).teamName,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
              onPressed: shown(team) == 0
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      setState(() => _delta[team] = _delta[team]! - 1);
                    },
            ),
            SizedBox(
              width: 44,
              child: Text('${shown(team)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _delta[team] == 0 ? Colors.white : Colors.amberAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _delta[team] = _delta[team]! + 1);
              },
            ),
          ],
        );

    final changed = _delta.values.any((d) => d != 0);
    return AlertDialog(
      backgroundColor: const Color(0xFF222222),
      title: Text('Set ${engine.currentSet}: change the score',
          style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(Team.home),
          row(Team.away),
          const SizedBox(height: 8),
          Text('Authorised by the ${widget.referee}. The change is written in the remarks.',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: !changed
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  for (final t in Team.values) {
                    if (_delta[t] != 0) {
                      await engine.adjustScore(t, _delta[t]!,
                          referee: widget.referee, ink: widget.ink);
                    }
                  }
                },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
