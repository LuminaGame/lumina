import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    FilamentMaterialBuilder.initEngine();
  });

  tearDownAll(() {
    FilamentMaterialBuilder.shutdownEngine();
  });

  group('MaterialInstance Stencil Tests (Task 03)', () {
    late FilamentEngine engine;
    late FilamentMaterial material;
    late FilamentMaterialInstance instance;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      final builder = FilamentMaterialBuilder.create();
      builder.setName('StencilTestMat');
      builder.setShading(FilamatShading.unlit);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = float4(1.0, 0.0, 0.0, 1.0);
        }
      ''');
      final bytes = builder.build()!;
      builder.dispose();

      material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: bytes,
      );
      instance = material.createInstance('StencilInstance');
    });

    tearDown(() {
      instance.dispose();
      material.dispose();
      if (!engine.isDisposed) engine.dispose();
    });

    test('Stencil write toggle and query', () {
      instance.setStencilWrite(true);
      expect(instance.isStencilWriteEnabled, isTrue);

      instance.setStencilWrite(false);
      expect(instance.isStencilWriteEnabled, isFalse);
    });

    test('Stencil compare function and operations for all faces', () {
      for (final face in StencilFace.values) {
        for (final func in DepthFunc.values) {
          expect(
            () => instance.setStencilCompareFunction(func, face: face),
            returnsNormally,
          );
        }

        for (final op in StencilOperation.values) {
          expect(
            () => instance.setStencilOpStencilFail(op, face: face),
            returnsNormally,
          );
          expect(
            () => instance.setStencilOpDepthFail(op, face: face),
            returnsNormally,
          );
          expect(
            () => instance.setStencilOpDepthStencilPass(op, face: face),
            returnsNormally,
          );
        }
      }
    });

    test('Stencil reference value and masks with range validation', () {
      for (final face in StencilFace.values) {
        expect(() => instance.setStencilReferenceValue(0, face: face), returnsNormally);
        expect(() => instance.setStencilReferenceValue(128, face: face), returnsNormally);
        expect(() => instance.setStencilReferenceValue(255, face: face), returnsNormally);

        expect(
          () => instance.setStencilReferenceValue(-1, face: face),
          throwsA(isA<RangeError>()),
        );
        expect(
          () => instance.setStencilReferenceValue(256, face: face),
          throwsA(isA<RangeError>()),
        );

        expect(() => instance.setStencilReadMask(0xFF, face: face), returnsNormally);
        expect(() => instance.setStencilWriteMask(0x0F, face: face), returnsNormally);

        expect(
          () => instance.setStencilReadMask(-5, face: face),
          throwsA(isA<RangeError>()),
        );
        expect(
          () => instance.setStencilWriteMask(300, face: face),
          throwsA(isA<RangeError>()),
        );
      }
    });

    test('View stencilBufferEnabled property toggle', () {
      final view = engine.createView();
      expect(view.stencilBufferEnabled, isFalse);

      view.stencilBufferEnabled = true;
      expect(view.stencilBufferEnabled, isTrue);

      view.stencilBufferEnabled = false;
      expect(view.stencilBufferEnabled, isFalse);

      engine.destroyView(view);
    });
  });
}
