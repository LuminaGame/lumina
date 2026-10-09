import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';

part 'my_blueprint_panel/state.dart';
part 'my_blueprint_panel/graph_sections.dart';
part 'my_blueprint_panel/context_sections.dart';
part 'my_blueprint_panel/variable_rows.dart';

/// One named row of a My Blueprint list (a function, macro or dispatcher).
typedef BlueprintNamedRowActions = ({
  VoidCallback onAdd,
  ValueChanged<String> onSelect,
  bool Function(String oldName, String newName) onRename,
  ValueChanged<String> onDelete,
  int Function(String name) usageCount,
});

/// The Graphs / Functions / Macros / Event Dispatchers / Local Variables
/// sections of My Blueprint, wired to the Blueprint
/// editor; absent for hosts without them (the Animation Blueprint editor).
class BlueprintMyBlueprintSections {
  final List<BlueprintGraphRef> graphs;
  final BlueprintGraphRef activeGraph;
  final ValueChanged<BlueprintGraphRef> onOpenGraph;
  final List<String> functions;
  final List<String> macros;
  final List<String> dispatchers;
  final String? selectedFunction;
  final String? selectedMacro;
  final String? selectedDispatcher;
  final BlueprintNamedRowActions functionActions;
  final BlueprintNamedRowActions macroActions;
  final BlueprintNamedRowActions dispatcherActions;

  /// The local variables of the function whose graph is active, or null.
  final String? localsOf;
  final List<LuminaBlueprintVariable> localVariables;
  final VoidCallback? onAddLocal;
  final bool Function(String oldName, String newName)? onRenameLocal;
  final void Function(String name, String typeName)? onSetLocalType;
  final ValueChanged<String>? onDeleteLocal;

  const BlueprintMyBlueprintSections({
    required this.graphs,
    required this.activeGraph,
    required this.onOpenGraph,
    required this.functions,
    required this.macros,
    required this.dispatchers,
    required this.functionActions,
    required this.macroActions,
    required this.dispatcherActions,
    this.selectedFunction,
    this.selectedMacro,
    this.selectedDispatcher,
    this.localsOf,
    this.localVariables = const [],
    this.onAddLocal,
    this.onRenameLocal,
    this.onSetLocalType,
    this.onDeleteLocal,
  });
}

/// The My Blueprint panel: the graphs (optional [graphs] section), the
/// variables, each with a type chip whose picker groups Basic / Object /
/// Widgets / Widget Elements / Components / Actors from the [context],
/// the Components section (draggable `Get <name>`
/// nodes) and, for a selected widget variable, its searchable elements. A
/// variable dragged onto a graph places a Get or Set node; renaming renames
/// its nodes; deleting asks first and removes its nodes.
class BlueprintMyBlueprintPanel extends StatefulWidget {
  final List<LuminaBlueprintVariable> variables;
  final List<LuminaBlueprintVariable> inheritedVariables;

  /// The document's type context: widget classes, components and actor
  /// classes the type picker and the Components section list.
  final LuminaBlueprintTypeContext context;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final bool Function(String oldName, String newName) onRename;
  final void Function(String name, String typeName) onSetType;
  final ValueChanged<String> onDelete;
  final int Function(String name) usageCount;

  /// Extra sections above the variables (the Animation Blueprint's graphs).
  final List<Widget> graphs;

  /// The Blueprint editor's graph / function / macro / dispatcher sections.
  final BlueprintMyBlueprintSections? sections;

  const BlueprintMyBlueprintPanel({
    super.key,
    required this.variables,
    this.inheritedVariables = const [],
    this.context = const LuminaBlueprintTypeContext(),
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onRename,
    required this.onSetType,
    required this.onDelete,
    required this.usageCount,
    this.graphs = const [],
    this.sections,
  });

  @override
  State<BlueprintMyBlueprintPanel> createState() => BlueprintMyBlueprintPanelState();
}

class BlueprintMyBlueprintPanelState extends _BlueprintMyBlueprintPanelStateBase
    with _MyBlueprintGraphSections, _MyBlueprintContextSections, _MyBlueprintVariableRows {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: ListView(
        children: [
          ...widget.graphs,
          ..._graphSections(),
          Row(
            children: [
              const Icon(LucideIcons.variable, size: 12, color: EditorColors.primary),
              const SizedBox(width: 6),
              const Text('VARIABLES',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              const Spacer(),
              GhostButton(
                key: const ValueKey('var_add'),
                size: ButtonSize.small,
                onPressed: widget.onAdd,
                child: const Icon(LucideIcons.plus, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.variables.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No variables. Press + to add one.',
                  style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            ),
          for (final v in widget.variables) _row(v),
          if (widget.inheritedVariables.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(LucideIcons.variable, size: 12, color: EditorColors.mutedForeground),
                SizedBox(width: 6),
                Text('INHERITED VARIABLES',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              ],
            ),
            const SizedBox(height: 4),
            for (final v in widget.inheritedVariables) _inheritedVariableRow(v),
          ],
          const SizedBox(height: 6),
          const Text('Drag a variable onto the graph: Get or Set (Ctrl: Get, Alt: Set).',
              style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          ..._localVariablesSection(),
          ..._elementsSection(),
          ..._componentsSection(),
          ..._levelActorsSection(),
          ..._widgetVariablesSection(),
        ],
      ),
    );
  }
}
