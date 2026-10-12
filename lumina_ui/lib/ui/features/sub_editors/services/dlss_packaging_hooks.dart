import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

/// The NVIDIA DLSS runtime's part of a packaging run, plugged into
/// [PackageTargetsStep] when the project's Bundle NVIDIA DLSS runtime option
/// is on (`packaging.bundle_dlss_runtime`):
/// - before a Windows or Linux build, the DLSS SDK of the flutter_filament the
///   game builds against must be fetched, or the target fails with how to
///   fetch it;
/// - after a Windows or Linux target is packaged, the runtime libraries,
///   NVIDIA's licence and a notice go next to the executable
///   ([DlssRuntimeBundle]), every file verified against the manifest first;
///   each bundled file is logged.
///
/// Other targets (web, Android, macOS, iOS) never get the files. With the
/// option off nothing happens.
class DlssPackagingHooks {
  final String projectDir;
  final LuminaProject project;

  /// Where flutter_filament is looked for when the project does not resolve
  /// one yet; default: the editor's source checkout.
  final List<String>? fallbackPackageRoots;

  DlssPackagingHooks({required this.projectDir, required this.project, this.fallbackPackageRoots});

  Future<DlssSdk?>? _sdk;

  bool get enabled => project.packaging.bundleDlssRuntime;

  Future<DlssSdk?> _locate() => _sdk ??= DlssSdk.locate(projectDir, fallbackPackageRoots: fallbackPackageRoots);

  /// Returns why [target] cannot be built with the runtime bundled, or null.
  Future<String?> beforeBuild(BuildStepContext ctx, String target) async {
    if (!enabled) return null;
    if (!DlssSdk.supportsTarget(target)) {
      ctx.log('NVIDIA DLSS runtime: not bundled into the ${packagingPlatformLabel(target)} package (Windows and Linux only)');
      return null;
    }
    final sdk = await _locate();
    if (sdk == null) {
      return 'Bundle NVIDIA DLSS runtime is on, but no flutter_filament with tool/dlss was found for this project. '
          'Turn the option off or build against a Lumina source checkout.';
    }
    if (!sdk.isFetched) return 'Bundle NVIDIA DLSS runtime is on, but ${sdk.missingReason}';
    ctx.log('NVIDIA DLSS runtime ${sdk.version} from ${sdk.sdkDir} will be bundled (NVIDIA RTX SDKs licence)');
    return null;
  }

  /// Bundles the runtime into [packageDir]; throws [DlssBundleRefused] (the
  /// target fails) when a file does not match the manifest.
  Future<void> afterPackage(BuildStepContext ctx, String target, String artifactPath, String packageDir) async {
    if (!enabled || !DlssSdk.supportsTarget(target)) return;
    final sdk = await _locate();
    if (sdk == null) throw const DlssBundleRefused('no flutter_filament with tool/dlss was found for this project');
    final report = await DlssRuntimeBundle.bundleInto(sdk, target: target, packageDir: packageDir);
    final lines = DlssRuntimeBundle.describe(report);
    for (var i = 0; i < lines.length; i++) {
      ctx.log(lines[i], level: i == lines.length - 1 ? 'success' : 'info');
    }
  }
}
