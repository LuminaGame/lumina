// Cooks a blank project with the OpenXR and MetaXR plugins enabled into a
// Meta Quest APK on this machine, then checks the packaged manifest against
// the composer. Run from lumina_editor_data:
//
//   LUMINA_ANDROID_COOK=1 \
//   [LUMINA_ANDROID_COOK_PROJECTS=<folder, default <temp>/lq>] \
//   [LUMINA_ANDROID_COOK_PLUGINS=<plugin folders, ';'-separated, default ../openxr;../metaxr of the workspace>] \
//   [LUMINA_ANDROID_COOK_CONFIG=debug|release (default release)] \
//   flutter test tool/android_quest/cook_android_quest_test.dart
//
// Skips without LUMINA_ANDROID_COOK or without an Android SDK (aapt2 in its
// build-tools). Writes `build/package/android/<project>-<version>.apk` (+
// `.sha256`) and `Saved/AndroidCook/report.json` in the project.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:path/path.dart' as p;

/// The Android SDK's newest `aapt2`, or null.
String? _aapt2() {
  final env = Platform.environment;
  final roots = [
    ?env['ANDROID_HOME'],
    ?env['ANDROID_SDK_ROOT'],
    if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}/Android/Sdk',
    if (env['HOME'] != null) '${env['HOME']}/Android/Sdk',
  ];
  for (final root in roots) {
    final tools = Directory('$root/build-tools');
    if (!tools.existsSync()) continue;
    final versions = tools.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
    for (final v in versions) {
      final exe = File('${v.path}/aapt2${Platform.isWindows ? '.exe' : ''}');
      if (exe.existsSync()) return exe.path;
    }
  }
  return null;
}

void main() {
  final env = Platform.environment;
  final aapt2 = _aapt2();
  final skip = env['LUMINA_ANDROID_COOK'] != '1'
      ? 'LUMINA_ANDROID_COOK=1 runs the real Android cook'
      : (aapt2 == null ? 'no Android SDK build-tools (aapt2) on this machine' : false);

  test('a blank project with OpenXR + MetaXR cooks to a Quest APK whose manifest is the composer\'s', () async {
    final sw = Stopwatch()..start();
    // The recent-projects list and other per-user config stay untouched.
    LuminaConfigDir.override = Directory.systemTemp.createTempSync('lq_config_');
    final projects = env['LUMINA_ANDROID_COOK_PROJECTS'] ?? p.join(Directory.systemTemp.path, 'lq');
    await Directory(projects).create(recursive: true);
    const name = 'blank_quest';
    final projectDir = p.join(projects, name).replaceAll(r'\', '/');
    if (await Directory(projectDir).exists()) {
      // Links (the plugin and engine junctions) first, so nothing behind
      // them is deleted.
      for (final e in Directory(projectDir).listSync(recursive: true, followLinks: false)) {
        if (e is Link) e.deleteSync();
      }
      await Directory(projectDir).delete(recursive: true);
    }
    final repo = ProjectRepository();
    var project = await repo.createProject(projectName: name, projectLocation: projects, onProgress: (e) => stdout.writeln('[create] ${e.message}'));
    final createMs = sw.elapsedMilliseconds;

    // The plugins, as project plugins (links to their checkouts).
    final workspace = p.normalize(p.join(Directory.current.path, '..', '..'));
    final pluginDirs = (env['LUMINA_ANDROID_COOK_PLUGINS']?.split(';') ?? [p.join(workspace, 'openxr'), p.join(workspace, 'metaxr')])
        .where((d) => d.isNotEmpty)
        .toList();
    final pluginsRoot = Directory(p.join(projectDir, 'plugins'))..createSync(recursive: true);
    for (final dir in pluginDirs) {
      final manifest = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.lmplugin'));
      final linkName = p.basenameWithoutExtension(manifest.path);
      DirectoryLink.createSync(p.join(pluginsRoot.path, linkName), p.normalize(p.absolute(dir)));
    }
    final scan = await PluginRepository(roots: [PluginScanRoot(dir: pluginsRoot, origin: PluginOrigin.project)]).scanAll();
    expect(scan.errors, isEmpty, reason: scan.errors.join('\n'));
    final plugins = scan.plugins;
    project = project.copyWith(
      enabledPlugins: [for (final pl in plugins) pl.name],
      packaging: project.packaging.copyWith(targets: const ['android'], android: const ProjectAndroidSettings.quest()),
    );
    await repo.saveProject(project, projectDir);
    ProjectEngineLink.apply(projectDir, luminaPackageDir: ProjectRepository.luminaPackagePath, onLog: stdout.writeln);

    final prep = await AndroidPackaging.prepare(projectDir, project, plugins);
    stdout.writeln('Prepared ${prep.applicationId}: ${prep.manifest.summary.join(', ')}; modules ${prep.runtimeModules.map((d) => d.package).join(', ')}');
    final gen = await GenerateDartCodeUseCase()(projectDir: projectDir, levelName: 'L_DefaultLevel', actors: const [], project: project);
    expect(gen.isSuccess, isTrue, reason: gen.error);
    expect(await File('$projectDir/lib/main.dart').readAsString(), contains('registerPluginRuntimeModules();'));

    final config = env['LUMINA_ANDROID_COOK_CONFIG'] ?? 'release';
    final cookSw = Stopwatch()..start();
    final build = await Process.start(
        'flutter', ['build', 'apk', '--$config', '--target-platform', AndroidPackaging.targetPlatforms(project.packaging.android).join(',')],
        workingDirectory: projectDir, runInShell: Platform.isWindows);
    build.stdout.transform(utf8.decoder).listen(stdout.write);
    build.stderr.transform(utf8.decoder).listen(stderr.write);
    final code = await build.exitCode;
    final cookMs = cookSw.elapsedMilliseconds;
    expect(code, 0, reason: 'flutter build apk failed');
    final built = File('$projectDir/build/app/outputs/flutter-apk/app-$config.apk');
    expect(await built.exists(), isTrue);
    final packageDir = project.packaging.packageDirFor(projectDir, 'android');
    await Directory(packageDir).create(recursive: true);
    await built.copy('$packageDir/app-$config.apk');
    final apk = (await AndroidPackaging.finishPackage(packageDir, project.projectName, project.packaging.android.versionName))!;
    stdout.writeln('APK ${apk.path}: ${(apk.bytes / (1024 * 1024)).toStringAsFixed(1)} MB, sha256 ${apk.sha256}');

    // The packaged manifest holds every entry the composer generated.
    final dump = await Process.run(aapt2!, ['dump', 'xmltree', '--file', 'AndroidManifest.xml', apk.path]);
    expect(dump.exitCode, 0, reason: '${dump.stderr}');
    final tree = '${dump.stdout}';
    final missing = <String>[];
    final values = RegExp(r'android:(?:name|value|authorities)="([^"]+)"');
    for (final line in prep.manifest.lines.where((l) => l.source != 'template' && l.source != 'generated')) {
      for (final m in values.allMatches(line.text)) {
        // Strings are quoted; booleans and numbers are compiled to typed values (`=false`).
        final v = m.group(1)!;
        if (!tree.contains('"$v"') && !RegExp('=${RegExp.escape(v)}\\s*\$', multiLine: true).hasMatch(tree)) {
          missing.add('${line.source}: $v');
        }
      }
    }
    expect(missing, isEmpty, reason: 'entries the composer wrote but the APK lacks:\n${missing.join('\n')}');
    expect(tree, contains('"${prep.applicationId}"'));
    expect(tree, isNot(contains('PROPERTY_XR_ACTIVITY_START_MODE')));
    // The headtracking feature is required (android:required(0x0101028e)=true).
    final feature = RegExp(r'E: uses-feature.*?(?=E: )', dotAll: true)
        .allMatches(tree)
        .map((m) => m.group(0)!)
        .firstWhere((b) => b.contains('android.hardware.vr.headtracking'));
    expect(feature, contains('=true'));

    final report = {
      'project': projectDir,
      'application_id': prep.applicationId,
      'apk': apk.path,
      'apk_bytes': apk.bytes,
      'sha256': apk.sha256,
      'config': config,
      'create_ms': createMs,
      'cook_ms': cookMs,
      'total_ms': sw.elapsedMilliseconds,
      'manifest_summary': prep.manifest.summary,
      'runtime_modules': [for (final d in prep.runtimeModules) d.package],
    };
    final out = File('$projectDir/Saved/AndroidCook/report.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    await File('$projectDir/Saved/AndroidCook/aapt2_manifest.txt').writeAsString(tree);
    stdout.writeln('Report: ${out.path}');
  }, skip: skip, timeout: Timeout.none);
}
