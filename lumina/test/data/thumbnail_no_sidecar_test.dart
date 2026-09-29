import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// Thumbnails live only inside the `.lmas` — rendering one
/// never writes a `.thumbnails/` sidecar, its staleness is the stamp in
/// metadata against the `.lmas` / `.entity.glb` times — and the one-time
/// migration removes the sidecars older builds left, keeping every thumbnail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_thumb_nosidecar_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  List<Directory> sidecarDirs(String project) => [
        for (final e in Directory('$project/contents').listSync(recursive: true))
          if (e is Directory && e.path.replaceAll(r'\', '/').endsWith('/.thumbnails')) e,
      ];

  test('rendering a thumbnail writes only the .lmas; a mesh with a newer .entity.glb is rendered again', () async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final project = '${temp.path}/NoSidecar';
    for (final sub in ['meshes/static', 'materials', 'textures']) {
      Directory('$project/contents/$sub').createSync(recursive: true);
    }
    await AssetRepository().importExternalFile(projectPath: project, sourceFilePath: barrel.path);
    final renderer = FilamentThumbnailRenderer();
    addTearDown(renderer.dispose);
    final service = ThumbnailService(renderer: renderer);
    final assets = AssetRepository().scanProjectContents(project);
    final texture = assets.firstWhere((a) => a.type == AssetType.texture).lmasPath!;
    final mesh = assets.firstWhere((a) => a.type == AssetType.filamesh).lmasPath!;

    for (final path in [texture, mesh]) {
      final before = Directory('$project/contents').listSync(recursive: true).map((e) => e.path).toSet();
      final result = await service.generate(path);
      expect(result, isNotNull, reason: path);
      final after = Directory('$project/contents').listSync(recursive: true).map((e) => e.path).toSet();
      expect(after.difference(before), isEmpty, reason: 'no new file beside ${path.split('/').last}');
      expect(sidecarDirs(project), isEmpty);
      final stored = LuminaAsset.fromBytes(File(path).readAsBytesSync());
      expect(stored.thumbnailPng, orderedEquals(result!.png));
      final stamp = DateTime.parse(stored.metadata[ThumbnailService.assetModifiedKey]!);
      expect(File(path).lastModifiedSync().millisecondsSinceEpoch, stamp.millisecondsSinceEpoch);
      expect(service.isStale(path), isFalse);
      // New files keep the base64 fields last.
      final text = utf8.decode(File(path).readAsBytesSync().sublist(4));
      expect(text.indexOf('"metadata"'), lessThan(text.indexOf('"thumbnail_png"')));
    }

    // The index sees the current thumbnail too (what the content browser queues from).
    final info = AssetRepository().scanProjectContents(project).firstWhere((a) => a.lmasPath == mesh);
    expect(ThumbnailService.isStaleInfo(info), isFalse);

    final entity = File(mesh.replaceAll('.lmas', '.entity.glb'));
    expect(entity.existsSync(), isTrue, reason: 'an imported mesh keeps its .entity.glb');
    // Re-imported a moment after the thumbnail was rendered.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    entity.setLastModifiedSync(DateTime.now());
    final stale = AssetRepository().scanProjectContents(project).firstWhere((a) => a.lmasPath == mesh);
    expect(ThumbnailService.isStaleInfo(stale), isTrue, reason: 'a newer .entity.glb makes the thumbnail stale');
    expect(await service.generate(mesh), isNotNull, reason: 'rendered again');
    expect(service.isStale(mesh), isFalse);
    expect(sidecarDirs(project), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('migration removes every .thumbnails/, keeps all thumbnails visible and current, moves the cover, and is idempotent', () async {
    final project = AssetProjectFixture.write(temp, name: 'Sidecars', count: 60, withSidecars: true);
    addTearDown(() => LuminaAssetIndex.close(project));
    expect(sidecarDirs(project), isNotEmpty);
    final sidecarOnly = <String>[];
    final current = <String>[];
    for (final dir in sidecarDirs(project)) {
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name == 'cover.png') continue;
        final folder = dir.parent.path.substring(project.length + 1).replaceAll(r'\', '/');
        final lmas = '$project/$folder/${name.replaceAll('.png', '.lmas')}';
        final summary = LuminaAsset.readSummary(File(lmas));
        (summary.hasThumbnailBytes ? current : sidecarOnly).add(lmas);
      }
    }
    expect(sidecarOnly, isNotEmpty);
    // Under the new rule, before migration, an old thumbnail reads as stale
    // (the .lmas is newer than its stamp).
    final rendered = current.firstWhere((p) => p.contains('/meshes/'));
    final info0 = AssetRepository().scanProjectContents(project).firstWhere((a) => a.lmasPath == rendered);
    expect(ThumbnailService.isStaleInfo(info0), isTrue);

    final repo = ProjectRepository(configDir: Directory('${temp.path}/config')..createSync());
    final report = await repo.migrateThumbnailSidecars(project);
    expect(sidecarDirs(project), isEmpty);
    expect(report.removedDirectories, greaterThan(0));
    expect(report.reembedded, sidecarOnly.length);
    expect(report.restamped, greaterThan(0));
    expect(report.coverMoved, isTrue);
    expect(File('$project/.lumina/cover.png').existsSync(), isTrue);
    expect(File('$project/contents/.thumbnails/cover.png').existsSync(), isFalse);
    expect(ProjectRepository.coverImageFile(project)!.path, '$project/.lumina/cover.png');
    final gitignore = File('$project/.gitignore').readAsStringSync();
    expect(gitignore, contains('.lumina/'));
    expect(gitignore, contains('**/.thumbnails/'));

    final scanned = AssetRepository().scanProjectContents(project);
    expect(scanned, hasLength(60));
    for (final a in scanned) {
      expect(a.thumbnailBytes, isNotNull, reason: '${a.relativePath} still shows its thumbnail');
    }
    for (final p in sidecarOnly) {
      expect(LuminaAsset.fromBytes(File(p).readAsBytesSync()).thumbnailPng, isNotNull, reason: '$p re-embedded');
    }
    // Thumbnails current before the migration are current after it (nothing re-renders).
    for (final p in current) {
      final info = scanned.firstWhere((a) => a.lmasPath == p);
      expect(ThumbnailService.isStaleInfo(info), isFalse, reason: '$p stays current');
    }

    final again = await repo.migrateThumbnailSidecars(project);
    expect(again.didAnything, isFalse, reason: 'idempotent');
    expect(File('$project/.gitignore').readAsStringSync(), gitignore);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
