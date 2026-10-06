import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_view/plugin_view_renderer.dart';

/// The body of an isolated plugin's declarative panel: the view the
/// process last sent ([view], replaced or patched by `host.view`), rendered
/// by [PluginViewRenderer]; the user's actions go back through [onEvent]
/// (`core.viewEvent`). The editor wraps it in the plugin's process guard.
class PluginProcessPanelView extends StatelessWidget {
  const PluginProcessPanelView({super.key, required this.view, required this.onEvent, this.projectDir});

  final ValueListenable<PluginViewSpec> view;
  final void Function(PluginViewEvent event) onEvent;
  final String? projectDir;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PluginViewSpec>(
        valueListenable: view,
        builder: (context, spec, _) => PluginViewRenderer(spec: spec, onEvent: onEvent, projectDir: projectDir),
      );
}
