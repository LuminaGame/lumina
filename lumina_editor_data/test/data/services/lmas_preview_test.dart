import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../project_template_test.dart' show createTemplateProject;

/// What a file manager shows for a `.lmas`: the Content Browser's thumbnail
/// of the asset (`ThumbnailService.preview`). A fresh thumbnail embedded in
/// the `.lmas` comes back as it is; a stale or missing one is rendered by the
/// same routing as `generate`, and the file is never written.
///
/// Real Third Person project (its mannequin, clips, Animation Blueprint,
/// Blend Space, level and Blueprints) with the barrel imported through the
/// real import pipeline. Renders on GPU 1 (`FILAMENT_GPU`); the PNGs land in
/// `build/thumbnails/lmas_preview/`.
Uint8List? _studioIbl() {
  final f = File('../flutter_filament/example/assets/ibl/default_env/default_env_ibl.ktx');
  return f.existsSync() ? f.readAsBytesSync() : null;
}

double _meanAbsDiff(Uint8List a, Uint8List b) {
  final x = img.decodePng(a)!;
  final y = img.decodePng(b)!;
  expect(x.width, y.width);
  expect(x.height, y.height);
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

/// The `.lmas` bytes and modification time, to prove nothing was written.
(Uint8List, DateTime) _snapshot(String path) => (File(path).readAsBytesSync(), File(path).lastModifiedSync());

void _expectUnchanged(String path, (Uint8List, DateTime) before) {
  expect(File(path).readAsBytesSync(), orderedEquals(before.$1), reason: '$path must not be written');
  expect(File(path).lastModifiedSync(), before.$2, reason: '$path keeps its modification time');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  final out = Directory('build/thumbnails/lmas_preview');
  late FilamentThumbnailRenderer renderer;
  late ThumbnailService service;
  late Directory root;
  late String tp;
  late Directory outside;

  setUpAll(() async {
    out.createSync(recursive: true);
    renderer = FilamentThumbnailRenderer(iblKtx: _studioIbl());
    service = ThumbnailService(renderer: renderer);
    root = Directory.systemTemp.createTempSync('lumina_lmas_preview_');
    outside = Directory('${root.path}/loose')..createSync();
    final config = Directory('${root.path}/.config')..createSync(recursive: true);
    tp = await createTemplateProject(root: root, configDir: config, name: 'tp_preview', template: kThirdPersonTemplateId);
    if (barrel.existsSync()) {
      await AssetRepository().importExternalFile(projectPath: tp, sourceFilePath: barrel.path);
    }
  });

  tearDownAll(() {
    renderer.dispose();
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  List<RealAssetInfo> scan() => AssetRepository().scanProjectContents(tp);
  String pathOf(AssetType type, {String? named}) => scan()
      .firstWhere((a) => a.type == type && (named == null || a.relativePath.contains(named)),
          orElse: () => throw StateError('no $type${named == null ? '' : ' named $named'} in the project'))
      .lmasPath!;

  /// preview (stale: rendered, not written) == generate(force) (rendered and
  /// embedded); then preview of the now fresh thumbnail is the embedded
  /// image itself, even with a renderer that cannot start.
  Future<void> expectContentBrowserThumbnail(String path, String source, String label) async {
    final before = _snapshot(path);
    final previewed = await service.preview(path);
    expect(previewed, isNotNull, reason: label);
    _expectUnchanged(path, before);
    File('${out.path}/$label.png').writeAsBytesSync(previewed!.png);

    final generated = await service.generate(path, force: true);
    expect(generated, isNotNull, reason: label);
    expect(previewed.source, generated!.source, reason: '$label: same route as the Content Browser');
    expect(previewed.source, source, reason: label);
    expect(_meanAbsDiff(previewed.png, generated.png), lessThan(0.5), reason: '$label: the Content Browser image');

    final offline = FilamentThumbnailRenderer()..dispose();
    final fresh = _snapshot(path);
    final cached = await ThumbnailService(renderer: offline).preview(path);
    expect(cached, isNotNull, reason: label);
    expect(cached!.png, orderedEquals(generated.png), reason: '$label: a fresh embedded thumbnail is returned as it is');
    _expectUnchanged(path, fresh);
  }

  group('each asset kind shows what the Content Browser shows', () {
    test('static mesh, its material and its texture (the imported barrel)', () async {
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      await expectContentBrowserThumbnail(pathOf(AssetType.filamesh, named: 'fuel_barrel_red'), ThumbnailService.sourceFilament, 'static_mesh');
      await expectContentBrowserThumbnail(pathOf(AssetType.filamat, named: 'fuel_barrel_red'), ThumbnailService.sourceFilament, 'material');
      await expectContentBrowserThumbnail(pathOf(AssetType.texture, named: 'fuel_barrel_red'), ThumbnailService.sourceImage, 'texture');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('skeletal mesh, animation clip, Animation Blueprint and Blend Space', () async {
      await expectContentBrowserThumbnail('$tp/${LuminaThirdPersonContent.projectMeshAssetPath}', ThumbnailService.sourceFilament, 'skeletal_mesh');
      await expectContentBrowserThumbnail(
          '$tp/${LuminaThirdPersonContent.projectAnimationDir}/Walk_Fwd_Loop.lmas', ThumbnailService.sourceFilament, 'animation');
      await expectContentBrowserThumbnail(
          '$tp/${LuminaThirdPersonContent.projectAnimBlueprintPath}', ThumbnailService.sourceFilament, 'anim_blueprint');
      await expectContentBrowserThumbnail(
          '$tp/${LuminaThirdPersonContent.projectWalkBlendSpacePath}', ThumbnailService.sourceFilament, 'blend_space');
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('a level, a Blueprint with a mesh and a type with nothing to render', () async {
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final level = File('$tp/contents/levels/L_Preview.lmas')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(<String, dynamic>{
          'assetId': 'level_L_Preview',
          'name': 'L_Preview',
          'type': 'level',
          'relativePath': 'contents/levels/L_Preview.lmas',
          'rawPayload': null,
          'metadata': <String, dynamic>{'actors': GameTemplateCatalog.thirdPerson.levelActors},
        }));
      await expectContentBrowserThumbnail(level.path, ThumbnailService.sourceFilament, 'level');

      final mesh = scan().firstWhere((a) => a.type == AssetType.filamesh && a.relativePath.contains('fuel_barrel_red'));
      final document = {
        'parentClass': 'LuminaActor',
        'components': [
          {'id': 'root_scene', 'name': 'DefaultSceneRoot', 'type': 'LuminaSceneComponent', 'parentId': null, 'properties': {}},
          {
            'id': 'sm',
            'name': 'StaticMeshComponent',
            'type': 'LuminaStaticMeshComponent',
            'parentId': 'root_scene',
            'properties': {'staticMeshAsset': mesh.relativePath},
          },
        ],
      };
      final bp = File('$tp/contents/blueprints/BP_PreviewBarrel.lmas')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(
          assetId: 'bp-preview',
          name: 'BP_PreviewBarrel',
          type: AssetType.actor,
          rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(document))),
        ).toProtoBufferBytes());
      await expectContentBrowserThumbnail(bp.path, ThumbnailService.sourceFilament, 'blueprint');

      final sound = File('$tp/contents/audio/S_Preview.lmas')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(const LuminaAsset(assetId: 'snd-preview', name: 'S_Preview', type: AssetType.audio).toProtoBufferBytes());
      await expectContentBrowserThumbnail(sound.path, ThumbnailService.sourceBadge, 'audio_badge');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('a copy outside its project (what the Windows shell passes)', () {
    test('keeps the thumbnail the editor made', () async {
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final original = pathOf(AssetType.filamesh, named: 'fuel_barrel_red');
      final made = await service.generate(original, force: true);
      final copy = File(original).copySync('${outside.path}/copied_mesh.lmas');
      // A copy is newer than the thumbnail's stamp; outside a project that
      // says nothing about the asset.
      final result = await ThumbnailService(renderer: FilamentThumbnailRenderer()..dispose()).preview(copy.path);
      expect(result!.png, orderedEquals(made!.png));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('without a thumbnail, renders what the file holds', () async {
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final mesh = File('${outside.path}/SM_Loose.lmas')
        ..writeAsBytesSync(LuminaAsset(
          assetId: 'sm-loose',
          name: 'SM_Loose',
          type: AssetType.filamesh,
          rawPayload: barrel.readAsBytesSync(),
        ).toProtoBufferBytes());
      final before = _snapshot(mesh.path);
      final result = await service.preview(mesh.path);
      expect(result!.source, ThumbnailService.sourceFilament);
      _expectUnchanged(mesh.path, before);
      File('${out.path}/loose_mesh.png').writeAsBytesSync(result.png);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a file that is not an asset gives nothing', () async {
      final text = File('${outside.path}/notes.lmas')..writeAsStringSync('not an asset');
      expect(await service.preview(text.path), isNull);
      expect(await service.preview('${outside.path}/missing.lmas'), isNull);
    });
  });

  test('the command line writes an .lmas preview at most the asked size', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final mesh = pathOf(AssetType.filamesh, named: 'fuel_barrel_red');
    final before = _snapshot(mesh);
    final output = '${outside.path}/cli_mesh.png';
    final code = await ModelThumbnailCommand.run(ModelThumbnailRequest(input: mesh, output: output, size: 96), ibl: _studioIbl());
    expect(code, ModelThumbnailCommand.exitOk);
    final image = img.decodePng(File(output).readAsBytesSync())!;
    expect(image.width, lessThanOrEqualTo(96));
    expect(image.height, lessThanOrEqualTo(96));
    _expectUnchanged(mesh, before);
    final notAsset = File('${outside.path}/garbage.lmas')..writeAsStringSync('garbage');
    expect(await ModelThumbnailCommand.run(ModelThumbnailRequest(input: notAsset.path, output: '${outside.path}/x.png')),
        ModelThumbnailCommand.exitInput);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
