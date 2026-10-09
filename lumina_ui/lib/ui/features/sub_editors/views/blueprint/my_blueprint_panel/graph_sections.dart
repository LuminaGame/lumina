part of '../my_blueprint_panel.dart';

/// The Graphs / Functions / Macros / Event Dispatchers and Local Variables
/// sections.
mixin _MyBlueprintGraphSections on _BlueprintMyBlueprintPanelStateBase {
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
}
