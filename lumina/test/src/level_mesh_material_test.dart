// The material assigned to a placed level mesh (the actor's `materialPath`,
// written by the Details panel and `set_actor_property material`) is what the
// mesh draws in the generated game: the level code generator carries it into
// the actor it emits, and that actor draws it on every section.
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

  setUpAll(() {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_level_mesh_material_');
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
    // Created but never compiled: source only.
    writeAsset(
      'contents/materials/M_Draft.lmas',
      LuminaAsset(
        assetId: 'm-draft',
        name: 'M_Draft',
        type: AssetType.filamat,
        rawMatSource: 'material { name : M_Draft, shadingModel : lit }',
      ),
    );
    final glb = barrel.readAsBytesSync();
    writeAsset(
      'contents/meshes/static/SM_Barrel.lmas',
      LuminaAsset(assetId: 'sm-barrel', name: 'SM_Barrel', type: AssetType.filamesh, rawPayload: glb),
    );
    File('${project.path}/contents/meshes/static/SM_Barrel.entity.glb').writeAsBytesSync(glb);
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  group('generated level', () {
    Map<String, dynamic> meshActor(String id, String? material, {String type = 'Mesh'}) => {
          'id': id,
          'name': id,
          'type': type,
          'location': [0.0, 0.0, 0.0],
          'meshAssetPath': '${project.path}/contents/meshes/static/SM_Barrel.lmas',
          'materialPath': material,
        };

    String lineOf(String code, String id) => code.split('\n').firstWhere((l) => l.contains("ValueKey('$id')"));

    test("a placed mesh's material is passed to the actor the level builds", () {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final code = DartCodeGeneratorService().generateLevelDart(
        levelName: 'L_Main',
        actors: const [],
        projectDir: project.path,
        actorMaps: [
          meshActor('relative', 'contents/materials/M_Red.lmas'),
          // The Static Mesh editor and older levels store absolute paths.
          meshActor('absolute', '${project.path}\\contents\\materials\\M_Red.lmas', type: 'StaticMesh'),
          {
            'id': 'cube',
            'name': 'cube',
            'type': 'Primitive',
            'location': [0.0, 0.0, 0.0],
            'materialPath': 'contents/materials/M_Red.lmas',
            'components': [
              {'id': 'cube_mesh', 'type': 'LuminaProceduralMeshComponent', 'properties': {'shape': 'box'}},
            ],
          },
        ],
      );
      for (final id in ['relative', 'absolute', 'cube']) {
        expect(lineOf(code, id), contains("materialOverrideAsset: 'contents/materials/M_Red.lmas'"), reason: id);
      }
      expect(code, isNot(contains(project.path.replaceAll(r'\', '/'))));
    });

    test('no material, an old placeholder name or an uncompiled material keeps the mesh its own', () {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final code = DartCodeGeneratorService().generateLevelDart(
        levelName: 'L_Main',
        actors: const [],
        projectDir: project.path,
        actorMaps: [
          meshActor('none', null),
          meshActor('placeholder', 'M_fuel_barrel_yellow_Mat'),
          meshActor('draft', 'contents/materials/M_Draft.lmas'),
          meshActor('missing', 'contents/materials/M_Gone.lmas'),
        ],
      );
      for (final id in ['none', 'placeholder', 'draft', 'missing']) {
        expect(lineOf(code, id), isNot(contains('materialOverrideAsset')), reason: id);
      }
      expect(code, contains('M_Draft.lmas carries no compiled material'));
      expect(code, contains('M_Gone.lmas was not found'));
    });

    test('the level preloads a drawn material and skips one that cannot draw', () {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final refs = LuminaLevelAssetManifest.fromActorMaps([
        meshActor('red', 'contents/materials/M_Red.lmas'),
        meshActor('draft', 'contents/materials/M_Draft.lmas'),
        meshActor('missing', 'contents/materials/M_Gone.lmas'),
      ], projectDir: project.path);
      final materials = [for (final r in refs) if (r.kind == LuminaAssetKind.material) r.path];
      expect(materials, ['contents/materials/M_Red.lmas']);
    });
  });

  group('drawn', () {
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

    /// The material instances drawn on every primitive of [entities].
    List<FilamentMaterialInstance?> drawnOn(Iterable<int> entities) {
      final rm = FilamentRenderableManager(engine);
      return [
        for (final e in entities)
          if (rm.hasComponent(e))
            for (var p = 0; p < rm.getPrimitiveCount(e); p++) rm.getMaterialInstanceAt(e, p),
      ];
    }

    /// Waits (up to 5 s) until every section of [mesh] draws [material].
    Future<List<FilamentMaterialInstance?>> drawnMaterial(LuminaStaticMeshComponent mesh, String material) async {
      await mesh.loaded.timeout(const Duration(seconds: 20));
      final end = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(end)) {
        final all = drawnOn(mesh.entities);
        if (all.isNotEmpty && all.every((mi) => mi != null && mi.name.contains(material))) return all;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return drawnOn(mesh.entities);
    }

    void expectRed(List<FilamentMaterialInstance?> drawn) {
      expect(drawn, isNotEmpty);
      for (final mi in drawn) {
        expect(mi?.name, contains('M_Red'));
        final c = mi!.getFloat4('baseColorFactor');
        expect([c.$1, c.$2, c.$3, c.$4], [for (final v in _red) closeTo(v, 1e-5)]);
      }
    }

    test('the static mesh actor a level builds draws its material on every section', () async {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final actor = LuminaStaticMeshActor(
        meshAssetPath: 'contents/meshes/static/SM_Barrel.entity.glb',
        materialOverrideAsset: 'contents/materials/M_Red.lmas',
      );
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      expectRed(await drawnMaterial(actor.meshComponent, 'M_Red'));
    });

    test('a basic shape draws its material in place of its colour', () async {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final cube = LuminaPrimitiveActor.fromComponentProperties(
        const {'shape': 'box', 'colorHex': '#20C040'},
        materialOverrideAsset: 'contents/materials/M_Red.lmas',
      );
      world.persistentLevel.registerActor(cube);
      world.beginPlay();
      expectRed(await drawnMaterial(cube.meshComponent, 'M_Red'));
    });

    test('the level viewport draws the material on an instance and gives the mesh its own back', () async {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      final bytes = File('${project.path}/contents/meshes/static/SM_Barrel.entity.glb').readAsBytesSync();
      final handle = await LuminaMeshAssetCache.forEngine(engine).acquireBytes(bytes, sourcePath: 'SM_Barrel');
      expect(handle, isNotNull);
      addTearDown(handle!.release);
      final entities = {handle.instance.root, ...handle.instance.entities};
      final own = [for (final mi in drawnOn(entities)) mi?.name];
      expect(own.every((n) => n != null && !n.contains('M_Red')), isTrue, reason: '$own');

      final red = LuminaInstanceMaterialOverride.fromBytes(
        engine,
        'contents/materials/M_Red.lmas',
        File('${project.path}/contents/materials/M_Red.lmas').readAsBytesSync(),
      );
      red.applyTo(handle.instance);
      expectRed(drawnOn(entities));
      red.dispose();
      expect([for (final mi in drawnOn(entities)) mi?.name], own);
    });

    test('a material without a compiled package is an error, not a crash', () {
      if (!haveAssets) return markTestSkipped('test-assets/Props/Barrels missing');
      expect(
        () => LuminaInstanceMaterialOverride.fromBytes(
          engine,
          'contents/materials/M_Draft.lmas',
          File('${project.path}/contents/materials/M_Draft.lmas').readAsBytesSync(),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('carries no compiled material'))),
      );
    });
  });
}
