part of '../blueprint_model.dart';

/// The type of a Blueprint pin.
///
/// Values are **authoring space**: a [vector] is centimetres, Z up, exactly
/// what the Details panel shows; a [rotator] is [LuminaRotator]. Only the
/// function library converts to the Y-up runtime.
enum LuminaPinType {
  exec,
  boolean,
  integer,
  float,
  string,
  name,
  vector,
  vector2D,
  rotator,
  object,
  transform,
  structEnum,

  /// A linear colour `[r, g, b, a]` in 0–1.
  color,

  /// A list of one element type; the pin's `elementType` says
  /// which.
  array,

  /// A trace hit as a JSON map (see Break Hit Result).
  hitResult,

  /// Any type: the element pins of the array nodes and loops until the node
  /// is given a `type` literal. Connects to every data pin.
  wildcard,

  /// A value of a project enum asset: the value's name as a
  /// string; the pin's `enumName` says which enum. Stored as `"type": "enum"`.
  enumeration,

  /// A red delegate: a custom event bound to a timer or a dispatcher.
  /// Only a custom event's `delegate` output can feed one.
  delegate,

  /// A `LuminaTimerHandle` from Set Timer.
  timerHandle;

  /// The name this type is stored under (`enum` for [enumeration]).
  String get jsonName => this == LuminaPinType.enumeration ? 'enum' : this.name;

  /// Reads a stored type name. The editor's older names map onto the new
  /// ones (`number` → [float], `vector3` → [vector], `objectRef` → [object]);
  /// an unknown name is null so the validator can report it.
  static LuminaPinType? parse(String? name) {
    switch (name) {
      case 'number':
        return LuminaPinType.float;
      case 'vector3':
        return LuminaPinType.vector;
      case 'objectRef':
        return LuminaPinType.object;
      case 'enum':
        return LuminaPinType.enumeration;
    }
    for (final t in LuminaPinType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// The type of a Blueprint variable declared as [typeName] in the My
  /// Blueprint panel (`Float`, `Bool`, `Int`, `String`, `Vector`, …).
  static LuminaPinType? parseVariableType(String? typeName) {
    switch (typeName?.toLowerCase()) {
      case 'float':
      case 'double':
      case 'number':
        return LuminaPinType.float;
      case 'bool':
      case 'boolean':
        return LuminaPinType.boolean;
      case 'int':
      case 'integer':
        return LuminaPinType.integer;
      case 'string':
        return LuminaPinType.string;
      case 'name':
        return LuminaPinType.name;
      case 'vector':
      case 'vector3':
        return LuminaPinType.vector;
      case 'vector2d':
        return LuminaPinType.vector2D;
      case 'rotator':
        return LuminaPinType.rotator;
      case 'object':
      case 'actor':
      case 'widget':
      case 'component':
        return LuminaPinType.object;
      case 'color':
      case 'linearcolor':
        return LuminaPinType.color;
      case 'transform':
        return LuminaPinType.transform;
      case 'hitresult':
        return LuminaPinType.hitResult;
      case 'exec':
        return LuminaPinType.exec;
      case 'delegate':
        return LuminaPinType.delegate;
      case 'timerhandle':
        return LuminaPinType.timerHandle;
    }
    // An enum asset: `Enum:E_DoorState`.
    if (typeName != null && typeName.toLowerCase().startsWith('enum:')) return LuminaPinType.enumeration;
    // A typed object class: `Widget:WBP_HUD`, `Actor:BP_Door`,
    // `Component:LuminaSpringArmComponent`, `WidgetElement:text`.
    if (typeName != null && LuminaBlueprintObjectClass.isClassString(typeName)) return LuminaPinType.object;
    // An array of a type: `Array:Float`, `Array:Actor:BP_Door`.
    if (typeName != null && typeName.toLowerCase().startsWith('array:')) {
      return parseVariableType(typeName.substring('array:'.length)) == null ? null : LuminaPinType.array;
    }
    return null;
  }
}

/// The class an object pin or variable carries, as a string:
/// `Widget:<name>`, `WidgetElement:<UmgWidgetType name>`,
/// `Component:<lumina component class>`, `Actor:<class>`, or `Object` (any).
/// A kind alone (`Widget`, `Actor`, `Component`, `WidgetElement`) means any
/// object of that kind.
abstract final class LuminaBlueprintObjectClass {
  static const String any = 'Object';
  static const String widgetKind = 'Widget';
  static const String widgetElementKind = 'WidgetElement';
  static const String componentKind = 'Component';
  static const String actorKind = 'Actor';

  /// A Blueprint save-game class: `SaveGame:SG_Player`.
  static const String saveGameKind = 'SaveGame';

  static const Set<String> kinds = {widgetKind, widgetElementKind, componentKind, actorKind, saveGameKind};

  /// Whether [s] is a class string this class understands.
  static bool isClassString(String s) => s == any || kinds.contains(kind(s));

  /// `Widget:WBP_HUD` → `Widget`; `Object` → `Object`.
  static String kind(String cls) {
    final i = cls.indexOf(':');
    return i < 0 ? cls : cls.substring(0, i);
  }

  /// `Widget:WBP_HUD` → `WBP_HUD`; `Widget` → '' (any widget).
  static String name(String cls) {
    final i = cls.indexOf(':');
    return i < 0 ? '' : cls.substring(i + 1);
  }

  static String widget(String name) => '$widgetKind:$name';
  static String widgetElement(String type) => '$widgetElementKind:$type';
  static String component(String componentClass) => '$componentKind:$componentClass';
  static String actor(String actorClass) => '$actorKind:$actorClass';
  static String saveGame(String saveClass) => '$saveGameKind:$saveClass';

  /// The base class every actor / component descends from.
  static const String anyActor = 'Actor:LuminaActor';
  static const String anyComponent = 'Component:LuminaActorComponent';

  /// The engine's own parent chains (the Blueprint class registry adds a
  /// project's Blueprint classes through [LuminaBlueprintTypeContext]).
  static const Map<String, String> engineParents = {
    'LuminaCharacter': 'LuminaPawn',
    'LuminaPawn': 'LuminaActor',
    // The placed-actor classes a Level Blueprint types.
    'LuminaLevelScriptActor': 'LuminaActor',
    'LuminaPlayerStart': 'LuminaActor',
    'LuminaVolume': 'LuminaActor',
    'LuminaTriggerVolume': 'LuminaVolume',
    'LuminaBlockingVolume': 'LuminaVolume',
    'LuminaPrimitiveActor': 'LuminaActor',
    'LuminaSceneComponent': 'LuminaActorComponent',
    'LuminaSpringArmComponent': 'LuminaSceneComponent',
    'LuminaCameraComponent': 'LuminaSceneComponent',
    'LuminaCollisionComponent': 'LuminaSceneComponent',
    'LuminaCapsuleComponent': 'LuminaCollisionComponent',
    'LuminaBoxComponent': 'LuminaCollisionComponent',
    'LuminaSphereComponent': 'LuminaCollisionComponent',
    'LuminaCylinderComponent': 'LuminaCollisionComponent',
    'LuminaConeComponent': 'LuminaCollisionComponent',
    'LuminaConvexComponent': 'LuminaCollisionComponent',
    'LuminaStaticMeshComponent': 'LuminaSceneComponent',
    'LuminaAnimatedMeshComponent': 'LuminaStaticMeshComponent',
    'LuminaSkeletalMeshComponent': 'LuminaAnimatedMeshComponent',
    'LuminaCharacterMovementComponent': 'LuminaActorComponent',
    'LuminaSpringMorphComponent': 'LuminaActorComponent',
    'LuminaRagdollComponent': 'LuminaActorComponent',
    'LuminaTraversalComponent': 'LuminaActorComponent',
    'LuminaArrowComponent': 'LuminaSceneComponent',
    'LuminaLightComponent': 'LuminaSceneComponent',
    'LuminaPointLightComponent': 'LuminaLightComponent',
    'LuminaSpotLightComponent': 'LuminaLightComponent',
    'LuminaDirectionalLightComponent': 'LuminaLightComponent',
    'LuminaAudioComponent': 'LuminaSceneComponent',
    'LuminaParticleSystemComponent': 'LuminaSceneComponent',
    'LuminaAnimBlueprintInstance': 'LuminaActorComponent',
  };

  /// The display names of widget element types (UmgWidgetType names).
  static const Map<String, String> elementDisplayNames = {
    'text': 'Text Block',
    'button': 'Button',
    'image': 'Image',
    'progressBar': 'Progress Bar',
    'slider': 'Slider',
    'checkBox': 'Check Box',
    'editableText': 'Editable Text',
    'comboBox': 'Combo Box',
    'widgetSwitcher': 'Widget Switcher',
    'canvasPanel': 'Canvas Panel',
    'overlay': 'Overlay',
    'horizontalBox': 'Horizontal Box',
    'verticalBox': 'Vertical Box',
    'gridPanel': 'Grid Panel',
    'scrollBox': 'Scroll Box',
    'sizeBox': 'Size Box',
    'border': 'Border',
    // The Container and the shadcn components.
    'container': 'Container',
    'shadcnCard': 'Card (shadcn)',
    'shadcnBadge': 'Badge (shadcn)',
    'shadcnAvatar': 'Avatar (shadcn)',
    'shadcnAlert': 'Alert (shadcn)',
    'shadcnSeparator': 'Separator (shadcn)',
    'shadcnProgress': 'Progress (shadcn)',
    'shadcnSwitch': 'Switch (shadcn)',
    'shadcnToggle': 'Toggle (shadcn)',
    'shadcnTabs': 'Tabs (shadcn)',
    'shadcnAccordion': 'Accordion (shadcn)',
    'shadcnTooltip': 'Tooltip (shadcn)',
    'shadcnChip': 'Chip (shadcn)',
    'shadcnKbd': 'Kbd (shadcn)',
    'shadcnSkeleton': 'Skeleton (shadcn)',
    'shadcnTextField': 'Text Field (shadcn)',
    'shadcnTextArea': 'Text Area (shadcn)',
    'shadcnSelect': 'Select (shadcn)',
    'shadcnRadioGroup': 'Radio Group (shadcn)',
    'shadcnSlider': 'Slider (shadcn)',
    'shadcnCheckbox': 'Checkbox (shadcn)',
    'shadcnPrimaryButton': 'Primary Button (shadcn)',
    'shadcnSecondaryButton': 'Secondary Button (shadcn)',
    'shadcnOutlineButton': 'Outline Button (shadcn)',
    'shadcnGhostButton': 'Ghost Button (shadcn)',
    'shadcnDestructiveButton': 'Destructive Button (shadcn)',
    'shadcnLinkButton': 'Link Button (shadcn)',
  };

  /// Element types that take the nodes of a common type because their state
  /// means the same: a shadcn Progress is a Progress Bar to
  /// `Set Percent`, a Switch a Check Box to `Set Is Checked`, a Select a
  /// Combo Box to `Set Selected Option`, Tabs a Widget Switcher to `Set
  /// Active Widget Index`, the buttons Buttons to `Set Label`.
  static const Map<String, String> elementParents = {
    'shadcnProgress': 'progressBar',
    'shadcnSwitch': 'checkBox',
    'shadcnToggle': 'checkBox',
    'shadcnCheckbox': 'checkBox',
    'shadcnSelect': 'comboBox',
    'shadcnRadioGroup': 'comboBox',
    'shadcnTabs': 'widgetSwitcher',
    'shadcnSlider': 'slider',
    'shadcnTextField': 'editableText',
    'shadcnTextArea': 'editableText',
    'shadcnBadge': 'text',
    'shadcnChip': 'text',
    'shadcnKbd': 'text',
    'shadcnPrimaryButton': 'button',
    'shadcnSecondaryButton': 'button',
    'shadcnOutlineButton': 'button',
    'shadcnGhostButton': 'button',
    'shadcnDestructiveButton': 'button',
    'shadcnLinkButton': 'button',
  };

  /// What the editor and diagnostics call [cls]: `Widget (WBP_HUD)`,
  /// `Text Block`, `Spring Arm`, `BP_Door`, `Object`.
  static String displayName(String? cls) {
    if (cls == null || cls == any) return 'Object';
    final k = kind(cls);
    final n = name(cls);
    switch (k) {
      case widgetKind:
        return n.isEmpty ? 'Widget' : 'Widget ($n)';
      case widgetElementKind:
        return n.isEmpty ? 'Widget Element' : (elementDisplayNames[n] ?? n);
      case componentKind:
        if (n.isEmpty) return 'Component';
        final short = n.replaceFirst(RegExp(r'^Lumina'), '').replaceFirst(RegExp(r'Component$'), '');
        return short.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (m) => ' ');
      case actorKind:
        return n.isEmpty ? 'Actor' : n;
      case saveGameKind:
        return n.isEmpty ? 'Save Game' : n;
    }
    return cls;
  }

  /// The parent chain of [cls] (excluding itself), through [parents] (a
  /// project's Blueprint classes, `BP_Door` → `LuminaActor`) and the engine's
  /// own hierarchy. Every actor ends at `LuminaActor`, every component at
  /// `LuminaActorComponent`.
  static List<String> ancestors(String cls, {Map<String, String> parents = const {}}) {
    final k = kind(cls);
    var n = name(cls);
    final out = <String>[];
    if (n.isEmpty) return out;
    final root = k == actorKind ? 'LuminaActor' : (k == componentKind ? 'LuminaActorComponent' : null);
    while (n.isNotEmpty && out.length < 64) {
      final parent = parents[n] ?? (k == widgetElementKind ? elementParents[n] : engineParents[n]);
      if (parent == null) {
        if (root != null && n != root) out.add('$k:$root');
        break;
      }
      out.add('$k:$parent');
      n = parent;
    }
    return out;
  }

  /// Whether a value of class [from] can be wired into a pin of class [to]
  /// (null on either side is `Object`): any → typed is refused (it needs a
  /// Cast), and so is a kind alone → a class of that kind (`Widget Element` →
  /// `Text Block`); typed → any is allowed, a class is assignable to itself
  /// and to its ancestors, `Widget:X` → `Widget:X` only.
  static bool isAssignable(String? from, String? to, {Map<String, String> parents = const {}}) =>
      assignError(from, to, parents: parents) == null;

  /// Why [from] cannot be wired into [to], or null when it can. A refusal a
  /// Cast bridges names the Cast To and its class string.
  static String? assignError(String? from, String? to, {Map<String, String> parents = const {}}) {
    final f = from ?? any;
    final t = to ?? any;
    if (t == any) return null;
    String needsCast() => 'Cannot connect ${displayName(f)} to ${displayName(t)}: it needs a Cast To ${displayName(t)} (class "$t").';
    if (f == any) return needsCast();
    if (kind(f) != kind(t)) return 'Cannot connect ${displayName(f)} to ${displayName(t)}.';
    if (name(t).isEmpty || f == t) return null;
    if (name(f).isEmpty) return needsCast();
    if (ancestors(f, parents: parents).contains(t)) return null;
    return 'Cannot connect ${displayName(f)} to ${displayName(t)}.';
  }
}
