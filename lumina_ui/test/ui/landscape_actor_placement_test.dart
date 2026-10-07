// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';

/// The level half. A `LANDSCAPE` `.lmas` dragged
/// into a level must become a `Landscape` actor that carries the asset path,
/// round-trips through `metadata.actors`, draws the sculpted terrain in the
/// viewport and generates a `LuminaLandscapeComponent` in game code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_landscape_actor_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<String> writeTerrain({int resolution = 129, double worldSize = 256.0}) async {
    final data = LandscapeData.flat(gridResolution: resolution, worldSize: worldSize, maxHeight: 100.0);
    final half = (resolution - 1) / 2.0;
    for (var r = 0; r < resolution; r++) {
      for (var c = 0; c < resolution; c++) {
        final u = (c - half) / half;
        final v = (r - half) / half;
        data.setHeight(c, r, 20.0 + math.exp(-((u - v) * (u - v)) * 6.0) * 45.0);
      }
    }
    final path = '${tempDir.path}/contents/landscapes/Terrain.lmas';
    await LandscapeAssetService.save(path: path, name: 'Terrain', data: data);
    return path;
  }

  test('AssetType.landscape spawns a Landscape actor, not an untyped Mesh', () async {
    // The bug this task fixes: a landscape asset fell through to the default
    // branch and became a `Mesh` actor with no geometry.
    expect(
      EditorViewModel.actorTypeNameForAssetType(AssetType.landscape),
      'Landscape',
    );
  });

  test('a Landscape actor round-trips through metadata.actors with its .lmas path', () async {
    final path = await writeTerrain();
    final node = EditorActorNode(
      id: 'act_9',
      name: 'Terrain_9',
      type: 'Landscape',
      location: [120.0, -30.0, 15.0],
      rotation: [0.0, 45.0, 0.0],
      scale: [1.0, 1.0, 1.0],
      meshAssetPath: path,
    );

    final restored = EditorActorNode.fromMap(node.toMap());
    expect(restored.type, 'Landscape');
    expect(restored.meshAssetPath, path);
    expect(restored.location, [120.0, -30.0, 15.0]);
    expect(restored.rotation, [0.0, 45.0, 0.0]);

    // …and the same map generates the runtime component for a packaged game.
    final code = DartCodeGeneratorService().generateLevelDart(
      levelName: 'L_Terrain',
      actors: const [],
      actorMaps: [restored.toMap()],
    );
    // A packaged game reads the asset from its bundle.
    expect(code, contains("LuminaLandscapeComponent(assetPath: 'contents/landscapes/Terrain.lmas'"));
    expect(code, isNot(contains(path)));
    // Stored Z-up [120, -30, 15] → runtime (x, z, −y).
    expect(code, contains('location: Vector3(120.0000, 15.0000, 30.0000)'));
  });

  test('the level viewport gets real sculpted geometry for a placed landscape', () async {
    final path = await writeTerrain();
    final mesh = await LandscapeGlbBuilder.proxyMeshFor(path);

    expect(mesh, isNotNull, reason: 'a placed landscape must resolve to real terrain geometry');
    // The glTF parser de-indexes, so assert on triangles rather than on the
    // shared-vertex count: 128² quads → two triangles each.
    expect(mesh!.indices.length ~/ 3, 128 * 128 * 2);

    // The proxy carries the payload's own heights, in the viewport's
    // centimetre units, not a flat plane.
    final payload = LandscapeAssetService.load(path)!;
    var maxY = -double.infinity;
    var minY = double.infinity;
    for (var i = 1; i < mesh.positions.length; i += 3) {
      if (mesh.positions[i] > maxY) maxY = mesh.positions[i];
      if (mesh.positions[i] < minY) minY = mesh.positions[i];
    }
    expect(maxY, closeTo(payload.heightMax * LandscapeGlbBuilder.proxyUnitsPerMetre, 0.01));
    expect(minY, closeTo(payload.heightMin * LandscapeGlbBuilder.proxyUnitsPerMetre, 0.01));
    expect(maxY - minY, greaterThan(1.0), reason: 'the ridge must survive into the viewport proxy');
  });

  test('the placed landscape is drawn at its real size, where Play draws it',() async {
    final path = await writeTerrain();
    final mesh = (await LandscapeGlbBuilder.proxyMeshFor(path))!;
    final payload = LandscapeAssetService.load(path)!;
    // The proxy is glTF metres, like every imported asset: the viewport's
    // asset unit scale (100) then draws it in centimetres, exactly as wide as
    // the runtime component draws it, with its height 0 on the actor origin.
    expect(mesh.maxBounds[0] - mesh.minBounds[0], closeTo(payload.worldSize, 0.01));
    expect(mesh.minBounds[1], closeTo(payload.heightMin, 0.01));
    final actor = EditorActorNode(
      id: 'act_land',
      name: 'Terrain',
      type: 'Landscape',
      location: [0.0, 0.0, 0.0],
      meshData: mesh,
      meshAssetPath: path,
    );
    final drawn = EditorTransforms.meshMatrix(actor);
    final west = drawn.transform3(Vector3(mesh.minBounds[0], 0.0, 0.0));
    final east = drawn.transform3(Vector3(mesh.maxBounds[0], 0.0, 0.0));
    expect((east - west).length, closeTo(payload.worldSize * LuminaUnits.unitsPerMetre, 1.0),
        reason: 'a ${payload.worldSize.toStringAsFixed(0)} m terrain is ${payload.worldSize * 100} cm wide in the viewport');
    expect(drawn.transform3(Vector3(0.0, 0.0, 0.0)).length, lessThan(1e-6), reason: 'height 0 sits on the actor origin');
  });

  test('a very large heightmap is sampled down for the viewport proxy only', () async {
    final path = await writeTerrain(resolution: 513, worldSize: 1024.0);
    final mesh = await LandscapeGlbBuilder.proxyMeshFor(path);
    expect(mesh, isNotNull);
    // 513 → step 2 → 257 per side, the stated proxy cap.
    expect(mesh!.indices.length ~/ 3, 256 * 256 * 2);
    // The payload itself keeps every sample.
    expect(LandscapeAssetService.load(path)!.gridResolution, 513);
  });

  test('a non-landscape or unreadable file yields no proxy rather than a fake one', () async {
    final bogus = File('${tempDir.path}/not_a_terrain.lmas')..writeAsBytesSync([1, 2, 3, 4]);
    expect(await LandscapeGlbBuilder.proxyMeshFor(bogus.path), isNull);
    expect(await LandscapeGlbBuilder.proxyMeshFor('${tempDir.path}/missing.lmas'), isNull);
  });

  test('restoring level or loading mesh data for a Landscape actor populates meshData with proxy glb', () async {
    final path = await writeTerrain();
    final p = LuminaProject(projectName: 'TestProj', activeLevel: 'contents/levels/L_Main.lmas');
    final vm = EditorViewModel(
      initialProject: p,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );

    final node = EditorActorNode(
      id: 'act_landscape',
      name: 'Terrain_1',
      type: 'Landscape',
      location: [0.0, 0.0, 0.0],
      meshAssetPath: path,
    );
    vm.addActorNodeForTest(node);
    expect(node.meshData, isNull);

    await vm.ensureActorMeshDataForTest(node);
    expect(node.meshData, isNotNull, reason: 'Landscape actor must have proxy GLB loaded for viewport');
    expect(node.meshData!.positions.isNotEmpty, isTrue);
  });
}

