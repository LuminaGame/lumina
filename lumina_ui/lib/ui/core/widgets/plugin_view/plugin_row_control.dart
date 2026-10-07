import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.row]: children side by side, `gap` px apart (default
/// 8). Buttons keep their own width; text shrinks to fit; every other
/// control shares the remaining width equally.
class PluginRowControl extends StatelessWidget {
  const PluginRowControl({super.key, required this.control, required this.children});

  final PluginControl control;

  /// Each child control with its widget, built by the renderer.
  final List<(PluginControl, Widget)> children;

  @override
  Widget build(BuildContext context) {
    final gap = control.number('gap')?.toDouble() ?? EditorDensity.gutter;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          switch (children[i].$1.kind) {
            PluginControlKind.button => children[i].$2,
            PluginControlKind.text => Flexible(child: children[i].$2),
            _ => Expanded(child: children[i].$2),
          },
        ],
      ],
    );
    return withPluginTooltip(control.tooltip, row);
  }
}
