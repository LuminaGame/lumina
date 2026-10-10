import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The widget's target frame rate counts display refreshes (the frame's vsync
/// timestamp), not the wall clock, and follows a rebuild with a new target.
void main() {
  const refresh = Duration(microseconds: 16667);

  Widget host({int? targetFps, bool vsyncEnabled = false, required void Function() onFrame}) => MaterialApp(
        home: SizedBox(
          width: 64,
          height: 48,
          child: FilamentWidget(
            backend: FilamentBackend.noop,
            targetFps: targetFps,
            vsyncEnabled: vsyncEnabled,
            skipReadPixels: true,
            onFrame: (_, _) => onFrame(),
          ),
        ),
      );

  Future<int> framesOver(WidgetTester tester, int refreshes, int Function() count) async {
    final before = count();
    for (var i = 0; i < refreshes; i++) {
      await tester.pump(refresh);
    }
    return count() - before;
  }

  testWidgets('30 FPS renders every other refresh, unlimited every refresh, 120 is capped', (tester) async {
    var frames = 0;
    void onFrame() => frames++;
    await tester.pumpWidget(host(targetFps: 30, onFrame: onFrame));
    // The engine starts after the first frame.
    await framesOver(tester, 10, () => frames);

    expect(await framesOver(tester, 120, () => frames), inInclusiveRange(59, 61));

    await tester.pumpWidget(host(onFrame: onFrame));
    expect(await framesOver(tester, 120, () => frames), inInclusiveRange(119, 120));

    await tester.pumpWidget(host(targetFps: 120, vsyncEnabled: true, onFrame: onFrame));
    expect(await framesOver(tester, 120, () => frames), inInclusiveRange(119, 120));

    await tester.pumpWidget(host(targetFps: 45, vsyncEnabled: true, onFrame: onFrame));
    expect(await framesOver(tester, 120, () => frames), inInclusiveRange(59, 61));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
