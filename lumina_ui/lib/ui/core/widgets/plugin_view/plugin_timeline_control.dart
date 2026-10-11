import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_native_control.dart';

/// [PluginControlKind.timeline]: the editor's native timeline over the
/// control's props ([PluginTimelineState]; `height`, default 220). A
/// `boundViewport` drives a Viewport element only in an editor panel.
class PluginTimelineControl extends StatelessWidget {
  const PluginTimelineControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) => PluginNativeControl(
        control: control,
        defaultHeight: 220,
        builder: (context, state, onEvent, onState) =>
            EditorTimeline(name: control.id, state: state, onEvent: onEvent, onState: onState),
      );
}
