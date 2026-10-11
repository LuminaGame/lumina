import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/packaging/android/android_gradle_configurator.dart';
import 'package:lumina_editor_data/src/packaging/android/android_manifest_composer.dart';
import 'package:lumina_editor_data/src/packaging/runtime_module_dependencies.dart';

/// What [AndroidPackaging.prepare] did.
class AndroidPreparation {
  final ComposedAndroidManifest manifest;

  /// The manifest before (null when it did not exist).
  final String? previousManifest;
  final String applicationId;
  final bool gradleChanged;
  final List<RuntimeModuleDependency> runtimeModules;
  const AndroidPreparation({
    required this.manifest,
    required this.previousManifest,
    required this.applicationId,
    required this.gradleChanged,
    required this.runtimeModules,
  });

  /// The manifest lines that changed, `+`/`-` prefixed, for the build log.
  List<String> get manifestDiff => AndroidPackaging.lineDiff(previousManifest ?? '', manifest.xml);
}

/// The packaged APK.
class AndroidPackagedApk {
  final String path;
  final int bytes;
  final String sha256;

  /// Set when the APK is above [AndroidPackaging.storeLimitBytes].
  final String? warning;
  const AndroidPackagedApk({required this.path, required this.bytes, required this.sha256, this.warning});
}

/// The Android (Meta Quest) packaging steps around `flutter build apk`:
/// [prepare] composes the manifest, writes the Gradle settings and makes the
/// enabled plugins' runtime modules game dependencies; [finishPackage]
/// names the APK `<project>-<version>.apk` with its `.sha256`.
abstract final class AndroidPackaging {
  /// The store's APK size limit without expansion files.
  static const int storeLimitBytes = 1024 * 1024 * 1024;

  static String manifestPath(String projectDir) => '$projectDir/android/app/src/main/AndroidManifest.xml';

  /// The `--target-platform` list of [settings]' ABIs.
  static List<String> targetPlatforms(ProjectAndroidSettings settings) => [
        for (final abi in settings.abis)
          switch (abi) {
            'arm64-v8a' => 'android-arm64',
            'armeabi-v7a' => 'android-arm',
            'x86_64' => 'android-x64',
            _ => abi,
          },
      ];

  /// The class names a project's levels and Blueprints use, among
  /// [candidates] (scanned off the UI isolate: every `.lmas` under
  /// `contents/`).
  static Future<Set<String>> usedClasses(String projectDir, Set<String> candidates) {
    if (candidates.isEmpty) return Future.value(const {});
    return Isolate.run(() {
      final found = <String>{};
      final root = Directory('$projectDir/contents');
      if (!root.existsSync()) return found;
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.lmas')) continue;
        String text;
        try {
          final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
          final payload = asset.rawPayload;
          text = '${asset.metadata.values.join('\n')}\n${payload == null ? '' : utf8.decode(payload, allowMalformed: true)}';
        } on Object {
          continue;
        }
        for (final c in candidates) {
          if (text.contains(c)) found.add(c);
        }
        if (found.length == candidates.length) break;
      }
      return found;
    });
  }

  /// The class names the plugins' contributions are conditional on.
  static Set<String> conditionalClasses(List<LuminaPluginDescriptor> plugins) => {
        for (final p in plugins)
          if (p.android != null) ...[
            for (final f in p.android!.usesFeatures) ...[?f.whenUsed, ?f.requiredWhenUsed],
            for (final x in p.android!.permissions) ?x.whenUsed,
            for (final m in p.android!.metaData) ?m.whenUsed,
          ],
      };

  /// The manifest [projectDir] would get, without writing anything (the
  /// Project Settings preview).
  static Future<ComposedAndroidManifest?> preview(String projectDir, LuminaProject project, List<LuminaPluginDescriptor> plugins) async {
    final file = File(manifestPath(projectDir));
    if (!await file.exists()) return null;
    final used = await usedClasses(projectDir, conditionalClasses(plugins));
    return AndroidManifestComposer.compose(
      template: await file.readAsString(),
      settings: project.packaging.android,
      plugins: [for (final p in plugins) if (p.android != null) (plugin: p.name, android: p.android!)],
      usedClasses: used,
    );
  }

  /// Runtime modules only (every target's build needs them).
  static Future<List<RuntimeModuleDependency>> applyRuntimeModules(
      String projectDir, LuminaProject project, List<LuminaPluginDescriptor> plugins) async {
    final deps = await RuntimeModuleDependencies.resolve(plugins);
    await RuntimeModuleDependencies.apply(projectDir, deps, settings: runtimeSettings(project));
    return deps;
  }

  /// What every runtime module's `register` receives: the project name and
  /// its Android settings (the XR profile, refresh rate, multiview).
  static Map<String, Object?> runtimeSettings(LuminaProject project) => {
        'project_name': project.projectName,
        ...project.packaging.android.toMap(),
      };

  /// Prepares [projectDir]'s Android app for a build.
  static Future<AndroidPreparation> prepare(String projectDir, LuminaProject project, List<LuminaPluginDescriptor> plugins) async {
    final manifestFile = File(manifestPath(projectDir));
    if (!await manifestFile.exists()) {
      throw StateError('The project has no Android app (android/app/src/main/AndroidManifest.xml): '
          'run `flutter create --platforms=android .` in $projectDir');
    }
    final settings = project.packaging.android;
    final previous = await manifestFile.readAsString();
    final used = await usedClasses(projectDir, conditionalClasses(plugins));
    final composed = AndroidManifestComposer.compose(
      template: previous,
      settings: settings,
      plugins: [for (final p in plugins) if (p.android != null) (plugin: p.name, android: p.android!)],
      usedClasses: used,
    );
    if (composed.xml != previous) await manifestFile.writeAsString(composed.xml);
    final gradle = await AndroidGradleConfigurator.apply(projectDir, settings, project.projectName);
    final deps = await applyRuntimeModules(projectDir, project, plugins);
    return AndroidPreparation(
      manifest: composed,
      previousManifest: previous,
      applicationId: settings.applicationIdFor(project.projectName),
      gradleChanged: gradle.gradleChanged,
      runtimeModules: deps,
    );
  }

  /// Renames the APK in [packageDir] to `<project>-<version>.apk` and writes
  /// its `.sha256` (`<hex>  <file>`).
  static Future<AndroidPackagedApk?> finishPackage(String packageDir, String projectName, String versionName) async {
    final dir = Directory(packageDir);
    if (!await dir.exists()) return null;
    File? apk;
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.apk')) apk = e;
    }
    if (apk == null) return null;
    final name = '${ProjectAndroidSettings.snakeName(projectName)}-${versionName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.apk';
    final target = File('$packageDir/$name');
    if (apk.path.replaceAll(r'\', '/') != target.path.replaceAll(r'\', '/')) {
      if (await target.exists()) await target.delete();
      apk = await apk.rename(target.path);
    }
    final path = apk.path;
    final digest = await Isolate.run(() => sha256.convert(File(path).readAsBytesSync()).toString());
    await File('$path.sha256').writeAsString('$digest  $name\n');
    final bytes = await apk.length();
    return AndroidPackagedApk(
      path: path,
      bytes: bytes,
      sha256: digest,
      warning: bytes > storeLimitBytes
          ? 'The APK is ${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB: above the store\'s 1 GB limit without expansion files.'
          : null,
    );
  }

  /// A minimal line diff of [before] → [after] (`-`/`+` lines, in order).
  static List<String> lineDiff(String before, String after) {
    final a = before.replaceAll('\r\n', '\n').split('\n');
    final b = after.replaceAll('\r\n', '\n').split('\n');
    // Longest common subsequence on lines (manifests are small).
    final n = a.length, m = b.length;
    final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    final out = <String>[];
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        out.add('- ${a[i++]}');
      } else {
        out.add('+ ${b[j++]}');
      }
    }
    while (i < n) {
      out.add('- ${a[i++]}');
    }
    while (j < m) {
      out.add('+ ${b[j++]}');
    }
    return out;
  }
}
