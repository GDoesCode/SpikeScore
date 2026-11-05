import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../match_engine.dart';

/// A page to write anything down, like the margin of the paper sheet: a junior
/// player's name and number, a delay, an incident. It is saved with the match
/// as you type and printed in the REMARKS box of the scoresheet.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final MatchEngine _engine;
  late final TextEditingController _controller;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _engine = context.read<MatchEngine>();
    _controller = TextEditingController(text: _engine.notes);
  }

  /// Saves shortly after the last keystroke, not on every one.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_controller.text != _engine.notes) {
      _engine.setNotes(_controller.text);
    }
  }

  @override
  void dispose() {
    _saveNow(); // never lose the last few words
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved with the match as you type. Printed in the REMARKS box of the '
              'scoresheet (about six short lines; longer notes are shrunk or cut '
              'off on the PDF, but never lost here).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (_) => _scheduleSave(),
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'For example: junior player #7 D. Evans (U16)',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
