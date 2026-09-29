import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// The pipeline steps a folder import leans on — one
/// shared format table, a `.gltf` with its `.bin` and images packed into a
/// self-contained GLB, TGA textures, `.lmas` copies and renamed imports.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_import_folder_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String newProject(String name) => (Directory('${temp.path}/$name/contents')..createSync(recursive: true)).parent.path;
  bool isGlb(List<int>? b) => b != null && b.length > 12 && b[0] == 0x67 && b[1] == 0x6C && b[2] == 0x54 && b[3] == 0x46;
  bool isPng(List<int>? b) => b != null && b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

  test('the format table classifies what the picker offers and explains the rest', () {
    expect(ImportFormats.extensions, containsAll(['glb', 'gltf', 'obj', 'fbx', 'png', 'jpg', 'jpeg', 'webp', 'tga', 'wav', 'ogg', 'mp3', 'lmas']));
    expect(ImportFormats.kindOf('/a/B.GLB'), ImportFormatKind.mesh);
    expect(ImportFormats.kindOf('x.tga'), ImportFormatKind.texture);
    expect(ImportFormats.kindOf('x.ogg'), ImportFormatKind.audio);
    expect(ImportFormats.kindOf('x.lmas'), ImportFormatKind.asset);
    expect(ImportFormats.kindOf('x.psd'), isNull);
    expect(ImportFormats.unsupportedReason('x.psd'), contains('Photoshop'));
    expect(ImportFormats.unsupportedReason('x.xyz'), 'unsupported file type .xyz');
    expect(ImportFormats.unsupportedReason('README'), 'no file extension');
  });

  test('a .gltf with an external .bin and image imports as a self-contained GLB with its texture', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final src = Directory('${temp.path}/src')..createSync();
    final glb = File('${SmokeArtifacts.testAssetsDir.path}/${ImportFolderFixture.splitSource}').readAsBytesSync();
    final image = ImportFolderFixture.unpackGlb(glb, src.path, 'lootbarrel_split');
    expect(image, isNotNull);
    final gltf = '${src.path}/lootbarrel_split.gltf';
    expect(GltfPacker.referencedFiles(gltf).map((f) => f.split('/').last), ['lootbarrel_split.bin', image!.name]);

    final project = newProject('P');
    final repo = AssetRepository();
    final info = await repo.importExternalFile(projectPath: project, sourceFilePath: gltf, targetSubFolder: 'contents/Imported', autoOrganize: false);
    expect(info.relativePath, 'contents/Imported/lootbarrel_split.lmas');
    final asset = LuminaAsset.fromBytes(File('$project/${info.relativePath}').readAsBytesSync());
    expect(asset.type, AssetType.filamesh);
    expect(isGlb(asset.rawPayload), isTrue, reason: 'the payload is a GLB, not the .gltf text');
    final doc = GlbDocument.parse(asset.rawPayload!, label: 'packed');
    expect(doc.json['buffers'], hasLength(1));
    expect((doc.json['buffers'] as List).first.containsKey('uri'), isFalse);
    expect((doc.json['images'] as List).every((i) => (i as Map).containsKey('bufferView') && !i.containsKey('uri')), isTrue);
    final textures = Directory('$project/contents/Imported/textures').listSync().whereType<File>().where((f) => f.path.endsWith('.lmas')).toList();
    expect(textures, isNotEmpty, reason: 'the external image became a texture asset');

    // The same mesh imported from the original GLB carries the same meshes.
    final ref = newProject('Ref');
    final refInfo = await repo.importExternalFile(
        projectPath: ref, sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${ImportFolderFixture.splitSource}', targetSubFolder: 'contents/Imported', autoOrganize: false);
    final refAsset = LuminaAsset.fromBytes(File('$ref/${refInfo.relativePath}').readAsBytesSync());
    final refDoc = GlbDocument.parse(refAsset.rawPayload!, label: 'ref');
    expect((doc.json['meshes'] as List).length, (refDoc.json['meshes'] as List).length);
    expect((doc.json['accessors'] as List).length, (refDoc.json['accessors'] as List).length);
    expect(Directory('$project/temp').listSync().whereType<File>(), isEmpty, reason: 'staging cleaned up');
  });

  test('a .gltf missing its .bin fails with a readable error', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final src = Directory('${temp.path}/src')..createSync();
    ImportFolderFixture.unpackGlb(File('${SmokeArtifacts.testAssetsDir.path}/${ImportFolderFixture.splitSource}').readAsBytesSync(), src.path, 'broken');
    File('${src.path}/broken.bin').deleteSync();
    await expectLater(
      AssetRepository().importExternalFile(projectPath: newProject('P'), sourceFilePath: '${src.path}/broken.gltf'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('broken.bin'))),
    );
  });

  test('a TGA imports as a PNG texture', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final fixture = ImportFolderFixture.build(temp);
    final project = newProject('P');
    final info = await AssetRepository().importExternalFile(
        projectPath: project, sourceFilePath: '${fixture.root}/Props/Textures/loot_barrel_bc.tga', targetSubFolder: 'contents/T', autoOrganize: false);
    expect(info.relativePath, 'contents/T/loot_barrel_bc.lmas');
    final asset = LuminaAsset.fromBytes(File('$project/${info.relativePath}').readAsBytesSync());
    expect(asset.type, AssetType.texture);
    expect(isPng(asset.rawPayload), isTrue);
  });

  // An auto-organized image import used to write the texture twice
  // (contents/textures/<name>.lmas and contents/<name>/<name>.lmas, two ids).
  test('an auto-organized PNG import writes exactly one texture .lmas, with its image beside it', () async {
    final source = File('${SmokeArtifacts.testAssetsDir.path}/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_T_Tread_Plate_Normal.png');
    if (!source.existsSync()) return markTestSkipped('test-assets missing');
    const name = 'SM_Slot_Machine_T_Tread_Plate_Normal';
    final project = newProject('P');
    final repo = AssetRepository();
    final written = await repo.writeImport(await repo.prepareImport(projectPath: project, sourceFilePath: source.path));
    expect(written.writtenPaths, ['contents/textures/$name.lmas']);
    expect(written.info.relativePath, 'contents/textures/$name.lmas');
    final onDisk = [
      for (final f in Directory('$project/contents').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.lmas')) f.path.substring(project.length + 1).replaceAll(r'\', '/'),
    ];
    expect(onDisk, ['contents/textures/$name.lmas']);
    final asset = LuminaAsset.fromBytes(File('$project/contents/textures/$name.lmas').readAsBytesSync());
    expect(asset.type, AssetType.texture);
    expect(isPng(asset.rawPayload), isTrue);
    expect(asset.thumbnailPng, isNotNull);
    expect(asset.metadata['source_file'], source.absolute.uri.toFilePath());
    expect(File('$project/contents/textures/$name.png').readAsBytesSync(), orderedEquals(asset.rawPayload!));
  });

  // The Texture editor's Reimport reads `source_file`.
  test('a texture import records the file it came from as source_file, directly and through the queue', () async {
    final source = File('${SmokeArtifacts.testAssetsDir.path}/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_T_Tread_Plate_Normal.png');
    if (!source.existsSync()) return markTestSkipped('test-assets missing');
    final project = newProject('P');
    final info = await AssetRepository().importExternalFile(projectPath: project, sourceFilePath: source.path, targetSubFolder: 'contents/T', autoOrganize: false);
    final asset = LuminaAsset.fromBytes(File('$project/${info.relativePath}').readAsBytesSync());
    expect(asset.type, AssetType.texture);
    expect(asset.metadata['source_file'], source.absolute.uri.toFilePath());

    // Auto-organized, the import writes the texture once, and it
    // remembers the source.
    final organized = newProject('O');
    final repo = AssetRepository();
    final written = await repo.writeImport(await repo.prepareImport(projectPath: organized, sourceFilePath: source.path));
    final lmasFiles = written.writtenPaths.where((p) => p.endsWith('.lmas')).toList();
    expect(lmasFiles, isNotEmpty);
    for (final p in lmasFiles) {
      expect(LuminaAsset.fromBytes(File('$organized/$p').readAsBytesSync()).metadata['source_file'], source.absolute.uri.toFilePath(), reason: p);
    }

    final queued = newProject('Q');
    final queue = ImportQueue(projectPath: queued, workers: 1);
    addTearDown(queue.dispose);
    final results = await queue.enqueue([ImportRequest(sourcePath: source.path, targetSubFolder: 'contents/T', autoOrganize: false)]);
    expect(results.single.stage, ImportStage.done, reason: results.single.error);
    final queuedAsset = LuminaAsset.fromBytes(File('$queued/${results.single.result!.relativePath}').readAsBytesSync());
    expect(queuedAsset.metadata['source_file'], source.absolute.uri.toFilePath());
    expect(File(queuedAsset.metadata['source_file']!).existsSync(), isTrue);
  });

  test('targetBaseName renames the import and its extracted assets', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final project = newProject('P');
    final repo = AssetRepository();
    final source = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/bent_barrel.glb';
    final first = await repo.importExternalFile(projectPath: project, sourceFilePath: source, targetSubFolder: 'contents/B', autoOrganize: false);
    final prepared = await repo.prepareImport(
        projectPath: project, sourceFilePath: source, targetSubFolder: 'contents/B', autoOrganize: false, targetBaseName: 'bent_barrel_1');
    final second = (await repo.writeImport(prepared)).info;
    expect(first.relativePath, 'contents/B/bent_barrel.lmas');
    expect(second.relativePath, 'contents/B/bent_barrel_1.lmas');
    final a = LuminaAsset.fromBytes(File('$project/${first.relativePath}').readAsBytesSync());
    final b = LuminaAsset.fromBytes(File('$project/${second.relativePath}').readAsBytesSync());
    expect(b.name, 'bent_barrel_1');
    expect(b.assetId, isNot(a.assetId));
    expect(b.rawPayload, a.rawPayload);
  });

  test('an .lmas imports as a copy; renamed, it becomes a new asset', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final repo = AssetRepository();
    final other = newProject('Other');
    final original = await repo.importExternalFile(
        projectPath: other, sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb', targetSubFolder: 'contents/X', autoOrganize: false);
    final lmas = '$other/${original.relativePath}';

    final project = newProject('P');
    final copy = await repo.importExternalFile(projectPath: project, sourceFilePath: lmas, targetSubFolder: 'contents/Copied', autoOrganize: false);
    expect(copy.relativePath, 'contents/Copied/dented_barrel.lmas');
    expect(copy.type, AssetType.filamesh);
    expect(File('$project/${copy.relativePath}').readAsBytesSync(), File(lmas).readAsBytesSync());

    final prepared = await repo.prepareImport(projectPath: project, sourceFilePath: lmas, targetSubFolder: 'contents/Copied', autoOrganize: false, targetBaseName: 'dented_barrel_1');
    final renamed = (await repo.writeImport(prepared)).info;
    final a = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
    final b = LuminaAsset.fromBytes(File('$project/${renamed.relativePath}').readAsBytesSync());
    expect(renamed.relativePath, 'contents/Copied/dented_barrel_1.lmas');
    expect(b.name, 'dented_barrel_1');
    expect(b.assetId, isNot(a.assetId));
    expect(b.rawPayload, a.rawPayload);
  });

  test('the queue imports a renamed request and an .lmas copy in a worker', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final project = newProject('P');
    final source = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/bent_barrel.glb';
    final queue = ImportQueue(projectPath: project, workers: 1);
    addTearDown(queue.dispose);
    final results = await queue.enqueue([
      ImportRequest(sourcePath: source, targetSubFolder: 'contents/Q', autoOrganize: false),
      ImportRequest(sourcePath: source, targetSubFolder: 'contents/Q', autoOrganize: false, targetBaseName: 'bent_barrel_1'),
    ]);
    expect(results.map((r) => r.stage), everyElement(ImportStage.done));
    expect(results.map((r) => r.result!.relativePath), ['contents/Q/bent_barrel.lmas', 'contents/Q/bent_barrel_1.lmas']);
    final copy = await queue.enqueue([
      ImportRequest(sourcePath: '$project/contents/Q/bent_barrel.lmas', targetSubFolder: 'contents/R', autoOrganize: false),
    ]);
    expect(copy.single.stage, ImportStage.done, reason: copy.single.error);
    expect(File('$project/contents/R/bent_barrel.lmas').existsSync(), isTrue);
  });
}
