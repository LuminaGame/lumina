part of '../blueprint_dart_generator.dart';

/// What makes a [_ClassWriter] write a level script.
class _LevelScript {
  final String levelName;
  final List<LuminaBlueprintLevelActorRef> actors;
  final Map<String, String> actorParents;
  final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners;
  final List<String> members;
  final List<String> beginPlay;
  final List<String> tick;
  _LevelScript(this.levelName, this.actors, this.actorParents, this.customEventOwners, this.members, this.beginPlay, this.tick);

  LuminaBlueprintTypeContext context(LuminaBlueprintDocument doc, List<LuminaInputAction> inputActions) =>
      LuminaBlueprintTypeContext.forLevel(LuminaLevelBlueprintDocument(levelPath: levelName, blueprint: doc),
          levelActors: actors, inputActions: inputActions, actorParents: actorParents, customEventOwners: customEventOwners);

  late final Map<String, String> _fields = () {
    final used = <String>{};
    return {
      for (final a in actors)
        a.name: () {
          var f = _var(a.name);
          while (!used.add(f)) {
            f = '${f}_';
          }
          return f;
        }(),
    };
  }();

  /// The field of placed actor [a] (`Door_01` → `door01`).
  String fieldOf(LuminaBlueprintLevelActorRef a) => _fields[a.name]!;

  /// The runtime type the field of [a] holds: its engine class, or
  /// `LuminaActor` for a Blueprint class (generated in another library).
  String dartTypeOf(LuminaBlueprintLevelActorRef a) {
    final name = LuminaBlueprintObjectClass.name(a.actorClass);
    return const {'LuminaPlayerStart', 'LuminaTriggerVolume', 'LuminaBlockingVolume', 'LuminaVolume', 'LuminaPawn', 'LuminaCharacter'}
            .contains(name)
        ? name
        : 'LuminaActor';
  }
}

/// What makes a [_ClassWriter] write a widget's graph script.
class _WidgetScript {
  final LuminaWidgetBlueprintDocument widget;
  final Map<String, String> actorParents;
  _WidgetScript(this.widget, this.actorParents);

  LuminaBlueprintTypeContext context(List<LuminaInputAction> inputActions) =>
      LuminaBlueprintTypeContext.forWidget(widget, inputActions: inputActions, actorParents: actorParents);

  /// The lifecycle events: the hook each is dispatched from, its frame's
  /// outputs, and the hook's parameters (the VM's `LuminaBlueprintUserWidget`).
  static const Map<String, ({String hook, Map<String, String> outputs, String params, String args})> events = {
    LuminaBlueprintNodeLibrary.eventWidgetPreConstruct: (
      hook: 'onWidgetPreConstruct',
      outputs: {'is_design_time': 'isDesignTime'},
      params: 'bool isDesignTime',
      args: 'isDesignTime',
    ),
    LuminaBlueprintNodeLibrary.eventWidgetConstruct: (hook: 'onWidgetConstruct', outputs: {}, params: '', args: ''),
    LuminaBlueprintNodeLibrary.eventWidgetDestruct: (hook: 'onWidgetDestruct', outputs: {}, params: '', args: ''),
    LuminaBlueprintNodeLibrary.eventWidgetTick: (
      hook: 'onWidgetTick',
      outputs: {'in_delta_time': 'inDeltaTime'},
      params: 'double inDeltaTime',
      args: 'inDeltaTime',
    ),
  };
}
