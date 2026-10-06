import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../features/main_editor/views/editor_slot_bar.dart' show editorToneColor;
import 'plugin_view_scope.dart';

/// [PluginControlKind.button]: `text`, `tone` ([EditorTone] name), `icon`
/// ([PluginIconSpec] json). Sends `pressed`.
///
/// The icon is drawn as its glyph from the named font, not as an
/// `IconData`, so the editor's release build keeps tree-shaking its icon
/// fonts; a glyph the editor never uses itself may be missing from a
/// tree-shaken build (Lucide icons the editor uses always draw).
class PluginButtonControl extends StatelessWidget {
  const PluginButtonControl({super.key, required this.control});

  final PluginControl control;

  static EditorTone toneOf(PluginControl c) =>
      EditorTone.values.where((t) => t.name == c.string('tone')).firstOrNull ?? EditorTone.neutral;

  @override
  Widget build(BuildContext context) {
    final c = control;
    final tone = toneOf(c);
    final enabled = c.enabled;
    final icon = PluginIconSpec.fromJson(c.props['icon']);
    final color = switch (tone) {
      EditorTone.success || EditorTone.warning => editorToneColor(tone),
      _ => null,
    };
    final label = Text(c.string('text') ?? c.label ?? c.id, style: TextStyle(fontSize: 10, color: color));
    final leading = icon == null
        ? null
        : Text(
            String.fromCharCode(icon.codePoint),
            style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 12, color: color, height: 1),
          );
    final VoidCallback? onPressed = enabled ? () => PluginViewScope.of(context).emit(c.id, 'pressed') : null;
    final style = switch (tone) {
      EditorTone.primary => const ButtonStyle.primary(density: ButtonDensity.compact),
      EditorTone.destructive => const ButtonStyle.destructive(density: ButtonDensity.compact),
      _ => const ButtonStyle.outline(density: ButtonDensity.compact),
    };
    final button = Button(style: style, onPressed: onPressed, enabled: enabled, leading: leading, child: label);
    return withPluginTooltip(c.tooltip, Align(alignment: Alignment.centerLeft, child: button));
  }
}
