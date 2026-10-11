import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_trust_prompt.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// One editor panel as the Plugin Manager and the plugin import
/// confirmation list it: its title, where it docks, what it may do and,
/// once compiled, whether it runs.
class EditorPanelSummary {
  const EditorPanelSummary({required this.title, required this.info, this.state});

  final String title;
  final LuminaEditorPanelInfo? info;

  /// `Ready`, `N errors`; null before compiling (an import).
  final String? state;

  factory EditorPanelSummary.ofRuntime(EditorPanelRuntime rt) => EditorPanelSummary(
        title: rt.title,
        info: rt.entry.info,
        state: rt.hasErrors ? '${rt.errors.length} error${rt.errors.length == 1 ? '' : 's'}' : 'Ready',
      );

  factory EditorPanelSummary.ofEntry(EditorPanelEntry e) =>
      EditorPanelSummary(title: e.displayTitle, info: e.info, state: e.infoError == null ? null : 'Invalid');

  String get capabilityText {
    final caps = info?.capabilities ?? const <LuminaEditorPanelCapability>{};
    return caps.isEmpty ? 'reads the editor only' : [for (final c in caps) editorPanelCapabilityText(c)].join(', ');
  }
}

/// The "Editor Panels" list: one row per panel with its dock, capabilities
/// and state.
class EditorPanelSummaryList extends StatelessWidget {
  const EditorPanelSummaryList({super.key, required this.panels, this.title = 'Editor Panels'});

  final List<EditorPanelSummary> panels;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (panels.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('editor_panel_summary_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        for (final p in panels)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.panelsTopLeft, size: 12, color: EditorColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${p.title} · ${p.info?.dock.name ?? '?'}',
                      style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  Text('Can ${p.capabilityText}.', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                ]),
              ),
              if (p.state != null)
                Text(p.state!,
                    style: TextStyle(fontSize: 10, color: p.state == 'Ready' ? EditorColors.logSuccess : EditorColors.logError)),
            ]),
          ),
      ],
    );
  }
}
