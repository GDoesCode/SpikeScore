import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

/// Turns PDF bytes into one PNG image per page.
typedef PdfPageRenderer = Future<List<Uint8List>> Function(Uint8List pdf);

/// Shows the filled-in scoresheet so the scorer can check it before sending
/// it anywhere. Pinch to zoom; the share icon (top right) opens the phone's share sheet
/// (save to Files, email, print, ...). Everything happens on the device.
class ScoresheetPreviewScreen extends StatefulWidget {
  const ScoresheetPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    this.renderPages = rasterizePdf,
    this.share = sharePdf,
  });

  final Uint8List bytes;
  final String fileName;

  /// Swappable so widget tests don't need the native PDF renderer.
  final PdfPageRenderer renderPages;
  final Future<void> Function(Uint8List bytes, String fileName) share;

  /// Renders each page at a resolution that stays sharp when zoomed in on a
  /// phone (the sheet is A4 landscape, so ~2300 px wide at 200 dpi).
  static Future<List<Uint8List>> rasterizePdf(Uint8List pdf) async {
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(pdf, dpi: 200)) {
      pages.add(await page.toPng());
    }
    return pages;
  }

  static Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  @override
  State<ScoresheetPreviewScreen> createState() =>
      _ScoresheetPreviewScreenState();
}

class _ScoresheetPreviewScreenState extends State<ScoresheetPreviewScreen> {
  late final Future<List<Uint8List>> _pages = widget.renderPages(widget.bytes);
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.share(widget.bytes, widget.fileName);
    } catch (e, st) {
      debugPrint('SpikeScore: could not share scoresheet: $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share the scoresheet: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade800,
      appBar: AppBar(
        title: const Text('Scoresheet preview'),
        actions: [
          IconButton(
            key: const Key('scoresheet-share'),
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _pages,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not show the preview (${snap.error}).\n'
                  'You can still share the PDF.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final png in snap.data!)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            color: Colors.white,
                            child: Image.memory(png, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
