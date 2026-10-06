import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_control_cache.dart';
import 'plugin_section_control.dart';
import 'plugin_view_scope.dart';

/// Renders a plugin's declarative panel ([PluginViewSpec]) with the
/// editor's shadcn widgets, one widget per control kind, keyed
/// `<viewId>/<controlId>`; user actions come back as [PluginViewEvent]s.
/// [projectDir] lets asset-ref fields and 3D previews resolve paths.
///
/// Pass a new spec (for example `spec.apply(patch)`) to update it: controls
/// that render the same keep their widgets untouched (focus, caret, typing,
/// collapsed sections, scroll positions); only changed ones rebuild. An
/// unknown control kind renders a muted "unsupported control" line.
/// The panel does not scroll by itself; its host (a dock panel) does.
class PluginViewRenderer extends StatefulWidget {
  const PluginViewRenderer({super.key, required this.spec, required this.onEvent, this.projectDir});

  final PluginViewSpec spec;
  final void Function(PluginViewEvent event) onEvent;
  final String? projectDir;

  @override
  State<PluginViewRenderer> createState() => _PluginViewRendererState();
}

class _PluginViewRendererState extends State<PluginViewRenderer> {
  late PluginViewHost _host = _newHost();
  late PluginControlCache _cache = PluginControlCache(widget.spec.id);

  PluginViewHost _newHost() =>
      PluginViewHost(viewId: widget.spec.id, projectDir: widget.projectDir, sink: (e) => widget.onEvent(e));

  @override
  void didUpdateWidget(PluginViewRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another view or project: nothing carries over.
    if (widget.spec.id != oldWidget.spec.id || widget.projectDir != oldWidget.projectDir) {
      _host = _newHost();
      _cache = PluginControlCache(widget.spec.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PluginViewScope(
      host: _host,
      child: PluginControlColumn(children: _cache.buildAll(widget.spec.children)),
    );
  }
}
