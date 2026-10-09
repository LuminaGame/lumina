import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_module_download.dart';

/// The status bar's web module segment: the download's progress while it
/// runs (started at launch or from Packaging), a warning after it failed
/// (Project Settings ▸ Packaging retries); nothing otherwise.
class WebModuleStatusSegment extends StatelessWidget {
  const WebModuleStatusSegment({super.key, this.download});

  /// Default [WebModuleDownload.instance].
  final WebModuleDownload? download;

  @override
  Widget build(BuildContext context) {
    final d = download ?? WebModuleDownload.instance;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final failed = d.phase == WebModuleDownloadPhase.failed;
        if (!d.isDownloading && !failed) return const SizedBox.shrink();
        final color = failed ? EditorColors.logWarning : EditorColors.mutedForeground;
        return Tooltip(
          tooltip: (context) => TooltipContainer(child: Text(failed ? (d.error ?? '') : (d.message ?? ''))),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(failed ? LucideIcons.triangleAlert : LucideIcons.download, size: 10, color: color),
              const SizedBox(width: 4),
              Text(
                failed ? 'Web module download failed' : 'Web module ${(d.progress * 100).round()}%',
                key: const ValueKey('status_web_module'),
                style: TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: color),
              ),
            ]),
          ),
        );
      },
    );
  }
}
