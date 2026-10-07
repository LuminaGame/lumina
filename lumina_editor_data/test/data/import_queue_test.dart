import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

/// Batch imports run through [ImportQueue] — staging and
/// conversion in a worker isolate, only the thumbnail painting and indexing
/// on this one — and write exactly what [AssetRepository.importExternalFile]
/// writes, one file after another.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Twenty real meshes from different Props kits (embedded textures,
  /// several materials, a multi-part prop).
  const meshes = [
    'Props/AC_units/ac_unit_a_300x300.glb',
    'Props/AC_units/aircon_small.glb',
    'Props/Access_cards/access_card_blue.glb',
    'Props/Antenaes/antenae_a.glb',
    'Props/Ash Trays/ashtrayblack_a.glb',
    'Props/Banana Bunch/banana_bunch_long.glb',
    'Props/Barbedwire_set/barbedwire_set_bend45.glb',
    'Props/Barrels/bent_barrel.glb',
    'Props/Barrels/dented_barrel.glb',
    'Props/Food Containers/applecrate_a.glb',
    'Props/Food Containers/coconutbucket.glb',
    'Props/gas_canisters/gas_canister_pile_a.glb',
    'Props/rain_gutters/gutter_100.glb',
    'Props/signs/weaponssign.glb',
    'Props/turnstile/turnstile_a.glb',
    'Props/apartment_door_mats/apartment_door_mat_a.glb',
    'Props/fishing_shop_sign/stinky_petes_sign.glb',
    'Props/supermarket_shelves/supermarket_shelves_a.glb',
    'Props/ceiling_pipe_cable_kit/ceiling_pipe_cable_kit_600x150_a.glb',
    'Props/Fishing_nets/fishing_net_crate_a.glb',
  ];

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_import_queue_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  List<String> sources() => [for (final m in meshes) '${SmokeArtifacts.testAssetsDir.path}/$m'];
  bool assetsPresent() => sources().every((s) => File(s).existsSync());

  String newProject(String name) {
    final dir = Directory('${temp.path}/$name/contents')..createSync(recursive: true);
    return dir.parent.path;
  }

  /// Every file under `contents/`: a `.lmas` as its decoded fields minus the
  /// random asset ids, anything else as its bytes.
  Map<String, Object?> snapshot(String project) {
    final out = <String, Object?>{};
    final root = Directory('$project/contents');
    for (final e in root.listSync(recursive: true)) {
      if (e is! File) continue;
      final rel = e.path.substring(project.length + 1);
      if (rel.endsWith('.lmas')) {
        final map = LuminaAsset.fromBytes(e.readAsBytesSync()).toMap()..remove('asset_id');
        map['references'] = [
          for (final r in map['references'] as List) Map<String, dynamic>.from(r as Map)..remove('asset_id'),
        ];
        out[rel] = jsonEncode(map);
      } else {
        out[rel] = base64Encode(e.readAsBytesSync());
      }
    }
    return out;
  }

  test('20 real meshes through the queue write exactly what a sequential import writes', () async {
    if (!assetsPresent()) return markTestSkipped('test-assets missing');
    final sequential = newProject('Sequential');
    final repo = AssetRepository();
    for (final s in sources()) {
      await repo.importExternalFile(projectPath: sequential, sourceFilePath: s);
    }

    final queued = newProject('Queued');
    final queue = ImportQueue(projectPath: queued);
    addTearDown(queue.dispose);
    final results = await queue.enqueue([for (final s in sources()) ImportRequest(sourcePath: s)]);
    expect(results.map((r) => r.stage), everyElement(ImportStage.done));

    final a = snapshot(sequential);
    final b = snapshot(queued);
    expect(b.keys.toSet(), a.keys.toSet(), reason: 'same files, same paths');
    expect(a.keys.where((k) => k.endsWith('.lmas')).length, greaterThanOrEqualTo(60),
        reason: 'meshes with their materials and textures');
    final differing = [
      for (final path in a.keys)
        if (b[path] != a[path]) path,
    ];
    expect(differing, isEmpty, reason: 'these differ between the queued and the sequential import');
    // The queue indexed what it wrote, file by file.
    final index = LuminaAssetIndex.open(queued);
    for (final path in a.keys.where((k) => k.endsWith('.lmas'))) {
      expect(index.byPath(path), isNotNull, reason: path);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('each file reports queued → converting → writing → thumbnail → done; the batch fraction is monotonic and ends at 1',
      () async {
    if (!assetsPresent()) return markTestSkipped('test-assets missing');
    final project = newProject('Progress');
    final thumbnailed = <String>[];
    final queue = ImportQueue(
      projectPath: project,
      thumbnailStep: (written) async {
        expect(written.result, isNotNull);
        expect(File(written.result!.lmasPath!).existsSync(), isTrue, reason: 'written before its thumbnail stage');
        thumbnailed.add(written.fileName);
      },
    );
    addTearDown(queue.dispose);
    final events = <ImportProgress>[];
    final sub = queue.progress.listen(events.add);
    final summaries = <ImportBatchSummary>[];
    final summarySub = queue.summaries.listen(summaries.add);
    await queue.enqueue([for (final s in sources()) ImportRequest(sourcePath: s)]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await summarySub.cancel();

    for (var i = 0; i < meshes.length; i++) {
      final stages = [for (final e in events) if (e.index == i) e.stage];
      expect(stages, [
        ImportStage.queued,
        ImportStage.converting,
        ImportStage.writing,
        ImportStage.thumbnail,
        ImportStage.done,
      ], reason: meshes[i]);
    }
    var last = 0.0;
    for (final e in events) {
      expect(e.overallFraction, greaterThanOrEqualTo(last - 1e-9), reason: '${e.fileName} ${e.stage}');
      last = e.overallFraction;
    }
    expect(events.last.overallFraction, closeTo(1.0, 1e-9));
    expect(thumbnailed, hasLength(meshes.length));
    final done = events.where((e) => e.stage == ImportStage.done).toList();
    expect(done.every((e) => e.assets.isNotEmpty && e.assets.any((a) => a.relativePath == e.result!.relativePath)), isTrue,
        reason: 'each finished file lists the assets it produced');
    expect(summaries.single.imported, meshes.length);
    expect(summaries.single.failed, 0);
    expect(queue.longestMainIsolateStep, lessThan(const Duration(milliseconds: 100)),
        reason: 'every UI-isolate step fits in a frame budget of 100 ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a truncated GLB fails with a readable error and the other 19 import', () async {
    if (!assetsPresent()) return markTestSkipped('test-assets missing');
    final project = newProject('Truncated');
    final whole = File(sources()[7]).readAsBytesSync();
    final truncated = File('${temp.path}/SM_Truncated.glb')..writeAsBytesSync(whole.sublist(0, whole.length ~/ 2));
    final batch = [...sources()]..[7] = truncated.path;

    final logs = <EngineLogEntry>[];
    final logSub = EngineLoggerService().logStream.listen(logs.add);
    addTearDown(logSub.cancel);
    final queue = ImportQueue(projectPath: project);
    addTearDown(queue.dispose);
    final results = await queue.enqueue([for (final s in batch) ImportRequest(sourcePath: s)]);

    expect(results[7].stage, ImportStage.failed);
    expect(results[7].error, allOf(contains('SM_Truncated.glb'), contains('truncated')));
    expect(results[7].error, isNot(startsWith('FormatException')));
    expect(results.where((r) => r.stage == ImportStage.done), hasLength(19));
    expect(File('$project/contents/meshes/static/SM_Truncated.lmas').existsSync(), isFalse);
    expect(Directory('$project/temp').listSync().whereType<File>().where((f) => f.path.endsWith('SM_Truncated.glb')), isEmpty,
        reason: 'the staged copy is cleaned up');
    expect(logs.any((l) => l.level == 'error' && l.message.contains('SM_Truncated.glb')), isTrue,
        reason: 'the failure is in the Output Log');
    expect(queue.lastSummary!.errors.keys, ['SM_Truncated.glb']);

    // A direct import says the same.
    await expectLater(
      AssetRepository().importExternalFile(projectPath: project, sourceFilePath: truncated.path),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('truncated'))),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('cancel during file 5 finishes file 5, skips 6–20: 5 imported, 15 cancelled', () async {
    if (!assetsPresent()) return markTestSkipped('test-assets missing');
    final project = newProject('Cancel');
    final queue = ImportQueue(projectPath: project);
    addTearDown(queue.dispose);
    final sub = queue.progress.listen((e) {
      if (e.index == 4 && e.stage == ImportStage.converting) queue.cancel();
    });
    addTearDown(sub.cancel);
    final results = await queue.enqueue([for (final s in sources()) ImportRequest(sourcePath: s)]);

    expect([for (final r in results.take(5)) r.stage], everyElement(ImportStage.done));
    expect([for (final r in results.skip(5)) r.stage], everyElement(ImportStage.cancelled));
    expect(queue.imported, 5);
    expect(queue.cancelled, 15);
    expect(queue.lastSummary!.imported, 5);
    expect(queue.lastSummary!.cancelled, 15);
    expect(File(results[4].result!.lmasPath!).existsSync(), isTrue, reason: 'file 5 was kept');
    final written = Directory('$project/contents/meshes/static').listSync().where((e) => e.path.endsWith('.lmas'));
    expect(written, hasLength(5));

    // The queue takes a new batch afterwards.
    final again = await queue.enqueue([ImportRequest(sourcePath: sources()[5])]);
    expect(again.single.stage, ImportStage.done);
    expect(again.single.batch, results.first.batch + 1);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the index takes just the new paths: refreshPaths adds them and broadcasts the change', () async {
    if (!assetsPresent()) return markTestSkipped('test-assets missing');
    final project = newProject('Index');
    final index = LuminaAssetIndex.open(project);
    addTearDown(() => LuminaAssetIndex.close(project));
    index.refreshSync();
    final changes = <AssetIndexChange>[];
    final sub = index.changes.listen(changes.add);
    addTearDown(sub.cancel);
    final written = await AssetRepository().prepareImport(projectPath: project, sourceFilePath: sources()[0]).then(
          (p) => AssetRepository().writeImport(p),
        );
    final infos = AssetRepository().indexAndDescribe(project, written.writtenPaths);
    await Future<void>.delayed(Duration.zero);
    expect(infos.map((i) => i.relativePath), unorderedEquals(written.writtenPaths));
    expect(changes.single.added, unorderedEquals(written.writtenPaths));
    final mesh = infos.firstWhere((i) => i.type == AssetType.filamesh);
    expect(mesh.assetId, isNotEmpty);
    expect(index.byPath(mesh.relativePath)!.summary.companionModified.keys, contains('ac_unit_a_300x300.entity.glb'));
    // A full refresh afterwards finds nothing new.
    expect(index.refreshSync().isEmpty, isTrue);
  });
}
