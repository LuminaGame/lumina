import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The release bootstrap against a real git "remote": a bare repository made
/// from a small fixture workspace in the system temp folder, cloned with the
/// real git and resolved with the real `flutter pub get`.
void main() {
  late Directory temp;
  late String remote;
  late String repoUrl;
  late String commit1;
  late String commit2;
  late Map<String, String> env;
  late int filamentCalls;
  late int openriglogicCalls;

  const filamentVersion = '1.77.0-test.1';

  String? envValue(Map<String, String> e, String name) {
    for (final kv in e.entries) {
      if (kv.key.toLowerCase() == name.toLowerCase()) return kv.value;
    }
    return null;
  }

  Future<String> git(List<String> args, String cwd) async {
    final r = await Process.run('git', args, workingDirectory: cwd, environment: env, includeParentEnvironment: false);
    if (r.exitCode != 0) fail('git ${args.join(' ')} failed: ${r.stderr}');
    return '${r.stdout}'.trim();
  }

  /// A stand-in for the release-asset download: a real directory in the
  /// cache root, like the one the prebuilt library extracts.
  Future<Directory> localFilament({
    required String version,
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
  }) async {
    filamentCalls++;
    final dir = Directory(p.join(cacheRoot.path, version));
    File(p.join(dir.path, 'include', 'filament', 'Engine.h'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// $releaseTag\n');
    onProgress?.call(1, 'extracted');
    return dir;
  }

  /// A stand-in for the OpenRigLogic release asset: the unpacked layout.
  Future<Directory> localOpenRigLogic({
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
  }) async {
    openriglogicCalls++;
    final dir = Directory(p.join(cacheRoot.path, releaseTag));
    File(p.join(dir.path, 'lib', Platform.isWindows ? 'riglogic.lib' : 'libriglogic.a'))
      ..createSync(recursive: true)
      ..writeAsStringSync('$releaseTag\n');
    onProgress?.call(1, 'extracted');
    return dir;
  }

  Future<Directory> offlineOpenRigLogic({
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
  }) =>
      throw StateError('network access');

  Future<Directory> offlineFilament({
    required String version,
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
  }) =>
      throw StateError('network access');

  EngineBootstrap bootstrap(
          {String? commit, Map<String, String>? environment, FilamentProvider? filament, OpenRigLogicProvider? openriglogic, String? repo}) =>
      EngineBootstrap(
        version: 'v0.0.0-test',
        commit: commit ?? commit1,
        repo: repo ?? repoUrl,
        engineRoot: Directory(p.join(temp.path, 'data', 'engine')),
        filamentRoot: Directory(p.join(temp.path, 'data', 'filament')),
        openriglogicRoot: Directory(p.join(temp.path, 'data', 'openriglogic')),
        environment: environment ?? env,
        filament: filament ?? localFilament,
        openriglogic: openriglogic ?? localOpenRigLogic,
        checkToolchain: false,
      );

  setUpAll(() async {
    env = Map.of(Platform.environment);
    // flutter_tester runs from <flutter>/bin/cache/artifacts/engine/<platform>/.
    final flutterBin = p.join(p.dirname(p.dirname(p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))))), 'bin');
    final pathKey = env.keys.firstWhere((k) => k.toLowerCase() == 'path', orElse: () => 'PATH');
    if (Directory(flutterBin).existsSync()) {
      env[pathKey] = '$flutterBin${Platform.isWindows ? ';' : ':'}${env[pathKey] ?? ''}';
    }
    env['GIT_AUTHOR_NAME'] = env['GIT_COMMITTER_NAME'] = 'Lumina Test';
    env['GIT_AUTHOR_EMAIL'] = env['GIT_COMMITTER_EMAIL'] = 'test@lumina.invalid';
  });

  setUp(() async {
    filamentCalls = 0;
    openriglogicCalls = 0;
    temp = Directory.systemTemp.createTempSync('engine_bootstrap_');
    final src = Directory(p.join(temp.path, 'src'))..createSync();
    File(p.join(src.path, 'pubspec.yaml')).writeAsStringSync('name: fixture_engine\npublish_to: none\nenvironment:\n  sdk: ^3.0.0\n');
    File(p.join(src.path, 'lumina', 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: lumina_fixture\n');
    File(p.join(src.path, 'tool', 'filament', 'VERSION'))
      ..createSync(recursive: true)
      ..writeAsStringSync('$filamentVersion\n');
    File(p.join(src.path, '.gitignore')).writeAsStringSync('/filament\n/openriglogic\n.dart_tool/\npubspec.lock\n');
    await git(['init', '-q', '-b', 'main'], src.path);
    await git(['add', '.'], src.path);
    await git(['commit', '-q', '-m', 'first'], src.path);
    commit1 = await git(['rev-parse', 'HEAD'], src.path);
    File(p.join(src.path, 'README.md')).writeAsStringSync('second\n');
    await git(['add', '.'], src.path);
    await git(['commit', '-q', '-m', 'second'], src.path);
    commit2 = await git(['rev-parse', 'HEAD'], src.path);
    remote = p.join(temp.path, 'remote.git');
    await git(['clone', '-q', '--bare', src.path, remote], temp.path);
    await git(['config', 'uploadpack.allowFilter', 'true'], remote);
    await git(['config', 'uploadpack.allowAnySHA1InWant', 'true'], remote);
    repoUrl = Uri.file(remote).toString();
  });

  tearDown(() async {
    LuminaWorkspace.clearCheckout();
    for (var i = 0; i < 5; i++) {
      try {
        if (temp.existsSync()) {
          if (Platform.isWindows) await Process.run('attrib', ['-R', '${temp.path}\\*', '/S', '/D'], runInShell: true);
          temp.deleteSync(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  });

  String head(EngineBootstrap b) => File(p.join(b.checkoutDir.path, '.git', 'HEAD')).readAsStringSync().trim();

  test('a fresh partial clone is checked out at the commit, linked to Filament, resolved and activated', () async {
    final b = bootstrap();
    final events = <EngineBootstrapEvent>[];
    final checkout = await b.ensure(onEvent: events.add);

    expect(checkout.commit, commit1);
    expect(head(b), commit1, reason: 'detached at the release commit, not main ($commit2)');
    expect(File(p.join(b.checkoutDir.path, 'README.md')).existsSync(), isFalse, reason: 'README.md only exists in the later commit');
    expect(File(p.join(b.checkoutDir.path, 'tool', 'filament', 'VERSION')).existsSync(), isTrue);
    expect(await git(['config', '--get', 'remote.origin.partialclonefilter'], b.checkoutDir.path), 'blob:none');

    final link = Link(p.join(b.checkoutDir.path, 'filament'));
    expect(link.existsSync(), isTrue);
    expect(File(p.join(link.path, 'include', 'filament', 'Engine.h')).existsSync(), isTrue);
    if (Platform.isWindows) {
      // A directory junction (IO_REPARSE_TAG_MOUNT_POINT), not a symbolic link: no admin or Developer Mode needed.
      final q = await Process.run('fsutil', ['reparsepoint', 'query', link.path]);
      expect('${q.stdout}'.toLowerCase(), contains('0xa0000003'));
    }
    expect(checkout.filamentVersion, filamentVersion);
    expect(p.equals(checkout.filamentDir, p.join(temp.path, 'data', 'filament', filamentVersion)), isTrue);

    // The release's OpenRigLogic, where the root pubspec's riglogic_lib_dir
    // (`openriglogic/lib`) looks for it.
    final riglogic = Link(p.join(b.checkoutDir.path, 'openriglogic'));
    expect(riglogic.existsSync(), isTrue);
    expect(File(p.join(riglogic.path, 'lib', Platform.isWindows ? 'riglogic.lib' : 'libriglogic.a')).readAsStringSync().trim(),
        'v0.0.0-test');
    expect(p.equals(checkout.openriglogicDir, p.join(temp.path, 'data', 'openriglogic', 'v0.0.0-test')), isTrue);

    expect(File(p.join(b.checkoutDir.path, '.dart_tool', 'package_config.json')).existsSync(), isTrue);
    expect(b.markerFile.existsSync(), isTrue);
    expect(await git(['status', '--porcelain'], b.checkoutDir.path), isEmpty, reason: 'the link and the marker are not changes');

    expect(LuminaWorkspace.root, p.normalize(b.checkoutDir.path));
    expect(LuminaWorkspace.engineCommit, commit1);
    expect(LuminaWorkspace.engineRepo, repoUrl);
    expect(EngineBootstrap.readMarker(b.checkoutDir.path)?.commit, commit1, reason: 'project editors read the marker');
    expect(EngineBootstrap.readMarker(temp.path), isNull);

    final done = events.whereType<EngineBootstrapStepDone>().map((e) => (e.step, e.skipped)).toList();
    expect(done, [for (final s in EngineBootstrapStep.values) (s, false)]);
    expect(done.map((d) => d.$1), containsAllInOrder([EngineBootstrapStep.filament, EngineBootstrapStep.openriglogic, EngineBootstrapStep.packages]));
    expect(events.whereType<EngineBootstrapLog>().where((e) => e.step == EngineBootstrapStep.packages), isNotEmpty);
    expect(filamentCalls, 1);
    expect(openriglogicCalls, 1);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a second run finds the complete checkout and does nothing', () async {
    final first = await bootstrap().ensure();
    final marker = bootstrap().markerFile.readAsStringSync();

    final events = <EngineBootstrapEvent>[];
    final again = await bootstrap().ensure(onEvent: events.add);
    expect(again.commit, first.commit);
    expect(bootstrap().markerFile.readAsStringSync(), marker, reason: 'marker untouched');
    expect(filamentCalls, 1);
    expect(openriglogicCalls, 1);
    expect(events.whereType<EngineBootstrapStepDone>().where((e) => e.step != EngineBootstrapStep.prerequisites).every((e) => e.skipped),
        isTrue);
    expect(events.whereType<EngineBootstrapLog>().where((e) => e.line.contains('Cloning') || e.line.contains('pub get')), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('starts offline once the checkout is complete', () async {
    await bootstrap().ensure();
    LuminaWorkspace.clearCheckout();
    Directory(remote).renameSync('$remote.gone');

    final b = bootstrap(filament: offlineFilament, openriglogic: offlineOpenRigLogic);
    expect(b.readyCheckout(), isNotNull);
    final checkout = await b.ensure();
    expect(checkout.commit, commit1);
    expect(LuminaWorkspace.root, p.normalize(b.checkoutDir.path));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a clone interrupted after its download is resumed, not cloned again', () async {
    final b = bootstrap();
    Directory(b.engineRoot.path).createSync(recursive: true);
    await git(['clone', '-q', '--filter=blob:none', '--no-checkout', repoUrl, b.checkoutDir.path], temp.path);
    final sentinel = File(p.join(b.checkoutDir.path, '.git', 'resume-sentinel'))..writeAsStringSync('x');

    final checkout = await b.ensure();
    expect(sentinel.existsSync(), isTrue, reason: 'the existing clone was reused');
    expect(checkout.commit, commit1);
    expect(File(p.join(b.checkoutDir.path, 'pubspec.yaml')).existsSync(), isTrue);
    expect(await git(['status', '--porcelain'], b.checkoutDir.path), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a broken clone is repaired by cloning again; damaged files are restored', () async {
    final b = bootstrap();
    Directory(p.join(b.checkoutDir.path, '.git', 'objects')).createSync(recursive: true);
    File(p.join(b.checkoutDir.path, 'junk.txt')).writeAsStringSync('half a clone');

    await b.ensure();
    expect(File(p.join(b.checkoutDir.path, 'junk.txt')).existsSync(), isFalse);
    expect(head(b), commit1);

    // A tracked file deleted and the marker lost: checked out again.
    File(p.join(b.checkoutDir.path, 'pubspec.yaml')).deleteSync();
    b.markerFile.deleteSync();
    await b.ensure();
    expect(File(p.join(b.checkoutDir.path, 'pubspec.yaml')).existsSync(), isTrue);
    expect(b.markerFile.existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('an existing checkout moves to a new commit of the same version; force downloads it again', () async {
    await bootstrap().ensure();
    final b2 = bootstrap(commit: commit2);
    expect(b2.readyCheckout(), isNull, reason: 'the marker names another commit');
    final checkout = await b2.ensure();
    expect(checkout.commit, commit2);
    expect(File(p.join(b2.checkoutDir.path, 'README.md')).existsSync(), isTrue);

    final sentinel = File(p.join(b2.checkoutDir.path, '.git', 'force-sentinel'))..writeAsStringSync('x');
    await b2.ensure(force: true);
    expect(sentinel.existsSync(), isFalse, reason: 'force deleted and cloned again');
    expect(Directory(p.join(temp.path, 'data', 'filament', filamentVersion)).existsSync(), isTrue,
        reason: 'deleting the checkout never follows its filament link');
    expect(Directory(p.join(temp.path, 'data', 'openriglogic', 'v0.0.0-test', 'lib')).existsSync(), isTrue,
        reason: 'nor its openriglogic link');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a lost openriglogic link makes the checkout incomplete; the next run links it again', () async {
    final first = await bootstrap().ensure();
    LuminaWorkspace.clearCheckout();
    Link(p.join(first.dir, 'openriglogic')).deleteSync();
    expect(bootstrap().readyCheckout(), isNull);

    final again = await bootstrap().ensure();
    expect(Link(p.join(again.dir, 'openriglogic')).existsSync(), isTrue);
    expect(again.openriglogicDir, first.openriglogicDir);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('an OpenRigLogic download failure fails its own step, before pub get', () async {
    final events = await bootstrap(openriglogic: offlineOpenRigLogic).run(activate: false).toList();
    final failed = events.last as EngineBootstrapFailed;
    expect(failed.error.step, EngineBootstrapStep.openriglogic);
    expect(failed.error.message, contains('OpenRigLogic'));
    expect(events.whereType<EngineBootstrapStepDone>().map((e) => e.step), isNot(contains(EngineBootstrapStep.packages)));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('missing prerequisites stop before anything is written, with install hints', () async {
    // The user's environment with an empty PATH: no git, no flutter.
    final noTools = {for (final e in env.entries) if (e.key.toLowerCase() != 'path') e.key: e.value, 'PATH': ''};
    final b = bootstrap(environment: noTools);
    final events = await b.run(activate: false).toList();
    final failed = events.last as EngineBootstrapFailed;
    expect(failed.error.step, EngineBootstrapStep.prerequisites);
    expect(failed.error.missing.map((m) => m.name), containsAll(['Git', 'Flutter SDK']));
    expect(failed.error.missing.every((m) => m.hint.isNotEmpty), isTrue);
    expect(b.checkoutDir.existsSync(), isFalse);
    expect(LuminaWorkspace.checkoutOverride, isNull);
  });

  test('an unknown commit fails the source step through the event stream', () async {
    final events = await bootstrap(commit: 'f' * 40).run().toList();
    final failed = events.last as EngineBootstrapFailed;
    expect(failed.error.step, EngineBootstrapStep.source);
    expect(events.whereType<EngineBootstrapCompleted>(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('findExecutable honours PATH (and PATHEXT on Windows)', () {
    final b = bootstrap();
    expect(b.findExecutable('git'), isNotNull);
    expect(bootstrap(environment: const {'PATH': ''}).findExecutable('git'), isNull);
    expect(envValue(env, 'PATH'), isNotEmpty);
  });

  group('LuminaDataDir', () {
    test('per-platform locations', () {
      String slash(Directory d) => d.path.replaceAll(r'\', '/');
      expect(slash(LuminaDataDir.resolve(environment: {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'}, operatingSystem: 'windows')),
          'C:/Users/u/AppData/Local/Lumina');
      expect(slash(LuminaDataDir.resolve(environment: {'HOME': '/home/u'}, operatingSystem: 'linux')), '/home/u/.local/share/lumina');
      expect(slash(LuminaDataDir.resolve(environment: {'HOME': '/home/u', 'XDG_DATA_HOME': '/x'}, operatingSystem: 'linux')), '/x/lumina');
      expect(slash(LuminaDataDir.resolve(environment: {'HOME': '/Users/u'}, operatingSystem: 'macos')),
          '/Users/u/Library/Application Support/Lumina');
      expect(slash(LuminaDataDir.engineRoot(environment: {'LUMINA_DATA_DIR': '/d'})), '/d/engine');
      expect(slash(LuminaDataDir.filamentRoot(environment: {'LUMINA_DATA_DIR': '/d'})), '/d/filament');
      expect(slash(LuminaDataDir.openriglogicRoot(environment: {'LUMINA_DATA_DIR': '/d'})), '/d/openriglogic');
    });
  });
}
