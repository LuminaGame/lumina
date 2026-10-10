import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Frame generation is not applied while the game is shown through Flutter
/// (one shown frame per rendered frame: generated frames would only cost
/// frame rate). The player's choice is kept, it still asks for Direct, the
/// reason is a rendering fallback, and it is applied again as soon as
/// nothing shows the game through Flutter.
void main() {
  FilamentEngine? engine;
  LuminaWorld? world;

  setUp(() {
    LuminaGamePresentation.reset();
    try {
      engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
    } catch (_) {
      engine = null;
    }
    final e = engine;
    if (e == null) return;
    final scene = e.createScene();
    final view = e.createView()
      ..scene = scene
      ..camera = e.createCamera(e.createEntity())
      ..setViewport(0, 0, 640, 360);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(e, scene, view: view);
  });

  tearDown(() {
    world?.cleanup();
    world = null;
    engine?.dispose();
    engine = null;
    LuminaGamePresentation.reset();
  });

  /// The world with FSR3 frame generation chosen, or null to skip.
  LuminaUserSettingsSubsystem? chooseFrameGeneration() {
    final w = world;
    if (w == null) return null;
    w.beginPlay();
    final settings = w.userSettings;
    if (!settings.renderingSupport.frameGeneration) return null;
    settings
      ..setUpscaler('FSR3')
      ..setFrameGenerator('FSR3')
      ..setFrameGenerationEnabled(true)
      ..applySettings();
    return settings;
  }

  const fallback = 'Frame generation is off: the game presents through Flutter (player setting).';

  test('shown through Flutter: not applied, recorded as a fallback, the choice kept; applied again with Direct', () {
    final settings = chooseFrameGeneration();
    if (settings == null) return markTestSkipped('needs a Vulkan engine with frame generation');
    expect(settings.activeRenderingFeatures.frameGeneration, isTrue, reason: 'no Flutter host: applied');
    expect(LuminaRtxController.frameGenerationActive.value, isTrue);
    expect(LuminaGamePresentation.requested.value,
        const LuminaPresentationDecision(LuminaPresentationMode.direct, reason: 'frame generation'));

    LuminaGamePresentation.setFlutterPresentation('player setting');
    world!.tick(1 / 60);
    expect(settings.frameGenerationEnabled, isTrue, reason: "Get Frame Generation Enabled: the player's choice");
    expect(settings.activeRenderingFeatures.frameGeneration, isFalse);
    expect(settings.frameGenerationActive, isFalse);
    final actor = LuminaActor();
    world!.persistentLevel.registerActor(actor);
    expect(LuminaBlueprintFunctionLibrary.isFrameGenerationActive(actor), isFalse, reason: 'Is Frame Generation Active');
    expect(LuminaBlueprintFunctionLibrary.getFrameGenerationEnabled(actor), isTrue, reason: 'Get Frame Generation Enabled');
    expect(settings.activeRenderingFeatures.upscaler, LuminaUpscaler.fsr3, reason: 'the upscaler stays');
    expect(settings.renderingFallbacks, contains(fallback));
    expect(LuminaRtxController.frameGenerationActive.value, isFalse);
    expect(LuminaGamePresentation.frameGenerationRequested, isTrue, reason: 'it still asks for Direct');

    // Direct in effect: nothing shows the game through Flutter.
    LuminaGamePresentation.setFlutterPresentation(null);
    world!.tick(1 / 60);
    expect(settings.activeRenderingFeatures.frameGeneration, isTrue);
    expect(settings.renderingFallbacks, isNot(contains(fallback)));
    expect(LuminaRtxController.frameGenerationActive.value, isTrue);

    // Turned off by the player: no request for Direct any more.
    settings
      ..setFrameGenerationEnabled(false)
      ..applySettings();
    expect(LuminaGamePresentation.frameGenerationRequested, isFalse);
    expect(LuminaGamePresentation.requested.value.mode, LuminaPresentationMode.flutter);
  });

  test('a Direct failure with frame generation chosen is stable: Flutter, frame generation off, no flip-flop', () {
    final settings = chooseFrameGeneration();
    if (settings == null) return markTestSkipped('needs a Vulkan engine with frame generation');
    var requestChanges = 0;
    var activeChanges = 0;
    void onRequest() => requestChanges++;
    void onActive() => activeChanges++;
    LuminaGamePresentation.requested.addListener(onRequest);
    LuminaRtxController.frameGenerationActive.addListener(onActive);
    addTearDown(() {
      LuminaGamePresentation.requested.removeListener(onRequest);
      LuminaRtxController.frameGenerationActive.removeListener(onActive);
    });

    // What the game host does when Direct cannot run.
    LuminaGamePresentation.reportFallback('no game window channel');
    LuminaGamePresentation.setFlutterPresentation('no game window channel');
    for (var i = 0; i < 120; i++) {
      world!.tick(1 / 60);
    }
    expect(requestChanges, 0, reason: 'frame generation going inactive does not withdraw the request for Direct');
    expect(activeChanges, 1, reason: 'turned off once, never back on');
    expect(LuminaGamePresentation.decision.value,
        const LuminaPresentationDecision(LuminaPresentationMode.flutter, reason: 'no game window channel'));
    expect(settings.activeRenderingFeatures.frameGeneration, isFalse);
    expect(settings.renderingFallbacks,
        contains('Frame generation is off: the game presents through Flutter (no game window channel).'));
  });

  test('the world going away withdraws its request for Direct', () {
    final settings = chooseFrameGeneration();
    if (settings == null) return markTestSkipped('needs a Vulkan engine with frame generation');
    expect(LuminaGamePresentation.frameGenerationRequested, isTrue);
    world!.cleanup();
    world = null;
    expect(LuminaGamePresentation.frameGenerationRequested, isFalse);
    expect(LuminaRtxController.frameGenerationActive.value, isFalse);
  });
}
