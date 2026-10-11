// Builds the MetaXR posing example project on this machine from a character
// GLB (the mobile MetaHuman export, never committed), then optionally cooks
// its Meta Quest APK. Run from lumina_editor_data:
//
//   LUMINA_METAXR_MESH=<character .glb> \
//   [LUMINA_METAXR_PROJECTS=<projects folder, default ~/Lumina Projects>] \
//   [LUMINA_METAXR_PROJECT=metaxr_posing] \
//   [LUMINA_METAXR_PLUGINS=<plugin folders, ';'-separated, default ../openxr;../metaxr of the workspace>] \
//   [LUMINA_METAXR_COOK=release|debug] \
//   flutter test tool/metaxr_posing/build_metaxr_posing_test.dart
//
// The plugins are linked into the project's plugins/ folder (project
// plugins). Writes Saved/MetaXrPosing/report.json (and, cooked,
// build/package/android/metaxr_posing-<version>.apk with its .sha256).
// Skips without LUMINA_METAXR_MESH.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:path/path.dart' as p;

void main() {
  final env = Platform.environment;
  final mesh = env['LUMINA_METAXR_MESH'];

  test('build the MetaXR posing example project', () async {
    final projects = env['LUMINA_METAXR_PROJECTS'] ?? '${LuminaWorkspace.home}/Lumina Projects';
    final name = env['LUMINA_METAXR_PROJECT'] ?? 'metaxr_posing';
    final total = Stopwatch()..start();
    final projectDir = (await MetaXrPosingBuilder.createProject(projects, name,
            onProgress: (e) => stdout.writeln('[create] ${e.message}')))
        .replaceAll(r'\', '/');
    stdout.writeln('Project: $projectDir');

    // The plugins as project plugins: links to their checkouts.
    final workspace = p.normalize(p.join(Directory.current.path, '..', '..'));
    final pluginDirs = (env['LUMINA_METAXR_PLUGINS']?.split(';') ?? [p.join(workspace, 'openxr'), p.join(workspace, 'metaxr')])
        .where((d) => d.isNotEmpty);
    final pluginsRoot = Directory('$projectDir/plugins')..createSync(recursive: true);
    for (final dir in pluginDirs) {
      final manifest = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.lmplugin'));
      final link = p.join(pluginsRoot.path, p.basenameWithoutExtension(manifest.path));
      if (FileSystemEntity.typeSync(link, followLinks: false) == FileSystemEntityType.notFound) {
        DirectoryLink.createSync(link, p.normalize(p.absolute(dir)));
      }
    }
    final scan = await PluginRepository(roots: [PluginScanRoot(dir: pluginsRoot, origin: PluginOrigin.project)]).scanAll();
    expect(scan.errors, isEmpty, reason: scan.errors.join('\n'));
    ProjectEngineLink.apply(projectDir, luminaPackageDir: ProjectRepository.luminaPackagePath, onLog: stdout.writeln);

    final report = await MetaXrPosingBuilder(projectDir: projectDir, characterGlb: mesh!, plugins: scan.plugins, log: stdout.writeln)
        .build();
    final result = <String, Object>{...report.toJson()};
    final config = env['LUMINA_METAXR_COOK'];
    if (config != null && config.isNotEmpty) {
      // Through a space-free alias: the native-assets hooks cannot compile
      // under a path with a space.
      final buildDir = SpaceFreeBuildDir.of(projectDir);
      final cook = Stopwatch()..start();
      final build = await Process.start('flutter', ['build', 'apk', '--$config', '--target-platform', 'android-arm64'],
          workingDirectory: buildDir, runInShell: Platform.isWindows);
      build.stdout.transform(utf8.decoder).listen(stdout.write);
      build.stderr.transform(utf8.decoder).listen(stderr.write);
      expect(await build.exitCode, 0, reason: 'flutter build apk failed');
      cook.stop();
      final project = (await ProjectRepository().loadProject('$projectDir/$name.lmproject'))!;
      final packageDir = project.packaging.packageDirFor(projectDir, 'android');
      await Directory(packageDir).create(recursive: true);
      await File('$projectDir/build/app/outputs/flutter-apk/app-$config.apk').copy('$packageDir/app-$config.apk');
      final apk = (await AndroidPackaging.finishPackage(packageDir, name, project.packaging.android.versionName))!;
      stdout.writeln('APK ${apk.path}: ${(apk.bytes / (1024 * 1024)).toStringAsFixed(1)} MB in ${cook.elapsed.inSeconds} s');
      result
        ..['apk'] = apk.path
        ..['apkBytes'] = apk.bytes
        ..['apkSha256'] = apk.sha256
        ..['cookSeconds'] = cook.elapsedMilliseconds / 1000.0
        ..['cookConfig'] = config;
    }
    result['totalSeconds'] = total.elapsedMilliseconds / 1000.0;
    final out = File('$projectDir/Saved/MetaXrPosing/report.json');
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    stdout.writeln('Report: ${out.path}');
  }, skip: mesh == null ? 'LUMINA_METAXR_MESH names no character GLB' : false, timeout: Timeout.none);
}
