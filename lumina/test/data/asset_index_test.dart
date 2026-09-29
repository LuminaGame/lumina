import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// The project asset index — built off the UI isolate,
/// refreshed incrementally (stat only when nothing changed), persisted to
/// `.lumina/asset_index.json`, rebuilt when that file is corrupt — and the
/// scans that read it give what the old full-decode scans gave.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late String project;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_asset_index_');
    project = AssetProjectFixture.write(temp, count: 300);
  });

  tearDown(() {
    LuminaAssetIndex.close(project);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('300 assets: first build off-thread, an unchanged refresh only stats (< 150 ms), a touched file is the only one decoded', () async {
    final index = LuminaAssetIndex.open(project);
    // A real project's cold index (≥ 16 MB of .lmas) is summarised by the
    // isolate pool; this fixture is smaller, so ask for it explicitly.
    expect(LuminaAssetIndex.shouldSummarizeOffThread(1248 * 1024 * 1024), isTrue);
    expect(LuminaAssetIndex.shouldSummarizeOffThread(64 * 1024), isFalse);
    final first = await index.refresh(offThread: true);
    expect(first.added, hasLength(300));
    expect(index.lastRefreshStats.decoded, 300);
    expect(index.lastRefreshStats.offThread, isTrue);
    expect(index.file.existsSync(), isTrue, reason: 'persisted to .lumina/asset_index.json');

    // Warm refreshes: no file decoded, both the async and the sync path.
    final warm = await index.refresh();
    expect(warm.isEmpty, isTrue);
    expect(index.lastRefreshStats.decoded, 0);
    final sw = Stopwatch()..start();
    index.refreshSync();
    sw.stop();
    expect(index.lastRefreshStats.decoded, 0);
    expect(sw.elapsedMilliseconds, lessThan(150), reason: 'unchanged refresh of 300 assets: ${sw.elapsedMilliseconds} ms');

    // A fresh session reads the persisted index: still nothing decoded.
    LuminaAssetIndex.close(project);
    final reopened = LuminaAssetIndex.open(project);
    reopened.refreshSync();
    expect(reopened.lastRefreshStats.decoded, 0);
    expect(reopened.entries, hasLength(300));

    // Touch one .lmas: exactly that file is summarised again.
    final touched = reopened.byType(AssetType.filamat).first;
    final file = touched.file;
    final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
    file.writeAsBytesSync(LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      thumbnailPng: asset.thumbnailPng,
      rawMatSource: asset.rawMatSource,
      metadata: {...asset.metadata, 'baseColor': '#123456'},
    ).toProtoBufferBytes());
    file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
    final events = <AssetIndexChange>[];
    final sub = reopened.changes.listen(events.add);
    final change = await reopened.refresh();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(reopened.lastRefreshStats.decoded, 1);
    expect(change.changed, [touched.path]);
    expect(reopened.byPath(touched.path)!.summary.metadata['baseColor'], '#123456');
    expect(events.single.changed, [touched.path], reason: 'the change stream carries the incremental update');

    // A newer companion (.entity.glb) updates the entry without decoding it.
    final mesh = reopened.entries.firstWhere((e) => e.summary.companionModified.keys.any((k) => k.endsWith('.entity.glb')));
    final glb = File(mesh.absolutePath.replaceAll('.lmas', '.entity.glb'));
    final newer = DateTime.now().add(const Duration(minutes: 1));
    glb.setLastModifiedSync(newer);
    reopened.refreshSync();
    expect(reopened.lastRefreshStats.decoded, 0);
    expect(reopened.byPath(mesh.path)!.summary.companionModified['${mesh.baseName}.entity.glb'], newer.millisecondsSinceEpoch);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('delete and rename are picked up; a corrupt or older-format index file rebuilds itself', () async {
    final index = LuminaAssetIndex.open(project);
    await index.refresh(offThread: true);
    final victim = index.byType(AssetType.texture).first;
    final renamed = index.byType(AssetType.particle).first;
    File(victim.absolutePath).deleteSync();
    final newPath = renamed.absolutePath.replaceAll('PS_Sparks', 'PS_Embers');
    File(renamed.absolutePath).renameSync(newPath);
    final change = index.refreshSync();
    expect(change.removed, containsAll([victim.path, renamed.path]));
    expect(change.added, [index.relativePathOf(newPath)]);
    expect(index.lastRefreshStats.decoded, 1);
    expect(index.byPath(newPath)!.summary.assetId, renamed.summary.assetId);
    expect(index.entries, hasLength(299));

    for (final corrupt in ['{"format": 1, "entries": ', jsonEncode({'format': 0, 'entries': {}})]) {
      LuminaAssetIndex.close(project);
      index.file.writeAsStringSync(corrupt);
      final rebuilt = LuminaAssetIndex.open(project);
      rebuilt.refreshSync();
      expect(rebuilt.lastRefreshStats.decoded, 299, reason: 'rebuilt from $corrupt');
      expect(rebuilt.entries, hasLength(299));
      expect(jsonDecode(rebuilt.file.readAsStringSync())['format'], LuminaAssetIndex.formatVersion);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('content browser listing and Blueprint registry assets from the index equal the full-scan results', () async {
    // The content browser as it was: decode every .lmas.
    final full = <String, ({String id, AssetType type, Uint8List? thumb, List<String> refs})>{};
    for (final f in Directory('$project/contents').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.lmas'))) {
      final a = LuminaAsset.fromBytes(f.readAsBytesSync());
      final thumb = (a.thumbnailPng?.isNotEmpty ?? false) ? a.thumbnailPng : (a.type == AssetType.texture ? a.rawPayload : null);
      full[f.path.substring(project.length + 1).replaceAll(r'\', '/')] = (id: a.assetId, type: a.type, thumb: thumb, refs: [for (final r in a.references) r.assetPath]);
    }
    final listed = AssetRepository().scanProjectContents(project);
    expect(listed.map((a) => a.relativePath).toSet(), full.keys.toSet());
    for (final a in listed) {
      final expected = full[a.relativePath]!;
      expect(a.assetId, expected.id, reason: a.relativePath);
      expect(a.type, expected.type, reason: a.relativePath);
      expect(a.thumbnailBytes, expected.thumb == null ? isNull : orderedEquals(expected.thumb!), reason: a.relativePath);
      expect([for (final r in a.references) r.assetPath], expected.refs, reason: a.relativePath);
    }

    // Blueprint registry assets as a full decode computes them.
    final assets = LuminaProjectBlueprintAssets.scan(project);
    final expectedEnums = <String>[], expectedInterfaces = <String>[], expectedSaves = <String>[], expectedMontages = <String>[];
    final expectedClasses = <String>[], expectedParticles = <String>[];
    final paths = full.keys.toList()..sort();
    for (final rel in paths) {
      final a = LuminaAsset.fromBytes(File('$project/$rel').readAsBytesSync());
      if (a.type == AssetType.particle && a.metadata['particle_system'] != null) expectedParticles.add(rel);
      if (a.type != AssetType.actor || a.rawPayload == null) continue;
      final json = jsonDecode(utf8.decode(a.rawPayload!)) as Map<String, dynamic>;
      switch (luminaBlueprintDocumentKind(json)) {
        case 'enum':
          expectedEnums.add(rel);
        case 'interface':
          expectedInterfaces.add(rel);
        case 'savegame':
          expectedSaves.add(rel);
        case 'montage':
          expectedMontages.add(rel);
        case 'class':
          expectedClasses.add('$rel:${json['parentClass'] ?? 'LuminaActor'}');
      }
    }
    expect([for (final e in assets.enums) e.path], expectedEnums);
    expect([for (final e in assets.interfaces) e.path], expectedInterfaces);
    expect([for (final e in assets.saveGameClasses) e.path], expectedSaves);
    expect([for (final e in assets.montages) e.path], expectedMontages);
    expect([for (final p in assets.particleTemplates) p.path], expectedParticles);
    expect([for (final c in assets.classes) '${c.path}:${c.parentClass}'], expectedClasses);
    expect(assets.enums.first.document.values, ['Idle', 'Walk', 'Run']);
    expect(assets.particleTemplates.first.config['lifetime'], 1.5);

    // Off the UI isolate, the same result.
    final offThread = await LuminaProjectBlueprintAssets.scanAsync(project);
    expect(jsonEncode(offThread.toJson()), jsonEncode(assets.toJson()));

    // The index answers kind queries without payloads.
    final index = LuminaAssetIndex.open(project);
    expect([for (final e in index.blueprintDocuments('enum')) e.path], expectedEnums);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
