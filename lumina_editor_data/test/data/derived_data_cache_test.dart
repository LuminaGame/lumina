import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../helpers/oversized_glb_fixture.dart';

/// The texture-budgeted GLB is persisted under the project's
/// `DerivedDataCache/`, so a later editor session loads it instead of
/// decoding and downscaling every oversized texture again.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final barrelFile = File('$assets/Props/Barrels/dented_barrel.glb');
  final bananaFile = File('$assets/Props/Banana Bunch/banana_bunch_long.glb');
  final cardFile = File('$assets/Props/Access_cards/access_card_blue.glb');
  final missing = [barrelFile, bananaFile, cardFile].where((f) => !f.existsSync()).map((f) => f.path).toList();
  final skip = missing.isEmpty ? null : 'test-assets missing: ${missing.join(', ')}';

  late Uint8List barrel8k;
  late Uint8List barrel8kTinted;
  late Uint8List barrel4k;
  late Directory temp;
  late List<EngineLogEntry> logs;
  late StreamSubscription<EngineLogEntry> logSub;

  setUpAll(() {
    if (skip != null) return;
    final source = barrelFile.readAsBytesSync();
    barrel8k = oversizedGlbFromTestAsset(source);
    barrel8kTinted = oversizedGlbFromTestAsset(source, tint: const [1.0, 0.55, 0.35]);
    barrel4k = oversizedGlbFromTestAsset(source, longEdge: 4096);
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_ddc_test_');
    AssetRepository.clearSanitizedGlbCache();
    logs = [];
    logSub = EngineLoggerService().logStream.listen(logs.add);
  });

  tearDown(() async {
    await logSub.cancel();
    AssetRepository.clearSanitizedGlbCache();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  List<String> ddcLines() => [for (final e in logs) if (e.source == 'DerivedDataCache') '[${e.level}] ${e.message}'];

  group('DerivedDataCache: the sanitized GLB across editor sessions', () {
    test('the first load builds the entry; a fresh-isolate session and a cleared memo load it without decoding a texture', () async {
      final project = writeTempProject(temp, 'ddc_first_load');
      final lmas = writeMeshAsset(project, 'SM_DentedBarrel_8K', barrel8k);
      expect(embeddedPngSizes(barrel8k), contains((8192, 4096)), reason: 'the fixture carries a genuinely oversized texture');

      // Both sessions time a warm editor loading this mesh, not the isolate's
      // first mesh parse (native Draco decoder lookup, static initialisers).
      await AssetRepository.loadMeshFromDisk(barrelFile.path);
      final conversionsBefore = GlbParserService.decodingConversionCount;
      final firstWatch = Stopwatch()..start();
      final first = await AssetRepository.loadMeshFromDisk(lmas);
      firstWatch.stop();
      expect(first, isNotNull);
      expect(GlbParserService.decodingConversionCount, conversionsBefore + 1, reason: 'a miss runs the downscale once');

      final cache = DerivedDataCache(project.path);
      expect(cache.directory.path, '${project.path}/DerivedDataCache');
      final entries = cache.entries();
      expect(entries, hasLength(1));
      final header = DerivedDataCache.readEntryHeader(entries.single)!;
      expect(header.key, endsWith('_b2048_v${GlbParserService.sanitizerVersion}'));
      expect(header.sourceBytes, barrel8k.length);
      final stored = (await cache.get(DerivedDataCache.sanitizedGlbBucket, header.key))!;
      expect(embeddedPngSizes(stored), contains((2048, 1024)), reason: 'the entry holds the budgeted texture');
      expect(stored.length, lessThan(barrel8k.length));

      final miss = ddcLines().where((l) => l.contains('DDC miss')).toList();
      expect(miss, hasLength(1), reason: ddcLines().join('\n'));
      expect(miss.single, allOf(contains('SM_DentedBarrel_8K'), contains('MB'), contains(' s')));

      // A new editor session: a fresh isolate has its own statics, so its
      // memo is empty and its converter counter starts at zero.
      final second = await _loadInFreshSession(lmas);
      expect(second.vertexCount, first!.vertexCount);
      expect(second.conversions, 0, reason: 'the cached session must not decode a texture:\n${second.logs.join('\n')}');
      expect(second.logs.where((l) => l.contains('DDC hit')), hasLength(1), reason: second.logs.join('\n'));
      expect(second.logs.firstWhere((l) => l.contains('DDC hit')), allOf(contains('MB'), contains('ms')));

      // The editor's own isolate after the memo is dropped: the DDC answers,
      // and the load is timed where the editor runs it (a background isolate
      // has no dart:ui, so parseGlb's texture decode there is not
      // representative).
      AssetRepository.clearSanitizedGlbCache();
      final thirdWatch = Stopwatch()..start();
      final third = await AssetRepository.loadMeshFromDisk(lmas);
      thirdWatch.stop();
      expect(third!.vertexCount, first.vertexCount);
      expect(GlbParserService.decodingConversionCount, conversionsBefore + 1);
      expect(ddcLines().where((l) => l.contains('DDC hit')), hasLength(1));
      expect(thirdWatch.elapsedMicroseconds, lessThan(firstWatch.elapsedMicroseconds ~/ 3),
          reason: 'first load ${firstWatch.elapsedMilliseconds} ms, cached load ${thirdWatch.elapsedMilliseconds} ms');
      // ignore: avoid_print
      print('[derived_data] first load ${firstWatch.elapsedMilliseconds} ms (miss), '
          'fresh-isolate session ${second.micros ~/ 1000} ms (hit, no conversion), '
          'memo-cleared load ${thirdWatch.elapsedMilliseconds} ms (hit), entry ${stored.length} B');
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('a changed source misses and rebuilds under a new key', () async {
      final project = writeTempProject(temp, 'ddc_source_change');
      final lmas = writeMeshAsset(project, 'SM_DentedBarrel_8K', barrel8k);
      final before = GlbParserService.decodingConversionCount;
      await AssetRepository.loadMeshFromDisk(lmas);

      // The artist re-exports the texture: same path, new bytes.
      writeMeshAsset(project, 'SM_DentedBarrel_8K', barrel8kTinted);
      AssetRepository.clearSanitizedGlbCache();
      await AssetRepository.loadMeshFromDisk(lmas);

      expect(GlbParserService.decodingConversionCount, before + 2);
      final keys = DerivedDataCache(project.path).entries().map((f) => DerivedDataCache.readEntryHeader(f)!.key).toSet();
      expect(keys, hasLength(2));
      expect(ddcLines().where((l) => l.contains('DDC miss')), hasLength(2));
      expect(ddcLines().where((l) => l.contains('DDC hit')), isEmpty);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('a different texture budget or converter version is a different key', () async {
      final project = writeTempProject(temp, 'ddc_budget_version');
      final cache = DerivedDataCache(project.path);
      final sha = DerivedDataCache.sha256Hex(barrel4k);
      final key = DerivedDataCache.sanitizedGlbKey(sha, 2048);
      expect(key, '${sha}_b2048_v${GlbParserService.sanitizerVersion}');
      expect(DerivedDataCache.sanitizedGlbKey(sha, 1024), isNot(key));
      expect(DerivedDataCache.sanitizedGlbKey(sha, 2048, converterVersion: GlbParserService.sanitizerVersion + 1), isNot(key));

      final before = GlbParserService.decodingConversionCount;
      final at2048 = await cache.sanitizedGlb(barrel4k, label: 'barrel_4k.glb');
      final at1024 = await cache.sanitizedGlb(barrel4k, maxTextureSize: 1024, label: 'barrel_4k.glb');
      expect(GlbParserService.decodingConversionCount, before + 2);
      expect(embeddedPngSizes(at2048), contains((2048, 1024)));
      expect(embeddedPngSizes(at1024), contains((1024, 512)));
      expect(cache.entries(), hasLength(2));

      // Derived data written by another converter version is never used.
      final other = DerivedDataCache(writeTempProject(temp, 'ddc_other_version').path);
      await other.put(DerivedDataCache.sanitizedGlbBucket,
          DerivedDataCache.sanitizedGlbKey(sha, 2048, converterVersion: GlbParserService.sanitizerVersion + 1), at2048);
      await other.sanitizedGlb(barrel4k, label: 'barrel_4k.glb');
      expect(GlbParserService.decodingConversionCount, before + 3);
      expect(other.entries(), hasLength(2));
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('a truncated or bit-flipped entry is detected, logged, discarded and rebuilt', () async {
      final project = writeTempProject(temp, 'ddc_corrupt');
      final cache = DerivedDataCache(project.path);
      final good = await cache.sanitizedGlb(barrel4k, label: 'barrel_4k.glb');
      final entry = cache.entries().single;
      final before = GlbParserService.decodingConversionCount;

      final bytes = entry.readAsBytesSync();
      entry.writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
      final afterTruncation = await cache.sanitizedGlb(barrel4k, label: 'barrel_4k.glb');
      expect(afterTruncation, good);
      expect(GlbParserService.decodingConversionCount, before + 1);
      expect(ddcLines().where((l) => l.startsWith('[warning]') && l.contains('truncated')), hasLength(1), reason: ddcLines().join('\n'));
      expect(cache.entries().single.lengthSync(), bytes.length, reason: 'the rebuilt entry replaces the truncated one');

      final flipped = cache.entries().single.readAsBytesSync();
      flipped[flipped.length - 100] ^= 0xFF;
      cache.entries().single.writeAsBytesSync(flipped);
      final afterFlip = await cache.sanitizedGlb(barrel4k, label: 'barrel_4k.glb');
      expect(afterFlip, good);
      expect(GlbParserService.decodingConversionCount, before + 2);
      expect(ddcLines().where((l) => l.startsWith('[warning]') && l.contains('hash mismatch')), hasLength(1), reason: ddcLines().join('\n'));
      expect(await cache.get(DerivedDataCache.sanitizedGlbBucket, DerivedDataCache.readEntryHeader(cache.entries().single)!.key), good);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('the size bound evicts the least recently used entry', () async {
      final project = writeTempProject(temp, 'ddc_bound');
      final a = barrelFile.readAsBytesSync();
      final b = bananaFile.readAsBytesSync();
      final c = cardFile.readAsBytesSync();
      // Room for any two of the three, never all three.
      final cache = DerivedDataCache(project.path, maxBytes: a.length + b.length + 2048);
      const bucket = DerivedDataCache.sanitizedGlbBucket;
      await cache.put(bucket, 'a', a, label: 'dented_barrel.glb');
      await cache.put(bucket, 'b', b, label: 'banana_bunch_long.glb');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await cache.get(bucket, 'a'), a, reason: 'a hit makes the barrel the most recently used');
      await cache.put(bucket, 'c', c, label: 'access_card_blue.glb');

      expect(await cache.get(bucket, 'b'), isNull, reason: 'the banana was least recently used');
      expect(await cache.get(bucket, 'a'), a);
      expect(await cache.get(bucket, 'c'), c);
      expect(cache.usage().bytes, lessThanOrEqualTo(cache.maxBytes));
      expect(ddcLines().where((l) => l.contains('evicted 1 entry')), hasLength(1), reason: ddcLines().join('\n'));
    }, skip: skip);

    test('clear() removes every entry and reports what it freed', () async {
      final project = writeTempProject(temp, 'ddc_clear');
      final cache = DerivedDataCache(project.path);
      await cache.put(DerivedDataCache.sanitizedGlbBucket, 'a', barrelFile.readAsBytesSync());
      await cache.put(DerivedDataCache.sanitizedGlbBucket, 'b', bananaFile.readAsBytesSync());
      final before = cache.usage();
      expect(before.entries, 2);

      final freed = await cache.clear();
      expect(freed.entries, 2);
      expect(freed.bytes, before.bytes);
      expect(cache.entries(), isEmpty);
      expect(cache.usage().bytes, 0);
      expect(ddcLines().where((l) => l.contains('Cleared') && l.contains('2 entries')), hasLength(1), reason: ddcLines().join('\n'));
    }, skip: skip);

    test('in-budget and external-image sources are converted but never persisted', () async {
      final project = writeTempProject(temp, 'ddc_not_cached');
      final cache = DerivedDataCache(project.path);
      final source = barrelFile.readAsBytesSync();

      // The real barrel (512 px WebP) and a 1024 px PNG variant fit the budget.
      await cache.sanitizedGlb(source, label: 'dented_barrel.glb');
      await cache.sanitizedGlb(oversizedGlbFromTestAsset(source, longEdge: 1024), label: 'barrel_1k.glb');
      expect(cache.entries(), isEmpty);

      // An image referenced by uri depends on a file the key does not cover.
      final dir = Directory('${project.path}/contents/meshes/static');
      final external = oversizedGlbFromTestAsset(source, longEdge: 4096, externalImageName: 'barrel_basecolor.png', writeImageNextTo: dir);
      final before = GlbParserService.decodingConversionCount;
      final sanitized = await cache.sanitizedGlb(external, searchDirs: [dir.path], label: 'barrel_external.glb');
      expect(GlbParserService.decodingConversionCount, before + 1);
      expect(embeddedPngSizes(sanitized), contains((2048, 1024)), reason: 'still budgeted, just not persisted');
      expect(cache.entries(), isEmpty);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('an asset outside any project is converted without writing a cache anywhere', () async {
      final loose = Directory('${temp.path}/loose')..createSync();
      final glb = File('${loose.path}/barrel_4k.glb')..writeAsBytesSync(barrel4k);
      expect(DerivedDataCache.findProjectRoot(glb.path), isNull);
      final before = GlbParserService.decodingConversionCount;

      final mesh = await AssetRepository.loadMeshFromDisk(glb.path);
      expect(mesh, isNotNull);
      expect(GlbParserService.decodingConversionCount, before + 1);
      expect(temp.listSync(recursive: true).where((e) => e.path.contains('DerivedDataCache')), isEmpty);

      final project = writeTempProject(temp, 'ddc_root');
      expect(DerivedDataCache.findProjectRoot('${project.path}/contents/meshes/static/x.lmas'), project.path);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('concurrent loads of one mesh share a single conversion', () async {
      final project = writeTempProject(temp, 'ddc_in_flight');
      final lmas = writeMeshAsset(project, 'SM_DentedBarrel_4K', barrel4k);
      final before = GlbParserService.decodingConversionCount;
      final meshes = await Future.wait([
        AssetRepository.loadMeshFromDisk(lmas),
        AssetRepository.loadMeshFromDisk(lmas),
      ]);
      expect(meshes.every((m) => m != null), isTrue);
      expect(GlbParserService.decodingConversionCount, before + 1, reason: 'the second viewport waits for the first build');
      expect(DerivedDataCache(project.path).entries(), hasLength(1));
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('DerivedDataCache: kept out of git and out of the cooked game', () {
    test('ensureIgnoredBy adds DerivedDataCache/ to the project .gitignore once', () {
      final project = writeTempProject(temp, 'ddc_gitignore');
      final gitignore = File('${project.path}/.gitignore')..writeAsStringSync('# Flutter\n/build/\n.dart_tool/\n');
      expect(DerivedDataCache.ensureIgnoredBy(project.path), isTrue);
      expect(DerivedDataCache.ensureIgnoredBy(project.path), isFalse);
      final lines = gitignore.readAsLinesSync();
      expect(lines.where((l) => l.trim() == 'DerivedDataCache/'), hasLength(1));
      expect(lines.first, '# Flutter', reason: 'existing rules are kept');

      final bare = writeTempProject(temp, 'ddc_gitignore_new');
      expect(DerivedDataCache.ensureIgnoredBy(bare.path), isTrue);
      expect(File('${bare.path}/.gitignore').readAsStringSync(), contains('DerivedDataCache/'));
    });

    test('git ignores a cache entry through the root .gitignore and through the cache\'s own .gitignore', () async {
      final git = await Process.run('git', ['--version']);
      if (git.exitCode != 0) return markTestSkipped('git is not installed');
      for (final withRootRule in [true, false]) {
        final project = writeTempProject(temp, 'ddc_git_$withRootRule');
        if (withRootRule) DerivedDataCache.ensureIgnoredBy(project.path);
        expect((await Process.run('git', ['init', '-q'], workingDirectory: project.path)).exitCode, 0);
        final cache = DerivedDataCache(project.path);
        await cache.put(DerivedDataCache.sanitizedGlbBucket, 'a', barrelFile.readAsBytesSync());
        final entry = cache.entries().single.path.substring(project.path.length + 1);
        final check = await Process.run('git', ['check-ignore', '-q', entry], workingDirectory: project.path);
        expect(check.exitCode, 0, reason: '$entry must be ignored (root rule: $withRootRule)');
        final status = await Process.run('git', ['status', '--porcelain', '--untracked-files=all'], workingDirectory: project.path);
        expect(status.stdout as String, isNot(contains('DerivedDataCache')));
      }
    }, skip: skip);

    test('clear() keeps the cache folder\'s own .gitignore on every platform', () async {
      final project = writeTempProject(temp, 'ddc_clear_keeps_gitignore');
      final cache = DerivedDataCache(project.path);
      await cache.put(DerivedDataCache.sanitizedGlbBucket, 'a', Uint8List.fromList(List<int>.generate(64, (i) => i)));
      final ignore = File('${cache.directory.path}/.gitignore');
      expect(ignore.existsSync(), isTrue, reason: 'the first write creates the cache\'s own .gitignore');
      final ignoreText = ignore.readAsStringSync();

      await cache.clear();
      expect(cache.entries(), isEmpty);
      expect(ignore.existsSync(), isTrue, reason: 'clear() must not delete ${ignore.path}');
      expect(ignore.readAsStringSync(), ignoreText);
      expect([for (final e in cache.directory.listSync()) e.uri.pathSegments.lastWhere((s) => s.isNotEmpty)], ['.gitignore']);
    });

    test('packagedEntriesIncludingCache flags asset entries that would bundle the cache', () {
      const clean = '''
name: game
flutter:
  uses-material-design: true
  assets:
    - contents/
    - contents/meshes/static/
''';
      expect(DerivedDataCache.packagedEntriesIncludingCache(clean), isEmpty);
      const leaking = '''
name: game
flutter:
  assets:
    - contents/
    - DerivedDataCache/
    - ./DerivedDataCache/SanitizedGlb/
    - path: DerivedDataCache/SanitizedGlb/abc.ddc
''';
      expect(DerivedDataCache.packagedEntriesIncludingCache(leaking),
          ['DerivedDataCache/', './DerivedDataCache/SanitizedGlb/', 'DerivedDataCache/SanitizedGlb/abc.ddc']);
      expect(DerivedDataCache.packagedEntriesIncludingCache('name: game\n'), isEmpty);
      expect(DerivedDataCache.packagedEntriesIncludingCache(': not yaml ['), isEmpty);
    });
  });
}

typedef _Session = ({int vertexCount, int micros, int conversions, List<String> logs});

/// Loads [lmasPath] in a new isolate: a new editor session as far as every
/// static (the sanitized-GLB memo, the converter counter, the logger) goes.
Future<_Session> _loadInFreshSession(String lmasPath) => Isolate.run(() => _session(lmasPath));

Future<_Session> _session(String lmasPath) async {
  final logs = <String>[];
  final sub = EngineLoggerService().logStream.listen((e) => logs.add('[${e.level}] [${e.source}] ${e.message}'));
  final watch = Stopwatch()..start();
  final mesh = await AssetRepository.loadMeshFromDisk(lmasPath);
  watch.stop();
  await sub.cancel();
  return (
    vertexCount: mesh?.vertexCount ?? -1,
    micros: watch.elapsedMicroseconds,
    conversions: GlbParserService.decodingConversionCount,
    logs: logs,
  );
}
