part of '../my_blueprint_panel.dart';

/// The sections listed from the type context: the selected widget
/// variable's elements, components, level actors and widget variables.
mixin _MyBlueprintContextSections on _BlueprintMyBlueprintPanelStateBase {
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
}
