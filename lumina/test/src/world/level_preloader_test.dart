import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../blueprint/level_load_fixture.dart';

/// LuminaLevelPreloader preloads a real project level found
/// through the asset index, one progress update per asset, and pins what it
/// loaded until the level is switched to or released.
void main() {
  late Directory project;
  late String dir;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lvl_preloader_');
    dir = project.resolveSymbolicLinksSync();
    writeLevelLoadProject(dir, broken: true);
  });
  tearDown(() {
    LuminaAssetIndex.close(dir);
    project.deleteSync(recursive: true);
  });

  ({LuminaLevelPreloader preloader, List<String> reads}) preloaderFor({int maxConcurrent = 4, Future<void>? gate}) {
    final reads = <String>[];
    final preloader = LuminaLevelPreloader(
      manifestResolver: (name) => LuminaLevelAssetManifest.forProjectLevel(dir, name),
      maxConcurrent: maxConcurrent,
      assetProvider: (path) async {
        reads.add(path);
        if (gate != null) await gate;
        return File(path).readAsBytes();
      },
    );
    return (preloader: preloader, reads: reads);
  }

  test('the manifest of L_Second names its six assets, the placed Blueprint and its component mesh included', () async {
    final refs = await LuminaLevelAssetManifest.forProjectLevel(dir, 'L_Second');
    expect(refs, isNotNull);
    expect([for (final r in refs!) r.path], [for (final a in levelSecondAssets) '$dir/$a']);
    expect({for (final r in refs) r.path.split('/').last: r.kind}, {
      'ac_unit_b_600x600.glb': LuminaAssetKind.mesh,
      'dented_barrel.glb': LuminaAssetKind.mesh,
      'BP_Crate.lmas': LuminaAssetKind.blueprint,
      'fuel_barrel_red.glb': LuminaAssetKind.mesh,
      'chime.wav': LuminaAssetKind.sound,
      'sky.png': LuminaAssetKind.texture,
    });
    expect(await LuminaLevelAssetManifest.forProjectLevel(dir, 'L_Nowhere'), isNull);
    final index = LuminaAssetIndex.open(dir);
    expect(LuminaLevelAssetManifest.levelNames(index)..sort(), ['L_Broken', 'L_First', 'L_Second']);
    expect(LuminaLevelAssetManifest.levelPath(index, 'L_Second.lmas'), levelSecondPath);
  });

  test('preloading L_Second emits one update per asset with percent 16.7…100, Total 6, Loaded 1…6, the asset name, then Success',
      () async {
    final (:preloader, :reads) = preloaderFor();
    final updates = await preloader.preload('L_Second').toList();
    expect(updates, hasLength(7));
    final progress = updates.take(6).toList();
    expect(progress.every((u) => !u.done && !u.hasError), isTrue);
    expect([for (final u in progress) u.total], List.filled(6, 6));
    expect([for (final u in progress) u.loaded], [1, 2, 3, 4, 5, 6]);
    expect([for (final u in progress) u.percent.toStringAsFixed(1)], ['16.7', '33.3', '50.0', '66.7', '83.3', '100.0']);
    expect({for (final u in progress) u.current},
        {'ac_unit_b_600x600', 'dented_barrel', 'BP_Crate', 'fuel_barrel_red', 'chime', 'sky'});
    final success = updates.last;
    expect(success.done, isTrue);
    expect(success.percent, 100.0);
    expect(success.hasError, isFalse);
    expect(preloader.isLoaded('L_Second'), isTrue);
    expect(reads.toSet(), {for (final a in levelSecondAssets) '$dir/$a'}, reason: 'each asset read once');
    expect(reads, hasLength(6));

    // Pinned: the level's components are served the bytes without a read.
    final served = await LuminaAssets.resolve((path) => throw StateError('read $path'))('$dir/$chimePath');
    expect(served, File('$dir/$chimePath').readAsBytesSync());
    expect(LuminaAssets.isResident('$dir/$skyPath'), isTrue);

    // A late listener gets the whole history.
    final replay = await preloader.preload('L_Second').toList();
    expect(replay.length, 7);
    expect(reads, hasLength(6), reason: 'a preloaded level is not loaded again');

    preloader.release('L_Second');
    expect(preloader.isLoaded('L_Second'), isFalse);
    expect(LuminaAssets.isResident('$dir/$skyPath'), isFalse, reason: 'released');
  });

  test('a level naming a missing mesh emits Error with the asset path and a stack trace, and never Success', () async {
    final (:preloader, reads: _) = preloaderFor(maxConcurrent: 1);
    final updates = await preloader.preload('L_Broken').toList();
    expect(updates.where((u) => u.done), isEmpty);
    final error = updates.last;
    expect(error.hasError, isTrue);
    expect('${error.error}', contains('$dir/$missingMeshPath'));
    expect('${error.stackTrace}', isNotEmpty);
    expect(error.total, 2);
    expect(preloader.isLoaded('L_Broken'), isFalse);
    expect(LuminaAssets.isResident('$dir/$acUnitPath'), isFalse, reason: 'an abandoned load is released');
    await expectLater(preloader.ensureLoaded('L_Broken'), throwsA(isA<Exception>()));

    final unknown = await preloader.preload('L_Nowhere').toList();
    expect(unknown.single.hasError, isTrue);
    expect('${unknown.single.error}', contains("no level named 'L_Nowhere'"));
  });

  test('cancel stops the preload: nothing more is sent and nothing stays pinned', () async {
    final gate = Completer<void>();
    final (:preloader, :reads) = preloaderFor(maxConcurrent: 1, gate: gate.future);
    final seen = <LuminaLevelLoadProgress>[];
    final closed = Completer<void>();
    preloader.preload('L_Second').listen(seen.add, onDone: closed.complete);
    await pumpEventQueue();
    expect(preloader.isLoading('L_Second'), isTrue);
    expect(reads, hasLength(1), reason: 'one at a time, the first still reading');
    preloader.cancel('L_Second');
    gate.complete();
    await closed.future;
    await pumpEventQueue();
    expect(seen, isEmpty);
    expect(reads, hasLength(1), reason: 'nothing more is read after cancel');
    expect(preloader.isLoading('L_Second'), isFalse);
    expect(preloader.isLoaded('L_Second'), isFalse);
    expect(LuminaAssets.isResident('$dir/$acUnitPath'), isFalse);
  });

  test('changeLevel swaps once the level is resident, then hands the assets over and releases them', () async {
    final (:preloader, :reads) = preloaderFor();
    await preloader.ensureLoaded('L_Second');
    expect(reads, hasLength(6));
    var swapped = false;
    final servedDuringSwap = <String, Uint8List>{};
    await preloader.changeLevel('L_Second', () async {
      swapped = true;
      // What the new level's components read while it mounts.
      servedDuringSwap[acUnitPath] = await LuminaAssets.resolve(null)('$dir/$acUnitPath');
    });
    expect(swapped, isTrue);
    expect(reads, hasLength(6), reason: 'the switch loads nothing again');
    expect(servedDuringSwap[acUnitPath], File('$dir/$acUnitPath').readAsBytesSync());
    expect(preloader.isLoaded('L_Second'), isFalse, reason: 'handed over');

    // Not preloaded: changeLevel loads it first.
    reads.clear();
    await preloader.changeLevel('L_First', () async {
      expect(reads, hasLength(1), reason: 'L_First is loaded before the swap');
    });
  });
}
