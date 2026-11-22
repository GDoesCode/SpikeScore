import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';
import '../scoresheet/scoresheet_publisher.dart';
import '../scoresheet/signature_slots.dart';
import 'referee_override.dart';
import 'team_sheets_screen.dart';

/// The two moments the scoresheet is signed.
enum SignOffStage {
  /// After the first coin toss: captains (and coaches) confirm the team sheets.
  preMatch,

  /// When the match is over: referees, scorers, line judges and captains.
  postMatch,
}

/// Collects drawn signatures for the scoresheet in two stages. Before the
/// match the captains and coaches sign to confirm the team sheets (the
/// SIGNATURES box); once the match is over the referees, scorers, line judges
/// and captains sign the APPROVAL table. The second stage stays hidden until
/// the match is finished. Leave [stage] out to show whichever stage is due.
class SignOffScreen extends StatelessWidget {
  const SignOffScreen({super.key, this.stage});

  final SignOffStage? stage;

  static SignOffStage stageFor(MatchEngine engine) =>
      engine.isMatchComplete ? SignOffStage.postMatch : SignOffStage.preMatch;

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    final current = stage ?? stageFor(engine);
    String name(Team t) => engine.sheetOf(t).teamName;

    String label(String id) {
      for (final t in Team.values) {
        if (id == SignatureSlots.captain(t)) return '${name(t)} captain';
        if (id == SignatureSlots.coach(t)) return '${name(t)} coach';
        if (id == SignatureSlots.approvalCaptain(t)) return '${name(t)} captain';
      }
      final j = SignatureSlots.lineJudges.indexOf(id);
      if (j >= 0) return 'Line judge ${j + 1}';
      return switch (id) {
        SignatureSlots.ref1 => '1st referee',
        SignatureSlots.ref2 => '2nd referee',
        SignatureSlots.scorer => 'Scorer',
        SignatureSlots.assistantScorer => 'Assistant scorer',
        _ => id,
      };
    }

    final pre = current == SignOffStage.preMatch;
    final slots = [
      for (final id in pre ? engine.preMatchSlots : MatchEngine.postMatchSlots)
        _Slot(id, label(id)),
    ];

    final winner = engine.winningTeam;
    final header = pre
        ? 'Captains${Team.values.any(engine.hasCoach) ? ' and coaches' : ''} sign '
            'to confirm the team sheets. Play starts once everyone listed has signed.'
        : winner == null
            ? 'Referees, scorers, line judges and captains sign the scoresheet.'
            : '${name(winner)} won the match '
                '${engine.setsWonOf(winner) + 1}:${engine.setsWonOf(winner.other)}. '
                'Referees, scorers, line judges and captains sign the scoresheet. '
                'Once anyone signs, scoring and undo are locked; a referee '
                'override unlocks them.';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(pre ? 'Confirm team sheets' : 'Sign the scoresheet',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(header, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          if (pre)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamSheetsScreen())),
                icon: const Icon(Icons.groups),
                label: const Text('Open team sheets'),
              ),
            ),
          const SizedBox(height: 8),
          _SectionTitle(pre
              ? 'Before the match: SIGNATURES box'
              : 'After the match: APPROVAL table'),
          for (final s in slots) _SlotTile(slot: s, engine: engine),
          const SizedBox(height: 16),
          if (!pre)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ScoresheetPublisher.publish(context, engine),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Publish scoresheet (PDF)'),
                style: TextButton.styleFrom(foregroundColor: Colors.lightBlueAccent),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => showRefereeOverride(context),
                icon: const Icon(Icons.gavel, size: 18),
                label: const Text('Referee override'),
                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
              ),
              if (pre)
                ElevatedButton(
                  onPressed: engine.preMatchSigned || engine.preMatchWaived
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  child: const Text('Start the match'),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Slot {
  final String id;
  final String label;
  const _Slot(this.id, this.label);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
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

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.engine});

  final _Slot slot;
  final MatchEngine engine;

  Future<void> _sign(BuildContext context) async {
    final result = await showDialog<List<List<List<double>>>>(
      context: context,
      builder: (_) => SignaturePadDialog(title: slot.label),
    );
    if (result != null && result.isNotEmpty) {
      await engine.setSignature(slot.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = engine.signatures[slot.id];
    final signed = ink != null;
    final locked = engine.isSignatureLocked(slot.id);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: locked ? null : () => _sign(context),
        leading: Icon(
          signed ? (locked ? Icons.lock : Icons.check_circle) : Icons.draw,
          color: signed ? Colors.greenAccent : Colors.white54,
        ),
        title: Text(slot.label, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          locked
              ? 'Signed. Locked now that play has started.'
              : signed
                  ? 'Signed. Tap to sign again.'
                  : 'Tap to sign',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ink != null)
              Container(
                width: 120,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(painter: _InkPainter(ink)),
              ),
            if (ink != null && !locked)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                tooltip: 'Remove signature',
                onPressed: () => engine.clearSignature(slot.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draws strokes whose points run 0 to 1 across the box they're painted in.
class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);

  final List<List<List<double>>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF12299E)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first[0] * size.width, stroke.first[1] * size.height);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i][0] * size.width, stroke[i][1] * size.height);
      }
      // A single tap becomes a dot.
      if (stroke.length == 1) {
        path.lineTo(stroke.first[0] * size.width + 0.1, stroke.first[1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  // The dialog adds points to the same list, so always repaint.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key, required this.title});

  final String title;

  @override
  State<SignaturePadDialog> createState() => SignaturePadDialogState();
}

class SignaturePadDialogState extends State<SignaturePadDialog> {
  // Strokes -> points -> [x, y], each 0 to 1 across the pad.
  final List<List<List<double>>> _strokes = [];

  List<double> _normalise(Offset p, Size size) => [
        (p.dx / size.width).clamp(0.0, 1.0).toDouble(),
        (p.dy / size.height).clamp(0.0, 1.0).toDouble(),
      ];

  void _save() {
    // Three decimals is plenty and keeps what we store small.
    double r(double v) => double.parse(v.toStringAsFixed(3));
    final rounded = _strokes
        .map((stroke) => stroke.map((p) => [r(p[0]), r(p[1])]).toList())
        .toList();
    HapticFeedback.mediumImpact();
    Navigator.pop(context, rounded);
  }

  @override
  Widget build(BuildContext context) {
    // A plain Dialog (not AlertDialog): AlertDialog measures its content with
    // intrinsic sizes, which a LayoutBuilder can't answer.
    return Dialog(
      backgroundColor: const Color(0xFF222222),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign with your finger in the white box.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: MatchEngine.signaturePadAspect,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) => setState(
                        () => _strokes.add([_normalise(d.localPosition, size)]),
                      ),
                      onPanUpdate: (d) => setState(
                        () => _strokes.last.add(_normalise(d.localPosition, size)),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: CustomPaint(
                          painter: _InkPainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                    child: const Text('Clear'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _strokes.isEmpty ? null : _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
