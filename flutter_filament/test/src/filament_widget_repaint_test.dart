import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rendered frame used to share a paint layer with
/// whatever surrounds the widget, so every new frame repainted the whole host
/// window (the entire Lumina Studio editor) and capped the viewport's FPS.
void main() {
  testWidgets('each new frame repaints only the frame, in its own layer', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 200,
          child: FilamentWidget(backend: FilamentBackend.noop),
        ),
      ),
    ));

    // Let the engine initialise and a frame render, read back and decode.
    RawImage? image;
    for (var i = 0; i < 60 && image == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      final found = find.byType(RawImage);
      if (found.evaluate().isNotEmpty) image = tester.widget<RawImage>(found);
    }
    expect(image, isNotNull, reason: 'the widget must present a rendered frame');

    final renderImage = tester.renderObject<RenderImage>(find.byType(RawImage));
    RenderObject? node = renderImage;
    RenderObject? boundary;
    while (node != null) {
      if (node.isRepaintBoundary) {
        boundary = node;
        break;
      }
      node = node.parent;
    }
    expect(boundary, isNotNull);
    // The nearest repaint boundary must be the frame's own, not an ancestor
    // shared with the rest of the host UI.
    final boundaryBox = boundary! as RenderBox;
    expect(boundaryBox.size, renderImage.size,
        reason: 'the frame must be isolated in a layer of its own size');

    // Dispose the widget (and its engine) while real async is available.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
