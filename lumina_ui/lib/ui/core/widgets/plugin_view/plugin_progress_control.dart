import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.progress]: `value` (0..1, or null for an indeterminate
/// bar) and `text` under the bar, with the percentage when determinate.
class PluginProgressControl extends StatelessWidget {
  const PluginProgressControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) {
    final c = control;
    final value = c.number('value')?.toDouble().clamp(0.0, 1.0);
    final text = c.string('text');
    final percent = value == null ? null : '${(value * 100).round()}%';
    final caption = const TextStyle(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 4,
          color: EditorColors.primary,
          backgroundColor: EditorColors.muted,
        ),
        if (text != null || percent != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: Text(text ?? '', overflow: TextOverflow.ellipsis, style: caption)),
              if (percent != null) Text(percent, style: EditorTypography.mono(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground)),
            ],
          ),
        ],
      ],
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, child: body));
  }
}
