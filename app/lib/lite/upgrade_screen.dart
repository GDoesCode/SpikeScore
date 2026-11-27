import 'package:material_ui/material_ui.dart';

import '../edition.dart';
import 'contact.dart';

/// What the full version of SpikeScore adds, and how a league gets it.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  static const _features = [
    (Icons.groups, 'Your real teams',
        'Team sheets with player names, captains, liberos and coaches, imported from your league.'),
    (Icons.picture_as_pdf, 'The official scoresheet',
        'Fills in your league\'s paper sheet (BVA or FIVB) as you score, ready to print or send.'),
    (Icons.draw, 'Signatures',
        'Captains, coaches, referees and scorers sign on the tablet, before and after the match.'),
    (Icons.lock, 'Locked when signed',
        'Once the sheet is signed nobody can change the score by accident.'),
    (Icons.gavel, 'Referee override',
        'The referees can correct an illegal player or a wrong score, and it goes in the remarks.'),
    (Icons.emoji_events, 'MVP and match officials',
        'Each captain picks the other team\'s MVP, and the officials go on the sheet.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Full version'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'SpikeScore for leagues',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'You are using SpikeScore Lite, the free version for trying the app out. '
            'The full version replaces the paper scoresheet at real matches.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          for (final (icon, title, text) in _features)
            Card(
              color: const Color(0xFF1E1E1E),
              child: ListTile(
                leading: Icon(icon, color: Colors.lightBlueAccent),
                title: Text(title, style: const TextStyle(color: Colors.white)),
                subtitle: Text(text, style: const TextStyle(color: Colors.white54)),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Ask your league or association to get in touch and we will set it up '
            'with your scoresheet and teams.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              key: const Key('contact-us'),
              onPressed: () => sendToSpikeScore(
                context,
                subject: 'SpikeScore for our league',
                body: 'Hello, we would like to know more about SpikeScore for our league.\n\n'
                    'League or association:\nContact name:\n',
              ),
              icon: const Icon(Icons.mail_outline),
              label: Text(Edition.contactEmail.isEmpty ? 'Copy a message to send us' : 'Contact us'),
            ),
          ),
        ],
      ),
    );
  }
}
