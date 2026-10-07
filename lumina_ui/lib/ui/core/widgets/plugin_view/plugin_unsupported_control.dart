import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// A control kind this editor does not know (a newer plugin protocol): one
/// muted line naming it instead of an error.
class PluginUnsupportedControl extends StatelessWidget {
  const PluginUnsupportedControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) => Text(
        'unsupported control ${control.kind}',
        style: const TextStyle(
            fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
      );
}
