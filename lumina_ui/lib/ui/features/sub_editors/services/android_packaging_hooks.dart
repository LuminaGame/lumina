import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

/// The enabled plugins' part of a packaging run, plugged into
/// [PackageTargetsStep] next to the project icon:
/// - before every target's `flutter build`, the enabled plugins' runtime
///   modules become game dependencies (pubspec, local pins, the generated
///   registration `main()` calls);
/// - before an Android build, the manifest is composed from Flutter's
///   template, the project's Android settings and the plugins'
///   contributions (its diff goes to the log), and the Gradle settings are
///   written ([AndroidPackaging.prepare]);
/// - after an Android target is packaged, the APK is named
///   `<project>-<version>.apk` with its `.sha256`, and its size reported.
class AndroidPackagingHooks {
  final String projectDir;
  final LuminaProject project;

  /// The enabled plugins; default [enabledPluginsOf].
  final Future<List<LuminaPluginDescriptor>> Function()? plugins;

  AndroidPackagingHooks({required this.projectDir, required this.project, this.plugins});

  Future<List<LuminaPluginDescriptor>>? _plugins;

  /// The project's enabled plugins, from the editor's plugin roots.
  static Future<List<LuminaPluginDescriptor>> enabledPluginsOf(String projectDir, LuminaProject project) async {
    final enabled = project.enabledPlugins ?? const <String>[];
    if (enabled.isEmpty) return const [];
    final scan = await PluginRepository(roots: editorPluginScanRoots(projectDir)).scanAll();
    return [for (final p in scan.plugins) if (enabled.contains(p.name)) p];
  }

  Future<List<LuminaPluginDescriptor>> _enabled() => _plugins ??= (plugins ?? () => enabledPluginsOf(projectDir, project))();

  /// Returns why [target] cannot be built, or null.
  Future<String?> beforeBuild(BuildStepContext ctx, String target) async {
    final List<LuminaPluginDescriptor> enabled;
    try {
      enabled = await _enabled();
    } catch (e) {
      return 'the enabled plugins could not be read: $e';
    }
    try {
      if (target != 'android') {
        final deps = await AndroidPackaging.applyRuntimeModules(projectDir, project, enabled);
        if (deps.isNotEmpty) ctx.log('Plugin runtime modules: ${deps.map((d) => d.package).join(', ')}');
        return null;
      }
      final prep = await AndroidPackaging.prepare(projectDir, project, enabled);
      final android = project.packaging.android;
      ctx.log('Android ${android.isQuest ? '(Meta Quest)' : ''}: ${prep.applicationId}, '
          'minSdk ${android.minSdk}, targetSdk ${android.targetSdk}, ${android.abis.join(', ')}, '
          '${android.hasReleaseKeystore ? 'release keystore ${android.keystorePath}' : 'debug signing'}');
      if (prep.runtimeModules.isNotEmpty) ctx.log('Plugin runtime modules: ${prep.runtimeModules.map((d) => d.package).join(', ')}');
      final diff = prep.manifestDiff;
      ctx.log(diff.isEmpty
          ? 'AndroidManifest.xml unchanged (${prep.manifest.summary.join(', ')})'
          : 'AndroidManifest.xml composed (${prep.manifest.summary.join(', ')}); ${diff.length} changed line(s):');
      for (final line in diff) {
        ctx.log('  $line');
      }
      if (android.hasReleaseKeystore) {
        ctx.log('The release keystore passwords are read from ${AndroidGradleConfigurator.storePasswordVariable} '
            'and ${AndroidGradleConfigurator.keyPasswordVariable}.');
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> afterPackage(BuildStepContext ctx, String target, String artifactPath, String packageDir) async {
    if (target != 'android') return;
    final apk = await AndroidPackaging.finishPackage(packageDir, project.projectName, project.packaging.android.versionName);
    if (apk == null) {
      ctx.log('No APK in $packageDir', level: 'warning');
      return;
    }
    ctx.log('APK ${apk.path} (${CookAndPackageStep.formatBytes(apk.bytes)}), sha256 ${apk.sha256}', level: 'success');
    if (apk.warning != null) ctx.log(apk.warning!, level: 'warning');
  }
}

/// [first] then [second]: the first problem wins.
Future<String?> Function(BuildStepContext, String) chainBeforeBuild(
        Future<String?> Function(BuildStepContext, String)? first, Future<String?> Function(BuildStepContext, String) second) =>
    (ctx, target) async => await first?.call(ctx, target) ?? await second(ctx, target);

/// [first] then [second].
Future<void> Function(BuildStepContext, String, String, String) chainAfterPackage(
        Future<void> Function(BuildStepContext, String, String, String)? first,
        Future<void> Function(BuildStepContext, String, String, String) second) =>
    (ctx, target, artifact, dir) async {
      await first?.call(ctx, target, artifact, dir);
      await second(ctx, target, artifact, dir);
    };
