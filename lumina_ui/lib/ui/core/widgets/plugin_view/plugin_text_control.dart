import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/editor_theme.dart';
import 'plugin_view_scope.dart';

/// [PluginControlKind.text]: `value` in one of the styles `body`, `muted`,
/// `heading`, `code` or `error`.
class PluginTextControl extends StatelessWidget {
  const PluginTextControl({super.key, required this.control});

  final PluginControl control;

  static TextStyle styleOf(String? style) => switch (style) {
        'muted' => const TextStyle(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
        'heading' => const TextStyle(
            fontSize: EditorTypography.bodySize + 1, fontWeight: FontWeight.w600, color: EditorColors.foreground),
        'code' => EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.secondaryForeground),
        'error' => const TextStyle(fontSize: EditorTypography.labelSize, color: EditorColors.destructive),
        _ => const TextStyle(fontSize: EditorTypography.labelSize, color: EditorColors.foreground),
      };

  @override
  Widget build(BuildContext context) {
    final text = Text(control.string('value') ?? '', style: styleOf(control.string('style')));
    return withPluginTooltip(control.tooltip, PluginFieldRow(label: control.label, child: text));
  }
}
