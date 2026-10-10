import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart';

class _TickCounter extends LuminaActor {
  int ticks = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    ticks++;
  }
}

class _BoxGame extends LuminaGame {
  final _TickCounter counter = _TickCounter();

  @override
  LuminaObject? build(LuminaBuildContext context) => LuminaNodeGroup(children: [
        counter,
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.box, size: Vector3.all(100), color: Vector3(0.8, 0.4, 0.2)),
        LuminaActor(root: LuminaDirectionalLightComponent(intensity: 100000)),
      ]);
}

/// On the Flutter presentation path the FilamentWidget renders the game's
/// view (into its own swap chain, read back for Flutter); the frame driver
/// only ticks and paces the world. The view's temporal history (TAA,
/// upscalers, frame generation) advances once per shown frame. Frame
/// generation is not applied while Flutter shows the game (a rendering
/// fallback), and a failed Direct request does not turn into a retry loop.
void main() {
  setUp(LuminaGamePresentation.reset);
  tearDown(LuminaGamePresentation.reset);

  Future<(LuminaFrameDriver?, _BoxGame)> mount(WidgetTester tester, {bool allowDirect = false}) async {
    final game = _BoxGame();
    LuminaFrameDriver? driver;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        height: 240,
        child: LuminaGameWidget(
            game: game, decorated: false, allowDirectPresentation: allowDirect, onFrameDriver: (d) => driver = d),
      ),
    ));
    return (driver, game);
  }

  /// The game's user settings with FSR3 frame generation chosen, or null
  /// (skipped) without a Vulkan scene that supports it.
  Future<LuminaUserSettingsSubsystem?> chooseFrameGeneration(WidgetTester tester, LuminaGame game) async {
    final world = game.world;
    final engine = world?.filamentEngineOrNull;
    if (world == null || engine == null || engine.backend != FilamentBackend.vulkan) {
      await tester.pumpWidget(const SizedBox.shrink());
      markTestSkipped('needs the FilamentWidget scene on a Vulkan engine');
      return null;
    }
    final settings = world.userSettings;
    if (!settings.renderingSupport.frameGeneration) {
      await tester.pumpWidget(const SizedBox.shrink());
      markTestSkipped('no frame generation here: ${settings.renderingSupport}');
      return null;
    }
    settings
      ..setUpscaler('FSR3')
      ..setFrameGenerator('FSR3')
      ..setFrameGenerationEnabled(true)
      ..applySettings();
    return settings;
  }

  /// One Flutter frame plus real time for the readback's image decode.
  Future<void> frame(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 4)));
  }

  ui.Image? shown(WidgetTester tester) {
    final images = find.byType(RawImage);
    return images.evaluate().isEmpty ? null : tester.widget<RawImage>(images.first).image;
  }

  testWidgets('the frame driver ticks the world without rendering the view a second time', (tester) async {
    final (driverOrNull, game) = await mount(tester);
    for (var i = 0; i < 3; i++) {
      await frame(tester);
    }
    final driver = driverOrNull;
    if (driver == null) {
      await tester.pumpWidget(const SizedBox.shrink());
      return markTestSkipped('FilamentWidget did not create a scene in the test binding');
    }
    for (var i = 0; i < 30; i++) {
      await frame(tester);
    }
    expect(game.counter.ticks, greaterThan(20), reason: 'the driver ticks the world');
    expect(driver.renderedFrames, 0, reason: 'the FilamentWidget is the only renderer of the view');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('frame generation chosen on a Flutter host: not applied, a fallback, new frames keep coming', (tester) async {
    final (driver, game) = await mount(tester);
    for (var i = 0; i < 3; i++) {
      await frame(tester);
    }
    if (driver == null) {
      await tester.pumpWidget(const SizedBox.shrink());
      return markTestSkipped('FilamentWidget did not create a scene in the test binding');
    }
    final settings = await chooseFrameGeneration(tester, game);
    if (settings == null) return;
    expect(LuminaGamePresentation.flutterPresentation.value, 'the host presents through Flutter');
    expect(settings.frameGenerationEnabled, isTrue, reason: "the player's choice is kept");
    expect(settings.activeRenderingFeatures.frameGeneration, isFalse);
    expect(LuminaRtxController.frameGenerationActive.value, isFalse);
    expect(settings.renderingFallbacks,
        contains('Frame generation is off: the game presents through Flutter (the host presents through Flutter).'));

    var newImages = 0;
    ui.Image? last = shown(tester);
    final clock = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      await frame(tester);
      final image = shown(tester);
      if (image != null && !identical(image, last)) newImages++;
      last = image;
    }
    expect(newImages, greaterThan(40), reason: 'a new frame for (nearly) every Flutter frame');
    expect(clock.elapsed, lessThan(const Duration(seconds: 30)), reason: 'no readback stalls');
    expect(driver.renderedFrames, 0);
    settings
      ..setFrameGenerationEnabled(false)
      ..setUpscaler('None')
      ..applySettings();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(LuminaGamePresentation.flutterPresentation.value, isNull, reason: 'the host went away');
  });

  testWidgets('a refused Direct request with frame generation chosen stays on Flutter, frame generation off, no retries',
      (tester) async {
    const channel = MethodChannel(LuminaWindowModeChannel.channelName);
    var createSurface = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createSurface') {
        createSurface++;
        throw PlatformException(code: 'unsupported', message: 'direct presentation is not available on this desktop');
      }
      return null;
    });
    LuminaGameWindow.backend = LuminaWindowModeChannel();
    addTearDown(() {
      LuminaGameWindow.backend = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    final (driver, game) = await mount(tester, allowDirect: true);
    for (var i = 0; i < 3; i++) {
      await frame(tester);
    }
    if (driver == null) {
      await tester.pumpWidget(const SizedBox.shrink());
      return markTestSkipped('FilamentWidget did not create a scene in the test binding');
    }
    final settings = await chooseFrameGeneration(tester, game);
    if (settings == null) return;
    var requestChanges = 0;
    void onRequest() => requestChanges++;
    for (var i = 0; i < 10; i++) {
      await frame(tester);
    }
    LuminaGamePresentation.requested.addListener(onRequest);
    final surfacesAsked = createSurface;
    for (var i = 0; i < 60; i++) {
      await frame(tester);
    }
    LuminaGamePresentation.requested.removeListener(onRequest);
    expect(LuminaGamePresentation.requested.value.mode, LuminaPresentationMode.direct, reason: 'still asked for');
    expect(LuminaGamePresentation.decision.value.mode, LuminaPresentationMode.flutter);
    expect(requestChanges, 0, reason: 'no flip-flop');
    expect(createSurface, lessThanOrEqualTo(1), reason: 'the runner is asked at most once');
    expect(createSurface, surfacesAsked, reason: 'and never again while it stays refused');
    final reason = LuminaGamePresentation.decision.value.reason!;
    expect(LuminaGamePresentation.flutterPresentation.value, reason);
    expect(settings.activeRenderingFeatures.frameGeneration, isFalse);
    expect(settings.renderingFallbacks, contains('Frame generation is off: the game presents through Flutter ($reason).'));
    settings
      ..setFrameGenerationEnabled(false)
      ..setUpscaler('None')
      ..applySettings();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  });
}
