import 'dart:async';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_dialog_controller.dart';

/// Standard frame for all Lumina Studio plugin dialogs.
///
/// Provides:
/// - Top header with title, plugin icon, minimize button (to status bar) and close button.
/// - Content area hosting the plugin's dialog body.
/// - Bottom status bar displaying which plugin called it, dynamic status text,
///   and live progress bar.
class PluginDialogFrame extends StatelessWidget {
  final PluginDialogController controller;
  final Widget child;

  const PluginDialogFrame({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final maxWidth = (media.size.width - 40).clamp(320.0, controller.width);
    final maxHeight = (media.size.height - 60).clamp(240.0, controller.height);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Center(
          child: SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: Card(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header Bar
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        border: Border(bottom: BorderSide(color: colorScheme.border)),
                      ),
                      child: Row(
                        children: [
                          if (controller.pluginIcon != null) ...[
                            Icon(controller.pluginIcon, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              controller.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Minimize button (docks to status bar)
                          Tooltip(
                            tooltip: (context) => TooltipContainer(child: const Text('Minimize to status bar')),
                            child: GhostButton(
                              density: ButtonDensity.compact,
                              onPressed: controller.minimize,
                              child: const Icon(LucideIcons.minus, size: 12),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button
                          Tooltip(
                            tooltip: (context) => TooltipContainer(child: const Text('Close')),
                            child: GhostButton(
                              density: ButtonDensity.compact,
                              onPressed: controller.close,
                              child: const Icon(LucideIcons.x, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Dialog Content Area
                    Expanded(child: child),

                    // 3. Bottom Status Bar (which plugin called it)
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.card.withValues(alpha: 0.92),
                        border: Border(top: BorderSide(color: colorScheme.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (controller.pluginIcon != null) ...[
                                  Icon(controller.pluginIcon, size: 10, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  'Plugin: ${controller.pluginName}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (controller.statusText != null && controller.statusText!.isNotEmpty)
                            Expanded(
                              child: Text(
                                controller.statusText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: colorScheme.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (controller.progress != null) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              height: 6,
                              child: Progress(progress: controller.progress!.clamp(0.0, 1.0)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(controller.progress! * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Presents a [PluginDialogFrame] modal over the editor.
///
/// Features:
/// - [barrierDismissible] is false by default: clicking outside does not dismiss.
/// - Top header carries minimize and close buttons.
/// - Bottom bar clearly identifies which plugin called the dialog.
/// - Minimizing the dialog docks it into the editor's status bar with the plugin's icon;
///   clicking the status bar chip restores the dialog seamlessly.
Future<T?> showPluginDialog<T>({
  required BuildContext context,
  required String pluginId,
  required String pluginName,
  IconData? pluginIcon,
  required String title,
  String? minimizedTitle,
  required PluginDialogBuilder builder,
  bool barrierDismissible = false,
  double width = 640,
  double height = 670,
  PluginDialogController? controller,
  VoidCallback? onCancelled,
  VoidCallback? onCompleted,
  dynamic taskData,
}) async {
  final ctrl = controller ??
      PluginDialogController(
        pluginId: pluginId,
        pluginName: pluginName,
        pluginIcon: pluginIcon,
        title: title,
        minimizedTitle: minimizedTitle,
        barrierDismissible: barrierDismissible,
        width: width,
        height: height,
        builder: builder,
        onCancelled: onCancelled,
        onCompleted: onCompleted,
        taskData: taskData,
      );

  ctrl.isMinimized = false;
  PluginDialogManager.instance.register(ctrl);

  BuildContext? activeDialogContext;

  ctrl.attachOverlayHandlers(
    onMinimize: () {
      if (activeDialogContext != null && activeDialogContext!.mounted) {
        closeOverlay(activeDialogContext!);
      }
    },
    onClose: () {
      if (activeDialogContext != null && activeDialogContext!.mounted) {
        closeOverlay(activeDialogContext!);
      }
      ctrl.onCancelled?.call();
    },
    onRestore: (restoreContext) {
      unawaited(showPluginDialog<T>(
        context: restoreContext,
        pluginId: ctrl.pluginId,
        pluginName: ctrl.pluginName,
        pluginIcon: ctrl.pluginIcon,
        title: ctrl.title,
        minimizedTitle: ctrl.minimizedTitle,
        barrierDismissible: ctrl.barrierDismissible,
        width: ctrl.width,
        height: ctrl.height,
        controller: ctrl,
        builder: ctrl.builder,
        onCancelled: ctrl.onCancelled,
        onCompleted: ctrl.onCompleted,
        taskData: ctrl.taskData,
      ));
    },
  );

  final completer = showOverlay<T>(
    context,
    DialogConfiguration(barrierDismissible: barrierDismissible),
    builder: (dialogCtx) {
      activeDialogContext = dialogCtx;
      return PluginDialogFrame(
        controller: ctrl,
        child: ctrl.builder(dialogCtx, ctrl),
      );
    },
  );

  final result = await completer.future;
  activeDialogContext = null;

  if (!ctrl.isMinimized) {
    ctrl.close();
  }

  return result;
}
