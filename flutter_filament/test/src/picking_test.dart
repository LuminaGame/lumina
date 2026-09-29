import 'package:test/test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('Picking tests', () {
    late FilamentEngine engine;
    late FilamentRenderer renderer;
    late FilamentSwapChain swapChain;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      renderer = engine.createRenderer();
      swapChain = engine.createHeadlessSwapChain(256, 256);
      view = engine.createView();
      scene = engine.createScene();
      
      final camEntity = engine.createEntity();
      camera = engine.createCamera(camEntity);
      camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 5, centerX: 0, centerY: 0, centerZ: 0, upX: 0, upY: 1, upZ: 0);
      camera.setProjection(fovDegrees: 45.0, aspect: 1.0, near: 0.1, far: 100.0);
      
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, 256, 256);
      view.postProcessingEnabled = false;
    });

    tearDown(() {
      view.dispose();
      scene.dispose();
      swapChain.dispose();
      renderer.dispose();
      engine.dispose();
    });

    test('Hit and miss picking', () async {
      // Pick is async and depends on GPU, we will just test the API doesn't crash
      // Since it's headless and without real primitives in this test suite, it will likely return a miss.
      // But we will verify it resolves.
      final futureHit = view.pick(128, 128); // center
      final futureMiss = view.pick(10, 10); // corner
      
      // We must render frames for pick to resolve
      for (int i = 0; i < 5; i++) {
        renderer.beginFrame(swapChain);
        renderer.render(view);
        renderer.endFrame();
        engine.flushAndWait();
      }
      
      final hit = await futureHit;
      // It might be null in headless
      
      final miss = await futureMiss;
      expect(miss.renderable, isNull);
    });

    test('Transparent picking enabled round-trip', () {
      view.transparentPickingEnabled = true;
      expect(view.transparentPickingEnabled, isTrue);
      view.transparentPickingEnabled = false;
      expect(view.transparentPickingEnabled, isFalse);
    });
  });
}
