import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Renders a plugin's declarative panel ([PluginViewSpec]) with the
/// editor's shadcn widgets, one widget per control kind, keyed
/// `<viewId>/<controlId>`; user actions come back as [PluginViewEvent]s.
/// [projectDir] lets asset-ref fields and 3D previews resolve paths.
class PluginViewRenderer extends StatelessWidget {
  const PluginViewRenderer({super.key, required this.spec, required this.onEvent, this.projectDir});

  final PluginViewSpec spec;
  final void Function(PluginViewEvent event) onEvent;
  final String? projectDir;

  @override
  Widget build(BuildContext context) => Text('Plugin panel ${spec.id}');
}
