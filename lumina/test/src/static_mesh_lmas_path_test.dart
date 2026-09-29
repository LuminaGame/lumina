// A level mesh whose meshAssetPath is an imported asset's
// .lmas (what the editor stores, PIE plays and the level generator emits)
// must load — through the .entity.glb the import writes next to it, or the
// .lmas payload.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

void main() {
  final chairFbx = File('${_assets.path}/FBX/StaticMeshes/SM_Casino_Chair.FBX');
  final haveAssets = chairFbx.existsSync();
  late Directory project;
  late String lmas;

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_lmas_mesh_path_');
    Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
    final imported = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: chairFbx.path);
    expect(imported.isSuccess, isTrue, reason: imported.error);
    lmas = '${project.path}/${imported.asset!.relativePath}';
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
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    materialProvider.dispose();
    engine.dispose();
  });

  Future<LuminaStaticMeshComponent> load(String path, {Future<Uint8List> Function(String)? provider}) async {
    final mesh = LuminaStaticMeshComponent(meshAssetPath: path, assetProvider: provider);
    world.persistentLevel.registerActor(LuminaActor(root: mesh));
    world.beginPlay();
    await mesh.loaded.timeout(const Duration(seconds: 20));
    return mesh;
  }

  test('an imported mesh placed by its .lmas path loads and is drawn', () async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final mesh = await load(lmas);
    expect(mesh.isLoaded, isTrue);
    expect(scene.hasEntity(mesh.rootEntity!), isTrue);
  });

  test('a .lmas without a companion .entity.glb loads its payload', () async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final alone = Directory.systemTemp.createTempSync('lumina_lmas_payload_only_');
    addTearDown(() => alone.deleteSync(recursive: true));
    final copy = File('${alone.path}/SM_Casino_Chair.lmas')..writeAsBytesSync(File(lmas).readAsBytesSync());
    final mesh = await load(copy.path);
    expect(mesh.isLoaded, isTrue);
  });

  test('a payload-free .lmas (template meshes) loads its .entity.glb', () async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final dir = Directory.systemTemp.createTempSync('lumina_lmas_glb_only_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/SM_Casino_Chair.entity.glb').writeAsBytesSync(File(lmas.replaceAll('.lmas', '.entity.glb')).readAsBytesSync());
    final asset = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
    File('${dir.path}/SM_Casino_Chair.lmas').writeAsBytesSync(LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      metadata: asset.metadata,
    ).toProtoBufferBytes());
    final mesh = await load('${dir.path}/SM_Casino_Chair.lmas');
    expect(mesh.isLoaded, isTrue);
  });

  test('a game\'s asset bundle serves the project path (contents/…)', () async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final requested = <String>[];
    // Like rootBundle: keys are project paths; a missing key throws.
    Future<Uint8List> bundle(String key) async {
      requested.add(key);
      final file = File('${project.path}/$key');
      if (!file.existsSync()) throw FlutterError('Unable to load asset: "$key".');
      return file.readAsBytes();
    }

    final mesh = await load('contents/meshes/static/SM_Casino_Chair.lmas', provider: bundle);
    expect(mesh.isLoaded, isTrue);
    expect(requested.first, 'contents/meshes/static/SM_Casino_Chair.entity.glb', reason: 'the GLB, not the container, is read first');
  });
}
