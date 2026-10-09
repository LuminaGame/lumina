import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_module_download.dart';

/// The Web target's module line in Packaging: while flutter_filament's
/// WebAssembly module is missing, a download button (progress while it
/// runs, the error and a retry after a failure) with the local-build hint
/// as secondary text; once found, where it comes from.
class WebModuleDownloadPanel extends StatelessWidget {
  const WebModuleDownloadPanel({super.key, required this.download, required this.module});

  final WebModuleDownload download;

  /// The module the web build stages, or null while there is none.
  final FlutterFilamentWebModule? module;

  static const TextStyle _muted = TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: download,
      builder: (context, _) {
        final found = module;
        if (found != null) {
          final from = found.source == FlutterFilamentWebModuleSource.download
              ? 'Web module: downloaded ${download.install?.tag ?? ''}'.trimRight()
              : 'Web module: local build';
          return Padding(
            padding: const EdgeInsets.only(left: 28, top: 1),
            child: Text('$from (${found.directory.path})',
                key: const ValueKey('project_settings_web_module_found'), maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Column(
            key: const ValueKey('project_settings_web_module'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                download.isDownloading
                    ? "Downloading flutter_filament's WebAssembly module…"
                    : "flutter_filament's WebAssembly module (flutter_filament.js + .wasm) is not installed yet.",
                style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning),
              ),
              const SizedBox(height: 4),
              if (download.isDownloading) ...[
                SizedBox(
                  width: 260,
                  height: 4,
                  child: LinearProgressIndicator(key: const ValueKey('project_settings_web_module_progress'), value: download.progress),
                ),
                const SizedBox(height: 3),
                Text(download.message ?? '', key: const ValueKey('project_settings_web_module_message'), style: _muted),
              ] else
                Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlineButton(
                    key: ValueKey(download.phase == WebModuleDownloadPhase.failed
                        ? 'project_settings_web_module_retry'
                        : 'project_settings_web_module_download'),
                    onPressed: () => download.phase == WebModuleDownloadPhase.failed ? download.retry() : download.start(),
                    leading: Icon(download.phase == WebModuleDownloadPhase.failed ? LucideIcons.rotateCw : LucideIcons.download, size: 11),
                    child: Text(download.phase == WebModuleDownloadPhase.failed ? 'Retry download' : 'Download web module',
                        style: const TextStyle(fontSize: 10)),
                  ),
                ]),
              if (download.phase == WebModuleDownloadPhase.failed && download.error != null) ...[
                const SizedBox(height: 3),
                Text(download.error!,
                    key: const ValueKey('project_settings_web_module_error'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8.5, color: EditorColors.logError)),
              ],
              const SizedBox(height: 3),
              const Text(FlutterFilamentWebModule.buildHint, key: ValueKey('project_settings_web_module_hint'), style: _muted),
            ],
          ),
        );
      },
    );
  }
}
