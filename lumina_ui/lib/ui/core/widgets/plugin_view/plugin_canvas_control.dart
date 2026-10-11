import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/editor_canvas.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_native_control.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.canvas]: the editor's native canvas over the
/// control's props ([PluginCanvasState]; `height`, default 200). Image
/// items resolve project paths against the view's project.
class PluginCanvasControl extends StatelessWidget {
  const PluginCanvasControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) => PluginNativeControl(
        control: control,
        defaultHeight: 200,
        builder: (context, state, onEvent, onState) => EditorCanvas(
          name: control.id,
          state: state,
          onEvent: onEvent,
          onState: onState,
          projectDir: PluginViewScope.of(context).projectDir,
        ),
      );
}
