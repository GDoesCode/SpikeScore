import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../edition.dart';
import '../match_engine.dart';
import 'contact.dart';

/// Lets someone trying Lite tell us about a bug or an idea. Nothing is sent
/// without them: it opens their email app (or copies the text).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _text = TextEditingController();
  bool _includeMatch = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// A short description of where the match is, to help reproduce a bug.
  String _matchState(MatchEngine e) => [
        'Set ${e.currentSet} of ${e.maxSets}, ${e.homeScore}-${e.awayScore}, '
            'sets ${e.homeSetsWon}-${e.awaySetsWon}',
        'Rules: ${e.rules.pointsPerSet} points, deciding set ${e.rules.decidingSetPoints}, '
            '${e.rules.winByTwo ? 'win by 2' : 'first to target'}, '
            '${e.rules.timeOutsPerSet} time-outs, ${e.rules.subsPerSet} subs',
        'Events recorded: ${e.events.length}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final engine = context.read<MatchEngine>();
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Send feedback'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Found a bug, or something that would make scoring easier? Tell us here.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-text'),
            controller: _text,
            minLines: 5,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'What happened, and what did you expect?',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          SwitchListTile(
            value: _includeMatch,
            onChanged: (v) => setState(() => _includeMatch = v),
            title: const Text('Include the current score and settings',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('No names or personal details, just the numbers.',
                style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              key: const Key('send-feedback'),
              onPressed: () => sendToSpikeScore(
                context,
                subject: 'SpikeScore Lite feedback',
                body: [
                  _text.text.trim(),
                  if (_includeMatch) '\n---\n${_matchState(engine)}',
                ].join('\n'),
              ),
              icon: const Icon(Icons.send),
              label: Text(Edition.contactEmail.isEmpty ? 'Copy feedback' : 'Send by email'),
            ),
          ),
        ],
      ),
    );
  }
}
