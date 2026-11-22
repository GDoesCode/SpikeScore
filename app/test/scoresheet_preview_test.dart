import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:spikescore/scoresheet/scoresheet_preview_screen.dart';

// A 1x1 transparent PNG, standing in for a rendered page.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  final pdf = Uint8List.fromList([1, 2, 3]);

  testWidgets('shows the rendered sheet and shares only when asked',
      (tester) async {
    final shared = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ScoresheetPreviewScreen(
        bytes: pdf,
        fileName: 'sheet.pdf',
        renderPages: (_) async => [_png],
        share: (bytes, name) async => shared.add(name),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Scoresheet preview'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(shared, isEmpty, reason: 'opening the preview must not share');

    await tester.tap(find.byKey(const Key('scoresheet-share')));
    await tester.pumpAndSettle();
    expect(shared, ['sheet.pdf']);
  });

  testWidgets('a failed render still lets the scorer share', (tester) async {
    final shared = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ScoresheetPreviewScreen(
        bytes: pdf,
        fileName: 'sheet.pdf',
        renderPages: (_) async => throw StateError('no renderer'),
        share: (bytes, name) async => shared.add(name),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not show the preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(shared, ['sheet.pdf']);
  });
}
