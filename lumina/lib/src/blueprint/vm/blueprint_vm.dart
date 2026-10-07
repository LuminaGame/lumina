import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:lumina/src/object/lumina_object_key.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/controller/controller.dart';
import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/game/game_mode.dart';
import 'package:lumina/src/input/input_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/character.dart';
import 'package:lumina/src/object/pawn.dart';
import 'package:lumina/src/umg/user_widget.dart';
import 'package:lumina/src/world/level_script_actor.dart';
import 'package:lumina/src/blueprint/blueprint_function_library.dart';
import 'package:lumina/src/blueprint/blueprint_function_registry.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_validator.dart';
import 'package:lumina/src/blueprint/editor_nodes.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/blueprint/blueprint_runtime.dart';
import 'package:lumina/src/blueprint/component_mapping.dart';
import 'package:lumina/src/blueprint/blueprint_enums_interfaces.dart';
import 'package:lumina/src/blueprint/level_blueprint.dart';
import 'package:lumina/src/blueprint/macro_expander.dart';
import 'package:lumina/src/blueprint/node_library.dart';
import 'package:lumina/src/blueprint/timeline_curve.dart';
import 'package:lumina/src/blueprint/widget_blueprint.dart';
import 'package:lumina/src/blueprint/widget_classes.dart';

part 'blueprint_vm/instance.dart';
part 'blueprint_vm/frame.dart';

/// Thrown by [LuminaBlueprintClass.instantiate] for a Blueprint with errors.
class LuminaBlueprintCompileError implements Exception {
  final String blueprint;
  final List<LuminaBlueprintDiagnostic> errors;
  const LuminaBlueprintCompileError(this.blueprint, this.errors);

  @override
  String toString() => 'Blueprint $blueprint has ${errors.length} error(s): ${errors.join('; ')}';
}

/// A Blueprint document ready to run in the VM: validated
/// once, then instantiated any number of times.
class LuminaBlueprintClass {
  /// The asset name, used in messages (`BP_ThirdPersonCharacter`).
  final String name;
  final LuminaBlueprintDocument document;
  final List<LuminaInputAction> inputActions;
  final LuminaBlueprintAssetResolver? resolveAsset;
  final Future<Uint8List> Function(String path)? assetProvider;

  /// Resolves a Skeletal Mesh's `animClass` to its Animation Blueprint.
  final LuminaAnimBlueprintFactory? Function(String animClass)? animBlueprints;

  /// Resolves another Blueprint class by its project-relative `.lmas` path —
  /// a GameMode Blueprint's Default Pawn Class. Called again at
  /// every spawn, so a registry that reloads recompiled classes serves the
  /// newest one.
  final LuminaBlueprintClass? Function(String path)? resolveClass;
  final List<LuminaBlueprintDiagnostic> diagnostics;

  /// A Level Blueprint's placed actors; null for a class
  /// Blueprint.
  final List<LuminaBlueprintLevelActorRef>? levelActors;

  /// Project Blueprint class → parent, and other classes' custom events, for
  /// typing object pins and targeted Call Custom Event.
  final Map<String, String> actorParents;
  final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners;
  final Map<String, List<LuminaBlueprintVariable>> variableOwners;
  final Map<String, List<LuminaBlueprintComponentRef>> componentOwners;

  /// A Widget Blueprint's `Is Variable` elements; null for any
  /// other Blueprint.
  final List<LuminaBlueprintWidgetElement>? widgetVariables;

  /// The parent Blueprint class when this class inherits another Blueprint.
  final LuminaBlueprintClass? parentBlueprintClass;

  LuminaBlueprintClass._(this.name, this.document, this.inputActions, this.resolveAsset, this.assetProvider,
      this.animBlueprints, this.resolveClass, this.diagnostics,
      {this.levelActors,
      this.actorParents = const {},
      this.customEventOwners = const {},
      this.variableOwners = const {},
      this.componentOwners = const {},
      this.widgetVariables,
      this.parentBlueprintClass});

  /// The root engine class this Blueprint descends from (e.g. `LuminaCharacter`, `LuminaPawn`, `LuminaActor`).
  String get rootEngineClass {
    if (parentBlueprintClass != null) return parentBlueprintClass!.rootEngineClass;
    if (isEngineParent(document.parentClass)) return document.parentClass;
    var current = document.parentClass;
    final visited = <String>{name};
    while (current.isNotEmpty && !isEngineParent(current) && visited.add(current)) {
      current = actorParents[current] ?? '';
    }
    return isEngineParent(current) ? current : 'LuminaActor';
  }

  /// The chain of parent Blueprint classes this class inherits from, from immediate
  /// parent to ancestor Blueprints (excluding engine classes).
  List<String> get parentClasses {
    final list = <String>[];
    final visited = <String>{name};
    var current = parentBlueprintClass;
    while (current != null && visited.add(current.name)) {
      list.add(current.name);
      current = current.parentBlueprintClass;
    }
    var parentName = document.parentClass;
    while (parentName.isNotEmpty && !isEngineParent(parentName) && visited.add(parentName)) {
      list.add(parentName);
      parentName = actorParents[parentName] ?? '';
    }
    return list;
  }

  /// All variables of this class, including inherited variables from parent Blueprints.
  /// Child variables override parent variables with the same name.
  List<LuminaBlueprintVariable> get allVariables {
    final parentVars = parentBlueprintClass?.allVariables ?? const <LuminaBlueprintVariable>[];
    final childVarNames = {for (final v in document.variables) v.name};
    return [
      for (final v in parentVars) if (!childVarNames.contains(v.name)) v,
      ...document.variables,
    ];
  }

  /// All components of this class, including inherited components from parent Blueprints.
  List<LuminaBlueprintComponent> get allComponents {
    final parentComps = parentBlueprintClass?.allComponents ?? const <LuminaBlueprintComponent>[];
    final childCompIds = {for (final c in document.components) c.id};
    return [
      for (final c in parentComps) if (!childCompIds.contains(c.id)) c,
      ...document.components,
    ];
  }

  /// All custom events inherited from parent Blueprints.
  List<LuminaBlueprintCustomEvent> get inheritedCustomEvents {
    if (parentBlueprintClass == null) return const [];
    return parentBlueprintClass!.allCustomEvents;
  }

  /// All custom events of this class, with child custom events overriding parent custom events of the same name.
  List<LuminaBlueprintCustomEvent> get allCustomEvents {
    final parentEvents = inheritedCustomEvents;
    final ownEvents = LuminaBlueprintNodeLibrary.customEventsOf(document.eventGraph);
    final ownNames = {for (final e in ownEvents) e.name};
    return [
      for (final e in parentEvents) if (!ownNames.contains(e.name)) e,
      ...ownEvents,
    ];
  }

  /// All class defaults of this class, with child defaults overriding parent defaults.
  Map<String, dynamic> get allClassDefaults => {
        ...?parentBlueprintClass?.allClassDefaults,
        ...document.classDefaults,
      };

  /// Whether this is a Widget Blueprint's graph (use [instantiateUserWidget]).
  bool get isUserWidget => document.parentClass == LuminaWidgetBlueprintDocument.parentClass;

  /// Whether this is a Level Blueprint (use [instantiateLevelScript]).
  bool get isLevelScript => document.parentClass == LuminaLevelBlueprintDocument.parentClass;

  /// Whether this is a GameMode Blueprint (use [createGameMode]).
  bool get isGameMode => rootEngineClass == 'LuminaGameMode';

  /// Whether this is a Pawn or Character Blueprint.
  bool get isPawn => rootEngineClass == 'LuminaPawn' || rootEngineClass == 'LuminaCharacter';

  /// Whether [parentClass] is an engine-level parent class rather than another Blueprint.
  static bool isEngineParent(String parentClass) =>
      parentClass == 'LuminaActor' ||
      parentClass == 'LuminaPawn' ||
      parentClass == 'LuminaCharacter' ||
      parentClass == 'LuminaGameMode' ||
      parentClass == LuminaLevelBlueprintDocument.parentClass ||
      parentClass == LuminaWidgetBlueprintDocument.parentClass ||
      LuminaBlueprintObjectClass.engineParents.containsKey(parentClass);

  /// The type context the class's graphs resolve in — [function]'s or
  /// [macro]'s graph when given.
  LuminaBlueprintTypeContext typeContext({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) =>
      _contextOf(document, name, inputActions, levelActors, actorParents, customEventOwners,
          variableOwners: variableOwners,
          componentOwners: componentOwners,
          functionScope: function,
          macroScope: macro,
          widgetVariables: widgetVariables,
          inheritedVariables: parentBlueprintClass?.allVariables,
          inheritedComponents: parentBlueprintClass?.allComponents,
          inheritedCustomEvents: parentBlueprintClass?.allCustomEvents);

  static LuminaBlueprintTypeContext _contextOf(
    LuminaBlueprintDocument document,
    String name,
    List<LuminaInputAction> inputActions,
    List<LuminaBlueprintLevelActorRef>? levelActors,
    Map<String, String> actorParents,
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners, {
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
    LuminaBlueprintFunctionGraph? functionScope,
    LuminaBlueprintMacroGraph? macroScope,
    List<LuminaBlueprintWidgetElement>? widgetVariables,
    List<LuminaBlueprintVariable>? inheritedVariables,
    List<LuminaBlueprintComponent>? inheritedComponents,
    List<LuminaBlueprintCustomEvent>? inheritedCustomEvents,
  }) {
    if (widgetVariables != null || document.parentClass == LuminaWidgetBlueprintDocument.parentClass) {
      return LuminaBlueprintTypeContext.forWidget(
          LuminaWidgetBlueprintDocument(widgetClass: name, variables: widgetVariables ?? const [], blueprint: document),
          inputActions: inputActions,
          actorParents: actorParents,
          functionScope: functionScope,
          macroScope: macroScope);
    }
    if (levelActors != null || document.parentClass == LuminaLevelBlueprintDocument.parentClass) {
      return LuminaBlueprintTypeContext.forLevel(LuminaLevelBlueprintDocument(levelPath: name, blueprint: document),
          levelActors: levelActors ?? const [],
          inputActions: inputActions,
          actorParents: actorParents,
          customEventOwners: customEventOwners,
          functionScope: functionScope,
          macroScope: macroScope);
    }
    return LuminaBlueprintTypeContext.forDocument(document,
        inputActions: inputActions,
        className: name,
        actorParents: actorParents,
        customEventOwners: customEventOwners,
        variableOwners: variableOwners,
        componentOwners: componentOwners,
        functionScope: functionScope,
        macroScope: macroScope,
        inheritedVariables: inheritedVariables,
        inheritedComponents: inheritedComponents,
        inheritedCustomEvents: inheritedCustomEvents);
  }

  /// A Level Blueprint ready to run: [levelDoc]'s graph with
  /// [levelActors] as the placed actors `Get <Actor>` finds, named after the
  /// level. Instantiate it with [instantiateLevelScript].
  factory LuminaBlueprintClass.forLevel(
    LuminaLevelBlueprintDocument levelDoc, {
    List<LuminaBlueprintLevelActorRef> levelActors = const [],
    String? name,
    List<LuminaInputAction> inputActions = const [],
    LuminaBlueprintAssetResolver? resolveAsset,
    Future<Uint8List> Function(String path)? assetProvider,
    LuminaBlueprintClass? Function(String path)? resolveClass,
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
  }) =>
      LuminaBlueprintClass.fromDocument(levelDoc.blueprint,
          name: name ?? levelDoc.levelName,
          inputActions: inputActions,
          resolveAsset: resolveAsset,
          assetProvider: assetProvider,
          resolveClass: resolveClass,
          levelActors: levelActors,
          actorParents: actorParents,
          customEventOwners: customEventOwners,
          variableOwners: variableOwners,
          componentOwners: componentOwners);

  /// A Widget Blueprint's graph ready to run: [widgetDoc]'s graph
  /// with its `Is Variable` elements, named after the widget class.
  /// Instantiate it with [instantiateUserWidget].
  factory LuminaBlueprintClass.forWidget(
    LuminaWidgetBlueprintDocument widgetDoc, {
    List<LuminaInputAction> inputActions = const [],
    LuminaBlueprintAssetResolver? resolveAsset,
    Future<Uint8List> Function(String path)? assetProvider,
    LuminaBlueprintClass? Function(String path)? resolveClass,
    Map<String, String> actorParents = const {},
  }) =>
      LuminaBlueprintClass.fromDocument(widgetDoc.blueprint,
          name: widgetDoc.widgetClass,
          inputActions: inputActions,
          resolveAsset: resolveAsset,
          assetProvider: assetProvider,
          resolveClass: resolveClass,
          actorParents: actorParents,
          widgetVariables: widgetDoc.variables);

  /// A new script of this Widget Blueprint, for [LuminaUserWidgets.register].
  LuminaBlueprintUserWidget instantiateUserWidget() {
    if (!isUserWidget) throw StateError('$name is not a Widget Blueprint (parent ${document.parentClass}).');
    return instantiate() as LuminaBlueprintUserWidget;
  }

  /// A new level script of this Level Blueprint, to set as the level's
  /// `scriptActor` before the world begins play.
  LuminaBlueprintLevelScript instantiateLevelScript({LuminaObjectKey? key}) {
    if (!isLevelScript) throw StateError('$name is not a Level Blueprint (parent ${document.parentClass}).');
    return instantiate(key: key) as LuminaBlueprintLevelScript;
  }

  /// A GameMode Blueprint's Default Pawn Class (its `.lmas` path), or ''.
  String get defaultPawnClass => document.classDefaults['defaultPawnClass'] as String? ?? '';

  factory LuminaBlueprintClass.fromDocument(
    LuminaBlueprintDocument document, {
    String name = 'Blueprint',
    List<LuminaInputAction> inputActions = const [],
    LuminaBlueprintAssetResolver? resolveAsset,
    Future<Uint8List> Function(String path)? assetProvider,
    LuminaAnimBlueprintFactory? Function(String animClass)? animBlueprints,
    LuminaBlueprintClass? Function(String path)? resolveClass,
    List<LuminaBlueprintLevelActorRef>? levelActors,
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    Map<String, List<LuminaBlueprintVariable>> variableOwners = const {},
    Map<String, List<LuminaBlueprintComponentRef>> componentOwners = const {},
    List<LuminaBlueprintWidgetElement>? widgetVariables,
    LuminaBlueprintClass? parentBlueprintClass,
    Set<String>? visitedClassNames,
  }) {
    // Comment boxes and reroutes are the editor's.
    document = LuminaBlueprintEditorNodes.forEngine(document);
    final levelScope = levelActors != null || document.parentClass == LuminaLevelBlueprintDocument.parentClass;
    // A Widget Blueprint's graph resolves in the widget's scope.
    final widgetScope = widgetVariables != null || document.parentClass == LuminaWidgetBlueprintDocument.parentClass;

    final currentActorParents = Map<String, String>.from(actorParents);
    final currentCustomEvents = Map<String, List<LuminaBlueprintCustomEvent>>.from(customEventOwners);
    final visited = visitedClassNames != null ? Set<String>.from(visitedClassNames) : <String>{};
    visited.add(name);

    final diagnostics = <LuminaBlueprintDiagnostic>[];

    if (parentBlueprintClass == null && !isEngineParent(document.parentClass) && resolveClass != null) {
      if (visited.contains(document.parentClass)) {
        diagnostics.add(LuminaBlueprintDiagnostic(
          LuminaBlueprintSeverity.error,
          "Circular inheritance detected in Blueprint '$name': extends '${document.parentClass}'.",
        ));
      } else {
        parentBlueprintClass = resolveClass(document.parentClass);
        if (parentBlueprintClass != null &&
            parentBlueprintClass.diagnostics.any((d) => d.message.contains('Circular inheritance'))) {
          diagnostics.add(LuminaBlueprintDiagnostic(
            LuminaBlueprintSeverity.error,
            "Circular inheritance detected in parent hierarchy of '$name': extends '${document.parentClass}'.",
          ));
        }
      }
    }

    if (parentBlueprintClass != null) {
      currentActorParents.addAll(parentBlueprintClass.actorParents);
      currentActorParents[name] = document.parentClass;
      currentCustomEvents.addAll(parentBlueprintClass.customEventOwners);
    }

    final inheritedVars = parentBlueprintClass?.allVariables;
    final inheritedComps = parentBlueprintClass?.allComponents;
    final inheritedEvents = parentBlueprintClass?.allCustomEvents;

    final typeCtx = levelScope ||
            widgetScope ||
            currentActorParents.isNotEmpty ||
            currentCustomEvents.isNotEmpty ||
            variableOwners.isNotEmpty ||
            componentOwners.isNotEmpty ||
            inheritedVars != null ||
            inheritedComps != null ||
            inheritedEvents != null
        ? _contextOf(document, name, inputActions, levelActors, currentActorParents, currentCustomEvents,
            variableOwners: variableOwners,
            componentOwners: componentOwners,
            widgetVariables: widgetScope ? (widgetVariables ?? const []) : null,
            inheritedVariables: inheritedVars,
            inheritedComponents: inheritedComps,
            inheritedCustomEvents: inheritedEvents)
        : null;

    diagnostics.addAll(validateBlueprint(document,
        inputActions: inputActions,
        className: name,
        typeContext: typeCtx));

    final gameMode = (parentBlueprintClass?.rootEngineClass ?? document.parentClass) == 'LuminaGameMode';
    if (gameMode) _checkGameMode(document, resolveClass, diagnostics);

    final allVars = [
      if (inheritedVars != null) ...inheritedVars.where((iv) => !document.variables.any((v) => v.name == iv.name)),
      ...document.variables,
    ];
    for (final key in document.classDefaults.keys) {
      if (!(gameMode ? _gameModeDefaultKeys : _classDefaultKeys).contains(key) &&
          allVars.every((v) => v.name != key)) {
        diagnostics.add(LuminaBlueprintDiagnostic(
          LuminaBlueprintSeverity.warning,
          "Class default '$key' matches no property or variable and is ignored.",
        ));
      }
    }
    for (final c in document.components) {
      final animClass = c.properties['animClass'];
      if (c.properties['animMode'] == 'Use Animation Blueprint' && animClass is String && animClass.isNotEmpty) {
        if (animBlueprints?.call(animClass) == null) {
          diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
              "Mesh '${c.name}': Animation Blueprint '$animClass' is not available; the mesh plays no animation."));
        }
      }
    }
    return LuminaBlueprintClass._(
        name, document, inputActions, resolveAsset, assetProvider, animBlueprints, resolveClass, diagnostics,
        levelActors: levelScope ? (levelActors ?? const []) : null,
        actorParents: currentActorParents,
        customEventOwners: currentCustomEvents,
        variableOwners: variableOwners,
        componentOwners: componentOwners,
        widgetVariables: widgetScope ? (widgetVariables ?? const []) : null,
        parentBlueprintClass: parentBlueprintClass);
  }

  static void _checkGameMode(LuminaBlueprintDocument document,
      LuminaBlueprintClass? Function(String path)? resolveClass, List<LuminaBlueprintDiagnostic> diagnostics) {
    final pawn = document.classDefaults['defaultPawnClass'];
    if (pawn is String && pawn.isNotEmpty && resolveClass != null) {
      final cls = resolveClass(pawn);
      if (cls == null) {
        diagnostics.add(LuminaBlueprintDiagnostic(
          LuminaBlueprintSeverity.error, "Default Pawn Class '$pawn' cannot be loaded."));
      } else if (!cls.isPawn) {
        diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error,
            "Default Pawn Class '$pawn' is not a Pawn or Character Blueprint (it is a ${cls.document.parentClass})."));
      }
    }
    final controller = document.classDefaults['playerControllerClass'];
    if (controller is String && controller.isNotEmpty && controller != 'LuminaPlayerController') {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
          "Player Controller Class '$controller' is not supported yet; LuminaPlayerController is used."));
    }
    if (document.eventGraph.nodes.isNotEmpty) {
      diagnostics.add(const LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
          'A GameMode Blueprint\'s event graph does not run yet; only its class defaults are used.'));
    }
  }

  static const Set<String> _gameModeDefaultKeys = {'defaultPawnClass', 'playerControllerClass', 'hudClass'};

  static const Set<String> _classDefaultKeys = {
    'bUseControllerRotationYaw',
    'bUseControllerRotationPitch',
    'bUseControllerRotationRoll',
    'baseEyeHeight',
  };

  bool get hasErrors => diagnostics.any((d) => d.isError);

  /// A new actor of this class: a [LuminaBlueprintCharacter],
  /// [LuminaBlueprintPawn] or [LuminaBlueprintActor] by `rootEngineClass`, with
  /// its components built and class defaults applied.
  LuminaActor instantiate({LuminaObjectKey? key, Vector3? location, Quaternion? rotation}) {
    if (hasErrors) {
      throw LuminaBlueprintCompileError(name, diagnostics.where((d) => d.isError).toList());
    }
    if (isGameMode) throw StateError('$name is a GameMode Blueprint: use createGameMode().');
    final LuminaActor actor;
    switch (rootEngineClass) {
      case 'LuminaCharacter':
        actor = LuminaBlueprintCharacter._(this, key: key, location: location, rotation: rotation);
      case 'LuminaPawn':
        actor = LuminaBlueprintPawn._(this, key: key, location: location, rotation: rotation);
      case LuminaLevelBlueprintDocument.parentClass:
        actor = LuminaBlueprintLevelScript._(this, key: key);
      case LuminaWidgetBlueprintDocument.parentClass:
        actor = LuminaBlueprintUserWidget._(this, key: key);
      default:
        actor = LuminaBlueprintActor._(this, key: key, location: location, rotation: rotation);
    }
    (actor as LuminaBlueprintInstance)._initBlueprint(this);
    return actor;
  }

  /// The game mode of a GameMode Blueprint: its Default Pawn
  /// Class (resolved through [resolveClass] at every spawn) at the player
  /// start, possessed by a [LuminaPlayerController]. [pawnOverride] is the
  /// project's Maps & Modes Default Pawn Class, which wins when given.
  LuminaGameMode createGameMode({LuminaPawn Function()? pawnOverride}) {
    if (!isGameMode) throw StateError('$name is not a GameMode Blueprint (parent ${document.parentClass}).');
    if (hasErrors) {
      throw LuminaBlueprintCompileError(name, diagnostics.where((d) => d.isError).toList());
    }
    final pawn = defaultPawnClass;
    LuminaPawn spawnDefault() {
      final cls = pawn.isEmpty ? null : resolveClass?.call(pawn);
      if (cls == null) return LuminaPawn();
      return cls.instantiate() as LuminaPawn;
    }

    return LuminaGameMode(
      defaultPawnFactory: pawnOverride ?? spawnDefault,
      playerControllerFactory: () => LuminaPlayerController(playerName: 'Player'),
    );
  }
}

/// What the interpreter runs a graph against: the graph
/// and its resolved pins, the variables, the actor the function library acts
/// on (`self`), tracing, latent Delay and the loop guard. A Blueprint actor is
/// one; an Animation Blueprint instance, whose `self` is its pawn, is another.
abstract interface class LuminaBlueprintGraphHost {
  LuminaBlueprintGraph get hostGraph;
  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins;
  Map<String, Object?> get hostVariables;
  LuminaActor get hostSelf;
  int get hostMaxNodes;
  String get hostName;
  void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? printed});
  void hostDelay(String nodeId, double seconds, void Function() resume);
  void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume);
  void hostError(String message);

  /// Per-node flow-control state by node id.
  Map<String, Object?> get hostFlowState;

  /// Local variables of the function frame being run; empty
  /// outside a function.
  Map<String, Object?> get hostLocals;

  /// The Blueprint the graph belongs to, for delegates, function calls and
  /// timelines; null for an Animation Blueprint.
  LuminaBlueprintInstance? get hostInstance;
}

/// Runs Blueprint graphs node by node.
abstract final class LuminaBlueprintInterpreter {
  /// Runs the chain leaving [nodeId]'s exec output [execPin]. [eventOutputs]
  /// are the starting event's data outputs (Delta Seconds, Action Value).
  static void run(LuminaBlueprintGraphHost host, String nodeId, String execPin, Map<String, Object?> eventOutputs,
      {String? eventNodeId, Map<String, Map<String, Object?>> impureSeed = const {}}) {
    final frame = _Frame(host, eventNodeId ?? nodeId, eventOutputs);
    frame._impureOutputs.addAll(impureSeed);
    try {
      frame.runFrom(nodeId, execPin);
    } on _InfiniteLoop catch (e) {
      final event = host.hostGraph.node(frame.eventNodeId)?.title ?? frame.eventNodeId;
      final message = 'Infinite loop detected in ${host.hostName}.$event at node ${e.nodeId}';
      host.hostError(message);
      developer.log(message, name: 'Blueprint', level: 1000);
    }
  }

  /// The value of [nodeId]'s input [pinId], evaluating pure nodes: a
  /// transition rule's result.
  static Object? evaluateInput(LuminaBlueprintGraphHost host, String nodeId, String pinId,
      {Map<String, Object?> eventOutputs = const {}}) {
    final frame = _Frame(host, nodeId, eventOutputs);
    final node = host.hostGraph.node(nodeId)!;
    return frame._input(node, pinId, host.hostPins[nodeId]!);
  }
}

/// A Blueprint with parent `LuminaActor`.
class LuminaBlueprintActor extends LuminaActor with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintActor._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});
}

/// A Blueprint with parent `LuminaPawn`.
class LuminaBlueprintPawn extends LuminaPawn with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintPawn._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});

  @override
  void possessedBy(LuminaController newController) {
    super.possessedBy(newController);
    _bindInput();
  }

  @override
  void unpossessed() {
    unbindBlueprintInput();
    super.unpossessed();
  }
}

/// A Blueprint with parent `LuminaCharacter`.
class LuminaBlueprintCharacter extends LuminaCharacter with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintCharacter._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});

  @override
  void possessedBy(LuminaController newController) {
    super.possessedBy(newController);
    _bindInput();
  }

  @override
  void unpossessed() {
    unbindBlueprintInput();
    super.unpossessed();
  }
}

/// A Level Blueprint's script actor: the level's
/// [LuminaLevelScriptActor] running its graph in the VM. Event BeginPlay /
/// Event Level BeginPlay, Tick, End Play, Level Loaded (before any other
/// actor's BeginPlay) and Level Unloaded; `Get <Actor>` finds the
/// level's placed actors by name. Never spawnable from a class.
class LuminaBlueprintLevelScript extends LuminaLevelScriptActor
    with LuminaBlueprintRuntime, LuminaBlueprintInstance, LuminaBlueprintLevelActors {
  LuminaBlueprintLevelScript._(LuminaBlueprintClass cls, {super.key})
      : levelActorIds = {for (final a in cls.levelActors ?? const <LuminaBlueprintLevelActorRef>[]) a.name: a.id};

  @override
  final Map<String, String> levelActorIds;

  bool _levelBeginPlayPending = false;

  /// Event (Level) BeginPlay waits for the local player: while the
  /// world has a game mode that has logged no one in yet — Play-In-Editor
  /// logs in right after `beginPlay` — it runs on [onPostLogin], or on the
  /// first tick if no one logs in. A built game logs in inside its script's
  /// BeginPlay, ahead of the graph, so both see the player's pawn.
  @override
  void onBeginPlay() {
    super.onBeginPlay();
    final w = world;
    if (w != null && w.gameMode != null && !w.hasLoggedInPlayer) {
      _levelBeginPlayPending = true;
      return;
    }
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, 'exec_out', const {});
  }

  void _runPendingLevelBeginPlay() {
    if (!_levelBeginPlayPending) return;
    _levelBeginPlayPending = false;
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, 'exec_out', const {});
  }

  @override
  void onPostLogin(LuminaPlayerController controller) {
    super.onPostLogin(controller);
    _runPendingLevelBeginPlay();
  }

  @override
  void onTick(double deltaTime) {
    _runPendingLevelBeginPlay();
    super.onTick(deltaTime);
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelTick, 'exec_tick_out', {'delta_seconds': deltaTime});
  }

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelEndPlay, 'exec_out', {'end_play_reason': reason.displayName});
  }

  @override
  void onLevelLoaded() {
    super.onLevelLoaded();
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelLoaded, 'exec_out', const {});
  }

  @override
  void onLevelUnloaded() {
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelUnloaded, 'exec_out', const {});
    super.onLevelUnloaded();
  }
}

/// A Widget Blueprint's script: the widget's [LuminaUserWidget]
/// running its graph in the VM. Event Pre Construct / Construct when the
/// widget is added to the viewport, Destruct when it is removed, Tick while
/// it is on screen, and each bound element event (`On Clicked (StartButton)`)
/// when [LuminaUserWidgets.fire] reports it.
class LuminaBlueprintUserWidget extends LuminaUserWidget with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintUserWidget._(LuminaBlueprintClass cls, {super.key});

  @override
  void onWidgetPreConstruct(bool isDesignTime) =>
      _dispatch(LuminaBlueprintNodeLibrary.eventWidgetPreConstruct, 'exec_out', {'is_design_time': isDesignTime});

  @override
  void onWidgetConstruct() => _dispatch(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'exec_out', const {});

  @override
  void onWidgetDestruct() => _dispatch(LuminaBlueprintNodeLibrary.eventWidgetDestruct, 'exec_out', const {});

  @override
  void onWidgetTick(double inDeltaTime) =>
      _dispatch(LuminaBlueprintNodeLibrary.eventWidgetTick, 'exec_out', {'in_delta_time': inDeltaTime});

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) {
    for (final node in _graph.nodes) {
      if (node.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement &&
          node.literals['element'] == element &&
          node.literals['event'] == event) {
        _run(node.id, 'exec_out', _eventArgs(node, args));
      }
    }
  }
}
