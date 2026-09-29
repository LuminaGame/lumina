import 'package:lumina/lumina.dart';

import 'blueprint_editor_type_context.dart';

/// A palette row that is an editor action rather than a library node, such
/// as the pinned "Promote to Variable".
enum BlueprintPaletteAction { promoteToVariable, addCustomEvent, addComment, collapseNodes, collapseToFunction, collapseToMacro }

/// One row of the graph editor's node palette: a library node, a variable
/// node already bound to one of the document's variables (`Get Speed`), a
/// generated typed-object node (`Get FPSCounter`, `Get CameraBoom`,
/// `Cast To WBP_Menu`) or an editor action (`Promote to Variable`).
class BlueprintPaletteEntry {
  final String registryId;
  final String title;
  final String category;
  final List<String> keywords;
  final int headerColor;
  final LuminaBlueprintNodeKind kind;

  /// Node settings the entry places the node with (`{'variable': 'Speed'}`,
  /// `{'class': 'WBP_HUD', 'element': 'FPSCounter'}`).
  final Map<String, dynamic> literals;

  /// Non-null for a node kept only so old documents load.
  final String? deprecation;

  /// A Dart function of the project exposed with `@BlueprintCallable` /
  /// `@BlueprintPure`, shown with a "Project" badge.
  final bool isProject;

  /// The function's doc comment (or the annotation's tooltip), on hover.
  final String? tooltip;

  /// The object class the entry is about (`Widget:WBP_HUD` for `Get
  /// FPSCounter`, `WidgetElement:text` for `Set Text (Text)`), for the
  /// palette's class headers; null for untyped nodes.
  final String? objectClass;

  /// Non-null for a row that runs an editor action instead of placing a
  /// library node.
  final BlueprintPaletteAction? action;

  /// A key of its own, for a row that places the same node as another row
  /// of the same palette ("Create a Reference to Door_01" beside `Door_01`).
  final String? keyOverride;

  /// Listed first, above the graph actions (the `Create a Reference to
  /// <Actor>` row at the top of the right-click menu).
  final bool pinned;

  const BlueprintPaletteEntry({
    required this.registryId,
    required this.title,
    required this.category,
    required this.keywords,
    required this.headerColor,
    required this.kind,
    this.literals = const {},
    this.deprecation,
    this.isProject = false,
    this.tooltip,
    this.objectClass,
    this.action,
    this.keyOverride,
    this.pinned = false,
  });

  /// A stable key for widgets and tests: the node id, plus the node setting
  /// that makes the row unique (variable, element, component, class).
  String get key {
    if (keyOverride != null) return keyOverride!;
    // A call of another class's custom event: class and event.
    if (literals['event'] != null && literals['class'] != null) return '${registryId}_${literals['class']}_${literals['event']}';
    final tag = literals['variable'] ??
        literals['actor'] ??
        literals['element'] ??
        literals['component'] ??
        literals['class'] ??
        literals['function'] ??
        literals['macro'] ??
        literals['event'] ??
        literals['dispatcher'] ??
        literals['enum'];
    final iface = literals['interface'];
    if (iface != null && tag != null) return '${registryId}_${iface}_$tag';
    return tag == null ? registryId : '${registryId}_$tag';
  }

  /// The top-level category (`Math|Vector` → `Math`).
  String get group => category.split('|').first;

  bool get isAction => action != null;

  /// The lower-cased text a search matches against.
  String get haystack => [title, category, registryId, ...keywords, if (isProject) 'project'].join(' ').toLowerCase();

  bool matches(String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (terms.isEmpty) return true;
    final hay = haystack;
    return terms.every(hay.contains);
  }
}

/// A pin a new node could be wired from: the pin the user dragged off. An
/// object pin carries its class and an array pin its element
/// type, so the palette can be context sensitive.
class BlueprintPinRef {
  final String nodeId;
  final String pinId;
  final LuminaPinType type;
  final bool isOutput;
  final String? objectClass;
  final LuminaPinType? elementType;

  /// The enum of an enumeration pin.
  final String? enumName;

  const BlueprintPinRef({
    required this.nodeId,
    required this.pinId,
    required this.type,
    required this.isOutput,
    this.objectClass,
    this.elementType,
    this.enumName,
  });

  /// The ref of [pin] on node [nodeId].
  factory BlueprintPinRef.of(String nodeId, LuminaBlueprintPinSpec pin, {required bool isOutput}) => BlueprintPinRef(
        nodeId: nodeId,
        pinId: pin.id,
        type: pin.type,
        isOutput: isOutput,
        objectClass: pin.objectClass,
        elementType: pin.elementType,
        enumName: pin.enumName,
      );

  /// A `Self` reference: what the Blueprint's own actor pins carry
  /// (`Actor:BP_ThirdPersonCharacter`); dragging it lists the component
  /// tree. The node id is empty: nothing is wired to it.
  factory BlueprintPinRef.self(LuminaBlueprintTypeContext context) => BlueprintPinRef(
        nodeId: '',
        pinId: 'self',
        type: LuminaPinType.object,
        isOutput: true,
        objectClass: context.selfClass,
      );

  bool get isSelf => nodeId.isEmpty && pinId == 'self';

  /// This pin as the library describes it, for [LuminaBlueprintNodeLibrary.canConnect].
  LuminaBlueprintPinSpec get spec =>
      LuminaBlueprintPinSpec(pinId, pinId, type, objectClass: objectClass, elementType: elementType, enumName: enumName);
}

/// The node palette over lumina's [LuminaBlueprintNodeLibrary]: every library
/// node grouped by category, variable nodes expanded per declared variable,
/// searchable by title, category and keywords, and filtered to the nodes that
/// can take a wire from a dragged pin. Pure Dart: the editor keeps no catalog
/// of its own, and the typed-object rows (`Get <Element>`, `Get <Component>`,
/// `Cast To <Class>`, Promote to Variable) are generated per drag from the
/// [LuminaBlueprintTypeContext].
abstract final class BlueprintPalette {
  static const String promoteToVariableId = 'promote_to_variable';

  /// The pinned first row of a pin drag: Promote to Variable.
  static const BlueprintPaletteEntry promoteToVariable = BlueprintPaletteEntry(
    registryId: promoteToVariableId,
    title: 'Promote to Variable',
    category: 'Variables',
    keywords: ['promote', 'variable', 'new', 'set'],
    headerColor: 0xFF6A1B9A,
    kind: LuminaBlueprintNodeKind.impure,
    action: BlueprintPaletteAction.promoteToVariable,
  );

  /// The graph actions of the right-click menu,
  /// offered as pinned rows of the palette: Add Custom Event…, Add Comment,
  /// and — with a selection — Collapse Nodes / to Function / to Macro.
  static const BlueprintPaletteEntry addCustomEvent = BlueprintPaletteEntry(
    registryId: 'action_add_custom_event',
    title: 'Add Custom Event…',
    category: 'Add Event',
    keywords: ['custom', 'event', 'add', 'new'],
    headerColor: 0xFFB71C1C,
    kind: LuminaBlueprintNodeKind.event,
    action: BlueprintPaletteAction.addCustomEvent,
  );
  static const BlueprintPaletteEntry addComment = BlueprintPaletteEntry(
    registryId: 'action_add_comment',
    title: 'Add Comment',
    category: 'Comments',
    keywords: ['comment', 'note', 'box', 'group'],
    headerColor: 0xFF3D4A5C,
    kind: LuminaBlueprintNodeKind.pure,
    action: BlueprintPaletteAction.addComment,
  );
  static const BlueprintPaletteEntry collapseNodes = BlueprintPaletteEntry(
    registryId: 'action_collapse_nodes',
    title: 'Collapse Nodes',
    category: 'Organization',
    keywords: ['collapse', 'nodes', 'graph', 'group'],
    headerColor: 0xFF546E7A,
    kind: LuminaBlueprintNodeKind.flow,
    action: BlueprintPaletteAction.collapseNodes,
  );
  static const BlueprintPaletteEntry collapseToFunction = BlueprintPaletteEntry(
    registryId: 'action_collapse_to_function',
    title: 'Collapse to Function',
    category: 'Organization',
    keywords: ['collapse', 'function', 'extract'],
    headerColor: 0xFF546E7A,
    kind: LuminaBlueprintNodeKind.impure,
    action: BlueprintPaletteAction.collapseToFunction,
  );
  static const BlueprintPaletteEntry collapseToMacro = BlueprintPaletteEntry(
    registryId: 'action_collapse_to_macro',
    title: 'Collapse to Macro',
    category: 'Organization',
    keywords: ['collapse', 'macro', 'extract'],
    headerColor: 0xFF546E7A,
    kind: LuminaBlueprintNodeKind.flow,
    action: BlueprintPaletteAction.collapseToMacro,
  );

  /// Engine actor classes a Cast To can target besides the project's own
  /// Blueprint classes.
  static const List<String> engineActorClasses = ['LuminaActor', 'LuminaPawn', 'LuminaCharacter'];

  /// Every entry for a graph whose variables are [variables]. [filter]
  /// restricts the library (a transition rule allows pure nodes only).
  /// Library nodes that only make sense bound to a document signature:
  /// the palette lists them per function / macro /
  /// event / dispatcher / interface function / enum through [generated],
  /// never bare.
  static const Set<String> signatureNodes = {
    LuminaBlueprintNodeLibrary.callFunction,
    LuminaBlueprintNodeLibrary.callFunctionPure,
    LuminaBlueprintNodeLibrary.callMacro,
    LuminaBlueprintNodeLibrary.callCustomEvent,
    LuminaBlueprintNodeLibrary.callDispatcher,
    LuminaBlueprintNodeLibrary.bindEventToDispatcher,
    LuminaBlueprintNodeLibrary.unbindEventFromDispatcher,
    LuminaBlueprintNodeLibrary.unbindAllEvents,
    LuminaBlueprintNodeLibrary.interfaceMessage,
    LuminaBlueprintNodeLibrary.eventInterfaceFunction,
    LuminaBlueprintNodeLibrary.enumLiteral,
    LuminaBlueprintNodeLibrary.switchOnEnum,
    'int_to_enum',
    'get_enum_value_count',
    LuminaBlueprintNodeLibrary.localVariableGet,
    LuminaBlueprintNodeLibrary.localVariableSet,
    LuminaBlueprintNodeLibrary.functionEntry,
    LuminaBlueprintNodeLibrary.macroInput,
    LuminaBlueprintNodeLibrary.macroOutput,
    // One `<Actor>` row per placed actor instead.
    LuminaBlueprintNodeLibrary.getLevelActor,
    // One row per widget variable / bound element event.
    LuminaBlueprintNodeLibrary.getWidgetVariable,
    LuminaBlueprintNodeLibrary.eventWidgetElement,
  };

  /// The palette row of a reference to the level's placed actor [ref]:
  /// titled with the actor's name, under **Level Actors**; [createReference] words it as the
  /// right-click menu's pinned `Create a Reference to <Actor>`.
  static BlueprintPaletteEntry levelActorReference(LuminaBlueprintLevelActorRef ref, {bool createReference = false}) {
    final spec = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.getLevelActor)!;
    return BlueprintPaletteEntry(
      registryId: spec.id,
      title: createReference ? 'Create a Reference to ${ref.name}' : ref.name,
      category: createReference ? 'Selected Actors' : 'Level Actors',
      keywords: [...spec.keywords, ref.name, LuminaBlueprintObjectClass.name(ref.actorClass), LuminaBlueprintObjectClass.displayName(ref.actorClass)],
      headerColor: spec.headerColor,
      kind: spec.kind,
      literals: {'actor': ref.name},
      objectClass: ref.actorClass,
      keyOverride: createReference ? 'create_reference_${ref.name}' : null,
      pinned: createReference,
    );
  }

  /// A widget graph's rows: `<Element>` (Get) per `Is
  /// Variable` element under **Widgets**, and `On <Event> (<Element>)` per
  /// event each offers under **Widget Events**; from a pin, only the Gets.
  static List<BlueprintPaletteEntry> widgetEntries(
    LuminaBlueprintTypeContext context, {
    BlueprintPinRef? from,
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
  }) {
    final out = <BlueprintPaletteEntry>[];
    final get = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.getWidgetVariable)!;
    final bound = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.eventWidgetElement)!;
    for (final v in context.widgetVariables ?? const <LuminaBlueprintWidgetElement>[]) {
      if ((filter == null || filter(get)) && (from == null || !from.isOutput)) {
        out.add(BlueprintPaletteEntry(
          registryId: get.id,
          title: v.name,
          category: 'Widgets',
          keywords: [...get.keywords, v.name, v.typeName, LuminaBlueprintObjectClass.displayName(v.objectClass)],
          headerColor: get.headerColor,
          kind: get.kind,
          literals: {'element': v.name},
          objectClass: v.objectClass,
        ));
      }
      if (from != null || (filter != null && !filter(bound))) continue;
      for (final event in LuminaWidgetEvents.forType(v.typeName)) {
        out.add(BlueprintPaletteEntry(
          registryId: bound.id,
          title: '${LuminaWidgetEvents.displayName(event)} (${v.name})',
          category: 'Widget Events',
          keywords: [...bound.keywords, v.name, event, LuminaWidgetEvents.displayName(event)],
          headerColor: bound.headerColor,
          kind: bound.kind,
          literals: {'element': v.name, 'event': event},
          objectClass: v.objectClass,
          keyOverride: 'widget_event_${v.name}_$event',
        ));
      }
    }
    return out;
  }

  /// [filter] narrowed to the nodes lumina allows in [context]'s scope
  /// (level-only nodes in a Level Blueprint, component nodes
  /// everywhere else).
  static bool Function(LuminaBlueprintNodeSpec spec) scoped(
    LuminaBlueprintTypeContext context,
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
  ) =>
      (spec) => (filter == null || filter(spec)) && LuminaBlueprintNodeLibrary.availableIn(spec, context);

  static List<BlueprintPaletteEntry> entries({
    List<LuminaBlueprintVariable> variables = const [],
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
  }) {
    final out = <BlueprintPaletteEntry>[];
    for (final spec in LuminaBlueprintNodeLibrary.all) {
      if (filter != null && !filter(spec)) continue;
      if (signatureNodes.contains(spec.id)) continue;
      if (spec.id == LuminaBlueprintNodeLibrary.variableGet || spec.id == LuminaBlueprintNodeLibrary.variableSet) {
        for (final v in variables) {
          out.add(BlueprintPaletteEntry(
            registryId: spec.id,
            title: '${spec.title} ${v.name}',
            category: spec.category,
            keywords: [v.name, v.typeName, 'variable', LuminaBlueprintObjectClass.displayName(v.objectClass)],
            headerColor: spec.headerColor,
            kind: spec.kind,
            literals: {'variable': v.name},
            objectClass: v.objectClass,
          ));
        }
        continue;
      }
      out.add(BlueprintPaletteEntry(
        registryId: spec.id,
        title: spec.title,
        category: spec.category,
        keywords: spec.keywords,
        headerColor: spec.headerColor,
        kind: spec.kind,
        deprecation: spec.deprecation,
        isProject: LuminaBlueprintFunctionRegistry.entry(spec.id) != null,
        tooltip: spec.tooltip,
        objectClass: _classOf(spec),
      ));
    }
    return out;
  }

  /// The class the node's Target (or first object input) is about.
  static String? _classOf(LuminaBlueprintNodeSpec spec) {
    for (final p in spec.inputs) {
      if (p.id == 'target' && p.type == LuminaPinType.object) return p.objectClass;
    }
    return null;
  }

  /// The generated rows of [context]: one `Get <Element>` per element of
  /// every widget class, one `Get <Component>` per component, and one
  /// `Cast To <Class>` per widget and actor class. With [from], only the
  /// rows that concern the dragged pin: the elements of its widget class,
  /// the components when it is Self.
  static List<BlueprintPaletteEntry> generated(
    LuminaBlueprintTypeContext context, {
    BlueprintPinRef? from,
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
  }) {
    final out = <BlueprintPaletteEntry>[];
    bool allowed(String id) {
      final spec = LuminaBlueprintNodeLibrary.spec(id);
      return spec != null && (filter == null || filter(spec));
    }

    final fromClass = from?.objectClass;
    final fromKind = fromClass == null ? null : LuminaBlueprintObjectClass.kind(fromClass);
    final fromName = fromClass == null ? '' : LuminaBlueprintObjectClass.name(fromClass);
    final fromIsOutput = from?.isOutput ?? true;

    // Get <Element>: from a Widget:<class> output, that class's elements; from
    // an input (or no pin) every class's elements, filtered later.
    if (allowed(LuminaBlueprintNodeLibrary.getWidgetElement)) {
      final spec = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.getWidgetElement)!;
      for (final w in context.widgetClasses) {
        if (from != null && fromIsOutput && !(fromKind == LuminaBlueprintObjectClass.widgetKind && (fromName.isEmpty || fromName == w.name))) {
          continue;
        }
        for (final e in w.elements) {
          out.add(BlueprintPaletteEntry(
            registryId: spec.id,
            title: 'Get ${e.name}',
            category: 'Widget|${w.name}',
            keywords: [e.name, e.typeName, LuminaBlueprintObjectClass.displayName(e.objectClass), w.name, 'element', 'widget'],
            headerColor: spec.headerColor,
            kind: spec.kind,
            literals: {'class': w.name, 'element': e.name},
            objectClass: w.objectClass,
          ));
        }
      }
    }

    // Get <Component>: the Blueprint's own tree, from Self or without a pin.
    if (allowed(LuminaBlueprintNodeLibrary.getComponent) && (from == null || !fromIsOutput || fromClass == context.selfClass)) {
      final spec = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.getComponent)!;
      for (final c in context.components) {
        out.add(BlueprintPaletteEntry(
          registryId: spec.id,
          title: 'Get ${c.name}',
          category: 'Components|${LuminaBlueprintObjectClass.displayName(context.selfClass)}',
          keywords: [c.name, c.componentClass, LuminaBlueprintObjectClass.displayName(c.objectClass), 'component', 'self'],
          headerColor: spec.headerColor,
          kind: spec.kind,
          literals: {'component': c.name},
          objectClass: context.selfClass,
        ));
      }
    }

    // `<Actor>` per placed actor of the level, typed by
    // its class; from a pin, only the actors that pin can take.
    if (context.isLevelScope && allowed(LuminaBlueprintNodeLibrary.getLevelActor) && (from == null || !fromIsOutput)) {
      for (final ref in context.levelActors!) {
        out.add(levelActorReference(ref));
      }
    }

    // A widget graph's variables and their element events.
    if (context.isWidgetScope) out.addAll(widgetEntries(context, from: from, filter: filter));

    out.addAll(signatureEntries(context, filter: filter));

    // Cast To <Class>: every widget class and every actor class.
    if (allowed(LuminaBlueprintNodeLibrary.castTo) && (from == null || fromIsOutput)) {
      final spec = LuminaBlueprintNodeLibrary.spec(LuminaBlueprintNodeLibrary.castTo)!;
      for (final cls in castTargets(context)) {
        out.add(BlueprintPaletteEntry(
          registryId: spec.id,
          title: 'Cast To ${LuminaBlueprintObjectClass.name(cls)}',
          category: spec.category,
          keywords: [...spec.keywords, LuminaBlueprintObjectClass.name(cls), LuminaBlueprintObjectClass.displayName(cls)],
          headerColor: spec.headerColor,
          kind: spec.kind,
          literals: {'class': cls},
          objectClass: cls,
        ));
      }
    }
    return out;
  }

  /// The rows bound to the document's signatures: a
  /// `Call <Function>` per user function (pure ones as pure nodes), a call
  /// per macro and custom event, Call / Bind / Unbind / Unbind All per
  /// dispatcher, `<Function> (Message)` per project interface function,
  /// `Event <Function>` per function of an implemented interface, the enum
  /// nodes per project enum, and local variable Get / Set in a function.
  static List<BlueprintPaletteEntry> signatureEntries(
    LuminaBlueprintTypeContext context, {
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
  }) {
    final out = <BlueprintPaletteEntry>[];
    void add(String id, String title, String category, Map<String, dynamic> literals, List<String> keywords, {String? objectClass}) {
      final spec = LuminaBlueprintNodeLibrary.spec(id);
      if (spec == null || (filter != null && !filter(spec))) return;
      out.add(BlueprintPaletteEntry(
        registryId: id,
        title: title,
        category: category,
        keywords: [...spec.keywords, ...keywords],
        headerColor: spec.headerColor,
        kind: spec.kind,
        literals: literals,
        objectClass: objectClass,
      ));
    }

    for (final f in context.functions) {
      add(f.pure ? LuminaBlueprintNodeLibrary.callFunctionPure : LuminaBlueprintNodeLibrary.callFunction, 'Call ${f.name}',
          'Call Function|${f.category}', {'function': f.name}, [f.name, LuminaBlueprintNodeLibrary.displayTitle(f.name), 'function', 'call']);
    }
    for (final m in context.macros) {
      add(LuminaBlueprintNodeLibrary.callMacro, m.name, 'Macros', {'macro': m.name}, [m.name, LuminaBlueprintNodeLibrary.displayTitle(m.name), 'macro']);
    }
    for (final e in context.customEvents) {
      add(LuminaBlueprintNodeLibrary.callCustomEvent, 'Call ${e.name}', 'Call Event', {'event': e.name}, [e.name, 'custom', 'event']);
    }
    // Another class's custom events, called on a Target of that
    // class (a Level Blueprint calls `Open` on Door_01).
    for (final owner in context.customEventOwners.entries) {
      final cls = LuminaBlueprintObjectClass.actor(owner.key);
      if (cls == context.selfClass) continue;
      for (final e in owner.value) {
        add(LuminaBlueprintNodeLibrary.callCustomEvent, 'Call ${e.name}', 'Call Event|${owner.key}', {'event': e.name, 'class': cls},
            [e.name, owner.key, 'custom', 'event'],
            objectClass: cls);
      }
    }
    for (final d in context.dispatchers) {
      final display = LuminaBlueprintNodeLibrary.displayTitle(d.name);
      add(LuminaBlueprintNodeLibrary.callDispatcher, 'Call $display', 'Event Dispatchers|${d.name}', {'dispatcher': d.name}, [d.name]);
      add(LuminaBlueprintNodeLibrary.bindEventToDispatcher, 'Bind Event to $display', 'Event Dispatchers|${d.name}', {'dispatcher': d.name}, [d.name]);
      add(LuminaBlueprintNodeLibrary.unbindEventFromDispatcher, 'Unbind Event from $display', 'Event Dispatchers|${d.name}', {'dispatcher': d.name}, [d.name]);
      add(LuminaBlueprintNodeLibrary.unbindAllEvents, 'Unbind all Events from $display', 'Event Dispatchers|${d.name}', {'dispatcher': d.name}, [d.name]);
    }
    final implemented = <String>{};
    final selfName = LuminaBlueprintObjectClass.name(context.selfClass);
    // The interfaces this Blueprint implements are the ones whose events it
    // may place; the type context lists them under the self class's parents.
    for (final i in context.interfaces) {
      for (final fn in i.functions) {
        add(LuminaBlueprintNodeLibrary.interfaceMessage, '${LuminaBlueprintNodeLibrary.displayTitle(fn.name)} (Message)', 'Interface Messages|${i.name}',
            {'interface': i.name, 'function': fn.name}, [i.name, fn.name, 'message', 'interface']);
      }
    }
    for (final name in BlueprintEditorTypeContext.implementedBy(context)) {
      final i = context.interface(name);
      if (i == null || !implemented.add(name)) continue;
      for (final fn in i.functions) {
        add(LuminaBlueprintNodeLibrary.eventInterfaceFunction, 'Event ${LuminaBlueprintNodeLibrary.displayTitle(fn.name)}', 'Events|Interfaces|${i.name}',
            {'interface': i.name, 'function': fn.name}, [i.name, fn.name, 'interface', 'event', selfName]);
      }
    }
    for (final e in context.enums) {
      add(LuminaBlueprintNodeLibrary.enumLiteral, e.name, 'Utilities|Enum|${e.name}', {'enum': e.name}, [e.name, ...e.values]);
      add(LuminaBlueprintNodeLibrary.switchOnEnum, 'Switch on ${e.name}', 'Flow Control|Switch', {'enum': e.name}, [e.name]);
      add('int_to_enum', 'Int to ${e.name}', 'Utilities|Enum|${e.name}', {'enum': e.name}, [e.name]);
      add('get_enum_value_count', 'Get ${e.name} Value Count', 'Utilities|Enum|${e.name}', {'enum': e.name}, [e.name]);
    }
    final scope = context.functionScope;
    if (scope != null) {
      for (final v in scope.localVariables) {
        add(LuminaBlueprintNodeLibrary.localVariableGet, 'Get ${v.name}', 'Variables|Local', {'variable': v.name}, [v.name, v.typeName, 'local'],
            objectClass: v.objectClass);
        add(LuminaBlueprintNodeLibrary.localVariableSet, 'Set ${v.name}', 'Variables|Local', {'variable': v.name}, [v.name, v.typeName, 'local'],
            objectClass: v.objectClass);
      }
    }
    return out;
  }

  /// The classes a Cast To can target in [context]: the widget classes, then
  /// the project's Blueprint actor classes and the engine's actor classes.
  static List<String> castTargets(LuminaBlueprintTypeContext context) => [
        for (final w in context.widgetClasses) w.objectClass,
        for (final name in {...context.actorParents.keys, ...engineActorClasses}) LuminaBlueprintObjectClass.actor(name),
      ];

  /// The context-sensitive palette for a drag off [from] (or the full
  /// palette when null): library entries, variable nodes, the generated
  /// typed rows, each narrowed to nodes with a pin [from] can join, and —
  /// for a data output — Promote to Variable pinned first. Pure: the same
  /// inputs give the same rows.
  static List<BlueprintPaletteEntry> entriesFor(
    LuminaBlueprintTypeContext context,
    BlueprintPinRef? from, {
    bool Function(LuminaBlueprintNodeSpec spec)? filter,
    bool allowPromote = true,
  }) {
    final inScope = scoped(context, filter);
    final all = [
      ...entries(variables: context.variables, filter: inScope),
      ...generated(context, from: from, filter: inScope),
    ];
    if (from == null) return all;
    return [
      if (allowPromote && from.isOutput && from.type != LuminaPinType.exec && !from.isSelf) promoteToVariable,
      ...compatibleWith(all, from, context),
    ];
  }

  /// [entries] matching [query]: every term must occur in the entry's
  /// haystack, built once per entry per search.
  static List<BlueprintPaletteEntry> search(List<BlueprintPaletteEntry> entries, String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return List.of(entries);
    return [
      for (final e in entries)
        if (terms.every(e.haystack.contains)) e,
    ];
  }

  /// How well [entry] answers [query], for ordering search results: 0 when every term is in the title (`movement` → Add Movement
  /// Input), 1 when only the category, id or keywords match.
  static int rank(BlueprintPaletteEntry entry, String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final title = entry.title.toLowerCase();
    return terms.every(title.contains) ? 0 : 1;
  }

  /// How closely [entry] concerns the class of the dragged pin [from], for
  /// ordering a context-sensitive palette: 0 when the entry
  /// is about exactly that class (the widget's elements, the element type's
  /// setters, the component class's nodes), 1 when about a class the pin is
  /// assignable to (any widget, any element), 2 for nodes that take any
  /// object or another type.
  static int relevance(BlueprintPaletteEntry entry, BlueprintPinRef? from, LuminaBlueprintTypeContext context) {
    final cls = from?.objectClass;
    final about = entry.objectClass;
    if (cls == null || about == null || from?.type != LuminaPinType.object) return 2;
    if (about == cls) return 0;
    return LuminaBlueprintObjectClass.isAssignable(cls, about, parents: context.actorParents) ? 1 : 2;
  }

  /// The pin of [entry]'s node a wire from [from] would join: an input the
  /// library lets [from] connect to when [from] is an output, an output when
  /// it is an input. Null when the node has no such pin, or [entry] is an
  /// action.
  static String? compatiblePin(BlueprintPaletteEntry entry, BlueprintPinRef from, LuminaBlueprintTypeContext context) {
    if (entry.isAction) return null;
    final probe = LuminaBlueprintNode(id: '_probe', registryId: entry.registryId, title: entry.title, literals: {...entry.literals});
    final pins = LuminaBlueprintNodeLibrary.pinsOf(probe, context);
    if (pins == null) return null;
    final fromSpec = from.spec;
    for (final p in from.isOutput ? pins.inputs : pins.outputs) {
      final ok = from.isOutput
          ? LuminaBlueprintNodeLibrary.canConnect(fromSpec, p, context: context)
          : LuminaBlueprintNodeLibrary.canConnect(p, fromSpec, context: context);
      if (ok) return p.id;
    }
    return null;
  }

  /// [entries] narrowed to nodes with a pin [from] can connect to. Actions
  /// stay, and so do the `Get <Component>` rows and the nodes that act on an
  /// implicit Self (`Self|…` and the `…_trace_forward` traces,
  /// no target pin) of a Self drag: Self is the node's implicit target, not
  /// a wire.
  static List<BlueprintPaletteEntry> compatibleWith(
    List<BlueprintPaletteEntry> entries,
    BlueprintPinRef from,
    LuminaBlueprintTypeContext context,
  ) =>
      entries
          .where((e) =>
              e.isAction ||
              (from.isSelf && takesImplicitSelf(e)) ||
              compatiblePin(e, from, context) != null)
          .toList();

  /// Whether [entry] acts on the Blueprint's own actor without a target
  /// pin, so a Self drag offers it.
  static bool takesImplicitSelf(BlueprintPaletteEntry entry) =>
      entry.registryId == LuminaBlueprintNodeLibrary.getComponent ||
      entry.category.startsWith('Self') ||
      (LuminaBlueprintNodeLibrary.traceNodes.contains(entry.registryId) && entry.registryId.endsWith('_forward'));

  /// The name for a promoted variable: the pin's name in PascalCase
  /// (`Return Value` of a `Create Widget` of `WBP_HUD` → `HudWidget`; `As
  /// Class` of a Cast To `BP_Door` → `AsBpDoor`; `Delta Seconds` →
  /// `DeltaSeconds`).
  static String promotedName(String pinName, {String? objectClass, String? nodeRegistryId}) {
    // `HUD` → `Hud`: a promoted name is title-cased.
    String pascal(String s) => s
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase() == w ? w[0] + w.substring(1).toLowerCase() : w[0].toUpperCase() + w.substring(1))
        .join();
    if (pinName == 'Return Value' || pinName == 'As Class') {
      final cls = objectClass == null ? '' : LuminaBlueprintObjectClass.name(objectClass);
      if (cls.isNotEmpty) {
        if (pinName == 'As Class') return 'As${pascal(cls)}';
        final kind = LuminaBlueprintObjectClass.kind(objectClass!);
        final base = pascal(cls.replaceFirst(RegExp(r'^(WBP|BP)_'), '').replaceFirst(RegExp(r'^Lumina'), ''));
        final name = kind == LuminaBlueprintObjectClass.widgetKind ? '${base}Widget' : base;
        if (name.isNotEmpty) return name;
      }
      if (nodeRegistryId != null) {
        final spec = LuminaBlueprintNodeLibrary.spec(nodeRegistryId);
        if (spec != null) return pascal(spec.title.replaceAll(RegExp(r'\(.*\)'), ''));
      }
    }
    final name = pascal(pinName);
    return name.isEmpty ? 'NewVar' : name;
  }
}
