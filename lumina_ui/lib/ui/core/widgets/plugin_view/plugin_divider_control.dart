import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/editor_theme.dart';

/// [PluginControlKind.divider]: a thin rule between controls.
class PluginDividerControl extends StatelessWidget {
  const PluginDividerControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: EditorDensity.gap),
        child: Divider(height: 1, color: EditorColors.border),
      );
}
