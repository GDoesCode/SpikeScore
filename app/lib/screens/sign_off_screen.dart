import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';
import '../scoresheet/signature_slots.dart';

/// Collects drawn signatures for the scoresheet: captains and coaches (the
/// SIGNATURES box) and the referees, scorers, line judges and captains again
/// (the APPROVAL table). Open it from the app bar whenever you need it; the
/// PDF uses whatever has been signed and leaves the rest blank.
class SignOffScreen extends StatelessWidget {
  const SignOffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();
    String name(Team t) => engine.sheetOf(t).teamName;

    final before = <_Slot>[
      _Slot(SignatureSlots.captain(Team.home), '${name(Team.home)} captain'),
      _Slot(SignatureSlots.coach(Team.home), '${name(Team.home)} coach'),
      _Slot(SignatureSlots.captain(Team.away), '${name(Team.away)} captain'),
      _Slot(SignatureSlots.coach(Team.away), '${name(Team.away)} coach'),
    ];
    final after = <_Slot>[
      const _Slot(SignatureSlots.ref1, '1st referee'),
      const _Slot(SignatureSlots.ref2, '2nd referee'),
      const _Slot(SignatureSlots.scorer, 'Scorer'),
      const _Slot(SignatureSlots.assistantScorer, 'Assistant scorer'),
      for (var i = 0; i < SignatureSlots.lineJudges.length; i++)
        _Slot(SignatureSlots.lineJudges[i], 'Line judge ${i + 1}'),
      _Slot(SignatureSlots.approvalCaptain(Team.home),
          '${name(Team.home)} captain (approval)'),
      _Slot(SignatureSlots.approvalCaptain(Team.away),
          '${name(Team.away)} captain (approval)'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Sign-off', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionTitle('Before the match: SIGNATURES box'),
          for (final s in before) _SlotTile(slot: s, engine: engine),
          const SizedBox(height: 16),
          const _SectionTitle('After the match: APPROVAL table'),
          for (final s in after) _SlotTile(slot: s, engine: engine),
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
      builder: (_) => _SignaturePadDialog(title: slot.label),
    );
    if (result != null && result.isNotEmpty) {
      await engine.setSignature(slot.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = engine.signatures[slot.id];
    final signed = ink != null;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _sign(context),
        leading: Icon(
          signed ? Icons.check_circle : Icons.draw,
          color: signed ? Colors.greenAccent : Colors.white54,
        ),
        title: Text(slot.label, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          signed ? 'Signed. Tap to sign again.' : 'Tap to sign',
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
            if (ink != null)
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

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog({required this.title});

  final String title;

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
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
