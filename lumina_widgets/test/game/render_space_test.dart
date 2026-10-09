import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// The game's render space inside its window: where the picture is drawn
/// (letterboxed for a chosen resolution), its pixel size (what Get Viewport
/// Size reports) and how a window position maps into it.
void main() {
  void expectOffset(Offset? actual, Offset expected) {
    expect(actual, isNotNull);
    expect(actual!.dx, closeTo(expected.dx, 1e-6));
    expect(actual.dy, closeTo(expected.dy, 1e-6));
  }

  group('letterbox, bars left and right (1920x1080 on 3440x1440)', () {
    const space = LuminaRenderSpace(space: Size(3440, 1440), renderResolution: (1920, 1080));

    test('the picture is 2560x1440, centred; the view and the UI are 1920x1080', () {
      expect(space.rect, const Rect.fromLTWH(440, 0, 2560, 1440));
      expect(space.viewportPixels, const Size(1920, 1080));
      expect(space.layoutSize, const Size(1920, 1080));
    });

    test('window positions map to render pixels; the bars map to nothing', () {
      expectOffset(space.toViewport(const Offset(440, 0)), Offset.zero);
      expectOffset(space.toViewport(const Offset(1720, 720)), const Offset(960, 540));
      expectOffset(space.toViewport(const Offset(2999, 1439)), const Offset(1919.25, 1079.25));
      expect(space.toViewport(const Offset(100, 700)), isNull);
      expect(space.toViewport(const Offset(3300, 700)), isNull);
    });

    test('a position on a bar clamps to the nearest edge of the picture', () {
      expectOffset(space.clampToViewport(const Offset(100, 720)), const Offset(0, 540));
      expectOffset(space.clampToViewport(const Offset(3400, 1440)), const Offset(1920, 1080));
    });

    test('render pixels map back to the window', () {
      expectOffset(space.fromViewport(const Offset(1920, 1080)), const Offset(3000, 1440));
      expectOffset(space.fromViewport(const Offset(960, 540)), const Offset(1720, 720));
    });
  });

  test('letterbox, bars top and bottom (1920x1080 on 1280x1024)', () {
    const space = LuminaRenderSpace(space: Size(1280, 1024), renderResolution: (1920, 1080));
    expect(space.rect.left, 0);
    expect(space.rect.top, closeTo(152, 1e-9));
    expect(space.rect.size.width, closeTo(1280, 1e-9));
    expect(space.rect.size.height, closeTo(720, 1e-9));
    expectOffset(space.toViewport(const Offset(640, 512)), const Offset(960, 540));
    expect(space.toViewport(const Offset(640, 100)), isNull);
    expect(space.toViewport(const Offset(640, 900)), isNull);
    expectOffset(space.clampToViewport(const Offset(640, 1000)), const Offset(960, 1080));
  });

  test('letterbox at device pixel ratio 2: render pixels stay the chosen resolution, the UI its logical half', () {
    // A 3440x1440 monitor at 200 %: 1720x720 logical.
    const space = LuminaRenderSpace(space: Size(1720, 720), renderResolution: (1920, 1080), devicePixelRatio: 2);
    expect(space.rect, const Rect.fromLTWH(220, 0, 1280, 720));
    expect(space.viewportPixels, const Size(1920, 1080));
    expect(space.layoutSize, const Size(960, 540));
    expectOffset(space.toViewport(const Offset(860, 360)), const Offset(960, 540));
    expectOffset(space.toViewport(const Offset(220, 0)), Offset.zero);
    expect(space.toViewport(const Offset(100, 360)), isNull);
  });

  group('windowed (no chosen resolution): identity up to the pixel ratio', () {
    test('DPR 1', () {
      const space = LuminaRenderSpace(space: Size(1280, 720));
      expect(space.rect, const Rect.fromLTWH(0, 0, 1280, 720));
      expect(space.viewportPixels, const Size(1280, 720));
      expect(space.layoutSize, const Size(1280, 720));
      expectOffset(space.toViewport(const Offset(10, 20)), const Offset(10, 20));
    });

    test('DPR 2 with a physical-pixel view', () {
      const space = LuminaRenderSpace(space: Size(1280, 720), devicePixelRatio: 2);
      expect(space.viewportPixels, const Size(2560, 1440));
      expect(space.layoutSize, const Size(1280, 720));
      expectOffset(space.toViewport(const Offset(10, 20)), const Offset(20, 40));
    });

    test('DPR 2 with a logical-pixel view', () {
      const space = LuminaRenderSpace(space: Size(1280, 720), devicePixelRatio: 2, physicalPixels: false);
      expect(space.viewportPixels, const Size(1280, 720));
      expectOffset(space.toViewport(const Offset(10, 20)), const Offset(10, 20));
    });
  });

  test('a chosen resolution at least the window size still fits with its aspect kept', () {
    const space = LuminaRenderSpace(space: Size(1920, 1080), renderResolution: (1920, 1080));
    expect(space.rect, const Rect.fromLTWH(0, 0, 1920, 1080));
    expectOffset(space.toViewport(const Offset(5, 7)), const Offset(5, 7));
  });
}
