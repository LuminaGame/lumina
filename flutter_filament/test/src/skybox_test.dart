import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;
  late FilamentSwapChain swapChain;
  late FilamentRenderer renderer;
  late FilamentView view;
  late FilamentScene scene;

  setUp(() {
    engine = FilamentEngine.create()!;
    swapChain = engine.createHeadlessSwapChain(64, 64);
    renderer = engine.createRenderer();
    view = engine.createView();
    scene = engine.createScene();
    view.scene = scene;
  });

  tearDown(() {
    view.dispose();
    scene.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  group('FilamentSkybox Tests', () {
    test('Skybox.build with solid color and intensity query', () {
      final skybox = FilamentSkybox.build(
        engine,
        color: Vector4(1.0, 0.0, 0.0, 1.0),
        intensity: 20000.0,
        priority: 7,
      );

      scene.skybox = skybox;
      expect(skybox.intensity, closeTo(20000.0, 1.0));
      expect(skybox.texture, isNull);

      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      skybox.dispose();
    });

    test('Skybox priority range validation', () {
      expect(
        () => FilamentSkybox.build(engine, priority: -1),
        throwsArgumentError,
      );
      expect(
        () => FilamentSkybox.build(engine, priority: 8),
        throwsArgumentError,
      );

      final validSkybox = FilamentSkybox.build(engine, priority: 0);
      validSkybox.dispose();
    });

    test('Skybox layer mask and runtime color update', () {
      final skybox = FilamentSkybox.build(
        engine,
        color: Vector4(0.2, 0.4, 0.6, 1.0),
      );
      scene.skybox = skybox;

      skybox.setLayerMask(select: 0xFF, values: 0x02);
      expect(skybox.layerMask, equals(0x02));

      // Runtime color update
      skybox.color = Vector4(0.8, 0.1, 0.1, 1.0);
      skybox.setColor(r: 0.1, g: 0.8, b: 0.1, a: 1.0);

      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      skybox.dispose();
    });

    test('Skybox with showSun flag true renders without crash', () {
      final skybox = FilamentSkybox.build(
        engine,
        color: Vector4(0.1, 0.1, 0.1, 1.0),
        showSun: true,
      );
      scene.skybox = skybox;

      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      skybox.dispose();
    });
  });
}
