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

  group('FilamentMaterialBuilder API Tests', () {
    test('FilamatShading enum values and indices', () {
      expect(FilamatShading.unlit.index, equals(0));
      expect(FilamatShading.lit.index, equals(1));
      expect(FilamatShading.subsurface.index, equals(2));
      expect(FilamatShading.cloth.index, equals(3));
      expect(FilamatShading.specularGlossiness.index, equals(4));
    });

    test('All filamat enum values match Filament C++ specifications', () {
      expect(MaterialDomain.surface.value, equals(0));
      expect(MaterialDomain.postProcess.value, equals(1));
      expect(MaterialDomain.compute.value, equals(2));

      expect(BlendingMode.opaque.value, equals(0));
      expect(BlendingMode.transparent.value, equals(1));
      expect(BlendingMode.add.value, equals(2));
      expect(BlendingMode.masked.value, equals(3));
      expect(BlendingMode.fade.value, equals(4));
      expect(BlendingMode.multiply.value, equals(5));
      expect(BlendingMode.screen.value, equals(6));
      expect(BlendingMode.custom.value, equals(7));

      expect(BlendFunction.zero.value, equals(0));
      expect(BlendFunction.one.value, equals(1));
      expect(BlendFunction.srcColor.value, equals(2));
      expect(BlendFunction.oneMinusSrcColor.value, equals(3));
      expect(BlendFunction.dstColor.value, equals(4));
      expect(BlendFunction.oneMinusDstColor.value, equals(5));
      expect(BlendFunction.srcAlpha.value, equals(6));
      expect(BlendFunction.oneMinusSrcAlpha.value, equals(7));
      expect(BlendFunction.dstAlpha.value, equals(8));
      expect(BlendFunction.oneMinusDstAlpha.value, equals(9));
      expect(BlendFunction.srcAlphaSaturate.value, equals(10));

      expect(RefractionMode.none.value, equals(0));
      expect(RefractionMode.cubemap.value, equals(1));
      expect(RefractionMode.screenSpace.value, equals(2));

      expect(RefractionType.solid.value, equals(0));
      expect(RefractionType.thin.value, equals(1));

      expect(ReflectionMode.default_.value, equals(0));
      expect(ReflectionMode.screenSpace.value, equals(1));

      expect(SpecularAOMode.none.value, equals(0));
      expect(SpecularAOMode.simple.value, equals(1));
      expect(SpecularAOMode.bentNormals.value, equals(2));

      expect(MaterialVariable.custom0.value, equals(0));
      expect(MaterialVariable.custom1.value, equals(1));
      expect(MaterialVariable.custom2.value, equals(2));
      expect(MaterialVariable.custom3.value, equals(3));
      expect(MaterialVariable.custom4.value, equals(4));

      expect(VertexDomain.object.value, equals(0));
      expect(VertexDomain.world.value, equals(1));
      expect(VertexDomain.view.value, equals(2));
      expect(VertexDomain.device.value, equals(3));

      expect(MaterialPlatform.desktop.value, equals(0));
      expect(MaterialPlatform.mobile.value, equals(1));
      expect(MaterialPlatform.all.value, equals(2));

      expect(TargetApi.opengl.value, equals(0x01));
      expect(TargetApi.vulkan.value, equals(0x02));
      expect(TargetApi.metal.value, equals(0x04));
      expect(TargetApi.webgpu.value, equals(0x08));
      expect(TargetApi.all.value, equals(0x07));

      expect(OptimizationLevel.none.value, equals(0));
      expect(OptimizationLevel.preprocessor.value, equals(1));
      expect(OptimizationLevel.size.value, equals(2));
      expect(OptimizationLevel.performance.value, equals(3));

      expect(OutputTarget.color.value, equals(0));
      expect(OutputTarget.depth.value, equals(1));

      expect(OutputType.float.value, equals(0));
      expect(OutputType.float4.value, equals(3));

      expect(ShaderQuality.default_.value, equals(-1));
      expect(ShaderQuality.low.value, equals(0));
      expect(ShaderQuality.normal.value, equals(1));
      expect(ShaderQuality.high.value, equals(2));

      expect(Interpolation.smooth.value, equals(0));
      expect(Interpolation.flat.value, equals(1));

      expect(UserVariantFilterBit.directionalLighting, equals(0x01));
      expect(UserVariantFilterBit.dynamicLighting, equals(0x02));
      expect(UserVariantFilterBit.shadowReceiver, equals(0x04));
      expect(UserVariantFilterBit.skinning, equals(0x08));
      expect(UserVariantFilterBit.fog, equals(0x10));
      expect(UserVariantFilterBit.vsm, equals(0x20));
      expect(UserVariantFilterBit.ssr, equals(0x40));
      expect(UserVariantFilterBit.ste, equals(0x80));
    });

    test('UniformType string conversions round-trip accurately', () {
      for (final type in UniformType.values) {
        final str = FilamentMaterialBuilder.uniformTypeToString(type);
        final parsed = FilamentMaterialBuilder.uniformTypeFromString(str);
        expect(parsed, equals(type));
      }
      expect(FilamentMaterialBuilder.uniformTypeFromString('invalid_type'), isNull);
    });

    test('Builds basic lit material', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('BasicLit');
      builder.setShading(FilamatShading.lit);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(0.8, 0.2, 0.2);
            material.roughness = 0.4;
        }
      ''');
      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with uniform parameters and specialization constants (Task 01)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('UniformsAndConstants');
      builder.setShading(FilamatShading.lit);
      builder.addParameter('albedoColor', UniformType.float4);
      builder.addParameter('roughnessValue', UniformType.floatType, precision: ParameterPrecision.high);
      builder.addParameterArray('lightWeights', 4, UniformType.floatType);
      builder.constantBool('enableCustomFeature', true);
      builder.constantInt('sampleCount', 8);
      builder.constantFloat('scaleMultiplier', 2.5);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = materialParams.albedoColor;
            material.roughness = materialParams.roughnessValue;
        }
      ''');
      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with vertex shader and custom variables (Task 02)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('VertexShaderAndVariables');
      builder.setShading(FilamatShading.lit);
      builder.vertexDomain(VertexDomain.object);
      builder.vertexDomainDeviceJittered(false);
      builder.flipUV(true);
      builder.variable(MaterialVariable.custom0, 'vCustomColor', precision: ParameterPrecision.high);

      builder.materialVertex('''
        void materialVertex(inout MaterialVertexInputs material) {
            variable_vCustomColor = float4(1.0, 0.0, 0.0, 1.0);
        }
      ''');

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = variable_vCustomColor;
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with blending and raster configuration (Task 03)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('BlendingAndRaster');
      builder.setShading(FilamatShading.unlit);
      builder.blending(BlendingMode.transparent);
      builder.transparencyMode(TransparencyMode.defaultMode);
      builder.maskThreshold(0.5);
      builder.alphaToCoverage(false);
      builder.refractionMode(RefractionMode.none);
      builder.refractionType(RefractionType.solid);
      builder.culling(CullingMode.none);
      builder.colorWrite(true);
      builder.depthWrite(false);
      builder.depthCulling(true);
      builder.instanced(true);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = float4(0.0, 1.0, 0.0, 0.5);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with custom blend functions (Task 03)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('CustomBlend');
      builder.setShading(FilamatShading.unlit);
      builder.blending(BlendingMode.custom);
      builder.customBlendFunctions(
        srcRgb: BlendFunction.srcAlpha,
        srcA: BlendFunction.one,
        dstRgb: BlendFunction.oneMinusSrcAlpha,
        dstA: BlendFunction.zero,
      );

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = float4(1.0, 0.0, 1.0, 0.8);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Configures domain, codegen targets, defines, and variant filters (Task 04)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('DomainAndCodegen');
      builder.setShading(FilamatShading.lit);
      builder.materialDomain(MaterialDomain.surface);
      builder.groupSize(x: 8, y: 8, z: 1);
      builder.shaderDefine('CUSTOM_FLAG', '1');
      builder.variantFilter(UserVariantFilterBit.fog | UserVariantFilterBit.skinning);
      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(0.1, 0.2, 0.3);
        }
      ''');

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with shadows, quality, specular AA, and customSurfaceShading (Task 05)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ShadowsAndShading');
      builder.setShading(FilamatShading.lit);
      builder.quality(ShaderQuality.high);
      builder.featureLevel(1);
      builder.includeEssl1(true);
      builder.interpolation(Interpolation.smooth);
      builder.specularAntiAliasing(true, variance: 0.15, threshold: 0.2);
      builder.clearCoatIorChange(true);
      builder.linearFog(false);
      builder.coloredPenumbra(true);
      builder.shadowFarAttenuation(true);
      builder.reflectionMode(ReflectionMode.default_);
      builder.multiBounceAmbientOcclusion(true);
      builder.specularAmbientOcclusion(SpecularAOMode.simple);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(0.9, 0.8, 0.7);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Builds material with customSurfaceShading (Task 05)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ToonShading');
      builder.setShading(FilamatShading.lit);
      builder.customSurfaceShading(true);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(1.0, 0.5, 0.0);
        }

        vec3 surfaceShading(
                const MaterialInputs materialInputs,
                const ShadingData shadingData,
                const LightData lightData) {
            return vec3(1.0);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('customSurfaceShading without surfaceShading function fails build safely (Task 05)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('InvalidCustomSurfaceShading');
      builder.setShading(FilamatShading.lit);
      builder.customSurfaceShading(true);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(1.0, 0.5, 0.0);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNull);
    });

    test('Builds material with shadowMultiplier on unlit AR ground catcher (Task 05)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ShadowMultiplierUnlit');
      builder.setShading(FilamatShading.unlit);
      builder.shadowMultiplier(true);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(1.0);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });

    test('Debug outputs: generateDebugInfo, saveRawVariants, printShaders (Task 06)', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('DebugMaterial');
      builder.setShading(FilamatShading.lit);
      builder.printShaders(true);
      builder.saveRawVariants(false);
      builder.generateDebugInfo(true);

      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(0.5, 0.5, 0.5);
        }
      ''');

      builder.platform(MaterialPlatform.desktop);
      builder.targetApi(TargetApi.opengl);
      builder.optimization(OptimizationLevel.none);

      final packageBytes = builder.build();
      builder.dispose();

      expect(packageBytes, isNotNull);
      expect(packageBytes!.isNotEmpty, isTrue);
    });
  });
}
