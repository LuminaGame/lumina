import 'dart:ffi' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Engine::Builder and Engine::Config Tests', () {
    test('enum values fidelity and explicit indices', () {
      expect(FilamentBackend.defaultBackend.value, equals(0));
      expect(FilamentBackend.opengl.value, equals(1));
      expect(FilamentBackend.vulkan.value, equals(2));
      expect(FilamentBackend.metal.value, equals(3));
      expect(FilamentBackend.webgpu.value, equals(4));
      expect(FilamentBackend.noop.value, equals(5));

      expect(ShaderLanguage.default_.value, equals(0));
      expect(ShaderLanguage.msl.value, equals(1));
      expect(ShaderLanguage.metalLibrary.value, equals(2));

      expect(GpuContextPriority.default_.value, equals(0));
      expect(GpuContextPriority.low.value, equals(1));
      expect(GpuContextPriority.medium.value, equals(2));
      expect(GpuContextPriority.high.value, equals(3));
      expect(GpuContextPriority.realtime.value, equals(4));

      expect(FeatureLevel.fl0.value, equals(0));
      expect(FeatureLevel.fl1.value, equals(1));
      expect(FeatureLevel.fl2.value, equals(2));
      expect(FeatureLevel.fl3.value, equals(3));

      expect(StereoscopicType.none.value, equals(0));
      expect(StereoscopicType.instanced.value, equals(1));
      expect(StereoscopicType.multiview.value, equals(2));
    });

    test('EngineConfig.defaults() returns valid non-zero configuration', () {
      final defaults = EngineConfig.defaults();
      expect(defaults.commandBufferSizeMB, greaterThan(0));
      expect(defaults.perRenderPassArenaSizeMB, greaterThan(0));
      expect(defaults.minCommandBufferSizeMB, greaterThan(0));
      expect(defaults.preferredShaderLanguage, equals(ShaderLanguage.default_));
      expect(defaults.forceGLES2Context, isFalse);
    });

    test('Headless engine creation with custom Config and round-trip via getConfig', () {
      final engine = FilamentEngine.create(
        backend: FilamentBackend.noop,
        config: const EngineConfig(
          commandBufferSizeMB: 6,
          perRenderPassArenaSizeMB: 4,
          minCommandBufferSizeMB: 2,
          jobSystemThreadCount: 2,
        ),
      );
      expect(engine, isNotNull);

      final cfg = engine!.config;
      expect(cfg.commandBufferSizeMB, equals(6));
      expect(cfg.perRenderPassArenaSizeMB, equals(4));
      expect(cfg.minCommandBufferSizeMB, equals(2));
      expect(cfg.jobSystemThreadCount, equals(2));

      engine.dispose();
    });

    test('Headless engine creation with null config and features map', () {
      final engine = FilamentEngine.create(
        backend: FilamentBackend.noop,
        features: {'engine.test_flag': true, 'bogus.flag': false},
      );
      expect(engine, isNotNull);
      engine!.dispose();
    });

    test('Paused engine creation smoke test', () {
      final engine = FilamentEngine.create(
        backend: FilamentBackend.noop,
        paused: true,
      );
      expect(engine, isNotNull);
      expect(engine!.isPaused, isTrue);

      engine.paused = false;
      expect(engine.isPaused, isFalse);

      engine.dispose();
    });
  });

  group('Engine isValid Family and Missing Destroys Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('isValidRenderer tracks renderer lifecycle', () {
      final renderer = engine.createRenderer();
      expect(engine.isValidRenderer(renderer), isTrue);

      renderer.dispose();
      expect(engine.isValidRenderer(renderer), isFalse);
    });

    test('isValidView tracks view lifecycle', () {
      final view = engine.createView();
      expect(engine.isValidView(view), isTrue);

      engine.destroyView(view);
      expect(engine.isValidView(view), isFalse);
    });

    test('isValidScene tracks scene lifecycle', () {
      final scene = engine.createScene();
      expect(engine.isValidScene(scene), isTrue);

      engine.destroyScene(scene);
      expect(engine.isValidScene(scene), isFalse);
    });

    test('isValidSwapChain tracks swapchain lifecycle', () {
      final swapChain = engine.createHeadlessSwapChain(64, 64);
      expect(engine.isValidSwapChain(swapChain), isTrue);

      swapChain.dispose();
      expect(engine.isValidSwapChain(swapChain), isFalse);
    });

    test('isValidCamera tracks camera component lifecycle', () {
      final entity = engine.createEntity();
      final camera = engine.createCamera(entity);
      expect(engine.isValidCamera(camera), isTrue);

      engine.destroyCamera(camera);
      expect(engine.isValidCamera(camera), isFalse);

      engine.destroyEntity(entity);
    });

    test('isValidSkybox tracks skybox lifecycle', () {
      final skybox = FilamentSkybox.createColor(
        engine: engine,
        r: 0.2,
        g: 0.4,
        b: 0.6,
        a: 1.0,
      );
      expect(skybox, isNotNull);
      expect(engine.isValidSkybox(skybox), isTrue);

      skybox.dispose();
      expect(engine.isValidSkybox(skybox), isFalse);
    });

    test('isValidColorGrading tracks color grading lifecycle', () {
      final cg = ColorGradingBuilder()
          .toneMapper(ToneMapper.aces())
          .build(engine);
      expect(engine.isValidColorGrading(cg), isTrue);

      cg.destroy();
      expect(engine.isValidColorGrading(cg), isFalse);
    });

    test('destroyEntityComponents removes all components of entity', () {
      final entity = engine.createEntity();
      final camera = engine.createCamera(entity);
      expect(engine.isValidCamera(camera), isTrue);

      engine.destroyEntityComponents(entity);
      expect(engine.isValidCamera(camera), isFalse);

      engine.destroyEntity(entity);
    });
  });

  group('Frame/Thread Control Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('steadyClockTimeNano is strictly positive and monotonically increasing', () {
      final t1 = engine.steadyClockTimeNano;
      final t2 = engine.steadyClockTimeNano;
      expect(t1, greaterThan(0));
      expect(t2, greaterThanOrEqualTo(t1));
    });

    test('flushAndWait with timeout returns true after frame rendering', () {
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(100, 100);
      final view = engine.createView();
      final scene = engine.createScene();
      view.scene = scene;

      if (renderer.beginFrame(swapChain, vsyncNs: engine.steadyClockTimeNano)) {
        renderer.render(view);
        renderer.endFrame();
      }

      final success = engine.flushAndWait(timeout: const Duration(seconds: 5));
      expect(success, isTrue);

      engine.destroyView(view);
      engine.destroyScene(scene);
      swapChain.dispose();
      renderer.dispose();
    });

    test('flush non-blocking and pumpMessageQueues executes without crash', () {
      expect(() => engine.flush(), returnsNormally);
      expect(() => engine.pumpMessageQueues(), returnsNormally);
    });

    test('setPaused and isPaused toggle smoothly', () {
      expect(engine.isPaused, isFalse);
      engine.paused = true;
      expect(engine.isPaused, isTrue);
      engine.paused = false;
      expect(engine.isPaused, isFalse);
    });
  });

  group('Capability Queries and Feature Level Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Feature level queries and set active feature level', () {
      final supported = engine.supportedFeatureLevel;
      expect(supported.index, greaterThanOrEqualTo(FeatureLevel.fl0.index));

      final active = engine.activeFeatureLevel;
      expect(active.index, lessThanOrEqualTo(supported.index));

      final setResult = engine.setActiveFeatureLevel(FeatureLevel.fl1);
      expect(setResult, equals(FeatureLevel.fl1));
      expect(engine.activeFeatureLevel, equals(FeatureLevel.fl1));
    });

    test('maxAutomaticInstances and backend consistency', () {
      expect(engine.maxAutomaticInstances, greaterThanOrEqualTo(1));
      expect(engine.backend, equals(FilamentBackend.noop));
    });

    test('hasUnrecoverableFailure and isStereoSupported', () {
      expect(engine.hasUnrecoverableFailure, isFalse);
      expect(engine.isStereoSupported(StereoscopicType.instanced), isA<bool>());
      expect(engine.isStereoSupported(StereoscopicType.multiview), isA<bool>());
    });

    test('defaultMaterialPointer is non-null and idempotent', () {
      final mat1 = engine.defaultMaterialPointer;
      final mat2 = engine.defaultMaterialPointer;
      expect(mat1, isNot(equals(ffi.nullptr)));
      expect(mat1.address, equals(mat2.address));
    });

    test('automaticInstancingEnabled getter and setter', () {
      engine.automaticInstancingEnabled = true;
      expect(engine.automaticInstancingEnabled, isTrue);

      engine.automaticInstancingEnabled = false;
      expect(engine.automaticInstancingEnabled, isFalse);
    });
  });
}
