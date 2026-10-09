import 'dart:ui' show Offset, Size;

import 'package:flutter/gestures.dart' show kPrimaryMouseButton, kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaKey;
import 'package:lumina_ui/ui/features/main_editor/services/pie_pointer_input.dart';

/// The rules of Play-In-Editor's mouse, without an editor: where the
/// position lands in view pixels, and which clicks the game gets.
void main() {
  late bool accepts, holds, released, uiOnly;
  late List<String> log;
  late (int, int)? viewport;
  late PiePointerInput input;

  setUp(() {
    accepts = true;
    holds = false;
    released = false;
    uiOnly = false;
    log = [];
    viewport = null;
    input = PiePointerInput(
      acceptsGameInput: () => accepts,
      gameHoldsCursor: () => holds,
      cursorReleased: () => released,
      uiOnly: () => uiOnly,
      injectPosition: (x, y) => log.add('pos ${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}'),
      injectKeyDown: (k) => log.add('down ${k.id}'),
      injectKeyUp: (k) => log.add('up ${k.id}'),
      setViewportSize: (w, h) => viewport = (w, h),
    )
      ..viewSize = (() => const Size(1100, 640))
      ..devicePixelRatio = (() => 2.0);
  });

  test('the position is in the view\'s pixels: the PIE view renders its logical size, whatever the pixel ratio', () {
    input.hover(const Offset(275, 160));
    expect(log, ['pos 275.0,160.0']);
    input.syncViewportSize();
    expect(viewport, (1100, 640), reason: 'Get Viewport Size is the view the game is drawn in');
  });

  test('a position outside the view is clamped to its edge; nothing reaches a session that takes no input', () {
    input.hover(const Offset(-40, 900));
    expect(log, ['pos 0.0,640.0']);
    accepts = false;
    log.clear();
    input.hover(const Offset(10, 10));
    input.viewButtons(const Offset(10, 10), kPrimaryMouseButton);
    expect(log, isEmpty);
  });

  test('a free cursor clicks into the game; UI Only and the F4 recapture click do not; a release always arrives', () {
    input.viewButtons(const Offset(5, 5), kPrimaryMouseButton | kSecondaryMouseButton);
    expect(log.where((l) => l.startsWith('down')), ['down ${LuminaKey.mouseLeft.id}', 'down ${LuminaKey.mouseRight.id}']);
    log.clear();
    accepts = false;
    input.viewButtons(const Offset(5, 5), 0);
    expect(log.where((l) => l.startsWith('up')), ['up ${LuminaKey.mouseLeft.id}', 'up ${LuminaKey.mouseRight.id}'],
        reason: 'buttons pressed before a pause are released');

    accepts = true;
    uiOnly = true;
    log.clear();
    input.viewButtons(const Offset(5, 5), kPrimaryMouseButton);
    expect(log.where((l) => l.startsWith('down')), isEmpty, reason: 'UI Only: clicks are the UI\'s');

    uiOnly = false;
    released = true;
    input.viewButtons(const Offset(5, 5), kPrimaryMouseButton);
    expect(log.where((l) => l.startsWith('down')), isEmpty, reason: 'the click that takes the mouse again');
  });

  test('while the game holds the cursor every click is the game\'s, also through the window shield', () {
    holds = true;
    input.heldButtons(const Offset(550, 320), kPrimaryMouseButton);
    expect(log, ['pos 550.0,320.0', 'down ${LuminaKey.mouseLeft.id}']);
    input.heldButtons(const Offset(550, 320), 0);
    expect(log.last, 'up ${LuminaKey.mouseLeft.id}');
    expect(input.pressedForTest, isEmpty);

    holds = false;
    log.clear();
    input.heldButtons(const Offset(550, 320), kPrimaryMouseButton);
    expect(log.where((l) => l.startsWith('down')), isEmpty, reason: 'the shield only stands for a held cursor');
  });
}
