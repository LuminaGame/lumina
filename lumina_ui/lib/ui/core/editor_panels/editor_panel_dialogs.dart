import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Opens `dialog` panel [panelId] modally over the editor (sized from its
/// `minWidth` / `minHeight`; Escape dismisses). Completes with the Json its
/// graph passed to `Close This Panel`, or null when dismissed.
Future<Object?> showEditorPanelDialog(EditorPanelHost host, String panelId) async {
  final rt = host.panel(panelId);
  final context = _anchor(host);
  if (rt == null || context == null || !context.mounted) return null;
  final instance = host.open(panelId, another: true);
  if (instance == null) return null;
  final result = Completer<Object?>();
  instance.dialogResult = result;
  final overlay = showOverlay<void>(
    context,
    const DialogConfiguration(),
    builder: (ctx) {
      // Close This Panel (the dialog's own graph) pops the dialog.
      unawaited(result.future.then((_) {
        if (ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      }));
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: rt.info.minWidth, minHeight: rt.info.minHeight, maxWidth: rt.info.minWidth * 2),
        child: AlertDialog(
          key: ValueKey('editor_panel_dialog_$panelId'),
          title: Text(rt.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
          content: SizedBox(
            width: rt.info.minWidth,
            height: rt.info.minHeight,
            child: _DialogBody(host: host, panelId: panelId, instanceSerial: instance.serial),
          ),
        ),
      );
    },
  );
  await overlay.future.catchError((_) {});
  if (!result.isCompleted) result.complete(null);
  host.close(panelId, only: instance);
  return result.future;
}

BuildContext? _anchor(EditorPanelHost host) {
  for (final i in host.openInstances) {
    final c = i.viewContext;
    if (c != null && c.mounted) return c;
  }
  return host.vm.mcpServer.editorBoundaryKey.currentContext;
}

/// The dialog's body: the panel instance [instanceSerial] opened for it.
class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.host, required this.panelId, required this.instanceSerial});

  final EditorPanelHost host;
  final String panelId;
  final int instanceSerial;

  @override
  Widget build(BuildContext context) => EditorPanelView(host: host, panelId: panelId, dialogSerial: instanceSerial);
}
