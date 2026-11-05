
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../match_engine.dart';
import 'scoresheet_data.dart';
import 'scoresheet_pdf.dart';

/// Turns the current match into a filled-in BVA scoresheet PDF and hands it to
/// the phone's share sheet (save to Files, email, print, AirDrop, ...).
class ScoresheetPublisher {
  static const _backgroundAsset = 'assets/scoresheet/bva_3set_blank.jpg';
  static const _layoutAsset = 'assets/scoresheet/bva_3set_layout.json';

  static bool _busy = false;

  /// Builds the PDF bytes from whatever has been recorded so far. Sets that
  /// haven't been played, and anything the app doesn't record, stay blank.
  static Future<Uint8List> buildPdf(MatchEngine engine) async {
    final data = ScoresheetData.fromEngine(engine);
    final background =
        (await rootBundle.load(_backgroundAsset)).buffer.asUint8List();
    final layoutJson = await rootBundle.loadString(_layoutAsset);
    return ScoresheetPdf.build(
      data,
      background: background,
      layoutJson: layoutJson,
    );
  }

  /// Builds the sheet and opens the share sheet. Safe to call at any time.
  static Future<void> publish(BuildContext context, MatchEngine engine) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!ScoresheetData.isSupported(engine)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('The BVA scoresheet is for 3-set matches only.'),
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
      await Printing.sharePdf(bytes: bytes, filename: _fileName(engine));
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
