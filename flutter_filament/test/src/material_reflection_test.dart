import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Material Parameter Reflection', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      FilamentMaterialBuilder.initEngine();
    });

    tearDown(() {
      FilamentMaterialBuilder.shutdownEngine();
      if (!engine.isDisposed) engine.dispose();
    });

    test('Reflect sampler and uniform parameters from a filamat-built material', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ReflectMat');
      builder.setShading(FilamatShading.unlit);

      // Add a sampler
      builder.addSamplerParameter('albedo', samplerType: 0); // 0 = SAMPLER_2D
      
      // Add a uniform
      builder.addParameter('baseColorFactor', UniformType.float4);
      
      // Add a uniform array
      builder.addParameterArray('colors', 4, UniformType.float4);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.baseColorFactor;
        }
      ''');

      final filamat = builder.build();
      expect(filamat, isNotNull);
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat!,
      );

      // 1. parameterCount
      expect(material.parameterCount, greaterThanOrEqualTo(3));

      // 2. getParameters
      final params = material.parameters;
      expect(params.length, equals(material.parameterCount));

      // 3. hasParameter & isSampler
      expect(material.hasParameter('albedo'), isTrue);
      expect(material.isSampler('albedo'), isTrue);

      expect(material.hasParameter('baseColorFactor'), isTrue);
      expect(material.isSampler('baseColorFactor'), isFalse);

      expect(material.hasParameter('doesNotExist'), isFalse);

      // Verify "albedo" details
      final albedo = params.firstWhere((p) => p.name == 'albedo');
      expect(albedo.isSampler, isTrue);
      expect(albedo.isSubpass, isFalse);
      expect(albedo.samplerType, equals(TextureSamplerType.sampler2d));
      expect(albedo.count, equals(1));

      // Verify "baseColorFactor" details
      final baseColor = params.firstWhere((p) => p.name == 'baseColorFactor');
      expect(baseColor.isSampler, isFalse);
      expect(baseColor.isSubpass, isFalse);
      expect(baseColor.uniformType, equals(UniformType.float4));
      expect(baseColor.count, equals(1));

      // Verify "colors" details
      final colors = params.firstWhere((p) => p.name == 'colors');
      expect(colors.isSampler, isFalse);
      expect(colors.uniformType, equals(UniformType.float4));
      expect(colors.count, equals(4));

      // 4. Repeated calls yield identical results (no state corruption)
      final params2 = material.parameters;
      expect(params2.length, equals(params.length));
      expect(params2.firstWhere((p) => p.name == 'albedo').name, equals('albedo'));

      material.dispose();
    });
  });
}
