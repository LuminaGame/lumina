import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/dlss_packaging_hooks.dart';
import 'package:path/path.dart' as p;

/// The packaging run's NVIDIA DLSS step: with Bundle NVIDIA DLSS runtime on, a
/// Windows package gets the verified runtime next to its executable and the
/// log names each file; off, or for web / Android, nothing. Uses the real SDK
/// fetched into flutter_filament (skips with the reason when it is missing).
void main() {
  final filamentRoot = LuminaWorkspace.packageIn(LuminaWorkspace.findSourceRoot() ?? LuminaWorkspace.root, 'flutter_filament');
  final realSdk = DlssSdk.readSync(filamentRoot);
  final noSdk = realSdk == null || !realSdk.isFetched
      ? 'the DLSS SDK is not fetched: run `dart run tool/dlss/fetch_sdk.dart` in $filamentRoot'
      : null;
  late Directory temp;
  late Directory project;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dlss_hooks_');
    project = Directory(p.join(temp.path, 'game'))..createSync();
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  LuminaProject game({required bool bundle}) =>
      LuminaProject(projectName: 'game', packaging: ProjectPackagingSettings(targets: const ['windows', 'web', 'android'], bundleDlssRuntime: bundle));

  (BuildStepContext, List<BuildLogEvent>) context(LuminaProject project0) {
    final logs = <BuildLogEvent>[];
    final ctx = BuildStepContext(
      projectDir: project.path,
      project: project0,
      token: BuildCancellationToken(),
      kind: BuildStepKind.cookAndPackage,
      emit: (e) {
        if (e is BuildLogEvent) logs.add(e);
      },
    );
    return (ctx, logs);
  }

  Directory packageDir(String target) {
    final dir = Directory(p.join(project.path, 'build', 'package', target))..createSync(recursive: true);
    if (target == 'windows') File(p.join(dir.path, 'game.exe')).writeAsStringSync('exe');
    return dir;
  }

  test('on: the Windows package gets the runtime next to game.exe and the log names every file', () async {
    if (noSdk != null) return markTestSkipped(noSdk);
    final hooks = DlssPackagingHooks(projectDir: project.path, project: game(bundle: true), fallbackPackageRoots: [realSdk!.packageRoot]);
    final (ctx, logs) = context(hooks.project);
    expect(await hooks.beforeBuild(ctx, 'windows'), isNull);
    final pkg = packageDir('windows');
    await hooks.afterPackage(ctx, 'windows', pkg.path, pkg.path);
    for (final name in ['nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll', DlssRuntimeBundle.licenseFileName, DlssRuntimeBundle.noticeFileName]) {
      expect(File(p.join(pkg.path, name)).existsSync(), isTrue, reason: name);
      expect(logs.any((l) => l.message.contains('bundled $name')), isTrue, reason: name);
    }
    expect(logs.last.level, 'success');
    expect(logs.last.message, contains('NVIDIA DLSS runtime bundled into'));
  });

  test('on: web and Android packages get nothing and the log says why', () async {
    if (realSdk == null) return markTestSkipped(noSdk!);
    final hooks = DlssPackagingHooks(projectDir: project.path, project: game(bundle: true), fallbackPackageRoots: [realSdk.packageRoot]);
    for (final target in ['web', 'android']) {
      final (ctx, logs) = context(hooks.project);
      expect(await hooks.beforeBuild(ctx, target), isNull);
      final pkg = packageDir(target);
      await hooks.afterPackage(ctx, target, pkg.path, pkg.path);
      expect(pkg.listSync(), isEmpty, reason: target);
      expect(logs.single.message, contains('Windows and Linux only'));
    }
  });

  test('off: nothing is checked, logged or bundled', () async {
    final hooks = DlssPackagingHooks(projectDir: project.path, project: game(bundle: false), fallbackPackageRoots: const []);
    final (ctx, logs) = context(hooks.project);
    expect(await hooks.beforeBuild(ctx, 'windows'), isNull);
    final pkg = packageDir('windows');
    await hooks.afterPackage(ctx, 'windows', pkg.path, pkg.path);
    expect(pkg.listSync().map((e) => p.basename(e.path)), ['game.exe']);
    expect(logs, isEmpty);
  });

  test('on with the SDK missing: the Windows target fails before the build with how to fetch it', () async {
    if (realSdk == null) return markTestSkipped(noSdk!);
    final root = Directory(p.join(temp.path, 'flutter_filament'));
    Directory(p.join(root.path, 'tool', 'dlss')).createSync(recursive: true);
    for (final f in ['VERSION', 'manifest.txt']) {
      File(p.join(realSdk.packageRoot, 'tool', 'dlss', f)).copySync(p.join(root.path, 'tool', 'dlss', f));
    }
    final hooks = DlssPackagingHooks(projectDir: project.path, project: game(bundle: true), fallbackPackageRoots: [root.path]);
    final (ctx, _) = context(hooks.project);
    final problem = await hooks.beforeBuild(ctx, 'windows');
    expect(problem, allOf(contains('Bundle NVIDIA DLSS runtime is on'), contains(DlssSdk.fetchCommand)));
    expect(await hooks.beforeBuild(ctx, 'web'), isNull, reason: 'web never needs the SDK');
  });
}
