import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The Content Browser's Migrate: copy an asset and its
/// dependency closure into another project, `contents/`-relative layout and
/// asset ids preserved, conflicts reported and never overwritten. A real
/// barrel from test-assets, imported into a real temp project.
void main() {
  final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
  late Directory source;
  late Directory target;
  late AssetRepository repo;

  Directory project(String name) {
    final dir = Directory.systemTemp.createTempSync('lumina_migrate_$name');
    Directory('${dir.path}/contents').createSync();
    File('${dir.path}/$name.lmproject').writeAsStringSync('{"projectName": "$name"}');
    return dir;
  }

  setUp(() {
    source = project('Source');
    target = project('Target');
    repo = AssetRepository();
  });

  tearDown(() {
    for (final d in [source, target]) {
      try {
        d.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('the closure is copied with its layout and ids; a second run reports every file as a conflict', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets not present');
    await repo.importExternalFile(projectPath: source.path, sourceFilePath: barrel.path);
    final assets = repo.scanProjectContents(source.path);
    final graph = AssetReferenceGraph()..build(assets);
    final mesh = assets.firstWhere((a) => a.type == AssetType.filamesh);
    final closure = graph.dependencyClosure(mesh.assetId!);
    expect(closure.length, greaterThan(1), reason: 'the mesh references its material(s)');

    final preview = repo.migratePreview(source.path, mesh.lmasPath!, target.path, graph);
    final lmas = preview.where((e) => e.relativePath.endsWith('.lmas')).toList();
    expect(lmas, hasLength(closure.length));
    expect(preview.every((e) => !e.conflict && !e.copied), isTrue);
    expect(preview.every((e) => e.bytes > 0), isTrue);

    final report = repo.migrateAsset(source.path, mesh.lmasPath!, target.path, graph);
    expect(report.every((e) => e.copied), isTrue);
    for (final e in report) {
      final copied = File('${target.path}/${e.relativePath}');
      expect(copied.existsSync(), isTrue, reason: e.relativePath);
      expect(copied.lengthSync(), File('${source.path}/${e.relativePath}').lengthSync());
    }
    // Every copied reference resolves inside the target project, by id.
    final targetAssets = repo.scanProjectContents(target.path);
    final targetGraph = AssetReferenceGraph()..build(targetAssets);
    final copiedMesh = targetAssets.firstWhere((a) => a.relativePath == mesh.relativePath);
    expect(copiedMesh.assetId, mesh.assetId);
    for (final ref in copiedMesh.references) {
      final resolved = targetGraph.resolve(ref);
      expect(resolved.broken, isFalse, reason: ref.assetPath);
      expect(resolved.resolvedPath, ref.assetPath);
    }

    final again = repo.migrateAsset(source.path, mesh.lmasPath!, target.path, graph);
    expect(again, hasLength(report.length));
    expect(again.every((e) => e.conflict && !e.copied), isTrue, reason: 'nothing is overwritten');
  });

  test('a target that is not a project, or the source project itself, is refused', () async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets not present');
    await repo.importExternalFile(projectPath: source.path, sourceFilePath: barrel.path);
    final assets = repo.scanProjectContents(source.path);
    final graph = AssetReferenceGraph()..build(assets);
    final mesh = assets.firstWhere((a) => a.type == AssetType.filamesh);
    final plain = Directory.systemTemp.createTempSync('lumina_migrate_plain_');
    addTearDown(() => plain.deleteSync(recursive: true));
    expect(() => repo.migratePreview(source.path, mesh.lmasPath!, plain.path, graph),
        throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'message', contains('.lmproject'))));
    expect(() => repo.migratePreview(source.path, mesh.lmasPath!, source.path, graph),
        throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'message', contains('same project'))));
  });
}
