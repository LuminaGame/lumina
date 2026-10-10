import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/win32_window.dart';

/// Direct presentation: given a native window, FilamentWidget renders into a
/// SwapChain on it (Filament presents, the UI overlay blended on top);
/// without one, or where it cannot, it renders through the texture path and
/// says why.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 8)));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }

  group('viewportFor', () {
    test('the whole surface without a render resolution', () {
      expect(FilamentDirectPresenter.viewportFor(1920, 1080), (0, 0, 1920, 1080));
    });
    test('a narrower picture gets bars left and right', () {
      // 16:9 on 3440x1440: 2560 wide, centred.
      expect(FilamentDirectPresenter.viewportFor(3440, 1440, renderAspect: 16 / 9), (440, 0, 2560, 1440));
    });
    test('odd sizes are rounded down to even pixels (DLSS Frame Generation needs them)', () {
      expect(FilamentDirectPresenter.viewportFor(1264, 861), (0, 0, 1264, 860));
      expect(FilamentDirectPresenter.viewportFor(1265, 861, renderAspect: 4 / 3), (58, 0, 1148, 860));
    });
    test('a wider picture gets bars top and bottom', () {
      expect(FilamentDirectPresenter.viewportFor(1600, 1200, renderAspect: 16 / 9), (0, 150, 1600, 900));
    });
  });

  testWidgets('the noop backend falls back to the texture path with the reason', (tester) async {
    final statuses = <FilamentPresentationStatus>[];
    await tester.pumpWidget(MaterialApp(
      home: FilamentWidget(
        backend: FilamentBackend.noop,
        decorated: false,
        nativeSurface: MissingSurface(),
        onPresentationChanged: statuses.add,
      ),
    ));
    await settle(tester, frames: 5);
    expect(statuses.last.kind, FilamentPresentationKind.texture);
    expect(statuses.last.reason, contains('Vulkan'));
    await unmount(tester);
  });

  testWidgets('a host without a native window falls back with its reason (Vulkan)', (tester) async {
    final statuses = <FilamentPresentationStatus>[];
    await tester.pumpWidget(MaterialApp(
      home: FilamentWidget(
        backend: FilamentBackend.vulkan,
        decorated: false,
        nativeSurface: MissingSurface(),
        onPresentationChanged: statuses.add,
      ),
    ));
    await settle(tester, frames: 5);
    expect(statuses.last, const FilamentPresentationStatus(FilamentPresentationKind.texture,
        reason: 'the runner has no presentation surface'));
    await unmount(tester);
  });

  testWidgets('presents into a native window with the UI overlay, follows resizes, and goes back to the texture path',
      (tester) async {
    if (!Platform.isWindows) {
      markTestSkipped('needs a Win32 window');
      return;
    }
    final window = await tester.runAsync(() async => Win32TestWindow.open(1024, 768, 'direct presentation'));
    final surface = Win32TestSurface(window!);
    final statuses = <FilamentPresentationStatus>[];
    FilamentUiOverlay? overlay;
    var frames = 0;
    Widget host(FilamentNativeSurface? nativeSurface) => MaterialApp(
          home: FilamentWidget(
            backend: FilamentBackend.vulkan,
            decorated: false,
            physicalResolution: true,
            vsyncEnabled: false,
            nativeSurface: nativeSurface,
            onPresentationChanged: statuses.add,
            onUiOverlay: (o) => overlay = o,
            onFrame: (_, _) => frames++,
          ),
        );
    try {
      await tester.pumpWidget(host(surface));
      await settle(tester);
      window.pump();
      expect(statuses.last.kind, FilamentPresentationKind.direct, reason: '$statuses');
      expect(overlay, isNotNull);
      expect(find.byType(RawImage), findsNothing, reason: 'nothing read back into Flutter');
      final (w, h) = window.clientSize;
      final picture = Uint8List(w * h * 4)..fillRange(0, w * 4 * 40, 200);
      expect(overlay!.upload(picture, w, h), isTrue);
      frames = 0;
      await settle(tester);
      expect(frames, greaterThan(20), reason: 'frames rendered into the window');

      window.resize(800, 600);
      window.pump();
      surface.sizeChanged();
      frames = 0;
      await settle(tester);
      window.pump();
      expect(frames, greaterThan(20), reason: 'frames after the resize');

      await tester.pumpWidget(host(null));
      await settle(tester, frames: 10);
      expect(statuses.last.kind, FilamentPresentationKind.texture);
      expect(overlay, isNull);
      expect(surface.releases, 1);
    } finally {
      await unmount(tester);
      await tester.runAsync(() async => window.close());
    }
  });
}
