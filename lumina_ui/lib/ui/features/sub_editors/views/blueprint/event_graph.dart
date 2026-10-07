import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';

/// The Blueprint editor's Event Graph tab: the shared [BlueprintGraphCanvas]
/// bound to the Blueprint's event graph.
class BlueprintEventGraph extends StatelessWidget {
  final BlueprintEditorViewModel viewModel;

  const BlueprintEventGraph({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) =>
      BlueprintGraphCanvas(key: const ValueKey('blueprint_event_graph_canvas'), editor: viewModel.eventGraph, graphLabel: 'Event Graph');
}
