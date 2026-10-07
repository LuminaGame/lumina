// One mesh upload per engine, however many worlds draw it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

final _assets = '${Directory.current.parent.path}/test-assets';
final _barrel = File('$_assets/Props/Barrels/dented_barrel.glb');
final _fixture = File('$_assets/fixtures/YVO3D_44368.glb');

/// A world with its own scene on [engine], as a viewport has.
LuminaWorld _world(FilamentEngine engine) {
  final scene = engine.createScene();
  return LuminaWorld(worldType: LuminaWorldType.editor)..initializeNativeContext(engine, scene);
}

Future<LuminaStaticMeshComponent> _place(LuminaWorld world, String path, {LuminaAssetProvider? provider}) async {
  final mesh = LuminaStaticMeshComponent(meshAssetPath: path, assetProvider: provider);
  world.persistentLevel.registerActor(LuminaActor(root: mesh));
  await mesh.loaded.timeout(const Duration(seconds: 60));
  return mesh;
}

/// [glb] re-encoded with `asset.extras` set to [extras] (a real edit of the
/// file's content that leaves its mesh intact).
Uint8List _withAssetExtras(Uint8List glb, Map<String, Object?> extras) {
  final header = ByteData.sublistView(glb);
  final jsonLength = header.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  (json['asset'] as Map<String, dynamic>)['extras'] = extras;
  var jsonBytes = utf8.encode(jsonEncode(json));
  final pad = (4 - jsonBytes.length % 4) % 4;
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled(pad, 0x20)]);
  final rest = glb.sublist(20 + jsonLength);
  final out = BytesBuilder()
    ..add(glb.sublist(0, 8))
    ..add(Uint8List(4)..buffer.asByteData().setUint32(0, 20 + jsonBytes.length + rest.length, Endian.little))
    ..add(Uint8List(4)..buffer.asByteData().setUint32(0, jsonBytes.length, Endian.little))
    ..add(glb.sublist(16, 20))
    ..add(jsonBytes)
    ..add(rest);
  return out.toBytes();
}

void main() {
  final hasAssets = _barrel.existsSync() && _fixture.existsSync();
  late FilamentEngineLease lease;
  late FilamentEngine engine;

  setUp(() {
    lease = FilamentEngineHost.acquire(owner: 'engine_scoped_mesh_cache_test')!;
    engine = lease.engine;
  });

  tearDown(() {
    if (!lease.isReleased) lease.release();
    LuminaMeshAssetCache.sourceFilter = null;
  });

  test('two worlds on one engine share one upload of a textured mesh', () async {
    // The cache's own objects (the ubershader provider's dummy texture, …)
    // live as long as the engine; count from after they exist.
    LuminaMeshAssetCache.forEngine(engine);
    final before = engine.resourceCounts;
    final a = _world(engine);
    final b = _world(engine);
    final meshA = await _place(a, _fixture.path);
    final afterA = engine.resourceCounts;
    final meshB = await _place(b, _fixture.path);
    final afterB = engine.resourceCounts;

    final cache = LuminaMeshAssetCache.forEngine(engine);
    expect(cache.uploadCount, 1);
    expect(cache.liveAssetCount, 1);
    expect(cache.entries.single.handles, 2);
    // Three images; gltfio makes one texture per image and colour space used.
    expect((afterA - before).textures, greaterThanOrEqualTo(3), reason: 'the first world uploads the fixture\'s textures');
    expect(afterB.textures, afterA.textures, reason: 'the second world uploads nothing');
    expect(meshA.entities.toSet().intersection(meshB.entities.toSet()), isEmpty, reason: 'each world has its own instance');
    expect(meshA.entities.every(a.filamentScene.hasEntity), isTrue);
    expect(meshB.entities.every(b.filamentScene.hasEntity), isTrue);
    expect(meshB.entities.any(a.filamentScene.hasEntity), isFalse);

    final sceneA = a.filamentScene;
    final sceneB = b.filamentScene;
    a.cleanup();
    expect(cache.liveAssetCount, 1, reason: 'world B still draws it');
    expect(meshA.entities.any(sceneA.hasEntity), isFalse);
    expect(meshB.entities.every(sceneB.hasEntity), isTrue);
    b.cleanup();
    expect(cache.liveAssetCount, 0);
    final after = engine.resourceCounts - before;
    for (final (name, value) in [
      ('textures', after.textures),
      ('renderables', after.renderables),
      ('vertexBuffers', after.vertexBuffers),
      ('indexBuffers', after.indexBuffers),
    ]) {
      expect(value, 0, reason: '$name left after both worlds cleaned up: $after');
    }
    sceneA.dispose();
    sceneB.dispose();
  }, skip: hasAssets ? false : 'test-assets missing');

  test('an .lmas payload and a path-based load of its .entity.glb are one entry; edited bytes are another', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_mesh_cache_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final lmas = File('${dir.path}/SM_Barrel.lmas')
      ..writeAsBytesSync(const LuminaAsset(assetId: 'SM_Barrel', name: 'SM_Barrel', type: AssetType.filamesh).toProtoBufferBytes());
    final companion = File('${dir.path}/SM_Barrel.entity.glb')..writeAsBytesSync(_barrel.readAsBytesSync());
    expect(LuminaMeshAssetCache.canonicalSourcePath(lmas.path), companion.absolute.path);

    final cache = LuminaMeshAssetCache.forEngine(engine);
    final payload = companion.readAsBytesSync();
    final byBytes = (await cache.acquireBytes(payload, sourcePath: lmas.path))!;
    final byPath = (await cache.acquire(lmas.path))!;
    expect(byPath.key, byBytes.key);
    expect(cache.uploadCount, 1);
    expect(cache.entries.single.sourcePaths, {companion.absolute.path});

    // The same bytes under another path are the same upload, both recorded.
    final copy = File('${dir.path}/SM_BarrelCopy.glb')..writeAsBytesSync(payload);
    final byCopy = (await cache.acquire(copy.path))!;
    expect(byCopy.key, byBytes.key);
    expect(cache.uploadCount, 1);
    expect(cache.entries.single.sourcePaths, {companion.absolute.path, copy.absolute.path});

    // The same mesh with an edited glTF header is new content: a second asset.
    final edited = _withAssetExtras(payload, {'edited': true});
    final byEdited = (await cache.acquireBytes(edited, sourcePath: lmas.path))!;
    expect(byEdited.key, isNot(byBytes.key));
    expect(cache.uploadCount, 2);

    for (final h in [byBytes, byPath, byCopy, byEdited]) {
      h.release();
    }
    expect(cache.liveAssetCount, 0);
  }, skip: hasAssets ? false : 'test-assets missing');

  test('an unchanged file is not read again; a rewritten one is a new entry', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_mesh_cache_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/SM_Mesh.glb')..writeAsBytesSync(_barrel.readAsBytesSync());
    var reads = 0;
    LuminaMeshAssetCache.sourceFilter = (path, bytes) async {
      reads++;
      return bytes;
    };
    final cache = LuminaMeshAssetCache.forEngine(engine);
    final first = (await cache.acquire(file.path))!;
    final second = (await cache.acquire(file.path))!;
    expect(reads, 1, reason: 'the file is read once while its size and mtime stay the same');
    expect(second.key, first.key);

    file.writeAsBytesSync(_fixture.readAsBytesSync());
    file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));
    final third = (await cache.acquire(file.path))!;
    expect(reads, 2);
    expect(third.key, isNot(first.key));
    expect(cache.uploadCount, 2);
    for (final h in [first, second, third]) {
      h.release();
    }
  }, skip: hasAssets ? false : 'test-assets missing');

  test('a released instance is taken apart while others hold the asset: open/close cycles do not grow', () async {
    final cache = LuminaMeshAssetCache.forEngine(engine);
    final keeper = (await cache.acquire(_fixture.path))!;
    final withOne = engine.resourceCounts;
    for (var cycle = 0; cycle < 5; cycle++) {
      final extra = (await cache.acquire(_fixture.path))!;
      expect(extra.instance.entities.toSet().intersection(keeper.instance.entities.toSet()), isEmpty);
      extra.release();
      final after = engine.resourceCounts - withOne;
      expect([after.renderables, after.transforms, after.entities, after.textures], [0, 0, 0, 0],
          reason: 'cycle $cycle left ${after.nonZero}');
    }
    expect(cache.uploadCount, 1);
    expect(cache.entries.single.handles, 1);
    // The keeper's instance still works after the others were destroyed.
    expect(keeper.instance.entities.every(FilamentRenderableManager(engine).hasComponent) ||
        keeper.instance.entities.any(FilamentRenderableManager(engine).hasComponent), isTrue);
    keeper.release();
    expect(cache.liveAssetCount, 0);
  }, skip: hasAssets ? false : 'test-assets missing');

  test('sourceFilter output is what is parsed and keyed', () async {
    final filtered = _fixture.readAsBytesSync();
    String? filteredPath;
    LuminaMeshAssetCache.sourceFilter = (path, bytes) async {
      filteredPath = path;
      return filtered;
    };
    final cache = LuminaMeshAssetCache.forEngine(engine);
    final handle = (await cache.acquire(_barrel.path))!;
    expect(filteredPath, _barrel.absolute.path);
    expect(handle.key, LuminaMeshAssetCache.contentDigest(filtered), reason: 'the fixture, not the barrel, was parsed');
    handle.release();
  }, skip: hasAssets ? false : 'test-assets missing');

  test('two different meshes acquired at once both finish loading (serialized resource loads)', () async {
    final cache = LuminaMeshAssetCache.forEngine(engine);
    final handles = await Future.wait([cache.acquire(_barrel.path), cache.acquire(_fixture.path)]);
    expect(handles.every((h) => h != null), isTrue);
    expect(cache.uploadCount, 2);
    final rm = FilamentRenderableManager(engine);
    for (final h in handles) {
      expect(h!.instance.entities.where(rm.hasComponent), isNotEmpty);
      h.release();
    }
  }, skip: hasAssets ? false : 'test-assets missing');

  test('the cache dies with its engine and a new engine gets a fresh one', () async {
    final dedicated = FilamentEngine.create()!;
    final cache = LuminaMeshAssetCache.forEngine(dedicated);
    final handle = (await cache.acquire(_barrel.path))!;
    expect(handle.isReleased, isFalse);
    dedicated.dispose();
    expect(cache.isDisposed, isTrue, reason: 'engine-scoped: torn down before the engine');
    expect(LuminaMeshAssetCache.existingFor(dedicated), isNull);

    final other = FilamentEngine.create()!;
    addTearDown(other.dispose);
    expect(identical(LuminaMeshAssetCache.forEngine(other), cache), isFalse);
  }, skip: hasAssets ? false : 'test-assets missing');
}
