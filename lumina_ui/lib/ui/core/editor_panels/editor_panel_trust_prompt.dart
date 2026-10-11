import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorPanelCapability;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// What each capability lets a panel do, for the trust prompt and the
/// Plugin Manager.
String editorPanelCapabilityText(LuminaEditorPanelCapability c) => switch (c) {
      LuminaEditorPanelCapability.level => 'edit level actors',
      LuminaEditorPanelCapability.assets => 'change project assets',
      LuminaEditorPanelCapability.process => 'talk to its plugin process',
      LuminaEditorPanelCapability.mcp => 'expose tools to AI agents (MCP)',
    };

/// Asks once whether the project's editor panels may run: lists each
/// untrusted panel with its capabilities; "Trust and run" stores the
/// decision per user (by project path and capability hash), "Not now"
/// leaves them stopped. Returns whether the user trusted them.
Future<bool> showEditorPanelTrustPrompt(BuildContext context, EditorPanelHost host) async {
  final panels = host.untrustedProjectPanels;
  if (panels.isEmpty) return true;
  final ok = await showOverlay<bool>(
    context,
    const DialogConfiguration(),
    builder: (ctx) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: AlertDialog(
        key: const ValueKey('editor_panel_trust_dialog'),
        title: const Text('Run this project\'s editor panels?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'The project ships editor panels: graphs that run inside Lumina Studio. Run them only for a project you trust.',
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          for (final rt in panels)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(rt.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                Text(
                  rt.info.capabilities.isEmpty
                      ? 'Reads the editor only.'
                      : 'Can ${[for (final c in rt.info.capabilities) editorPanelCapabilityText(c)].join(', ')}.',
                  style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                ),
                Text(rt.entry.assetPath, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ]),
            ),
        ]),
        actions: [
          OutlineButton(
            key: const ValueKey('editor_panel_trust_not_now'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          PrimaryButton(
            key: const ValueKey('editor_panel_trust_run'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Trust and run'),
          ),
        ],
      ),
    ),
  ).future;
  if (ok == true) await host.trustProjectPanels([for (final p in panels) p.id]);
  return ok == true;
}
