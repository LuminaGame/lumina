import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    FilamentMaterialBuilder.initEngine();
  });

  tearDownAll(() {
    FilamentMaterialBuilder.shutdownEngine();
  });

  group('FilamentMaterial & MaterialInstance API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    Uint8List buildTestMaterialPackage({
      String name = 'TestMaterial',
      FilamatShading shading = FilamatShading.lit,
      BlendingMode blending = BlendingMode.opaque,
      bool doubleSided = false,
      CullingMode culling = CullingMode.back,
      bool hasConstants = false,
    }) {
      final builder = FilamentMaterialBuilder.create();
      builder.setName(name);
      builder.setShading(shading);
      builder.blending(blending);
      builder.setDoubleSided(doubleSided);
      builder.culling(culling);
      builder.addParameter('baseColor', UniformType.float4);
      builder.addParameter('roughness', UniformType.floatType);
      builder.addParameter('useFeature', UniformType.boolType);
      builder.addParameter('featureCount', UniformType.intType);
      builder.addParameter('vec2Param', UniformType.float2);
      builder.addParameter('vec3Param', UniformType.float3);
      builder.addParameter('mat3Param', UniformType.mat3);
      builder.addParameter('mat4Param', UniformType.mat4);

      if (hasConstants) {
        builder.constantBool('useFeature', true);
        builder.constantFloat('featureScale', 1.0);
        builder.constantInt('featureCount', 4);
      }

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.baseColor;
            material.roughness = materialParams.roughness;
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final bytes = builder.build();
      builder.dispose();
      return bytes!;
    }

    test('Named instances, defaultInstance and setDefaultParameter family (Task 02)', () {
      final package = buildTestMaterialPackage(name: 'DefaultsTestMaterial');
      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: package,
      );

      expect(material.name, equals('DefaultsTestMaterial'));

      // Named instances
      final instance1 = material.createInstance('enemy_red');
      final instance2 = material.createInstance('enemy_blue');
      expect(instance1.nativePointer, isNot(equals(instance2.nativePointer)));

      // Default instance
      final def1 = material.defaultInstance;
      final def2 = material.defaultInstance;
      expect(def1, equals(def2));
      expect(def1.nativePointer, equals(def2.nativePointer));

      // Default parameter setters
      expect(() => material.setDefaultParameterBool('useFeature', true), returnsNormally);
      expect(() => material.setDefaultParameterInt('featureCount', 8), returnsNormally);
      expect(() => material.setDefaultParameterFloat('roughness', 0.5), returnsNormally);
      expect(() => material.setDefaultParameterFloat2('vec2Param', 1.0, 2.0), returnsNormally);
      expect(() => material.setDefaultParameterFloat3('vec3Param', 1.0, 2.0, 3.0), returnsNormally);
      expect(() => material.setDefaultParameterFloat4('baseColor', 1.0, 0.0, 0.0, 1.0), returnsNormally);
      expect(
        () => material.setDefaultParameterMat3('mat3Param', List.filled(9, 1.0)),
        returnsNormally,
      );
      expect(
        () => material.setDefaultParameterMat4('mat4Param', List.filled(16, 1.0)),
        returnsNormally,
      );
      expect(
        () => material.setDefaultColor('baseColor', RgbType.sRgb, (1.0, 0.5, 0.2)),
        returnsNormally,
      );
      expect(
        () => material.setDefaultColorRgba('baseColor', RgbaType.sRgb, (1.0, 0.5, 0.2, 1.0)),
        returnsNormally,
      );

      // Nonexistent parameter throws ArgumentError
      expect(
        () => material.setDefaultParameterFloat('nonexistentParam', 1.0),
        throwsA(isA<ArgumentError>()),
      );

      // Default instance disposal is safe and does not destroy native handle prematurely
      def1.dispose();
      expect(def1.isDisposed, isTrue);

      instance1.dispose();
      instance2.dispose();
      material.dispose();
    });

    test('Specialization constants and fromBuffer expansion (Task 03)', () {
      final package = buildTestMaterialPackage(
        name: 'ConstantsMaterial',
        hasConstants: true,
      );

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: package,
        constants: const [
          MaterialConstant.bool_('useFeature', false),
          MaterialConstant.float('featureScale', 2.5),
          MaterialConstant.int32('featureCount', 16),
        ],
        sphericalHarmonicsBandCount: 3,
        shadowSamplingQuality: ShadowSamplingQuality.high,
      );

      expect(material.name, equals('ConstantsMaterial'));
      expect(material.parameterCount, greaterThanOrEqualTo(2));
      material.dispose();
    });

    test('Asynchronous compile (Task 03)', () async {
      final package = buildTestMaterialPackage(name: 'CompileMaterial');
      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: package,
      );

      final future = material.compile(
        priority: CompilerPriorityQueue.high,
        variantFilter: UserVariantFilterBit.all,
      );

      engine.flushAndWait();
      engine.pumpMessageQueues();

      await expectLater(
        future,
        completes,
      );

      material.dispose();
    });

    test('Introspection getters (Task 04)', () {
      final package = buildTestMaterialPackage(
        name: 'IntrospectionMaterial',
        shading: FilamatShading.lit,
        blending: BlendingMode.transparent,
        doubleSided: true,
        culling: CullingMode.none,
      );

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: package,
      );

      expect(material.name, equals('IntrospectionMaterial'));
      expect(material.shading, equals(FilamatShading.lit));
      expect(material.blendingMode, equals(BlendingMode.transparent));
      expect(material.materialDomain, equals(MaterialDomain.surface));
      expect(material.vertexDomain, equals(VertexDomain.object));
      expect(material.isDoubleSided, isTrue);
      expect(material.isColorWriteEnabled, isTrue);
      expect(material.isDepthWriteEnabled, isFalse);
      expect(material.isDepthCullingEnabled, isTrue);
      expect(material.featureLevel, greaterThanOrEqualTo(0));
      expect(material.requiredAttributes, isA<Set<VertexAttribute>>());

      material.dispose();
    });
  });
}
