import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    FilamentMaterialBuilder.initEngine();
  });

  tearDownAll(() {
    FilamentMaterialBuilder.shutdownEngine();
  });

  group('MaterialInstance Queries and Constants Tests (Task 04)', () {
    late FilamentEngine engine;
    late FilamentMaterial material;
    late FilamentMaterialInstance instance;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      final builder = FilamentMaterialBuilder.create();
      builder.setName('QueriesTestMat');
      builder.setShading(FilamatShading.lit);
      builder.specularAntiAliasing(true);
      builder.addParameter('fVal', UniformType.floatType);
      builder.addParameter('f2Val', UniformType.float2);
      builder.addParameter('f3Val', UniformType.float3);
      builder.addParameter('f4Val', UniformType.float4);
      builder.addParameter('iVal', UniformType.intType);
      builder.addParameter('i2Val', UniformType.int2);
      builder.addParameter('i3Val', UniformType.int3);
      builder.addParameter('i4Val', UniformType.int4);
      builder.addParameter('uVal', UniformType.uint);
      builder.addParameter('bVal', UniformType.boolType);
      builder.addParameter('m4Val', UniformType.mat4);

      builder.constantBool('tintEnabled', true);
      builder.constantFloat('tintFactor', 1.0);
      builder.constantInt('tintPasses', 2);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.f4Val;
        }
      ''');

      final bytes = builder.build()!;
      builder.dispose();

      material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: bytes,
      );
      instance = material.createInstance('queries_test_instance');
    });

    tearDown(() {
      instance.dispose();
      material.dispose();
      if (!engine.isDisposed) engine.dispose();
    });

    test('Identity and Material access', () {
      expect(instance.name, equals('queries_test_instance'));
      expect(instance.material.nativePointer, equals(material.nativePointer));
    });

    test('Scalar parameters read-back', () {
      instance.setFloat('fVal', 0.75);
      expect(instance.getFloat('fVal'), closeTo(0.75, 1e-5));

      instance.setInt('iVal', 42);
      expect(instance.getInt('iVal'), equals(42));

      instance.setUint('uVal', 12345);
      expect(instance.getUint('uVal'), equals(12345));

      instance.setBool('bVal', true);
      expect(instance.getBool('bVal'), isTrue);

      instance.setBool('bVal', false);
      expect(instance.getBool('bVal'), isFalse);
    });

    test('Vector parameters read-back', () {
      instance.setFloat2('f2Val', 1.5, 2.5);
      final f2 = instance.getFloat2('f2Val');
      expect(f2.$1, closeTo(1.5, 1e-5));
      expect(f2.$2, closeTo(2.5, 1e-5));

      instance.setFloat3('f3Val', 1.0, 2.0, 3.0);
      final f3 = instance.getFloat3('f3Val');
      expect(f3.$1, closeTo(1.0, 1e-5));
      expect(f3.$2, closeTo(2.0, 1e-5));
      expect(f3.$3, closeTo(3.0, 1e-5));

      instance.setFloat4('f4Val', 0.1, 0.2, 0.3, 0.4);
      final f4 = instance.getFloat4('f4Val');
      expect(f4.$1, closeTo(0.1, 1e-5));
      expect(f4.$2, closeTo(0.2, 1e-5));
      expect(f4.$3, closeTo(0.3, 1e-5));
      expect(f4.$4, closeTo(0.4, 1e-5));

      instance.setInt2('i2Val', 10, 20);
      expect(instance.getInt2('i2Val'), equals((10, 20)));

      instance.setInt3('i3Val', 10, 20, 30);
      expect(instance.getInt3('i3Val'), equals((10, 20, 30)));

      instance.setInt4('i4Val', 10, 20, 30, 40);
      expect(instance.getInt4('i4Val'), equals((10, 20, 30, 40)));
    });

    test('Matrix parameter read-back', () {
      final inMatrix = List<double>.generate(16, (i) => i.toDouble());
      instance.setMat4('m4Val', inMatrix);
      final outMatrix = instance.getMat4('m4Val');
      expect(outMatrix.length, equals(16));
      for (int i = 0; i < 16; i++) {
        expect(outMatrix[i], closeTo(i.toDouble(), 1e-5));
      }
    });

    test('Specialization constants', () {
      expect(() => instance.setConstantBool('tintEnabled', false), returnsNormally);
      expect(() => instance.setConstantFloat('tintFactor', 0.5), returnsNormally);
      expect(() => instance.setConstantInt('tintPasses', 4), returnsNormally);
    });

    test('Specular anti-aliasing setters and getters', () {
      instance.setSpecularAntiAliasingVariance(0.25);
      expect(instance.specularAntiAliasingVariance, closeTo(0.25, 1e-5));

      instance.setSpecularAntiAliasingThreshold(0.35);
      expect(instance.specularAntiAliasingThreshold, closeTo(0.35, 1e-5));
    });
  });
}
