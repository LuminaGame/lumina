import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('MaterialInstance Render State Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      FilamentMaterialBuilder.initEngine();
    });

    tearDown(() {
      FilamentMaterialBuilder.shutdownEngine();
      if (!engine.isDisposed) engine.dispose();
    });

    test('Getter round-trips: every setter followed by its getter returns the set value', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('StateMat');
      builder.setShading(FilamatShading.unlit);
      builder.setDoubleSided(true);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(1.0);
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );

      final instance = material.getDefaultInstance();

      // Culling mode
      for (final mode in CullingMode.values) {
        instance.setCullingMode(mode);
        expect(instance.cullingMode, equals(mode));
      }

      instance.setCullingModeSeparate(CullingMode.front, CullingMode.back);
      expect(instance.cullingMode, equals(CullingMode.front)); // getter returns color pass mode

      // Double sided
      instance.setDoubleSided(true);
      expect(instance.isDoubleSided, isTrue);
      // setDoubleSided(true) implies culling=none in Filament
      expect(instance.cullingMode, equals(CullingMode.none));

      instance.setDoubleSided(false);
      expect(instance.isDoubleSided, isFalse);

      // Color/Depth Write
      instance.setColorWrite(true);
      expect(instance.isColorWriteEnabled, isTrue);
      instance.setColorWrite(false);
      expect(instance.isColorWriteEnabled, isFalse);

      instance.setDepthWrite(true);
      expect(instance.isDepthWriteEnabled, isTrue);
      instance.setDepthWrite(false);
      expect(instance.isDepthWriteEnabled, isFalse);

      // Depth Culling
      instance.setDepthCulling(true);
      expect(instance.isDepthCullingEnabled, isTrue);
      instance.setDepthCulling(false);
      expect(instance.isDepthCullingEnabled, isFalse);

      // Depth Func
      for (final func in DepthFunc.values) {
        instance.setDepthFunc(func);
        expect(instance.depthFunc, equals(func));
      }

      // Transparency Mode
      for (final mode in TransparencyMode.values) {
        instance.setTransparencyMode(mode);
        expect(instance.transparencyMode, equals(mode));
      }

      // Mask Threshold (on non-masked material, safe no-op returning 0.0)
      instance.setMaskThreshold(0.75);
      expect(instance.maskThreshold, equals(0.0));
      instance.setMaskThreshold(0.25);
      expect(instance.maskThreshold, equals(0.0));


      // Polygon Offset (no getters in Filament for this, just ensure no panic)
      instance.setPolygonOffset(-1.0, -1.0);

      // Scissor (no getters in Filament, just ensure no panic)
      instance.setScissor(left: 0, bottom: 0, width: 100, height: 100);
      instance.unsetScissor();

      material.dispose();
    });
  });
}
