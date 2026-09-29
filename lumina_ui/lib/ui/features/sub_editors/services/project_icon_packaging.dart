import 'dart:typed_data';

import 'package:lumina/lumina.dart';

import 'build_pipeline_service.dart';
import 'project_icon_rasterizer.dart';

/// The project icon's part of a packaging run, plugged
/// into [PackageTargetsStep]:
/// - before a target's `flutter build`, that platform's app-icon files are
///   written from the project icon ([AppIconService]);
/// - after a Linux target is packaged, the bundle gets its `.desktop` entry
///   and the executable its file-manager icon ([LinuxBundleBranding]);
/// - before a web build, the loading screen is generated from the project's
///   Web Loading Style, with the project icon as its default logo
/// ([WebLoadingScreenService]).
///
/// The icon is rasterized once per run.
class ProjectIconPackaging {
  final String projectDir;
  final LuminaProject project;

  ProjectIconPackaging({required this.projectDir, required this.project});

  Future<Uint8List>? _master;

  /// The project icon at 512 px, the web loading screen's default logo.
  Uint8List? _webLogo;

  String get iconLabel => project.branding.usesDefaultIcon ? 'the Lumina logo (default)' : project.branding.icon;

  /// Writes [target]'s app-icon files. Returns why it could not, or null.
  Future<String?> beforeBuild(BuildStepContext ctx, String target) async {
    final Uint8List master;
    try {
      master = await (_master ??= ProjectIconRasterizer.masterPng(projectDir, project.branding));
    } catch (e) {
      return 'the project icon ($iconLabel) could not be rendered: $e';
    }
    if (target == 'web') {
      try {
        _webLogo = await ProjectIconRasterizer.rasterizeImage(master, size: 512);
      } catch (e) {
        ctx.log('Web loading screen: the project icon could not be resized ($e); using web/icons/Icon-512.png', level: 'warning');
      }
    }
    final background = project.branding.iconBackgroundArgb;
    if (background == null) return 'Icon Background "${project.branding.iconBackground}" is not a #RRGGBB colour';
    final report = await AppIconService.writeAsync(
      projectDir: projectDir,
      masterPng: master,
      appName: project.projectName,
      backgroundArgb: background,
      platforms: [target],
    );
    final result = report.platforms[target]!;
    if (!result.written) {
      // flutter build reports the missing platform folder itself.
      ctx.log('App icon not written: ${result.skippedReason}', level: 'warning');
      return null;
    }
    ctx.log('App icon from $iconLabel: wrote ${result.files.length} file(s) (${result.files.first}${result.files.length > 1 ? ', …' : ''})');
    for (final w in result.warnings) {
      ctx.log('App icon: $w', level: 'warning');
    }
    if (target == 'web') _writeWebLoadingScreen(ctx);
    return null;
  }

  /// `web/index.html`, `loading.css`, `loading.js`, `flutter_bootstrap.js`
  /// and the logo, from the project's Web Loading Style.
  void _writeWebLoadingScreen(BuildStepContext ctx) {
    final style = project.packaging.webLoadingStyle.resolve(project);
    final report = WebLoadingScreenService.write(
      projectDir: projectDir,
      project: project,
      iconPng: style.logo == ProjectWebLoadingStyle.logoFromIcon ? _webLogo : null,
    );
    if (!report.written) {
      ctx.log('Web loading screen not written: ${report.skippedReason}', level: 'warning');
      return;
    }
    ctx.log('Web loading screen "${style.title}" (${style.progressStyle}): wrote ${report.files.join(', ')}');
    for (final w in report.warnings) {
      ctx.log('Web loading screen: $w', level: 'warning');
    }
  }

  /// Finishes a packaged Linux bundle (and Flutter's own bundle it was
  /// copied from): `.desktop` entry and file-manager icon.
  Future<void> afterPackage(BuildStepContext ctx, String target, String artifactPath, String packageDir) async {
    if (target != 'linux') return;
    final appId = AppIconService.linuxApplicationId(projectDir) ?? 'com.example.${project.projectName}';
    final exe = AppIconService.linuxBinaryName(projectDir) ?? project.projectName;
    for (final dir in [packageDir, artifactPath]) {
      final report = await LinuxBundleBranding.finish(bundleDir: dir, executableName: exe, appName: project.projectName, applicationId: appId);
      for (final m in report.messages) {
        ctx.log(m, level: report.ok ? 'info' : 'warning');
      }
    }
  }
}
