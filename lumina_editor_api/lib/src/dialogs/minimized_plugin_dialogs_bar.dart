import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_editor_api/src/dialogs/plugin_dialog_controller.dart';

/// Renders minimized plugin dialog chips in the editor's status bar.
///
/// When a plugin dialog is minimized, it docks here with the plugin's icon
/// and active progress. Clicking the chip restores the dialog to the center.
class MinimizedPluginDialogsBar extends StatelessWidget {
  final double horizontalGap;

  const MinimizedPluginDialogsBar({
    super.key,
    this.horizontalGap = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PluginDialogManager.instance,
      builder: (context, _) {
        final minimized = PluginDialogManager.instance.minimizedDialogs;
        if (minimized.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in minimized) ...[
              Tooltip(
                tooltip: (context) => TooltipContainer(
                  child: Text('${d.title} (Click to restore)'),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => d.restore(context),
                    child: Container(
                      height: 18,
                      margin: EdgeInsets.only(right: horizontalGap),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            d.pluginIcon ?? LucideIcons.appWindow,
                            size: 10,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.minimizedTitle,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: colorScheme.foreground,
                            ),
                          ),
                          if (d.progress != null) ...[
                            const SizedBox(width: 5),
                            SizedBox(
                              width: 38,
                              height: 4,
                              child: Progress(progress: d.progress!.clamp(0.0, 1.0)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(d.progress! * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontFamily: 'monospace',
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
