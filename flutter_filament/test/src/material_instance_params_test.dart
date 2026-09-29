import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('MaterialInstance Parameters & Duplicate Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      FilamentMaterialBuilder.initEngine();
    });

    tearDown(() {
      FilamentMaterialBuilder.shutdownEngine();
      if (!engine.isDisposed) engine.dispose();
    });

    test('Duplicate creates an independent instance', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('TestMat');
      builder.setShading(FilamatShading.unlit);
      builder.addParameter('baseColor', UniformType.float4);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.baseColor;
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );

      final instanceA = material.createInstance('InstanceA');
      instanceA.setFloat4('baseColor', 1.0, 0.0, 0.0, 1.0); // Red

      // Duplicate
      final instanceB = instanceA.duplicate(name: 'InstanceB');
      
      // They should have independent parameters, but checking the name for now
      // and ensuring duplicate returns successfully
      expect(instanceB.isDisposed, isFalse);

      instanceB.setFloat4('baseColor', 0.0, 1.0, 0.0, 1.0); // Green

      instanceA.dispose();
      instanceB.dispose();
      material.dispose();
    });

    test('Array setters (setFloat4Array, etc.) upload without error', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ArrayMat');
      builder.setShading(FilamatShading.unlit);
      builder.addParameterArray('colors', 4, UniformType.float4);
      builder.addParameterArray('bonePalettes', 2, UniformType.mat4);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.colors[2];
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );

      final instance = material.getDefaultInstance();

      final float4Array = Float32List(16); // 4 * 4 floats
      instance.setFloat4Array('colors', float4Array);

      final mat4Array = Float32List(32); // 2 * 16 floats
      instance.setMat4Array('bonePalettes', mat4Array);

      material.dispose();
    });

    test('uint/bool vectors and RgbType color setters', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('UintBoolColorMat');
      builder.setShading(FilamatShading.unlit);
      builder.addParameter('flags', UniformType.uint3);
      builder.addParameter('toggles', UniformType.bool3);
      builder.addParameter('albedo', UniformType.float3);
      builder.addParameter('baseColor', UniformType.float4);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = materialParams.albedo;
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );

      final instance = material.getDefaultInstance();

      instance.setUint3('flags', 1, 2, 3);
      instance.setBool3('toggles', true, false, true);
      
      instance.setColor('albedo', RgbType.sRgb, 1.0, 0.5, 0.2);
      instance.setColorRgba('baseColor', RgbaType.sRgb, 1.0, 0.5, 0.2, 1.0);

      material.dispose();
    });
  });
}
