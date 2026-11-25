
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../match_engine.dart';
import 'scoresheet_data.dart';
import 'scoresheet_format.dart';
import 'scoresheet_pdf.dart';
import 'scoresheet_preview_screen.dart';

/// Turns the current match into a filled-in scoresheet PDF (on the sheet
/// chosen in Settings: BVA or FIVB) and opens a
/// preview of it, whose Share button hands it to the phone's share sheet
/// (save to Files, email, print, ...).
class ScoresheetPublisher {
  static bool _busy = false;

  /// Builds the PDF bytes from whatever has been recorded so far. Sets that
  /// haven't been played, and anything the app doesn't record, stay blank.
  static Future<Uint8List> buildPdf(MatchEngine engine) async {
    final data = ScoresheetData.fromEngine(engine);
    final format = engine.scoresheetFormat;
    final background =
        (await rootBundle.load(format.backgroundAsset)).buffer.asUint8List();
    final layoutJson = await rootBundle.loadString(format.layoutAsset);
    return ScoresheetPdf.build(
      data,
      background: background,
      layoutJson: layoutJson,
    );
  }

  /// Builds the sheet and opens the preview screen. Safe to call at any time.
  static Future<void> publish(BuildContext context, MatchEngine engine) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final format = engine.scoresheetFormat;
    if (!format.fits(engine.maxSets)) {
      messenger.showSnackBar(SnackBar(
        content: Text(format == ScoresheetFormat.bva
            ? 'The BVA scoresheet is for 3-set matches only. '
                'Choose the FIVB scoresheet in Settings for 5 sets.'
            : 'The FIVB scoresheet is for 5-set matches only. '
                'Choose the BVA scoresheet in Settings for 3 sets.'),
      ));
      return;
    }
    if (_busy) return;
    _busy = true;

    messenger.showSnackBar(const SnackBar(
      content: Text('Creating scoresheet…'),
      duration: Duration(seconds: 2),
    ));

    try {
      final bytes = await buildPdf(engine);
      final fileName = _fileName(engine);
      messenger.hideCurrentSnackBar();
      // Don't await: the preview stays open as long as the scorer wants, and
      // the busy flag only guards against double taps while building.
      navigator.push(MaterialPageRoute<void>(
        builder: (_) =>
            ScoresheetPreviewScreen(bytes: bytes, fileName: fileName),
      ));
    } catch (e, st) {
      debugPrint('SpikeScore: could not publish scoresheet: $e\n$st');
      messenger.showSnackBar(SnackBar(
        content: Text('Could not create the scoresheet: $e'),
      ));
    } finally {
      _busy = false;
    }
  }

  static String _fileName(MatchEngine engine) {
    String clean(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    String two(int n) => n.toString().padLeft(2, '0');

    final now = DateTime.now();
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final home = clean(engine.homeTeamSheet.teamName);
    final away = clean(engine.awayTeamSheet.teamName);
    return 'scoresheet_${home}_vs_${away}_$stamp.pdf';
  }
}
