import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

Uint8List buildSmokeFilamatPackage() {
  FilamentMaterialBuilder.initEngine();
  final builder = FilamentMaterialBuilder.create();
  builder.setName('M_Smoke_PBR');
  builder.setShading(FilamatShading.lit);
  builder.materialDomain(MaterialDomain.surface);
  builder.blending(BlendingMode.opaque);
  builder.culling(CullingMode.none);
  builder.addParameter('baseColorFactor', UniformType.float4);
  builder.addParameter('roughness', UniformType.float_);
  builder.addParameter('metallic', UniformType.float_);
  builder.platform(MaterialPlatform.desktop);
  builder.targetApi(TargetApi.vulkan);
  builder.optimization(OptimizationLevel.none);
  builder.setCode('''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColorFactor;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
  ''');
  final bytes = builder.build()!;
  builder.dispose();
  return bytes;
}

void main() {
  group('Material Module Smoke Tests', () {
    late Uint8List sampleFilamatBytes;

    setUpAll(() {
      sampleFilamatBytes = buildSmokeFilamatPackage();
    });

    test('Scenario 01: LuminaMaterial and LuminaMaterialInstance asset pipeline with typed parameter mutation, caching, and real 3D assets', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_a_300x300.glb',
      ];

      final baseMaterial = await LuminaMaterial.load(
        world,
        'contents/materials/M_Smoke_PBR.filamat',
        assetProvider: (_) async => sampleFilamatBytes,
      );

      expect(baseMaterial.name, equals('M_Smoke_PBR'));
      expect(baseMaterial.hasParameter('baseColorFactor'), isTrue);
      expect(baseMaterial.hasParameter('roughness'), isTrue);
      expect(baseMaterial.hasParameter('metallic'), isTrue);

      // Create distinct instances with customized parameters
      final instRed = baseMaterial.createInstance(name: 'MI_RedMetal');
      instRed.setFloat4('baseColorFactor', Vector4(0.9, 0.1, 0.1, 1.0));
      instRed.setFloat('roughness', 0.2);
      instRed.setFloat('metallic', 0.9);

      final instGold = baseMaterial.createInstance(name: 'MI_GoldSatin');
      instGold.setFloat4('baseColorFactor', Vector4(1.0, 0.84, 0.0, 1.0));
      instGold.setFloat('roughness', 0.4);
      instGold.setFloat('metallic', 0.8);

      expect(instRed.getFloat4('baseColorFactor').x, closeTo(0.9, 1e-3));
      expect(instGold.getFloat4('baseColorFactor').x, closeTo(1.0, 1e-3));

      // Render 10-second headless simulation with real assets and materials
      const testTitle = 'material_smoke_test: Scenario 01 LuminaMaterial and LuminaMaterialInstance asset pipeline';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );

      instRed.dispose();
      instGold.dispose();
      baseMaterial.release();

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('Scenario 02: LuminaDynamicMaterialInstance runtime MID parameter mutation, render state overrides, and real 3D assets', () async {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);

      final usedAssets = [
        'Props/Access_cards/access_card_red.glb',
        'Props/Banana Bunch/banana_bunch_short.glb',
      ];

      final baseMaterial = await LuminaMaterial.load(
        world,
        'contents/materials/M_Smoke_PBR.filamat',
        assetProvider: (_) async => sampleFilamatBytes,
      );

      final dynamicInst = LuminaDynamicMaterialInstance.from(
        baseMaterial.defaultInstance,
        name: 'MID_Runtime_Smoke',
      );

      dynamicInst.setVector('baseColorFactor', Vector4(0.2, 0.8, 0.3, 1.0));
      dynamicInst.setScalar('metallic', 0.85);
      dynamicInst.setScalar('roughness', 0.15);
      dynamicInst.cullingMode = CullingMode.none;
      dynamicInst.isDepthWriteEnabled = true;

      expect(dynamicInst.getFloat4('baseColorFactor').y, closeTo(0.8, 1e-3));
      expect(dynamicInst.getFloat('metallic'), closeTo(0.85, 1e-3));
      expect(dynamicInst.cullingMode, equals(CullingMode.none));

      const testTitle = 'material_smoke_test: Scenario 02 LuminaDynamicMaterialInstance runtime parameter mutation and render state';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );

      dynamicInst.dispose();
      baseMaterial.release();

      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
  });
}
