import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';
import '../../models/blueprint_graph_ref.dart';
import '../../models/blueprint_pin_style.dart';
import 'graph_canvas.dart';

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

class BlueprintMyBlueprintPanelState extends State<BlueprintMyBlueprintPanel> {
  /// Which list a rename is in: `var`, `fn`, `macro`, `dispatcher`, `local`.
  String _renamingKind = 'var';
  String? _renaming;
  final TextEditingController _renameController = TextEditingController();
  String? _renameError;
  final TextEditingController _elementSearch = TextEditingController();
  String _elementQuery = '';

  @override
  void dispose() {
    _renameController.dispose();
    _elementSearch.dispose();
    super.dispose();
  }

  /// The elements of the selected widget variable's class matching the
  /// search, or null when the selection is not a widget variable.
  List<LuminaBlueprintWidgetElement>? get visibleElements {
    final v = widget.variables.where((v) => v.name == widget.selected).firstOrNull;
    final cls = v?.objectClass;
    if (cls == null || LuminaBlueprintObjectClass.kind(cls) != LuminaBlueprintObjectClass.widgetKind) return null;
    final w = widget.context.widgetClass(LuminaBlueprintObjectClass.name(cls));
    if (w == null) return null;
    final q = _elementQuery.toLowerCase();
    return [
      for (final e in w.elements)
        if (q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            LuminaBlueprintObjectClass.displayName(e.objectClass).toLowerCase().contains(q))
          e,
    ];
  }

  /// Starts renaming [name] in place.
  void beginRename(String name, {String kind = 'var'}) {
    setState(() {
      _renamingKind = kind;
      _renaming = name;
      _renameError = null;
      _renameController.text = name;
    });
  }

  bool _rename(String old, String next) {
    final sections = widget.sections;
    return switch (_renamingKind) {
      'fn' => sections?.functionActions.onRename(old, next) ?? false,
      'macro' => sections?.macroActions.onRename(old, next) ?? false,
      'dispatcher' => sections?.dispatcherActions.onRename(old, next) ?? false,
      'local' => sections?.onRenameLocal?.call(old, next) ?? false,
      _ => widget.onRename(old, next),
    };
  }

  void _commitRename() {
    final old = _renaming;
    if (old == null) return;
    final next = _renameController.text.trim();
    if (next == old) {
      setState(() => _renaming = null);
      return;
    }
    if (_rename(old, next)) {
      setState(() => _renaming = null);
    } else {
      setState(() => _renameError = 'Not a valid, unused name');
    }
  }

  void _confirmDelete(String name, {String kind = 'var', String noun = 'variable', int? uses, ValueChanged<String>? onDelete}) {
    final count = uses ?? widget.usageCount(name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $noun $name?'),
        content: Text(count == 0
            ? 'No node uses it.'
            : '$count node${count == 1 ? '' : 's'} use${count == 1 ? 's' : ''} it and will be removed from the graph.'),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          DestructiveButton(
            key: ValueKey('${kind}_delete_confirm'),
            onPressed: () {
              closeOverlay(dialogContext);
              (onDelete ?? widget.onDelete)(name);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _menu(String name, Offset global, {String kind = 'var', String noun = 'variable', int? uses, ValueChanged<String>? onDelete}) {
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: ValueKey('${kind}_menu_rename'),
            leading: const Icon(LucideIcons.pencil, size: 12),
            child: const Text('Rename', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => beginRename(name, kind: kind),
          ),
          MenuButton(
            key: ValueKey('${kind}_menu_delete'),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Delete', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => _confirmDelete(name, kind: kind, noun: noun, uses: uses, onDelete: onDelete),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, {VoidCallback? onAdd, String? addKey}) => Row(
        children: [
          Icon(icon, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          if (onAdd != null)
            GhostButton(
              key: ValueKey(addKey ?? 'add_$title'),
              size: ButtonSize.small,
              onPressed: onAdd,
              child: const Icon(LucideIcons.plus, size: 12),
            ),
        ],
      );

  Widget _renameField() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('var_rename_field'),
              controller: _renameController,
              autofocus: true,
              style: const TextStyle(fontSize: 10),
              onSubmitted: (_) => _commitRename(),
            ),
            if (_renameError != null) Text(_renameError!, style: const TextStyle(fontSize: 8, color: EditorColors.destructive)),
          ],
        ),
      );

  /// A function / macro / dispatcher row: click selects (and opens the
  /// graph), right-click or the menu renames / deletes, drag places a call.
  Widget _namedRow({
    required String kind,
    required String noun,
    required String name,
    required IconData icon,
    required Color color,
    required bool selected,
    required BlueprintNamedRowActions actions,
    Object? drag,
    VoidCallback? onOpen,
  }) {
    if (_renaming == name && _renamingKind == kind) return _renameField();
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
      ],
    );
    final row = GestureDetector(
      onSecondaryTapUp: (d) =>
          _menu(name, d.globalPosition, kind: kind, noun: noun, uses: actions.usageCount(name), onDelete: actions.onDelete),
      onDoubleTap: onOpen,
      child: Clickable(
        onPressed: () => actions.onSelect(name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(child: chip),
              Builder(
                builder: (buttonContext) => GhostButton(
                  key: ValueKey('${kind}_menu_$name'),
                  size: ButtonSize.xSmall,
                  density: ButtonDensity.icon,
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox?;
                    _menu(name, box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
                        kind: kind, noun: noun, uses: actions.usageCount(name), onDelete: actions.onDelete);
                  },
                  child: const Icon(LucideIcons.ellipsisVertical, size: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (drag == null) return KeyedSubtree(key: ValueKey('${kind}_row_$name'), child: row);
    return Draggable<Object>(
      key: ValueKey('${kind}_row_$name'),
      data: drag,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: EditorColors.card, borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: chip),
      ),
      child: row,
    );
  }

  List<Widget> _graphSections() {
    final s = widget.sections;
    if (s == null) return const [];
    const gap = SizedBox(height: 10);
    return [
      _sectionHeader(LucideIcons.gitFork, 'GRAPHS'),
      const SizedBox(height: 4),
      for (final g in s.graphs)
        Clickable(
          key: ValueKey('graph_row_${g.key}'),
          onPressed: () => s.onOpenGraph(g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: g == s.activeGraph ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(children: [
              Icon(
                g.isFunction
                    ? LucideIcons.squareFunction
                    : g.isMacro
                        ? LucideIcons.boxes
                        : LucideIcons.gitFork,
                size: 11,
                color: EditorColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(g.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      gap,
      _sectionHeader(LucideIcons.squareFunction, 'FUNCTIONS', onAdd: s.functionActions.onAdd, addKey: 'fn_add'),
      const SizedBox(height: 4),
      if (s.functions.isEmpty)
        const Padding(padding: EdgeInsets.all(6), child: Text('No functions. Press + to add one.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
      for (final f in s.functions)
        _namedRow(
          kind: 'fn',
          noun: 'function',
          name: f,
          icon: LucideIcons.squareFunction,
          color: const Color(0xFF42A5F5), // function-graph blue, as the node headers
          selected: s.selectedFunction == f,
          actions: s.functionActions,
          drag: BlueprintGraphCallDrag(f),
          onOpen: () => s.onOpenGraph(BlueprintGraphRef.function(f)),
        ),
      gap,
      _sectionHeader(LucideIcons.boxes, 'MACROS', onAdd: s.macroActions.onAdd, addKey: 'macro_add'),
      const SizedBox(height: 4),
      if (s.macros.isEmpty)
        const Padding(padding: EdgeInsets.all(6), child: Text('No macros. Press + to add one.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
      for (final m in s.macros)
        _namedRow(
          kind: 'macro',
          noun: 'macro',
          name: m,
          icon: LucideIcons.boxes,
          color: const Color(0xFF9E9E9E), // macro grey, as the node headers
          selected: s.selectedMacro == m,
          actions: s.macroActions,
          drag: BlueprintGraphCallDrag(m, isMacro: true),
          onOpen: () => s.onOpenGraph(BlueprintGraphRef.macro(m)),
        ),
      gap,
      _sectionHeader(LucideIcons.radio, 'EVENT DISPATCHERS', onAdd: s.dispatcherActions.onAdd, addKey: 'dispatcher_add'),
      const SizedBox(height: 4),
      if (s.dispatchers.isEmpty)
        const Padding(padding: EdgeInsets.all(6), child: Text('No dispatchers. Press + to add one.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
      for (final d in s.dispatchers)
        _namedRow(
          kind: 'dispatcher',
          noun: 'dispatcher',
          name: d,
          icon: LucideIcons.radio,
          color: BlueprintPinStyle.color(LuminaPinType.delegate),
          selected: s.selectedDispatcher == d,
          actions: s.dispatcherActions,
          drag: BlueprintDispatcherDrag(d),
        ),
      const Text('Drag a dispatcher onto the graph: Call, Bind, Unbind or Assign.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
      gap,
    ];
  }

  List<Widget> _localVariablesSection() {
    final s = widget.sections;
    if (s == null || s.localsOf == null) return const [];
    return [
      const SizedBox(height: 10),
      _sectionHeader(LucideIcons.variable, 'LOCAL VARIABLES (${s.localsOf!.toUpperCase()})', onAdd: s.onAddLocal, addKey: 'local_add'),
      const SizedBox(height: 4),
      if (s.localVariables.isEmpty)
        const Padding(padding: EdgeInsets.all(6), child: Text('No local variables.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
      for (final v in s.localVariables)
        _renaming == v.name && _renamingKind == 'local'
            ? _renameField()
            : Draggable<Object>(
                key: ValueKey('local_row_${v.name}'),
                data: BlueprintLocalVariableDrag(v.name),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: EditorColors.card, borderRadius: BorderRadius.circular(4), border: Border.all(color: BlueprintPinStyle.color(v.type))),
                  child: DefaultTextStyle(
                      style: const TextStyle(decoration: TextDecoration.none, fontSize: 10, color: EditorColors.foreground), child: Text(v.name)),
                ),
                child: GestureDetector(
                  onSecondaryTapUp: (d) => _menu(v.name, d.globalPosition, kind: 'local', noun: 'local variable', uses: 0, onDelete: s.onDeleteLocal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 2),
                    child: Row(children: [
                      Container(width: 10, height: 4, decoration: BoxDecoration(color: BlueprintPinStyle.color(v.type), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Expanded(child: Text(v.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600))),
                      _typeChip(
                        key: ValueKey('local_type_${v.name}'),
                        typeName: v.typeName,
                        onPick: (t) => s.onSetLocalType?.call(v.name, t),
                      ),
                      Builder(
                        builder: (buttonContext) => GhostButton(
                          key: ValueKey('local_menu_${v.name}'),
                          size: ButtonSize.xSmall,
                          density: ButtonDensity.icon,
                          onPressed: () {
                            final box = buttonContext.findRenderObject() as RenderBox?;
                            _menu(v.name, box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
                                kind: 'local', noun: 'local variable', uses: 0, onDelete: s.onDeleteLocal);
                          },
                          child: const Icon(LucideIcons.ellipsisVertical, size: 11),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
    ];
  }

  /// The coloured type pill: a menu of the type groups.
  Widget _typeChip({required Key key, required String typeName, required ValueChanged<String> onPick}) {
    final color = BlueprintPinStyle.color(LuminaPinType.parseVariableType(typeName));
    return Builder(
      builder: (chipContext) => Clickable(
        key: key,
        onPressed: () {
          final box = chipContext.findRenderObject() as RenderBox?;
          showDropdown(
            context: context,
            // An explicit position is where the menu opens; following the
            // anchor widget would drag it to that widget's bottom centre.
            follow: false,
            // Top-left corner at the point, as editor context menus open.
            alignment: Alignment.topLeft,
            anchorAlignment: Alignment.topLeft,
            position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
            builder: (context) => DropdownMenu(
              children: [
                for (final group in BlueprintPinStyle.variableTypeGroups(widget.context))
                  if (group.typeNames.isNotEmpty) ...[
                    MenuLabel(
                      key: ValueKey('var_type_group_${group.title}'),
                      child: Text(group.title.toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                    ),
                    for (final t in group.typeNames)
                      MenuButton(
                        key: ValueKey('var_type_item_$t'),
                        leading: Container(width: 10, height: 4, color: BlueprintPinStyle.color(LuminaPinType.parseVariableType(t))),
                        child: Text(BlueprintPinStyle.variableLabel(t), style: const TextStyle(fontSize: 10)),
                        onPressed: (ctx) => onPick(t),
                      ),
                  ],
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Text(BlueprintPinStyle.variableLabel(typeName), style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

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

  /// The selected widget variable's elements (`FPSCounter · Text Block`),
  /// searchable, each draggable onto the graph as `Get <var>` → `Get <element>`.
  List<Widget> _elementsSection() {
    final elements = visibleElements;
    if (elements == null) return const [];
    final selected = widget.selected!;
    return [
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(LucideIcons.layoutTemplate, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('ELEMENTS OF ${selected.toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      TextField(
        key: const ValueKey('element_search'),
        controller: _elementSearch,
        style: const TextStyle(fontSize: 9),
        placeholder: const Text('Search elements...', style: TextStyle(fontSize: 9)),
        onChanged: (v) => setState(() => _elementQuery = v),
      ),
      const SizedBox(height: 4),
      if (elements.isEmpty)
        const Padding(
          padding: EdgeInsets.all(6),
          child: Text('No element matches.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ),
      for (final e in elements)
        _draggableRow(
          key: ValueKey('element_row_${e.name}'),
          data: BlueprintElementDrag(selected, e.name),
          color: BlueprintPinStyle.color(LuminaPinType.object),
          title: e.name,
          subtitle: LuminaBlueprintObjectClass.displayName(e.objectClass),
        ),
    ];
  }

  /// The Blueprint's component tree as draggable `Get <name>` nodes.
  List<Widget> _componentsSection() {
    final components = widget.context.components;
    if (components.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      const Row(
        children: [
          Icon(LucideIcons.boxes, size: 12, color: EditorColors.primary),
          SizedBox(width: 6),
          Text('COMPONENTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        ],
      ),
      const SizedBox(height: 4),
      for (final c in components)
        _draggableRow(
          key: ValueKey('component_row_${c.name}'),
          data: BlueprintComponentDrag(c.name),
          color: BlueprintPinStyle.color(LuminaPinType.object),
          title: c.name,
          subtitle: LuminaBlueprintObjectClass.displayName(c.objectClass),
        ),
      const SizedBox(height: 4),
      const Text('Drag a component onto the graph: Get <component>.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
    ];
  }

  /// A Level Blueprint's placed actors, mirroring the
  /// outliner: each drags onto the graph as a reference, `Get <Actor>`.
  List<Widget> _levelActorsSection() {
    final actors = widget.context.levelActors;
    if (actors == null) return const [];
    return [
      const SizedBox(height: 10),
      const Row(
        children: [
          Icon(LucideIcons.listTree, size: 12, color: EditorColors.primary),
          SizedBox(width: 6),
          Text('LEVEL ACTORS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        ],
      ),
      const SizedBox(height: 4),
      if (actors.isEmpty)
        const Text('The level has no placed actors.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      for (final a in actors)
        _draggableRow(
          key: ValueKey('level_actor_row_${a.name}'),
          data: BlueprintLevelActorDrag(a.name),
          color: BlueprintPinStyle.color(LuminaPinType.object),
          title: a.name,
          subtitle: LuminaBlueprintObjectClass.displayName(a.actorClass),
        ),
      const SizedBox(height: 4),
      const Text('Drag an actor onto the graph: a reference to it.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
    ];
  }

  /// A widget graph's `Is Variable` elements: each drags
  /// onto the graph as `Get <Element>`, typed by its element type.
  List<Widget> _widgetVariablesSection() {
    final variables = widget.context.widgetVariables;
    if (variables == null) return const [];
    return [
      const SizedBox(height: 10),
      const Row(
        children: [
          Icon(LucideIcons.layoutTemplate, size: 12, color: EditorColors.primary),
          SizedBox(width: 6),
          Text('WIDGETS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        ],
      ),
      const SizedBox(height: 4),
      if (variables.isEmpty)
        const Text('No element is marked Is Variable in the Designer.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      for (final v in variables)
        _draggableRow(
          key: ValueKey('widget_variable_row_${v.name}'),
          data: BlueprintWidgetVariableDrag(v.name),
          color: BlueprintPinStyle.color(LuminaPinType.object),
          title: v.name,
          subtitle: LuminaBlueprintObjectClass.displayName(v.objectClass),
        ),
      const SizedBox(height: 4),
      const Text('Drag a widget onto the graph: Get <widget>.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
    ];
  }

  Widget _draggableRow({required Key key, required Object data, required Color color, required String title, required String subtitle}) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
      ],
    );
    return Draggable<Object>(
      key: key,
      data: data,
      // The whole row starts the drag, not only its label.
      hitTestBehavior: HitTestBehavior.opaque,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: chip),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: chip),
            Text(subtitle, style: TextStyle(fontSize: 8.5, color: color.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }

  Widget _row(LuminaBlueprintVariable v) {
    final color = BlueprintPinStyle.color(v.type);
    final selected = widget.selected == v.name;
    if (_renaming == v.name && _renamingKind == 'var') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('var_rename_field'),
              controller: _renameController,
              autofocus: true,
              style: const TextStyle(fontSize: 10),
              onSubmitted: (_) => _commitRename(),
            ),
            if (_renameError != null)
              Text(_renameError!, style: const TextStyle(fontSize: 8, color: EditorColors.destructive)),
          ],
        ),
      );
    }
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(v.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
      ],
    );
    return Draggable<BlueprintVariableDrag>(
      key: ValueKey('var_row_${v.name}'),
      data: BlueprintVariableDrag(v.name),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: chip),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (d) => _menu(v.name, d.globalPosition),
        child: Clickable(
          onPressed: () => widget.onSelect(v.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Expanded(child: chip),
                // The type chip: a coloured pill, a menu of the types.
                Builder(
                  builder: (chipContext) => Clickable(
                    key: ValueKey('var_type_${v.name}'),
                    onPressed: () {
                      final box = chipContext.findRenderObject() as RenderBox?;
                      showDropdown(
                        context: context,
                        // An explicit position is where the menu opens; following the
                        // anchor widget would drag it to that widget's bottom centre.
                        follow: false,
                        // Top-left corner at the point, as editor context menus open.
                        alignment: Alignment.topLeft,
                        anchorAlignment: Alignment.topLeft,
                        position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
                        builder: (context) => DropdownMenu(
                          children: [
                            // The type picker groups; one flat menu with
                            // group labels so every type is one click away.
                            for (final group in BlueprintPinStyle.variableTypeGroups(widget.context))
                              if (group.typeNames.isNotEmpty) ...[
                                MenuLabel(
                                  key: ValueKey('var_type_group_${group.title}'),
                                  child: Text(group.title.toUpperCase(),
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                                ),
                                for (final t in group.typeNames)
                                  MenuButton(
                                    key: ValueKey('var_type_item_$t'),
                                    leading: Container(
                                      width: 10,
                                      height: 4,
                                      color: BlueprintPinStyle.color(LuminaPinType.parseVariableType(t)),
                                    ),
                                    child: Text(BlueprintPinStyle.variableLabel(t), style: const TextStyle(fontSize: 10)),
                                    onPressed: (ctx) => widget.onSetType(v.name, t),
                                  ),
                              ],
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.7)),
                      ),
                      child: Text(BlueprintPinStyle.variableLabel(v.typeName),
                          style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                Builder(
                  builder: (buttonContext) => GhostButton(
                    key: ValueKey('var_menu_${v.name}'),
                    size: ButtonSize.xSmall,
                    density: ButtonDensity.icon,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox?;
                      final origin = box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero;
                      _menu(v.name, origin);
                    },
                    child: const Icon(LucideIcons.ellipsisVertical, size: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inheritedVariableRow(LuminaBlueprintVariable v) {
    final color = BlueprintPinStyle.color(v.type);
    final selected = widget.selected == v.name;
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(v.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: EditorColors.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: EditorColors.border, width: 0.5),
          ),
          child: const Text('Inherited', style: TextStyle(fontSize: 7.5, color: EditorColors.mutedForeground)),
        ),
      ],
    );
    return Draggable<BlueprintVariableDrag>(
      key: ValueKey('var_inherited_row_${v.name}'),
      data: BlueprintVariableDrag(v.name),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: chip),
      ),
      child: Clickable(
        onPressed: () => widget.onSelect(v.name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(child: chip),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Text(BlueprintPinStyle.variableLabel(v.typeName),
                    style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
