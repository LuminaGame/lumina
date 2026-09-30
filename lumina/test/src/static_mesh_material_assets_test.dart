// A material asset assigned to a static mesh must be what the mesh draws at
// play time: a Set Material node, a Blueprint Static Mesh component's
// Material Override and the mesh asset's own material slots all name a
// material `.lmas` saved by the Material Editor (the compiled package in its
// payload, the edited parameter values in `metadata.parameter_defaults`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import 'dynamic_material_test.dart' show buildDynamicTestFilamatPackage;

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

const _red = [0.85, 0.12, 0.1, 1.0];

void main() {
  final barrel = File('${_assets.path}/Props/Barrels/fuel_barrel_yellow.glb');
  final haveAssets = barrel.existsSync();
  late Directory project;

  void writeAsset(String relative, LuminaAsset asset) {
    File('${project.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(asset.toProtoBufferBytes());
  }

  void writeMesh(String name, List<AssetReference> references) {
    final glb = barrel.readAsBytesSync();
    writeAsset(
      'contents/meshes/static/$name.lmas',
      LuminaAsset(assetId: name, name: name, type: AssetType.filamesh, rawPayload: glb, references: references),
    );
    File('${project.path}/contents/meshes/static/$name.entity.glb').writeAsBytesSync(glb);
  }

  setUpAll(() {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_mesh_materials_');
    // Saved by the Material Editor: compiled package + edited parameter values.
    writeAsset(
      'contents/materials/M_Red.lmas',
      LuminaAsset(
        assetId: 'm-red',
        name: 'M_Red',
        type: AssetType.filamat,
        rawPayload: buildDynamicTestFilamatPackage(),
        metadata: {'parameter_defaults': jsonEncode({'baseColorFactor': _red, 'metallic': 0.0})},
      ),
    );
    // Written by a mesh import: source only, no compiled package.
    writeAsset(
      'contents/materials/M_Imported.lmas',
      LuminaAsset(
        assetId: 'm-imported',
        name: 'M_Imported',
        type: AssetType.filamat,
        rawMatSource: 'material { name : M_Imported, shadingModel : lit }',
      ),
    );
    writeMesh('SM_Barrel', const []);
    // The Static Mesh editor stores the slot's material as an absolute path.
    writeMesh('SM_Barrel_Red', [
      AssetReference(slotName: 'element_0', assetId: 'm-red', assetPath: '${project.path}\\contents/materials/M_Red.lmas'),
    ]);
    writeMesh('SM_Barrel_Imported', const [
      AssetReference(slotName: 'material_slot_0', assetId: 'm-imported', assetPath: 'contents/materials/M_Imported.lmas'),
    ]);
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  late FilamentEngine engine;
  late FilamentMaterialProvider materialProvider;
  late FilamentScene scene;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create()!;
    materialProvider = FilamentMaterialProvider.ubershader(engine);
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    // A built game's bundle: project-relative `contents/…` keys only.
    LuminaAssets.defaultProvider = (path) async {
      if (!path.startsWith('contents/')) throw StateError('not in the bundle: $path');
      return File('${project.path}/$path').readAsBytes();
    };
  });

  tearDown(() {
    LuminaAssets.defaultProvider = null;
    world.cleanup();
    scene.dispose();
    materialProvider.dispose();
    engine.dispose();
  });

  /// The material instance drawn on the mesh's first primitive.
  FilamentMaterialInstance? drawn(LuminaStaticMeshComponent mesh) {
    final rm = FilamentRenderableManager(engine);
    for (final e in mesh.entities) {
      if (rm.hasComponent(e) && rm.getPrimitiveCount(e) > 0) return rm.getMaterialInstanceAt(e, 0);
    }
    return null;
  }

  /// Waits (up to 5 s) until the mesh draws a material instance named after [material].
  Future<FilamentMaterialInstance?> drawnMaterial(LuminaStaticMeshComponent mesh, String material) async {
    await mesh.loaded.timeout(const Duration(seconds: 20));
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      final mi = drawn(mesh);
      if (mi != null && mi.name.contains(material)) return mi;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return drawn(mesh);
  }

  void expectRed(FilamentMaterialInstance? mi) {
    expect(mi, isNotNull);
    expect(mi!.name, contains('M_Red'));
    final c = mi.getFloat4('baseColorFactor');
    expect([c.$1, c.$2, c.$3, c.$4], [for (final v in _red) closeTo(v, 1e-5)]);
  }

  test('Set Material at BeginPlay draws the material asset with its saved colour', () async {
    if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
    final mesh = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/static/SM_Barrel.entity.glb');
    final actor = LuminaActor(root: mesh);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    // Before the mesh has finished loading, as a BeginPlay graph runs it.
    LuminaBlueprintFunctionLibrary.setMaterial(actor, mesh, 0, 'contents/materials/M_Red.lmas');
    expectRed(await drawnMaterial(mesh, 'M_Red'));
  });

  test("a Blueprint Static Mesh component's Material Override is drawn", () async {
    if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
    final actor = LuminaActor();
    final built = LuminaBlueprintComponents.construct(actor, [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent', parentId: null, isSceneComponent: true),
      LuminaBlueprintComponent(
        id: 'mesh',
        name: 'StaticMeshComponent',
        type: 'LuminaStaticMeshComponent',
        parentId: 'root',
        properties: {
          'staticMeshAsset': 'contents/meshes/static/SM_Barrel.lmas',
          'materialOverride': 'contents/materials/M_Red.lmas',
        },
        isSceneComponent: true,
      ),
    ]);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    expectRed(await drawnMaterial(built['mesh']! as LuminaStaticMeshComponent, 'M_Red'));
  });

  test("the material assigned to the mesh asset's slot is drawn", () async {
    if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
    final mesh = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/static/SM_Barrel_Red.entity.glb');
    world.persistentLevel.registerActor(LuminaActor(root: mesh));
    world.beginPlay();
    expectRed(await drawnMaterial(mesh, 'M_Red'));
  });

  test("an import's source-only slot material keeps the mesh's own material", () async {
    if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
    final plain = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/static/SM_Barrel.entity.glb');
    final imported = LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/static/SM_Barrel_Imported.entity.glb');
    world.persistentLevel.registerActor(LuminaActor(root: plain));
    world.persistentLevel.registerActor(LuminaActor(root: imported));
    world.beginPlay();
    await plain.loaded.timeout(const Duration(seconds: 20));
    await imported.loaded.timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(drawn(imported)?.name, drawn(plain)?.name);
    expect(drawn(imported)?.name, isNot(contains('M_Imported')));
  });

  test('the editor reads a project-relative material path from the open project', () async {
    if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
    LuminaAssets.defaultProvider = null;
    LuminaAssets.projectDir = project.path;
    addTearDown(() => LuminaAssets.projectDir = null);
    final mesh = LuminaStaticMeshComponent(meshAssetPath: '${project.path}/contents/meshes/static/SM_Barrel.entity.glb');
    final actor = LuminaActor(root: mesh);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    LuminaBlueprintFunctionLibrary.setMaterial(actor, mesh, 0, 'contents/materials/M_Red.lmas');
    expectRed(await drawnMaterial(mesh, 'M_Red'));
  });
}
