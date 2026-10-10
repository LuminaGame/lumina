part of '../blueprint_graph_editor.dart';

/// The presentation seams the canvas asks the editor for (pin colours, type
/// labels, node bodies, palette rows); a subclass with its own pin types
/// overrides them.
mixin _BlueprintGraphPresentation on _BlueprintGraphEditorCore {

  // ---------------------------------------------------------------------------
  // Presentation seams: the canvas asks the editor rather than the Blueprint
  // pin style, so a graph with its own pin types (the Material Editor's)
  // shares the canvas. The defaults are the Blueprint look.
  // ---------------------------------------------------------------------------

  /// The colour of [pin]'s anchor and of wires leaving it.
  Color pinColor(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) =>
      BlueprintPinStyle.color(pin.type);

  /// [pin]'s type as the context-sensitive palette names it.
  String pinTypeLabel(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) =>
      BlueprintPinStyle.pinLabel(pin);

  /// Whether an unconnected input edits its literal inline (when the type
  /// has an inline editor at all).
  bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) => true;

  /// [entries] narrowed to nodes that can take a wire from [from].
  List<BlueprintPaletteEntry> compatibleEntries(List<BlueprintPaletteEntry> entries, BlueprintPinRef from) =>
      BlueprintPalette.compatibleWith(entries, from, context);

  /// Whether [wire] is drawn as broken.
  bool wireHasProblem(LuminaBlueprintWire wire) =>
      whyNotConnect(wire.fromNodeId, wire.fromPinId, wire.toNodeId, wire.toPinId) != null;

  /// Height of the widget [nodeBody] draws under a node's header (0: none).
  double nodeBodyHeight(LuminaBlueprintNode node) => 0;

  /// A widget drawn between a node's header and its pins (the Material
  /// Editor's texture thumbnail on a Texture Sample node); null for none.
  Widget? nodeBody(BuildContext context, LuminaBlueprintNode node) => null;

  /// Dropdown options for a pin's literal value, or null if it uses a standard editor.
  List<String>? pinOptions(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) {
    if (BlueprintGraphEditor.settingPins[node.registryId]?.contains(pin.id) ?? false) {
      switch (pin.id) {
        case 'class':
          return BlueprintPalette.castTargets(context);
        case 'element':
          final cls = node.literals['class'];
          final classes = cls is String && context.widgetClass(cls) != null ? [context.widgetClass(cls)!] : context.widgetClasses;
          return [for (final w in classes) for (final e in w.elements) e.name];
        case 'component':
          return [for (final c in context.components) c.name];
      }
    }
    if (pin.type == LuminaPinType.enumeration) {
      final engine = LuminaBlueprintNodeLibrary.engineEnumValues(pin.enumName);
      if (engine != null) return engine;
      final values = context.enumeration(pin.enumName)?.values;
      if (values != null && values.isNotEmpty) return values;
    }
    // An input key pin (`Is Input Key Down`) picks from the
    // keys the engine names.
    if (BlueprintGraphEditor.inputKeyNodes.contains(node.registryId) && pin.id == 'key') {
      return [for (final k in LuminaKey.values) k.id];
    }
    final provided = pinOptionsProvider?.call(node, pin);
    if (provided != null) return provided;
    if (node.registryId == 'create_widget' && pin.id == 'class') {
      final widgets = host.availableWidgetClasses;
      final current = node.literals['class'] as String?;
      final set = <String>{
        ...widgets,
        if (current != null && current.isNotEmpty) current,
        if (widgets.isEmpty && (current == null || current.isEmpty)) 'WBP_HUD',
      };
      return set.toList();
    }
    return null;
  }

  /// The colour [wire] is drawn in: its source pin's.
  Color wireColor(LuminaBlueprintWire wire) {
    final n = node(wire.fromNodeId);
    final p = pin(wire.fromNodeId, wire.fromPinId, output: true);
    return n == null || p == null ? BlueprintPinStyle.color(null) : pinColor(n, p, output: true);
  }
}
