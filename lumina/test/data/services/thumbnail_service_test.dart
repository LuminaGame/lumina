import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

import '../project_template_test.dart' show createTemplateProject;

/// [ThumbnailService] routes each asset type
/// to its thumbnail (Filament for meshes, materials, levels and Blueprints;
/// the image itself for textures; the badge for the rest), stores it only in
/// the `.lmas` (no `.thumbnails/` sidecar), and knows when it
/// is stale.
///
/// Real project on disk: the barrel is imported through the real import
/// pipeline, which emits the mesh, its material and its texture.

Uint8List? _studioIbl() {
  final f = File('../flutter_filament/example/assets/ibl/default_env/default_env_ibl.ktx');
  return f.existsSync() ? f.readAsBytesSync() : null;
}

void _save(String name, Uint8List png) {
  final dir = Directory('build/thumbnails')..createSync(recursive: true);
  final file = File('${dir.path}/$name')..writeAsBytesSync(png);
  // ignore: avoid_print
  print('thumbnail: ${file.absolute.path}');
}

(double, double, double) _meanRgb(img.Image image) {
  var r = 0.0, g = 0.0, b = 0.0;
  for (final p in image) {
    r += p.r;
    g += p.g;
    b += p.b;
  }
  final n = image.width * image.height;
  return (r / n, g / n, b / n);
}

LuminaAsset _read(String path) => LuminaAsset.fromBytes(File(path).readAsBytesSync());

/// Mean absolute difference per channel (0–255) between two same-size PNGs.
double _meanAbsDiff(Uint8List a, Uint8List b) {
  final x = img.decodePng(a)!;
  final y = img.decodePng(b)!;
  expect(x.width, y.width);
  var sum = 0.0;
  for (var j = 0; j < x.height; j++) {
    for (var i = 0; i < x.width; i++) {
      final p = x.getPixel(i, j);
      final q = y.getPixel(i, j);
      sum += (p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs();
    }
  }
  return sum / (x.width * x.height * 3);
}

/// The thumbnail lives only in the `.lmas`.
void _expectNoSidecar(String lmasPath) {
  expect(Directory('${File(lmasPath).parent.path}/.thumbnails').existsSync(), isFalse,
      reason: 'no .thumbnails/ sidecar beside ${lmasPath.split('/').last}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  late FilamentThumbnailRenderer renderer;
  late ThumbnailService service;
  late Directory temp;
  late String project;
  late List<RealAssetInfo> imported;

  setUpAll(() {
    renderer = FilamentThumbnailRenderer(iblKtx: _studioIbl());
    service = ThumbnailService(renderer: renderer);
  });

  tearDownAll(() => renderer.dispose());

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('lumina_thumbnail_service_');
    project = '${temp.path}/ThumbGame';
    for (final sub in ['meshes/static', 'materials', 'textures', 'levels', 'blueprints']) {
      Directory('$project/contents/$sub').createSync(recursive: true);
    }
    if (barrel.existsSync()) {
      await AssetRepository().importExternalFile(projectPath: project, sourceFilePath: barrel.path);
    }
    imported = AssetRepository().scanProjectContents(project);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  RealAssetInfo ofType(AssetType type) => imported.firstWhere((a) => a.type == type);

  test('a texture thumbnail is the source image, downscaled (mean colour within 3/255)', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final texture = ofType(AssetType.texture);
    final result = await service.generate(texture.lmasPath!);
    expect(result, isNotNull);
    expect(result!.source, ThumbnailService.sourceImage);

    final source = img.decodeImage(_read(texture.lmasPath!).rawPayload!)!;
    final thumb = img.decodePng(result.png)!;
    expect(thumb.width, lessThanOrEqualTo(ThumbnailService.size));
    expect(thumb.height, lessThanOrEqualTo(ThumbnailService.size));
    expect(thumb.width * source.height, closeTo(thumb.height * source.width, source.width.toDouble()),
        reason: 'aspect ratio kept');
    // Downscaling averages texels, so the mean colour is the source's own.
    final (er, eg, eb) = _meanRgb(source);
    final (tr, tg, tb) = _meanRgb(thumb);
    expect((tr - er).abs(), lessThanOrEqualTo(3));
    expect((tg - eg).abs(), lessThanOrEqualTo(3));
    expect((tb - eb).abs(), lessThanOrEqualTo(3));

    final stored = _read(texture.lmasPath!);
    expect(stored.thumbnailPng, orderedEquals(result.png));
    expect(stored.metadata[ThumbnailService.sourceKey], ThumbnailService.sourceImage);
    _expectNoSidecar(texture.lmasPath!);
    _save('texture_${stored.name}.png', result.png);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('mesh and material assets are rendered by Filament and stored in the .lmas only', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    for (final type in [AssetType.filamesh, AssetType.filamat]) {
      final asset = ofType(type);
      final result = await service.generate(asset.lmasPath!);
      expect(result, isNotNull, reason: '$type');
      expect(result!.source, ThumbnailService.sourceFilament, reason: '$type');
      final stored = _read(asset.lmasPath!);
      expect(stored.hasThumbnail, isTrue);
      expect(stored.thumbnailPng, orderedEquals(result.png));
      expect(stored.metadata[ThumbnailService.sourceKey], ThumbnailService.sourceFilament);
      _expectNoSidecar(asset.lmasPath!);
      final image = img.decodePng(result.png)!;
      expect(image.width, ThumbnailService.size);
      _save('${type.name}_${stored.name}.png', result.png);
      // The barrel (its white-and-rust texture) or the material's sphere
      // is at the centre, lit, well above the dark backdrop.
      final bg = image.getPixel(0, 0);
      final centre = image.getPixel(image.width ~/ 2, image.height ~/ 2);
      expect(centre.r + centre.g + centre.b, greaterThan(bg.r + bg.g + bg.b + 150), reason: '$type centre $centre vs $bg');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('stale detection: a current thumbnail is not re-rendered; a changed asset is', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final mesh = ofType(AssetType.filamesh).lmasPath!;
    expect(service.isStale(mesh), isTrue, reason: 'the import only drew a CPU badge');

    expect(await service.generate(mesh), isNotNull);
    expect(service.isStale(mesh), isFalse);
    final lmasMtime = File(mesh).lastModifiedSync();
    final stamp = DateTime.parse(_read(mesh).metadata[ThumbnailService.assetModifiedKey]!);
    expect(lmasMtime.millisecondsSinceEpoch, stamp.millisecondsSinceEpoch,
        reason: 'the .lmas carries its thumbnail stamp as its modification time');
    _expectNoSidecar(mesh);

    // Unchanged: generate() without force renders nothing and writes nothing.
    expect(await service.generate(mesh), isNull);
    expect(File(mesh).lastModifiedSync(), lmasMtime);

    // Changed: an editor save rewrites the .lmas after the thumbnail.
    final asset = _read(mesh);
    File(mesh).writeAsBytesSync(LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      hasThumbnail: asset.hasThumbnail,
      thumbnailPng: asset.thumbnailPng,
      rawPayload: asset.rawPayload,
      references: asset.references,
      metadata: {...asset.metadata, 'last_modified': DateTime.now().toIso8601String()},
    ).toProtoBufferBytes());
    File(mesh).setLastModifiedSync(stamp.add(const Duration(seconds: 2)));
    expect(service.isStale(mesh), isTrue);
    expect(await service.generate(mesh), isNotNull);
    expect(service.isStale(mesh), isFalse);

    // A newer `.entity.glb` (the mesh re-imported) makes it stale too.
    final entity = File(mesh.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    if (entity.existsSync()) {
      final now = DateTime.parse(_read(mesh).metadata[ThumbnailService.assetModifiedKey]!);
      entity.setLastModifiedSync(now.add(const Duration(seconds: 3)));
      expect(service.isStale(mesh), isTrue, reason: 'newer .entity.glb');
      expect(await service.generate(mesh), isNotNull);
      expect(service.isStale(mesh), isFalse);
    }
    _expectNoSidecar(mesh);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a level is rendered from its actors and its JSON document survives the thumbnail write', () async {
    // Exactly what the launcher scaffold writes for a Third Person project.
    final level = File('$project/contents/levels/L_DefaultLevel.lmas');
    final actors = GameTemplateCatalog.thirdPerson.levelActors;
    level.writeAsStringSync(jsonEncode(<String, dynamic>{
      'assetId': 'level_L_DefaultLevel',
      'name': 'L_DefaultLevel',
      'type': 'level',
      'relativePath': 'contents/levels/L_DefaultLevel.lmas',
      'rawPayload': null,
      'metadata': <String, dynamic>{'actors': actors},
    }));

    final result = await service.generate(level.path);
    expect(result, isNotNull);
    expect(result!.source, ThumbnailService.sourceFilament);
    _save('level_L_DefaultLevel.png', result.png);

    // Still the editor's JSON (not rewritten as LMAS binary), actors intact.
    final map = jsonDecode(level.readAsStringSync()) as Map<String, dynamic>;
    expect((map['metadata'] as Map)['actors'], hasLength(actors.length));
    expect(((map['metadata'] as Map)['actors'] as List).first, isA<Map>());
    expect(map['assetId'], 'level_L_DefaultLevel');
    expect(base64Decode(map['thumbnail_png'] as String), orderedEquals(result.png));
    expect((map['metadata'] as Map)[ThumbnailService.sourceKey], ThumbnailService.sourceFilament);
    expect(service.isStale(level.path), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a Blueprint renders its mesh components', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final mesh = ofType(AssetType.filamesh);
    final document = {
      'parentClass': 'LuminaActor',
      'components': [
        {'id': 'root_scene', 'name': 'DefaultSceneRoot', 'type': 'LuminaSceneComponent', 'parentId': null, 'properties': {}},
        {
          'id': 'sm_mesh',
          'name': 'StaticMeshComponent',
          'type': 'LuminaStaticMeshComponent',
          'parentId': 'root_scene',
          'properties': {'staticMeshAsset': mesh.relativePath},
        },
      ],
      'eventGraph': {'nodes': [], 'connections': []},
      'variables': [],
      'classDefaults': {},
    };
    final bp = File('$project/contents/blueprints/BP_Barrel.lmas');
    bp.writeAsBytesSync(LuminaAsset(
      assetId: 'bp-barrel',
      name: 'BP_Barrel',
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(document))),
      metadata: const {'parent_class': 'LuminaActor'},
    ).toProtoBufferBytes());

    final result = await service.generate(bp.path);
    expect(result, isNotNull);
    expect(result!.source, ThumbnailService.sourceFilament);
    _save('blueprint_BP_Barrel.png', result.png);

    // A Blueprint with no mesh keeps its badge.
    final empty = File('$project/contents/blueprints/BP_Empty.lmas')
      ..writeAsBytesSync(const LuminaAsset(assetId: 'bp-empty', name: 'BP_Empty', type: AssetType.actor).toProtoBufferBytes());
    final badge = await service.generate(empty.path);
    expect(badge, isNotNull);
    expect(badge!.source, ThumbnailService.sourceBadge);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Animation Blueprints and Blend Spaces get their type badge once, and their JSON document is kept', () async {
    Directory('$project/contents/animations').createSync(recursive: true);
    final documents = <AssetType, Map<String, dynamic>>{
      AssetType.animBlueprint: {
        'name': 'ABP_Thumb',
        'skeleton': 'contents/meshes/skeletal/SKM_Superhero_Female.lmas',
        'variables': [
          {'name': 'Speed', 'type': 'float', 'default': 0.0},
        ],
        'stateMachine': {'entry': 'Idle', 'states': [], 'transitions': []},
      },
      AssetType.blendSpace: {
        'name': 'BS_Thumb',
        'axisX': {'name': 'Speed', 'min': 0.0, 'max': 600.0},
        'samples': [],
      },
    };
    for (final MapEntry(key: type, value: document) in documents.entries) {
      final file = File('$project/contents/animations/${document['name']}.lmas');
      final payload = utf8.encode(jsonEncode(document));
      file.writeAsBytesSync(LuminaAsset(
        assetId: '${type.name}-thumb',
        name: document['name'] as String,
        type: type,
        rawPayload: Uint8List.fromList(payload),
      ).toProtoBufferBytes());
      final info = AssetRepository().scanProjectContents(project).firstWhere((a) => a.lmasPath == file.path);
      expect(info.type, type);
      expect(ThumbnailService.isStaleInfo(info), isTrue, reason: '$type has no thumbnail yet');

      final result = await service.generate(file.path);
      expect(result, isNotNull, reason: '$type');
      expect(result!.source, ThumbnailService.sourceBadge, reason: '$type has nothing to render yet');
      expect(img.decodePng(result.png), isNotNull);

      final stored = _read(file.path);
      expect(stored.type, type);
      expect(stored.rawPayload, orderedEquals(payload), reason: 'the $type document is untouched');
      expect(stored.thumbnailPng, orderedEquals(result.png));
      _expectNoSidecar(file.path);
      final rescanned = AssetRepository().scanProjectContents(project).firstWhere((a) => a.lmasPath == file.path);
      expect(ThumbnailService.isStaleInfo(rescanned), isFalse, reason: '$type is current: not queued again');
      expect(await service.generate(file.path), isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  // The Third Person template's animation assets (and an FBX clip
  // bound to its mannequin) are rendered, not left with a type badge.
  group('animation assets on a Third Person project', () {
    late Directory tpRoot;
    late String tp;
    const quinn = LuminaThirdPersonContent.projectMeshAssetPath;
    final clipDir = LuminaThirdPersonContent.projectAnimationDir;

    setUpAll(() async {
      tpRoot = Directory.systemTemp.createTempSync('lumina_thumbnail_anim_');
      final config = Directory('${tpRoot.path}/.config')..createSync(recursive: true);
      tp = await createTemplateProject(root: tpRoot, configDir: config, name: 'tp_thumbs', template: kThirdPersonTemplateId);
    });
    tearDownAll(() {
      if (tpRoot.existsSync()) tpRoot.deleteSync(recursive: true);
    });

    RealAssetInfo scanned(String rel) =>
        AssetRepository().scanProjectContents(tp).firstWhere((a) => a.relativePath == rel);

    test('clips, the Animation Blueprint and the Blend Space are queued and rendered by Filament', () async {
      final mesh = await service.generate('$tp/$quinn', force: true);
      expect(mesh?.source, ThumbnailService.sourceFilament, reason: 'the mannequin itself renders');
      _save('anim_rest_pose_SKM_Superhero_Female.png', mesh!.png);

      final results = <String, ThumbnailResult>{};
      for (final rel in [
        '$clipDir/Idle_Loop.lmas',
        '$clipDir/Walk_Fwd_Loop.lmas',
        LuminaThirdPersonContent.projectAnimBlueprintPath,
        LuminaThirdPersonContent.projectWalkBlendSpacePath,
      ]) {
        final info = scanned(rel);
        expect(ThumbnailService.isStaleInfo(info), isTrue,
            reason: '$rel has no rendered thumbnail, so the editor must queue it (${info.thumbnailSource})');
        final result = await service.generate('$tp/$rel');
        expect(result, isNotNull, reason: rel);
        expect(result!.source, ThumbnailService.sourceFilament, reason: '$rel renders its skeletal mesh');
        final stored = _read('$tp/$rel');
        expect(stored.thumbnailPng, orderedEquals(result.png), reason: '$rel: persisted in the .lmas');
        expect(stored.metadata[ThumbnailService.sourceKey], ThumbnailService.sourceFilament);
        _expectNoSidecar('$tp/$rel');
        expect(ThumbnailService.isStaleInfo(scanned(rel)), isFalse, reason: '$rel is current afterwards');
        results[rel] = result;
        _save('anim_${rel.split('/').last.replaceAll('.lmas', '')}.png', result.png);
      }

      // A clip is the mannequin posed by the clip, not its rest pose.
      final walk = results['$clipDir/Walk_Fwd_Loop.lmas']!.png;
      final idle = results['$clipDir/Idle_Loop.lmas']!.png;
      expect(_meanAbsDiff(walk, mesh.png), greaterThan(2.0), reason: 'the walk clip poses the mesh');
      expect(_meanAbsDiff(idle, mesh.png), greaterThan(2.0), reason: 'the idle clip poses the mesh');
      expect(_meanAbsDiff(walk, idle), greaterThan(1.0), reason: 'two clips, two poses');

      // At the middle of the clip: the renderer's own mid-clip frame, not its first.
      final glb = (await FilamentThumbnailRenderer.loadMeshGlb('$tp/$quinn'))!;
      Future<Uint8List> posed(String clip, double fraction) async => (await service.renderer
          .renderMeshParts([ThumbnailMeshPart(glb, pose: ThumbnailPose(clip: clip, fraction: fraction))]))!;
      final mid = await posed('Walk_Fwd_Loop', 0.5);
      final start = await posed('Walk_Fwd_Loop', 0.0);
      expect(_meanAbsDiff(walk, mid), lessThan(0.5), reason: 'the clip thumbnail is its middle frame');
      expect(_meanAbsDiff(start, mid), greaterThan(1.0), reason: 'and the middle frame is not the first');

      // ABP_Character: its target mesh; BS_Walk: posed by the sample at the centre
      // of its Direction axis (0°, the forward walk).
      final abp = results[LuminaThirdPersonContent.projectAnimBlueprintPath]!.png;
      final bs = results[LuminaThirdPersonContent.projectWalkBlendSpacePath]!.png;
      expect(_meanAbsDiff(abp, mesh.png), lessThan(0.5), reason: 'ABP_Character draws SKM_Superhero_Female');
      expect(_meanAbsDiff(bs, mid), lessThan(0.5), reason: 'BS_Walk draws its centre sample, Walk_Fwd_Loop');
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('an FBX animation imported onto the mannequin is queued and rendered posed', () async {
      final fbx = File('${SmokeArtifacts.testAssetsDir.path}/FBX/Animations/AS_Poker_Dealer_Idle_01.FBX');
      if (!fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      final result = await ImportAssetUseCase()(projectDir: tp, sourceFilePath: fbx.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      final rel = result.asset!.relativePath;
      expect(_read('$tp/$rel').metadata['source_mesh'], quinn, reason: 'bound to the mannequin');

      final info = scanned(rel);
      expect(ThumbnailService.isStaleInfo(info), isTrue, reason: 'the import only drew a badge');
      final thumb = await service.generate('$tp/$rel');
      expect(thumb?.source, ThumbnailService.sourceFilament);
      _save('anim_AS_Poker_Dealer_Idle_01.png', thumb!.png);
      final rest = await service.renderer.renderMesh((await FilamentThumbnailRenderer.loadMeshGlb('$tp/$quinn'))!);
      expect(_meanAbsDiff(thumb.png, rest!), greaterThan(2.0), reason: 'the dealer idle poses the mannequin');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
