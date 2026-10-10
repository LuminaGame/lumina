import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// A label whose text the test changes.
class _Label extends StatefulWidget {
  const _Label({super.key});

  @override
  State<_Label> createState() => _LabelState();
}

class _LabelState extends State<_Label> {
  String text = 'Health 100';

  void set(String value) => setState(() => text = value);

  @override
  Widget build(BuildContext context) => Text(text, textDirection: TextDirection.ltr);
}

/// The game's UI is captured for Filament only after a frame that changed it.
void main() {
  late FilamentEngine engine;
  late FilamentUiOverlay overlay;

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    overlay = FilamentUiOverlay.create(engine)!;
    LuminaUiCapture.stats.value = const LuminaUiCaptureStats();
  });

  tearDown(() {
    overlay.dispose();
    engine.dispose();
  });

  /// Pumps [frames] frames and lets the asynchronous readbacks finish.
  Future<void> frames(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  testWidgets('a static UI is captured once, a changed one again, at the device pixel ratio', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final label = GlobalKey<_LabelState>();
    await tester.pumpWidget(LuminaUiCapture(overlay: overlay, child: Center(child: _Label(key: label))));
    await frames(tester, 6);
    var stats = LuminaUiCapture.stats.value;
    expect(stats.captures, 1);
    expect((stats.lastWidth, stats.lastHeight), (800, 600));
    expect(overlay.uploadCount, 1);
    expect(overlay.pictureSize, (800, 600));

    label.currentState!.set('Health 90');
    await frames(tester, 4);
    stats = LuminaUiCapture.stats.value;
    expect(stats.captures, 2);
    expect(stats.lastLatencyMicros, greaterThan(0));
  });

  testWidgets('a change inside a nested repaint boundary is captured too', (tester) async {
    final label = GlobalKey<_LabelState>();
    await tester.pumpWidget(LuminaUiCapture(
      overlay: overlay,
      child: Center(child: RepaintBoundary(child: RepaintBoundary(child: _Label(key: label)))),
    ));
    await frames(tester, 4);
    expect(LuminaUiCapture.stats.value.captures, 1);
    label.currentState!.set('Ammo 12');
    await frames(tester, 4);
    expect(LuminaUiCapture.stats.value.captures, 2);
  });

  testWidgets('without an overlay nothing is captured', (tester) async {
    await tester.pumpWidget(const LuminaUiCapture(overlay: null, child: SizedBox.expand()));
    await frames(tester, 4);
    expect(LuminaUiCapture.stats.value.captures, 0);
    expect(overlay.uploadCount, 0);
  });
}
