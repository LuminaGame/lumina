import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';
import '../../view_models/material_editor_view_model.dart';
import '../blueprint/graph_canvas.dart';
import 'node_details_panel.dart';

/// The Material Editor's Node Graph tab: the material as
/// material expressions on the Blueprint editor's graph canvas, with a
/// Details panel for the selected node. Graph and GLSL tab are two views of
/// one material: an edit here rewrites the source, an edit there re-parses
/// into this graph.
class MaterialGraphView extends StatefulWidget {
  final MaterialEditorViewModel viewModel;

  const MaterialGraphView({super.key, required this.viewModel});

  @override
  State<MaterialGraphView> createState() => MaterialGraphViewState();
}

class MaterialGraphViewState extends State<MaterialGraphView> {
  final GlobalKey<BlueprintGraphCanvasState> _canvasKey = GlobalKey();

  BlueprintGraphCanvasState? get canvas => _canvasKey.currentState;

  @override
  void initState() {
    super.initState();
    widget.viewModel.graph.ensureSynced();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final controller = vm.graph;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): controller.redo,
      },
      child: Column(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, controller.transactions]),
            builder: (context, _) => _toolbar(vm),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: BlueprintGraphCanvas(
                    key: _canvasKey,
                    editor: controller.editor,
                    graphLabel: 'Material',
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(width: 250, child: MaterialNodeDetailsPanel(viewModel: vm)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(MaterialEditorViewModel vm) {
    final controller = vm.graph;
    final tx = controller.transactions;
    final errors = controller.analysis.diagnostics.where((d) => d.isError).length;
    return Container(
      height: 32,
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(tx.undoLabel, style: const TextStyle(fontSize: 9))),
            child: GhostButton(
              key: const ValueKey('material_graph_undo'),
              onPressed: tx.canUndo ? controller.undo : null,
              child: const Icon(LucideIcons.undo2, size: 13),
            ),
          ),
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(tx.redoLabel, style: const TextStyle(fontSize: 9))),
            child: GhostButton(
              key: const ValueKey('material_graph_redo'),
              onPressed: tx.canRedo ? controller.redo : null,
              child: const Icon(LucideIcons.redo2, size: 13),
            ),
          ),
          const SizedBox(width: 6),
          GhostButton(
            key: const ValueKey('material_graph_add_node'),
            onPressed: () {
              final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
              final size = box?.size ?? const Size(400, 300);
              canvas?.openNodePalette(Offset(size.width / 2, size.height / 2));
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 12),
                SizedBox(width: 4),
                Text('Add Node', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          GhostButton(
            key: const ValueKey('material_graph_arrange'),
            onPressed: controller.arrange,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.layoutGrid, size: 12),
                SizedBox(width: 4),
                Text('Arrange', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          const Spacer(),
          if (controller.fallbackReason != null)
            const OutlineBadge(child: Text('Custom (Fragment)', style: TextStyle(fontSize: 10)))
          else if (errors > 0)
            DestructiveBadge(
              key: const ValueKey('material_graph_status'),
              child: Text('$errors graph error${errors == 1 ? '' : 's'} — source not updated', style: const TextStyle(fontSize: 10)),
            )
          else
            const SecondaryBadge(
              key: ValueKey('material_graph_status'),
              child: Text('Graph ⇄ GLSL in sync', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }
}
