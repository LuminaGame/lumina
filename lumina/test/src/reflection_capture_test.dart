import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaReflectionCaptureComponent', () {
    test('Constructor validation: resolution power of two in 16..1024', () {
      expect(
        () => LuminaReflectionCaptureComponent(resolution: 100),
        throwsArgumentError,
      );
      expect(
        () => LuminaReflectionCaptureComponent(resolution: 2048),
        throwsArgumentError,
      );
      expect(
        () => LuminaReflectionCaptureComponent(resolution: 8),
        throwsArgumentError,
      );

      final validComp = LuminaReflectionCaptureComponent(resolution: 256);
      expect(validComp.resolution, equals(256));
    });

    test('captureOnRegister false leaves hasCapture false and IndirectLight untouched', () {
      final comp = LuminaReflectionCaptureComponent(
        captureOnRegister: false,
        resolution: 128,
      );
      expect(comp.hasCapture, isFalse);
      expect(comp.reflectionsTexture, isNull);
    });

    test('captureFromEquirect validation rejects non-HDR textures before native calls', () async {
      final comp = LuminaReflectionCaptureComponent(
        captureOnRegister: false,
        resolution: 128,
      );

      // Null or invalid format check throws ArgumentError
      expect(
        () => comp.validateEquirectTextureFormat(TextureFormat.rgba8),
        throwsArgumentError,
      );
      expect(
        () => comp.validateEquirectTextureFormat(TextureFormat.rgb8),
        throwsArgumentError,
      );
      expect(
        comp.validateEquirectTextureFormat(TextureFormat.rgba16f),
        isTrue,
      );
      expect(
        comp.validateEquirectTextureFormat(TextureFormat.rgba32f),
        isTrue,
      );
    });

    test('Serialization: concurrent capture calls return the identical Future', () async {
      final comp = LuminaReflectionCaptureComponent(
        captureOnRegister: false,
        resolution: 128,
      );

      final future1 = comp.capture();
      final future2 = comp.capture();

      expect(identical(future1, future2), isTrue);
      await future1;
      expect(comp.hasCapture, isTrue);
    });

    test('Filter cache creation and disposal lifecycle', () {
      final engine = FilamentEngine.create()!;
      final cache = LuminaReflectionFilterCache(engine);

      expect(cache.createdContextCount, equals(0));
      final ctx = cache.getOrCreateContext();
      expect(ctx, isNotNull);
      expect(cache.createdContextCount, equals(1));

      // Second call returns cached context
      final ctx2 = cache.getOrCreateContext();
      expect(identical(ctx, ctx2), isTrue);
      expect(cache.createdContextCount, equals(1));

      cache.dispose();
      engine.dispose();
    });

    test('Real world reflection capture installs IndirectLight on scene', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final probe = LuminaReflectionCaptureComponent(
        resolution: 64,
        specularLevels: 4,
        captureOnRegister: false,
      );
      final actor = LuminaActor(root: probe);
      world.persistentLevel.registerActor(actor);

      await probe.capture();
      expect(probe.hasCapture, isTrue);
      expect(scene.indirectLight, isNotNull);

      probe.invalidate();
      expect(scene.indirectLight, isNull);

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
  });
}
