import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/editor_build_cache.dart';
import 'package:lumina/data/services/editor_build_fingerprint.dart';
import 'package:lumina/data/services/editor_build_service.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/engine_bootstrap.dart';
import 'package:lumina/data/services/engine_identity.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Which engine a project's copy of the engine source came from, and whether
/// the running engine is another one. Real temp workspaces, hosts and
/// `.lmproject` files on disk.
void main() {
  late Directory temp;
  late String engine;
  late String host;

  void write(String rel, String content) {
    final f = File(p.join(engine, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('engine_update_');
    engine = p.join(temp.path, 'engine');
    host = p.join(temp.path, 'Game', '.lumina', 'editor');
    Directory(host).createSync(recursive: true);
    write('a_ui/pubspec.yaml', 'name: a_ui\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  a_core:\n    path: ../a_core\n');
    write('a_ui/lib/ui.dart', '// ui\n');
    write('a_core/pubspec.yaml', 'name: a_core\nenvironment:\n  sdk: ^3.12.0\n');
    write('a_core/lib/core.dart', '// core\n');
    write('filament/include/x.h', '#define X 1\n');
  });

  tearDown(() {
    for (var i = 0; i < 20; i++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 200));
      }
    }
  });

  EditorSourceVendorService service() => EditorSourceVendorService(engineRoot: engine, rootPackage: 'a_ui');

  void setStampEngine(String hostDir, Object? engineJson) {
    final f = File(p.join(hostDir, EditorSourceVendorService.stampFileName));
    final stamp = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    if (engineJson == null) {
      stamp.remove('engine');
    } else {
      stamp['engine'] = engineJson;
    }
    f.writeAsStringSync(jsonEncode(stamp));
  }

  const older = EngineIdentity(version: '0.0.1-dev.3', commit: '1111111111111111111111111111111111111111', release: true);

  group('EngineIdentity', () {
    test('a source checkout: the source version and its HEAD', () async {
      final id = await EngineIdentity.of(LuminaWorkspace.root);
      expect(id.version, LuminaRelease.displayVersion);
      expect(id.release, isFalse);
      expect(id.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(id.label, '${LuminaRelease.displayVersion} (${id.commit.substring(0, 7)})');
      expect(id.key, '${id.version}@${id.commit}');
    });

    test('a fetched release checkout: its tag and commit from the bootstrap marker', () async {
      final checkout = Directory(p.join(temp.path, 'v0.0.9'))..createSync();
      Directory(p.join(checkout.path, '.git')).createSync();
      File(p.join(checkout.path, '.git', EngineBootstrap.markerName)).writeAsStringSync(jsonEncode(EngineCheckout(
        dir: checkout.path,
        version: 'v0.0.9',
        commit: 'abcdef0123456789abcdef0123456789abcdef01',
        repo: 'https://example.invalid/lumina.git',
        filamentVersion: '1.77.0-lumina.2',
        filamentDir: temp.path,
        openriglogicDir: temp.path,
        completedAt: DateTime.utc(2026, 9, 30),
      ).toJson()));
      final id = await EngineIdentity.of(checkout.path);
      expect(id.version, '0.0.9');
      expect(id.commit, 'abcdef0123456789abcdef0123456789abcdef01');
      expect(id.release, isTrue);
      expect(id.label, '0.0.9');
    });

    test('a tree that is not a git checkout has no commit; JSON round trip', () async {
      final id = await EngineIdentity.of(engine);
      expect(id.commit, isEmpty);
      expect(id.label, LuminaRelease.displayVersion);
      expect(EngineIdentity.fromJson(older.toJson()), older);
      expect(EngineIdentity.fromJson({'commit': 'x'}), isNull);
      expect(EngineIdentity.fromJson('0.0.1'), isNull);
    });
  });

  group('engineUpdate', () {
    test('a copy records the engine it came from and is current for it', () async {
      await service().vendor(host);
      final current = await EngineIdentity.of(engine);
      expect(EditorSourceVendorService.copiedEngine(host), current);
      expect(await service().engineUpdate(host, current: current), isNull);
    });

    test('a copy from an older engine is an update naming both versions', () async {
      await service().vendor(host);
      setStampEngine(host, older.toJson());
      final current = await EngineIdentity.of(engine);
      final update = await service().engineUpdate(host, current: current, projectEngineVersion: '0.0.1');
      expect(update, isNotNull);
      expect(update!.copied, older);
      expect(update.fromLabel, '0.0.1-dev.3');
      expect(update.toLabel, current.label);
      expect(update.changedRepos, isEmpty);
    });

    test('the same engine with changed source names the changed repos', () async {
      await service().vendor(host);
      write('a_core/lib/core.dart', '// core, edited\n');
      final current = await EngineIdentity.of(engine);
      final update = await service().engineUpdate(host, current: current);
      expect(update, isNotNull);
      expect(update!.changedRepos, ['a_core']);
      expect(update.toLabel, '${current.label}, changed: a_core');
    });

    test('an older stamp: unchanged source and the placeholder engine_version ask nothing', () async {
      await service().vendor(host);
      setStampEngine(host, null);
      final current = await EngineIdentity.of(engine);
      expect(await service().engineUpdate(host, current: current, projectEngineVersion: kLuminaEngineVersion), isNull);
      expect(await service().engineUpdate(host, current: current), isNull);
    });

    test("an older stamp: the project's engine_version names another version", () async {
      await service().vendor(host);
      setStampEngine(host, null);
      final current = await EngineIdentity.of(engine);
      final update = await service().engineUpdate(host, current: current, projectEngineVersion: 'v0.0.1-dev.2');
      expect(update, isNotNull);
      expect(update!.copied, isNull);
      expect(update.fromLabel, '0.0.1-dev.2');
      expect(await service().engineUpdate(host, current: current, projectEngineVersion: current.version), isNull);
    });

    test('an older stamp with changed source: "an older engine"', () async {
      await service().vendor(host);
      setStampEngine(host, null);
      write('a_ui/lib/ui.dart', '// ui, newer\n');
      final update = await service().engineUpdate(host, current: await EngineIdentity.of(engine));
      expect(update, isNotNull);
      expect(update!.fromLabel, 'an older engine');
      expect(update.changedRepos, ['a_ui']);
    });

    test('no copy: nothing to update', () async {
      expect(await service().engineUpdate(host, current: older), isNull);
    });
  });

  group('ProjectRepository.updateEngineVersion', () {
    test('rewrites engine_version only; a second call changes nothing', () async {
      final dir = Directory(p.join(temp.path, 'Game'));
      final manifest = File(p.join(dir.path, 'Game.lmproject'));
      final original = LuminaProject(projectName: 'Game', enabledPlugins: const ['a_plugin']).toMap();
      manifest.writeAsStringSync(jsonEncode(original));
      final repo = ProjectRepository(configDir: Directory(p.join(temp.path, 'config')));
      expect(await repo.updateEngineVersion(dir.path, '0.0.1-dev.7'), kLuminaEngineVersion);
      final after = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      expect(after['engine_version'], '0.0.1-dev.7');
      expect({...after}..remove('engine_version'), {...original}..remove('engine_version'));
      expect(await repo.updateEngineVersion(dir.path, '0.0.1-dev.7'), isNull);
      expect(await repo.updateEngineVersion(p.join(temp.path, 'nowhere'), '0.0.1-dev.7'), isNull);
    });
  });

  group('EditorBuildService syncSource', () {
    test('replaces an older copy on the copy phase and reports it before the build', () async {
      final projectDir = Directory(p.join(temp.path, 'SyncGame'))..createSync();
      File(p.join(projectDir.path, 'SyncGame.lmproject')).writeAsStringSync(jsonEncode(LuminaProject(projectName: 'SyncGame').toMap()));
      final hostDir = EditorHostGeneratorService.hostDirOf(projectDir.path);
      final vendor = EditorSourceVendorService(engineRoot: LuminaWorkspace.root, linkPackages: true);
      await vendor.vendor(hostDir);
      setStampEngine(hostDir, older.toJson());
      final events = <String>[];
      final buildService = EditorBuildService(
        engineRoot: LuminaWorkspace.root,
        vendor: vendor,
        cache: EditorBuildCache(root: Directory(p.join(temp.path, 'cache'))),
        hostAliasRoot: Directory(p.join(temp.path, 'hosts')),
        flutterInfo: () async => const FlutterToolInfo('3.47.5', '6a19cca564'),
        killTree: (_) async {},
        // The build itself is not this test's: the first tool call ends it.
        processStarter: (exe, args, {workingDirectory, environment}) async {
          events.add('process ${args.first}');
          throw const ProcessException('flutter', [], 'no build in this test');
        },
      );
      final messages = <String>[];
      final lines = <String>[];
      final job = buildService.start(projectDir.path, const [], projectName: 'SyncGame', syncSource: true, onSourceSynced: () {
        events.add('synced ${EditorSourceVendorService.copiedEngine(hostDir)?.key}');
      });
      job.progress.listen((e) {
        messages.add(e.message);
        if (e.logLine != null) lines.add(e.logLine!);
      });
      final outcome = await job.result;
      expect(outcome, isA<EditorBuildFailed>());
      final current = await EngineIdentity.of(LuminaWorkspace.root);
      expect(events.first, 'synced ${current.key}', reason: 'the copy is replaced before any build step');
      expect(events.where((e) => e.startsWith('synced')), hasLength(1));
      expect(messages, contains('Updating editor source'));
      expect(lines.where((l) => l.startsWith('Updating the editor source in ')), hasLength(1), reason: 'on the splash log');
      expect(EditorSourceVendorService.copiedEngine(hostDir), current);
    });

    test('without syncSource an existing copy is left alone', () async {
      final projectDir = Directory(p.join(temp.path, 'KeepGame'))..createSync();
      File(p.join(projectDir.path, 'KeepGame.lmproject')).writeAsStringSync(jsonEncode(LuminaProject(projectName: 'KeepGame').toMap()));
      final hostDir = EditorHostGeneratorService.hostDirOf(projectDir.path);
      final vendor = EditorSourceVendorService(engineRoot: LuminaWorkspace.root, linkPackages: true);
      await vendor.vendor(hostDir);
      setStampEngine(hostDir, older.toJson());
      var synced = 0;
      final buildService = EditorBuildService(
        engineRoot: LuminaWorkspace.root,
        vendor: vendor,
        cache: EditorBuildCache(root: Directory(p.join(temp.path, 'cache'))),
        hostAliasRoot: Directory(p.join(temp.path, 'hosts')),
        flutterInfo: () async => const FlutterToolInfo('3.47.5', '6a19cca564'),
        killTree: (_) async {},
        processStarter: (exe, args, {workingDirectory, environment}) async =>
            throw const ProcessException('flutter', [], 'no build in this test'),
      );
      final job = buildService.start(projectDir.path, const [], projectName: 'KeepGame', onSourceSynced: () => synced++);
      await job.result;
      expect(synced, 0);
      expect(EditorSourceVendorService.copiedEngine(hostDir), older);
    });
  });
}
