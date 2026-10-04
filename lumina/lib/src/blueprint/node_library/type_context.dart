part of '../node_library.dart';

/// What a node's dynamic pins depend on: the document's variables, the
/// project's input actions and, for typed object pins, the
/// project's widget classes, the document's component tree, the class of
/// `Self` and the parent chain of the project's Blueprint classes.
class LuminaBlueprintTypeContext {
  final List<LuminaBlueprintVariable> variables;
  final List<LuminaInputAction> inputActions;

  /// The widget classes `Create Widget` can make and `Get <Element>` reads.
  final List<LuminaBlueprintWidgetClass> widgetClasses;

  /// The components of the Blueprint (`Get CameraBoom` → Spring Arm).
  final List<LuminaBlueprintComponentRef> components;

  /// The class of `Self` (`Actor:LuminaCharacter`, `Actor:BP_Door`).
  final String selfClass;

  /// Project Blueprint class → its parent (`BP_Door` → `LuminaActor`), for
  /// assignability up the chain.
  final Map<String, String> actorParents;

  /// The document's user functions, macros and dispatchers.
  final List<LuminaBlueprintFunctionGraph> functions;
  final List<LuminaBlueprintMacroGraph> macros;
  final List<LuminaBlueprintDispatcher> dispatchers;

  /// Dispatchers of other Blueprint classes by class name, for
  /// `Bind Event to <Dispatcher>` on a typed target.
  final Map<String, List<LuminaBlueprintDispatcher>> dispatcherOwners;

  /// The custom events the event graph declares.
  final List<LuminaBlueprintCustomEvent> customEvents;

  /// The project's enum and interface assets (default: the registries).
  final List<LuminaBlueprintEnumDocument> enums;
  final List<LuminaBlueprintInterfaceDocument> interfaces;

  /// The project's GameMode Blueprint class (`BP_ThirdPersonGameMode`), what
  /// `Get Game Mode` is typed as.
  final String? gameModeClass;

  /// The project's save-game classes (default: the registry).
  final List<LuminaBlueprintSaveGameDocument> saveGameClasses;

  /// The function or macro whose graph is being resolved, when one is
  /// (`function_entry` / `function_result` / local variables / `macro_input`
  /// / `macro_output` type from it).
  final LuminaBlueprintFunctionGraph? functionScope;
  final LuminaBlueprintMacroGraph? macroScope;

  /// The placed actors a Level Blueprint refers to by name;
  /// null outside a Level Blueprint.
  final List<LuminaBlueprintLevelActorRef>? levelActors;

  /// Custom events of other Blueprint classes by class name, for a Call
  /// Custom Event on a typed target (e.g. a Level Blueprint calls
  /// `Open` on `Door_01`).
  final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners;

  /// Member variables of other Blueprint classes by class name, for
  /// `Get <Variable>` and `Set <Variable>` on a typed target.
  final Map<String, List<LuminaBlueprintVariable>> variableOwners;

  /// Components of other Blueprint classes by class name, for
  /// `Get <Component>` on a typed target.
  final Map<String, List<LuminaBlueprintComponentRef>> componentOwners;

  /// The `Is Variable` elements of the widget a Widget Blueprint graph
  /// scripts; null outside a Widget Blueprint.
  final List<LuminaBlueprintWidgetElement>? widgetVariables;

  const LuminaBlueprintTypeContext({
    this.variables = const [],
    this.inputActions = const [],
    this.widgetClasses = const [],
    this.components = const [],
    this.selfClass = LuminaBlueprintObjectClass.anyActor,
    this.actorParents = const {},
    this.functions = const [],
    this.macros = const [],
    this.dispatchers = const [],
    this.dispatcherOwners = const {},
    this.customEvents = const [],
    this.enums = const [],
    this.interfaces = const [],
    this.gameModeClass,
    this.saveGameClasses = const [],
    this.functionScope,
    this.macroScope,
    this.levelActors,
    this.customEventOwners = const {},
    this.variableOwners = const {},
    this.componentOwners = const {},
    this.widgetVariables,
  });

  /// Whether this is a Level Blueprint's graph.
  bool get isLevelScope => levelActors != null;

  /// Whether this is a Widget Blueprint's graph.
  bool get isWidgetScope => widgetVariables != null;

  /// The widget variable (an `Is Variable` element) named [name], or null.
  LuminaBlueprintWidgetElement? widgetVariable(String? name) {
    for (final v in widgetVariables ?? const <LuminaBlueprintWidgetElement>[]) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// The placed actor [name] of the level, or null.
  LuminaBlueprintLevelActorRef? levelActor(String? name) {
    for (final a in levelActors ?? const <LuminaBlueprintLevelActorRef>[]) {
      if (a.name == name) return a;
    }
    return null;
  }

  LuminaBlueprintSaveGameDocument? saveGameClass(String? cls) {
    final name = cls == null ? null : (LuminaBlueprintObjectClass.kind(cls) == LuminaBlueprintObjectClass.saveGameKind ? LuminaBlueprintObjectClass.name(cls) : cls);
    for (final c in saveGameClasses) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// The context of [doc]: its variables and components, `Self` typed as its
  /// parent class (or [className] when given, the Blueprint's own class),
  /// plus the widget classes of [widgetClasses] (default: the
  /// [LuminaWidgetClassRegistry]), its functions, macros, dispatchers and
  /// custom events, and the project's enums / interfaces (default: the
  /// registries).
  factory LuminaBlueprintTypeContext.forDocument(
    LuminaBlueprintDocument doc, {
    List<LuminaInputAction> inputActions = const [],
    List<LuminaBlueprintWidgetClass>? widgetClasses,
    String? className,
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintDispatcher>> dispatcherOwners = const {},
    List<LuminaBlueprintEnumDocument>? enums,
    List<LuminaBlueprintInterfaceDocument>? interfaces,
    String? gameModeClass,
    List<LuminaBlueprintSaveGameDocument>? saveGameClasses,
    LuminaBlueprintFunctionGraph? functionScope,
    LuminaBlueprintMacroGraph? macroScope,
    List<LuminaBlueprintLevelActorRef>? levelActors,
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
    List<LuminaBlueprintWidgetElement>? widgetVariables,
    List<LuminaBlueprintVariable>? inheritedVariables,
    List<LuminaBlueprintComponent>? inheritedComponents,
  }) {
    final childVarNames = {for (final v in doc.variables) v.name};
    final effectiveVariables = [
      if (inheritedVariables != null)
        for (final v in inheritedVariables)
          if (!childVarNames.contains(v.name)) v,
      ...doc.variables,
    ];
    final childCompIds = {for (final c in doc.components) c.id};
    final effectiveComponents = [
      if (inheritedComponents != null)
        for (final c in inheritedComponents)
          if (!childCompIds.contains(c.id)) c,
      ...doc.components,
    ];
    return LuminaBlueprintTypeContext(
      variables: effectiveVariables,
      inputActions: inputActions,
      widgetClasses: widgetClasses ?? LuminaWidgetClassRegistry.classes,
      components: LuminaBlueprintComponentRef.fromComponents(effectiveComponents),
      // A widget graph's Self is the widget (`Widget:WBP_Clicker`).
      selfClass: widgetVariables != null
          ? LuminaBlueprintObjectClass.widget(className ?? '')
          : LuminaBlueprintObjectClass.actor(className ?? doc.parentClass),
      actorParents: {
        ...actorParents,
        if (widgetVariables == null && className != null && className != doc.parentClass) className: doc.parentClass,
      },
      functions: doc.functions,
      macros: doc.macros,
      dispatchers: doc.dispatchers,
      dispatcherOwners: {...dispatcherOwners, ?className: doc.dispatchers},
      customEvents: LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph),
      enums: enums ?? LuminaBlueprintEnums.all,
      interfaces: interfaces ?? LuminaBlueprintInterfaces.all,
      gameModeClass: gameModeClass,
      saveGameClasses: saveGameClasses ?? LuminaBlueprintSaveGameClasses.all,
      functionScope: functionScope,
      macroScope: macroScope,
      levelActors: levelActors,
      customEventOwners: customEventOwners,
      variableOwners: {
        ...variableOwners,
        ?className: effectiveVariables,
      },
      componentOwners: {
        ...componentOwners,
        ?className: LuminaBlueprintComponentRef.fromComponents(effectiveComponents),
      },
      widgetVariables: widgetVariables,
    );
  }

  /// A Widget Blueprint's context: [widgetDoc]'s graph, `Self`
  /// typed `Widget:<class>`, and its `Is Variable` elements, which
  /// `Get <Element>` reads with no target and bound events are keyed by.
  factory LuminaBlueprintTypeContext.forWidget(
    LuminaWidgetBlueprintDocument widgetDoc, {
    List<LuminaInputAction> inputActions = const [],
    List<LuminaBlueprintWidgetClass>? widgetClasses,
    Map<String, String> actorParents = const {},
    List<LuminaBlueprintEnumDocument>? enums,
    List<LuminaBlueprintInterfaceDocument>? interfaces,
    String? gameModeClass,
    List<LuminaBlueprintSaveGameDocument>? saveGameClasses,
    LuminaBlueprintFunctionGraph? functionScope,
    LuminaBlueprintMacroGraph? macroScope,
  }) =>
      LuminaBlueprintTypeContext.forDocument(widgetDoc.blueprint,
          inputActions: inputActions,
          widgetClasses: widgetClasses,
          className: widgetDoc.widgetClass,
          actorParents: actorParents,
          enums: enums,
          interfaces: interfaces,
          gameModeClass: gameModeClass,
          saveGameClasses: saveGameClasses,
          functionScope: functionScope,
          macroScope: macroScope,
          widgetVariables: widgetDoc.variables);

  /// A Level Blueprint's context: [levelDoc]'s variables,
  /// functions…, `Self` typed `Actor:LuminaLevelScriptActor`, and the level's
  /// placed actors ([levelActors]) that `Get <Actor>` refers to by name, with
  /// their project Blueprint classes' parents ([actorParents]) and custom
  /// events ([customEventOwners]).
  factory LuminaBlueprintTypeContext.forLevel(
    LuminaLevelBlueprintDocument levelDoc, {
    List<LuminaBlueprintLevelActorRef> levelActors = const [],
    List<LuminaInputAction> inputActions = const [],
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintDispatcher>> dispatcherOwners = const {},
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
    List<LuminaBlueprintEnumDocument>? enums,
    List<LuminaBlueprintInterfaceDocument>? interfaces,
    String? gameModeClass,
    List<LuminaBlueprintSaveGameDocument>? saveGameClasses,
    LuminaBlueprintFunctionGraph? functionScope,
    LuminaBlueprintMacroGraph? macroScope,
  }) =>
      LuminaBlueprintTypeContext.forDocument(levelDoc.blueprint,
          inputActions: inputActions,
          className: LuminaLevelBlueprintDocument.parentClass,
          actorParents: actorParents,
          dispatcherOwners: dispatcherOwners,
          enums: enums,
          interfaces: interfaces,
          gameModeClass: gameModeClass,
          saveGameClasses: saveGameClasses,
          functionScope: functionScope,
          macroScope: macroScope,
          levelActors: levelActors,
          customEventOwners: customEventOwners,
          variableOwners: variableOwners,
          componentOwners: componentOwners);

  /// This context for [function]'s or [macro]'s graph of [doc]: everything
  /// the event graph knows (level actors, owners…) in that scope.
  LuminaBlueprintTypeContext scoped(LuminaBlueprintDocument doc,
          {LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) =>
      LuminaBlueprintTypeContext(
        variables: variables,
        inputActions: inputActions,
        widgetClasses: widgetClasses,
        components: components,
        selfClass: selfClass,
        actorParents: actorParents,
        functions: functions,
        macros: macros,
        dispatchers: dispatchers,
        dispatcherOwners: dispatcherOwners,
        customEvents: customEvents,
        enums: enums,
        interfaces: interfaces,
        gameModeClass: gameModeClass,
        saveGameClasses: saveGameClasses,
        functionScope: function,
        macroScope: macro,
        levelActors: levelActors,
        customEventOwners: customEventOwners,
        variableOwners: variableOwners,
        componentOwners: componentOwners,
        widgetVariables: widgetVariables,
      );

  /// The context of [function]'s own graph inside [doc].
  factory LuminaBlueprintTypeContext.forFunction(
    LuminaBlueprintDocument doc,
    LuminaBlueprintFunctionGraph function, {
    List<LuminaInputAction> inputActions = const [],
    String? className,
    Map<String, String> actorParents = const {},
    List<LuminaBlueprintEnumDocument>? enums,
    List<LuminaBlueprintInterfaceDocument>? interfaces,
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
  }) =>
      LuminaBlueprintTypeContext.forDocument(doc,
          inputActions: inputActions,
          className: className,
          actorParents: actorParents,
          enums: enums,
          interfaces: interfaces,
          functionScope: function,
          customEventOwners: customEventOwners,
          variableOwners: variableOwners,
          componentOwners: componentOwners);

  /// The context of [macro]'s body inside [doc].
  factory LuminaBlueprintTypeContext.forMacro(
    LuminaBlueprintDocument doc,
    LuminaBlueprintMacroGraph macro, {
    List<LuminaInputAction> inputActions = const [],
    String? className,
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
  }) =>
      LuminaBlueprintTypeContext.forDocument(doc,
          inputActions: inputActions,
          className: className,
          actorParents: actorParents,
          macroScope: macro,
          customEventOwners: customEventOwners,
          variableOwners: variableOwners,
          componentOwners: componentOwners);

  LuminaBlueprintFunctionGraph? function(String? name) {
    for (final f in functions) {
      if (f.name == name) return f;
    }
    return null;
  }

  LuminaBlueprintMacroGraph? macro(String? name) {
    for (final m in macros) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// The dispatcher [name] of this Blueprint, or of the class [ownerClass]
  /// (`Actor:BP_Door` / `BP_Door`) when given and known.
  LuminaBlueprintDispatcher? dispatcher(String? name, {String? ownerClass}) {
    if (ownerClass != null) {
      final raw = LuminaBlueprintObjectClass.name(ownerClass);
      var current = raw.isEmpty ? ownerClass : raw;
      final visited = <String>{};
      while (current.isNotEmpty && visited.add(current)) {
        for (final d in dispatcherOwners[current] ?? const <LuminaBlueprintDispatcher>[]) {
          if (d.name == name) return d;
        }
        final parent = actorParents[current];
        if (parent == null || parent.isEmpty || parent == current) break;
        final parentRaw = LuminaBlueprintObjectClass.name(parent);
        current = parentRaw.isEmpty ? parent : parentRaw;
      }
    }
    for (final d in dispatchers) {
      if (d.name == name) return d;
    }
    for (final list in dispatcherOwners.values) {
      for (final d in list) {
        if (d.name == name) return d;
      }
    }
    return null;
  }

  LuminaBlueprintCustomEvent? customEvent(String? name) {
    for (final e in customEvents) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// The custom event [name] of class string [cls] (`Actor:BP_Door`): its
  /// own when [cls] is Self's class, else [customEventOwners]'.
  LuminaBlueprintCustomEvent? customEventOf(String cls, String? name) {
    final raw = LuminaBlueprintObjectClass.name(cls);
    final targetName = raw.isEmpty ? cls : raw;
    final selfRaw = LuminaBlueprintObjectClass.name(selfClass);
    final selfName = selfRaw.isEmpty ? selfClass : selfRaw;
    if (targetName == selfName) {
      return customEvent(name);
    }
    var current = targetName;
    final visited = <String>{};
    while (current.isNotEmpty && visited.add(current)) {
      for (final e in customEventOwners[current] ?? const <LuminaBlueprintCustomEvent>[]) {
        if (e.name == name) return e;
      }
      final parent = actorParents[current];
      if (parent == null || parent.isEmpty || parent == current) break;
      final parentRaw = LuminaBlueprintObjectClass.name(parent);
      current = parentRaw.isEmpty ? parent : parentRaw;
    }
    return null;
  }

  /// The member variable [name] of class string [cls] (`Actor:BP_Interactable`):
  /// its own when [cls] is Self's class, else [variableOwners]'.
  LuminaBlueprintVariable? variableOf(String cls, String? name) {
    final raw = LuminaBlueprintObjectClass.name(cls);
    final targetName = raw.isEmpty ? cls : raw;
    final selfRaw = LuminaBlueprintObjectClass.name(selfClass);
    final selfName = selfRaw.isEmpty ? selfClass : selfRaw;
    if (targetName == selfName) {
      return variable(name);
    }
    var current = targetName;
    final visited = <String>{};
    while (current.isNotEmpty && visited.add(current)) {
      for (final v in variableOwners[current] ?? const <LuminaBlueprintVariable>[]) {
        if (v.name == name) return v;
      }
      final parent = actorParents[current];
      if (parent == null || parent.isEmpty || parent == current) break;
      final parentRaw = LuminaBlueprintObjectClass.name(parent);
      current = parentRaw.isEmpty ? parent : parentRaw;
    }
    return null;
  }

  /// The component [name] of class string [cls] (`Actor:BP_Interactable`):
  /// its own when [cls] is Self's class, else [componentOwners]'.
  LuminaBlueprintComponentRef? componentOf(String cls, String? name) {
    final raw = LuminaBlueprintObjectClass.name(cls);
    final targetName = raw.isEmpty ? cls : raw;
    final selfRaw = LuminaBlueprintObjectClass.name(selfClass);
    final selfName = selfRaw.isEmpty ? selfClass : selfRaw;
    if (targetName == selfName) {
      return component(name);
    }
    var current = targetName;
    final visited = <String>{};
    while (current.isNotEmpty && visited.add(current)) {
      for (final c in componentOwners[current] ?? const <LuminaBlueprintComponentRef>[]) {
        if (c.name == name || c.id == name) return c;
      }
      final parent = actorParents[current];
      if (parent == null || parent.isEmpty || parent == current) break;
      final parentRaw = LuminaBlueprintObjectClass.name(parent);
      current = parentRaw.isEmpty ? parent : parentRaw;
    }
    return null;
  }

  LuminaBlueprintEnumDocument? enumeration(String? name) {
    for (final e in enums) {
      if (e.name == name) return e;
    }
    return null;
  }

  LuminaBlueprintInterfaceDocument? interface(String? name) {
    for (final i in interfaces) {
      if (i.name == name) return i;
    }
    return null;
  }

  /// A local variable of the function being resolved.
  LuminaBlueprintVariable? localVariable(String? name) => functionScope?.localVariable(name ?? '');

  LuminaBlueprintVariable? variable(String? name) {
    for (final v in variables) {
      if (v.name == name) return v;
    }
    return null;
  }

  LuminaInputAction? inputAction(String? name) {
    for (final a in inputActions) {
      if (a.name == name) return a;
    }
    return null;
  }

  LuminaBlueprintWidgetClass? widgetClass(String? name) {
    for (final w in widgetClasses) {
      if (w.name == name) return w;
    }
    return null;
  }

  /// The element [elementName] of widget class [className], or of the first
  /// class that has one by that name when [className] is null.
  ({LuminaBlueprintWidgetClass cls, LuminaBlueprintWidgetElement element})? widgetElement(
      String? className, String? elementName) {
    for (final w in widgetClasses) {
      if (className != null && w.name != className) continue;
      final e = w.element(elementName);
      if (e != null) return (cls: w, element: e);
    }
    return null;
  }

  LuminaBlueprintComponentRef? component(String? name) {
    for (final c in components) {
      if (c.name == name || c.id == name) return c;
    }
    return null;
  }

  /// Why a value of object class [from] cannot feed a pin of class [to]
  /// (see [LuminaBlueprintObjectClass.assignError]).
  String? assignError(String? from, String? to) =>
      LuminaBlueprintObjectClass.assignError(from, to, parents: actorParents);
}
