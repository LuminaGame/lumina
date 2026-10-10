import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;

import '../smoke/smoke_helper.dart';

/// A premultiplied RGBA8 picture of [w] x [h]: [color] in the top-left
/// quarter, transparent elsewhere.
Uint8List quarterPicture(int w, int h, List<int> color) {
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h ~/ 2; y++) {
    for (var x = 0; x < w ~/ 2; x++) {
      rgba.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, color);
    }
  }
  return rgba;
}

/// The UI overlay of direct presentation blends a premultiplied picture over
/// the frame already in the SwapChain, after the main view.
void main() {
  group('UI overlay on a headless SwapChain', () {
    const size = 256;
    late SmokeRig rig;
    FilamentUiOverlay? overlay;
    LoadedGltf? barrel;

    setUp(() {
      rig = SmokeRig.create(width: size, height: size, backend: FilamentBackend.vulkan);
      rig.renderer.clearOptions = ClearOptions(clearColor: Vector4(0, 0, 1, 1), clear: true);
      rig.addSun();
      barrel = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_red.glb');
      overlay = FilamentUiOverlay.create(rig.engine);
      overlay?.setViewport(0, 0, size, size);
    });

    tearDown(() {
      overlay?.dispose();
      barrel?.dispose(rig.scene);
      rig.dispose();
    });

    /// One frame: the main view, then the overlay; the SwapChain read back.
    Uint8List frame() {
      final out = calloc<ffi.Uint8>(size * size * 4);
      try {
        for (var rendered = 0, attempts = 0; rendered < 4 && attempts < 400; attempts++) {
          sleep(const Duration(milliseconds: 4));
          if (!rig.renderer.beginFrame(rig.swapChain)) continue;
          rig.renderer.render(rig.view);
          overlay!.render(rig.renderer);
          if (++rendered == 4) {
            c.filament_renderer_read_pixels(rig.renderer.nativePointer, rig.engine.nativePointer, 0, 0, size, size,
                out.cast(), ffi.nullptr, ffi.nullptr);
          }
          rig.renderer.endFrame();
        }
        rig.engine.flushAndWait();
        return Uint8List.fromList(out.asTypedList(size * size * 4));
      } finally {
        calloc.free(out);
      }
    }

    List<int> px(Uint8List rgba, int x, int y) => rgba.sublist((y * size + x) * 4, (y * size + x) * 4 + 4);

    /// The main view dithers: the same pixel differs by one between frames.
    void expectNear(List<int> actual, List<int> expected, String reason) {
      for (var i = 0; i < 3; i++) {
        expect(actual[i], closeTo(expected[i], 2), reason: '$reason: $actual vs $expected');
      }
    }

    test('blends a premultiplied picture over the frame, top rows first', () {
      expect(overlay, isNotNull);
      final base = frame();
      expect(overlay!.upload(quarterPicture(size, size, [128, 0, 0, 128]), size, size), isTrue);
      final withUi = frame();
      // Top-left quarter: 128 + base * (1 - 128/255) per channel.
      for (final (x, y) in [(10, 10), (60, 100), (120, 120)]) {
        final b = px(base, x, y);
        final p = px(withUi, x, y);
        expect(p[0], closeTo(128 + b[0] * 127 / 255, 3), reason: 'red at ($x, $y): base $b, got $p');
        expect(p[1], closeTo(b[1] * 127 / 255, 3), reason: 'green at ($x, $y)');
        expect(p[2], closeTo(b[2] * 127 / 255, 3), reason: 'blue at ($x, $y)');
      }
      // Elsewhere the frame is unchanged.
      for (final (x, y) in [(200, 200), (200, 10), (10, 200)]) {
        expectNear(px(withUi, x, y), px(base, x, y), '($x, $y)');
      }
      expect(overlay!.uploadCount, 1);
    });

    test('clear() leaves the frame alone; a picture of another size is stretched over the viewport', () {
      final base = frame();
      overlay!.upload(quarterPicture(size, size, [255, 255, 255, 255]), size, size);
      frame();
      overlay!.clear();
      expect(overlay!.hasContent, isFalse);
      final cleared = frame();
      expectNear(px(cleared, 30, 30), px(base, 30, 30), 'cleared');
      expect(overlay!.upload(quarterPicture(64, 64, [0, 255, 0, 255]), 64, 64), isTrue);
      final small = frame();
      expectNear(px(small, 40, 40), [0, 255, 0], 'small picture, top-left');
      expectNear(px(small, 200, 200), px(base, 200, 200), 'small picture, bottom-right');
    });

    test('upload refuses a buffer shorter than the size', () {
      expect(overlay!.upload(Uint8List(10), 4, 4), isFalse);
      expect(overlay!.hasContent, isFalse);
    });
  });
}
