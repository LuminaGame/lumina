import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Uint8List buildDynamicTestFilamatPackage() {
  FilamentMaterialBuilder.initEngine();
  final builder = FilamentMaterialBuilder.create();
  builder.setName('M_Dynamic_Test');
  builder.setShading(FilamatShading.lit);
  builder.materialDomain(MaterialDomain.surface);
  builder.blending(BlendingMode.masked);
  builder.culling(CullingMode.none);
  builder.addParameter('baseColorFactor', UniformType.float4);
  builder.addParameter('metallic', UniformType.float_);
  builder.addParameter('useEmissive', UniformType.bool_);
  builder.addParameterArray('colors', 4, UniformType.float4);
  builder.addSamplerParameter('albedoMap');
  builder.platform(MaterialPlatform.desktop);
  builder.targetApi(TargetApi.vulkan);
  builder.optimization(OptimizationLevel.none);
  builder.setCode('''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColorFactor;
        material.metallic = materialParams.metallic;
    }
  ''');
  final bytes = builder.build()!;
  builder.dispose();
  return bytes;
}

void main() {
  group('LuminaDynamicMaterialInstance Tests (Task 02)', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;
    late Uint8List sampleBytes;

    setUpAll(() {
      sampleBytes = buildDynamicTestFilamatPackage();
    });

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('Duplicate isolation and setter round-trips', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final d1 = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance, name: 'dynamic_actor_1');
      final d2 = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance, name: 'dynamic_actor_2');

      d1.setVector('baseColorFactor', Vector4(1.0, 0.0, 0.0, 1.0));
      d2.setVector('baseColorFactor', Vector4(0.0, 1.0, 0.0, 1.0));

      expect(d1.getFloat4('baseColorFactor').x, closeTo(1.0, 1e-4));
      expect(d1.getFloat4('baseColorFactor').y, closeTo(0.0, 1e-4));

      expect(d2.getFloat4('baseColorFactor').x, closeTo(0.0, 1e-4));
      expect(d2.getFloat4('baseColorFactor').y, closeTo(1.0, 1e-4));

      // Test scalar and bool
      d1.setScalar('metallic', 0.75);
      expect(d1.getFloat('metallic'), closeTo(0.75, 1e-4));

      d1.setBool('useEmissive', true);
      expect(d1.getBool('useEmissive'), isTrue);

      d1.dispose();
      d2.dispose();
      baseMat.release();
    });

    test('Validation guards for non-existent parameters and type mismatches', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final dynamicInst = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance);

      expect(
        () => dynamicInst.setScalar('nonExistent', 1.0),
        throwsArgumentError,
      );

      expect(
        () => dynamicInst.setVector('metallic', Vector4.zero()),
        throwsArgumentError,
      );

      expect(
        () => dynamicInst.setScalar('baseColorFactor', 1.0),
        throwsArgumentError,
      );

      dynamicInst.dispose();
      baseMat.release();
    });

    test('setVectorArray validates count against reflected parameter definition', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final dynamicInst = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance);

      final validPacked16 = Float32List(16); // 4 float4s
      dynamicInst.setVectorArray('colors', validPacked16);

      final invalidPacked20 = Float32List(20); // 5 float4s
      expect(
        () => dynamicInst.setVectorArray('colors', invalidPacked20),
        throwsArgumentError,
      );

      dynamicInst.dispose();
      baseMat.release();
    });

    test('Render state overrides and getters', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final dynamicInst = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance);

      dynamicInst.cullingMode = CullingMode.none;
      expect(dynamicInst.cullingMode, equals(CullingMode.none));

      dynamicInst.isDepthWriteEnabled = false;
      expect(dynamicInst.isDepthWriteEnabled, isFalse);

      dynamicInst.transparencyMode = TransparencyMode.twoPassesOneSide;
      expect(dynamicInst.transparencyMode, equals(TransparencyMode.twoPassesOneSide));

      dynamicInst.maskThreshold = 0.5;
      expect(dynamicInst.maskThreshold, closeTo(0.5, 1e-4));

      dynamicInst.setScissor(left: 0, bottom: 0, width: 100, height: 100);
      dynamicInst.unsetScissor();

      dynamicInst.dispose();
      baseMat.release();
    });

    test('Texture binding and lifecycle management', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final dynamicInst = LuminaDynamicMaterialInstance.from(baseMat.defaultInstance);

      // Create 4x4 solid blue texture from pixels
      final bluePixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < 16; i++) {
        bluePixels[i * 4 + 0] = 0;
        bluePixels[i * 4 + 1] = 0;
        bluePixels[i * 4 + 2] = 255;
        bluePixels[i * 4 + 3] = 255;
      }

      dynamicInst.setTextureFromPixels(
        'albedoMap',
        width: 4,
        height: 4,
        rgbaBytes: bluePixels,
      );

      dynamicInst.dispose();
      baseMat.release();
    });

    test('LuminaStaticMeshComponent createDynamicMaterialInstance creates and caches per-primitive', () async {
      final baseMat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Dynamic_Test.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      const glbPath = '../test-assets/Props/AC_units/ac_unit_a_300x300.glb';
      final mesh = LuminaStaticMeshComponent(meshAssetPath: glbPath);
      final actor = LuminaActor(root: mesh);
      world.persistentLevel.registerActor(actor);
      await mesh.loaded;

      mesh.setMaterialOverride(baseMat.defaultInstance, primitiveIndex: 0);

      final mid0_1 = mesh.createDynamicMaterialInstance(primitiveIndex: 0);
      final mid0_2 = mesh.createDynamicMaterialInstance(primitiveIndex: 0);

      expect(identical(mid0_1, mid0_2), isTrue);

      mid0_1.setScalar('metallic', 0.9);
      expect(mid0_1.getFloat('metallic'), closeTo(0.9, 1e-4));

      baseMat.release();
    });
  });
}
