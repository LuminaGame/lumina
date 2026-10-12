import 'dart:async';

import 'package:lumina_editor_data/lumina_editor.dart' show DlssSdk, DlssRuntimeBundle;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/dlss_sdk_download.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';

/// The licence notice beside the option (also what the widget tests check).
const String kDlssBundleLicenseNotice =
    'These files are NVIDIA\'s, not Lumina\'s: they are redistributed under the NVIDIA RTX SDKs licence, and shipping '
    'them is your decision. Your game must meet its distribution requirements (§2: material additional functionality, '
    'terms at least as protective as NVIDIA\'s; no stand-alone distribution, §4b) and must not make the SDK subject to an '
    'open-source licence (§4e), so do not bundle them into a game released under the GPL or another open-source licence. '
    'NVIDIA also asks to be notified before a commercial release and requires DLSS attribution on splash and credit '
    'screens (supplement §4, §7.1b). Which DLSS features the game uses (Super Resolution, Ray Reconstruction, Frame '
    'Generation) is chosen separately.';

/// Project Settings ▸ Packaging ▸ NVIDIA DLSS Runtime: the opt-in checkbox,
/// the licence notice with the licence text, and the DLSS SDK's state (where
/// it is, or how to fetch it, with a Fetch button and its progress).
class DlssBundlePanel extends StatefulWidget {
  const DlssBundlePanel({super.key, required this.vm});

  final ProjectSettingsViewModel vm;

  @override
  State<DlssBundlePanel> createState() => _DlssBundlePanelState();
}

class _DlssBundlePanelState extends State<DlssBundlePanel> {
  static const TextStyle _muted = TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground);

  @override
  void initState() {
    super.initState();
    // After the first frame: the view model notifies, and the editor rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.vm.dlssSdkLooked) unawaited(widget.vm.refreshDlssSdk());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final on = vm.project.packaging.bundleDlssRuntime;
    final running = vm.packaging.isRunning;
    return Column(
      key: const ValueKey('project_settings_dlss_bundle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Checkbox(
            key: const ValueKey('project_settings_bundle_dlss_runtime'),
            state: on ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: running ? null : (v) => vm.setBundleDlssRuntime(v == CheckboxState.checked),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Bundle NVIDIA DLSS runtime (Windows/Linux)', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
          ),
        ]),
        const SizedBox(height: 6),
        Alert(
          key: const ValueKey('project_settings_dlss_license_notice'),
          leading: const Icon(LucideIcons.scale, size: 14, color: EditorColors.warning),
          title: const Text('NVIDIA RTX SDKs licence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(kDlssBundleLicenseNotice, style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            const SizedBox(height: 6),
            Row(children: [
              OutlineButton(
                key: const ValueKey('project_settings_dlss_view_license'),
                density: ButtonDensity.compact,
                onPressed: vm.dlssSdk == null ? null : () => _showLicense(context),
                leading: const Icon(LucideIcons.fileText, size: 11),
                child: const Text('View licence', style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Packages get ${DlssRuntimeBundle.licenseFileName} and ${DlssRuntimeBundle.noticeFileName} next to the runtime.',
                  style: _muted,
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 6),
        _sdkState(vm),
      ],
    );
  }

  Widget _sdkState(ProjectSettingsViewModel vm) {
    final sdk = vm.dlssSdk;
    if (!vm.dlssSdkLooked) {
      return const Text('Looking for the DLSS SDK…', key: ValueKey('project_settings_dlss_sdk_looking'), style: _muted);
    }
    if (sdk == null) {
      return const Text(
        'No flutter_filament with the DLSS tooling (tool/dlss) was found for this project: packages cannot get the runtime.',
        key: ValueKey('project_settings_dlss_sdk_none'),
        style: TextStyle(fontSize: 8.5, color: EditorColors.logWarning),
      );
    }
    if (sdk.isFetched) {
      return Text(
        'DLSS SDK ${sdk.version}: ${sdk.sdkDir}',
        key: const ValueKey('project_settings_dlss_sdk_found'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.logSuccess),
      );
    }
    final download = vm.dlssSdkDownload;
    final failed = download.phase == DlssSdkDownloadPhase.failed;
    return Column(
      key: const ValueKey('project_settings_dlss_sdk_missing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The DLSS SDK ${sdk.version} is not fetched (${sdk.missing.length} file(s) missing in ${sdk.sdkDir}).',
          style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning),
        ),
        const SizedBox(height: 4),
        if (download.isRunning) ...[
          SizedBox(
            width: 260,
            height: 4,
            child: LinearProgressIndicator(key: const ValueKey('project_settings_dlss_fetch_progress'), value: download.progress),
          ),
          const SizedBox(height: 3),
          Text(download.message ?? '', key: const ValueKey('project_settings_dlss_fetch_message'), style: _muted),
        ] else
          OutlineButton(
            key: ValueKey(failed ? 'project_settings_dlss_fetch_retry' : 'project_settings_dlss_fetch'),
            density: ButtonDensity.compact,
            onPressed: () => unawaited(vm.fetchDlssSdk()),
            leading: Icon(failed ? LucideIcons.rotateCw : LucideIcons.download, size: 11),
            child: Text(failed ? 'Retry fetch' : 'Fetch DLSS SDK', style: const TextStyle(fontSize: 10)),
          ),
        if (failed && download.error != null) ...[
          const SizedBox(height: 3),
          Text(download.error!,
              key: const ValueKey('project_settings_dlss_fetch_error'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.5, color: EditorColors.logError)),
        ],
        const SizedBox(height: 3),
        Text('Or run `${DlssSdk.fetchCommand}` in ${sdk.packageRoot}', key: const ValueKey('project_settings_dlss_fetch_hint'), style: _muted),
      ],
    );
  }

  Future<void> _showLicense(BuildContext context) async {
    final text = await widget.vm.readDlssLicense();
    if (!context.mounted) return;
    final sdk = widget.vm.dlssSdk;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('project_settings_dlss_license_dialog'),
        title: const Text('NVIDIA RTX SDKs licence'),
        content: SizedBox(
          width: 640,
          height: 420,
          child: SingleChildScrollView(
            child: Text(
              text ?? 'The licence is not fetched yet: ${sdk?.licenseFile ?? 'build/dlss-sdk/LICENSE.txt'} is missing. '
                  'Fetch the DLSS SDK, or read it at https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt.',
              key: const ValueKey('project_settings_dlss_license_text'),
              style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
            ),
          ),
        ),
        actions: [
          PrimaryButton(
            key: const ValueKey('project_settings_dlss_license_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
