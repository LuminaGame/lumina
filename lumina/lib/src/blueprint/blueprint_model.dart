import 'dart:convert';

import 'package:vector_math/vector_math_64.dart';

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

/// A rotation in the Details panel's convention: degrees about the authoring
/// X, Y and Z axes. Authoring forward is +Y, so [x] is pitch, [y] roll and
/// [z] yaw.
class LuminaRotator {
  final double x;
  final double y;
  final double z;

  const LuminaRotator(this.x, this.y, this.z);
  const LuminaRotator.zero() : this(0.0, 0.0, 0.0);

  double get pitch => x;
  double get roll => y;
  double get yaw => z;

  /// Reads `[x, y, z]`; missing entries are 0.
  factory LuminaRotator.fromList(List<num>? v) {
    double at(int i) => v != null && v.length > i ? v[i].toDouble() : 0.0;
    return LuminaRotator(at(0), at(1), at(2));
  }

  List<double> toList() => [x, y, z];

  @override
  bool operator ==(Object other) => other is LuminaRotator && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'LuminaRotator($x, $y, $z)';
}

/// One component of a Blueprint's component tree.
class LuminaBlueprintComponent {
  final String id;
  String name;
  final String type;
  String? parentId;
  final Map<String, dynamic> properties;
  final bool isSceneComponent;

  LuminaBlueprintComponent({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    Map<String, dynamic>? properties,
    this.isSceneComponent = true,
  }) : properties = properties ?? <String, dynamic>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'parentId': parentId,
        'properties': properties,
        'isSceneComponent': isSceneComponent,
      };

  /// Reads the editor's shape. Keys other than the known top-level
  /// fields are folded into [properties], as the editor does.
  factory LuminaBlueprintComponent.fromJson(Map<String, dynamic> map) {
    final type = map['type'] as String? ?? 'LuminaSceneComponent';
    final isScene = map['isSceneComponent'] as bool? ??
        (!type.contains('Movement') && !type.contains('Player') && !type.contains('Input'));
    final props = Map<String, dynamic>.from(map['properties'] as Map? ?? const {});
    map.forEach((k, v) {
      if (!const {'id', 'name', 'type', 'parentId', 'properties', 'isSceneComponent'}.contains(k)) {
        props[k] = v;
      }
    });
    return LuminaBlueprintComponent(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? type.replaceAll('Lumina', ''),
      type: type,
      parentId: map['parentId'] as String?,
      properties: props,
      isSceneComponent: isScene,
    );
  }
}

/// A variable declared in the My Blueprint panel.
class LuminaBlueprintVariable {
  final String name;

  /// The type exactly as stored (`Float`, `Bool`, …), kept so a document
  /// round-trips unchanged.
  final String typeName;
  final dynamic defaultValue;

  const LuminaBlueprintVariable({required this.name, required this.typeName, this.defaultValue});

  /// Null when [typeName] is not a known type (a validator error).
  LuminaPinType? get type => LuminaPinType.parseVariableType(typeName);

  /// The class of an object variable (`Widget:WBP_HUD`, `Actor:BP_Door`);
  /// null for `Object` (any) and for non-object variables.
  String? get objectClass => luminaBlueprintObjectClassOf(typeName);

  /// The element type of an `Array:<type>` variable.
  LuminaPinType? get elementType {
    if (!typeName.toLowerCase().startsWith('array:')) return null;
    return LuminaPinType.parseVariableType(typeName.substring('array:'.length));
  }

  /// The enum of an `Enum:<name>` variable, else null.
  String? get enumName => luminaBlueprintEnumNameOf(typeName);

  /// This variable as the pin it declares (a function parameter, a
  /// dispatcher parameter, a custom event parameter): id and name are the
  /// variable's name.
  LuminaBlueprintPin toPin({required bool isOutput}) => LuminaBlueprintPin(
        id: name,
        name: name,
        type: type,
        isOutput: isOutput,
        defaultValue: defaultValue,
        objectClass: objectClass,
        elementType: elementType,
        enumName: enumName,
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': typeName, 'default': defaultValue};

  factory LuminaBlueprintVariable.fromJson(Map<String, dynamic> map) => LuminaBlueprintVariable(
        name: map['name'] as String? ?? '',
        typeName: map['type'] as String? ?? 'Float',
        defaultValue: map['default'],
      );
}

/// The object class a stored variable type name carries: `Widget:WBP_HUD`
/// stays as is, the legacy `Actor` is `Actor:LuminaActor`, `Object` / other
/// types are null. An `Array:<object class>` gives its element class.
String? luminaBlueprintObjectClassOf(String? typeName) {
  if (typeName == null) return null;
  if (typeName.toLowerCase().startsWith('array:')) return luminaBlueprintObjectClassOf(typeName.substring(6));
  if (typeName.toLowerCase() == 'actor') return LuminaBlueprintObjectClass.anyActor;
  if (typeName == LuminaBlueprintObjectClass.any) return null;
  if (LuminaBlueprintObjectClass.isClassString(typeName) && typeName.contains(':')) return typeName;
  if (LuminaBlueprintObjectClass.kinds.contains(typeName)) return typeName;
  return null;
}

/// The enum name a stored variable type carries: `Enum:E_DoorState` →
/// `E_DoorState`; `Array:Enum:X` → `X`; anything else null.
String? luminaBlueprintEnumNameOf(String? typeName) {
  if (typeName == null) return null;
  if (typeName.toLowerCase().startsWith('array:')) return luminaBlueprintEnumNameOf(typeName.substring(6));
  if (typeName.toLowerCase().startsWith('enum:')) return typeName.substring(5);
  return null;
}

/// A pin as stored on a placed node.
class LuminaBlueprintPin {
  final String id;
  final String name;

  /// Null when the stored type name is unknown.
  final LuminaPinType? type;
  final bool isOutput;
  final dynamic defaultValue;

  /// The class of an object pin; null is any object. Stored as
  /// `"class"`.
  final String? objectClass;

  /// The element type of an array pin; stored as `"of"`.
  final LuminaPinType? elementType;

  /// The enum of an [LuminaPinType.enumeration] pin; stored
  /// as `"enum"`.
  final String? enumName;

  const LuminaBlueprintPin({
    required this.id,
    required this.name,
    required this.type,
    this.isOutput = false,
    this.defaultValue,
    this.objectClass,
    this.elementType,
    this.enumName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type?.jsonName ?? 'exec',
        if (elementType != null) 'of': elementType!.jsonName,
        if (objectClass != null) 'class': objectClass,
        if (enumName != null) 'enum': enumName,
        'isOutput': isOutput,
        if (defaultValue != null) 'defaultValue': defaultValue,
      };

  factory LuminaBlueprintPin.fromJson(Map<String, dynamic> json) => LuminaBlueprintPin(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: LuminaPinType.parse(json['type'] as String?),
        isOutput: json['isOutput'] as bool? ?? false,
        defaultValue: json['defaultValue'],
        objectClass: json['class'] as String?,
        elementType: LuminaPinType.parse(json['of'] as String?),
        enumName: json['enum'] as String?,
      );
}

/// A node placed in a graph: which library node it is ([registryId]), its
/// pins, its literal pin values and where the editor draws it.
class LuminaBlueprintNode {
  final String id;
  final String registryId;
  String title;
  String category;
  double x;
  double y;

  /// ARGB header colour the editor stored; kept for round-tripping only.
  final int? headerColor;
  final List<LuminaBlueprintPin> inputs;
  final List<LuminaBlueprintPin> outputs;

  /// Pin id → literal value for pins without a wire, plus node settings such
  /// as an input action's `action` or a variable node's `variable`.
  final Map<String, dynamic> literals;

  LuminaBlueprintNode({
    required this.id,
    required this.registryId,
    required this.title,
    this.category = 'General',
    this.x = 0.0,
    this.y = 0.0,
    this.headerColor,
    List<LuminaBlueprintPin>? inputs,
    List<LuminaBlueprintPin>? outputs,
    Map<String, dynamic>? literals,
  })  : inputs = inputs ?? <LuminaBlueprintPin>[],
        outputs = outputs ?? <LuminaBlueprintPin>[],
        literals = literals ?? <String, dynamic>{};

  LuminaBlueprintPin? pin(String pinId) {
    for (final p in inputs) {
      if (p.id == pinId) return p;
    }
    for (final p in outputs) {
      if (p.id == pinId) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'registryId': registryId,
        'title': title,
        'category': category,
        'position': {'x': x, 'y': y},
        if (headerColor != null) 'headerColor': headerColor,
        'inputs': inputs.map((p) => p.toJson()).toList(),
        'outputs': outputs.map((p) => p.toJson()).toList(),
        'literals': literals,
      };

  factory LuminaBlueprintNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map? ?? const {};
    List<LuminaBlueprintPin> pins(Object? list) => (list as List? ?? const [])
        .map((p) => LuminaBlueprintPin.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    return LuminaBlueprintNode(
      id: json['id'] as String? ?? '',
      registryId: json['registryId'] as String? ?? '',
      title: json['title'] as String? ?? 'Node',
      category: json['category'] as String? ?? 'General',
      x: (pos['x'] as num?)?.toDouble() ?? 0.0,
      y: (pos['y'] as num?)?.toDouble() ?? 0.0,
      headerColor: json['headerColor'] as int?,
      inputs: pins(json['inputs']),
      outputs: pins(json['outputs']),
      literals: Map<String, dynamic>.from(json['literals'] as Map? ?? const {}),
    );
  }
}

/// A wire from an output pin to an input pin.
class LuminaBlueprintWire {
  final String id;
  final String fromNodeId;
  final String fromPinId;
  final String toNodeId;
  final String toPinId;

  const LuminaBlueprintWire({
    required this.id,
    required this.fromNodeId,
    required this.fromPinId,
    required this.toNodeId,
    required this.toPinId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'fromPinId': fromPinId,
        'toNodeId': toNodeId,
        'toPinId': toPinId,
      };

  factory LuminaBlueprintWire.fromJson(Map<String, dynamic> json) => LuminaBlueprintWire(
        id: json['id'] as String? ?? '',
        fromNodeId: json['fromNodeId'] as String? ?? '',
        fromPinId: json['fromPinId'] as String? ?? '',
        toNodeId: json['toNodeId'] as String? ?? '',
        toPinId: json['toPinId'] as String? ?? '',
      );
}

/// One node graph (the event graph today).
class LuminaBlueprintGraph {
  final List<LuminaBlueprintNode> nodes;
  final List<LuminaBlueprintWire> wires;

  LuminaBlueprintGraph({List<LuminaBlueprintNode>? nodes, List<LuminaBlueprintWire>? wires})
      : nodes = nodes ?? <LuminaBlueprintNode>[],
        wires = wires ?? <LuminaBlueprintWire>[];

  LuminaBlueprintNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Wires leaving [nodeId]'s output [pinId].
  Iterable<LuminaBlueprintWire> wiresFrom(String nodeId, String pinId) =>
      wires.where((w) => w.fromNodeId == nodeId && w.fromPinId == pinId);

  /// The wire into [nodeId]'s input [pinId], if any.
  LuminaBlueprintWire? wireInto(String nodeId, String pinId) {
    for (final w in wires) {
      if (w.toNodeId == nodeId && w.toPinId == pinId) return w;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'connections': wires.map((w) => w.toJson()).toList(),
      };

  factory LuminaBlueprintGraph.fromJson(Map<String, dynamic>? json) => LuminaBlueprintGraph(
        nodes: (json?['nodes'] as List? ?? const [])
            .map((n) => LuminaBlueprintNode.fromJson(Map<String, dynamic>.from(n as Map)))
            .toList(),
        wires: (json?['connections'] as List? ?? const [])
            .map((w) => LuminaBlueprintWire.fromJson(Map<String, dynamic>.from(w as Map)))
            .toList(),
      );
}

List<LuminaBlueprintVariable> _variables(Object? list) => [
      for (final v in list as List? ?? const []) LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(v as Map)),
    ];

/// A user function of a Blueprint: its signature, its own
/// graph (with a `function_entry` and, when it has outputs, a
/// `function_result` node), local variables, and whether it is pure (no exec
/// pins; callable from data chains).
class LuminaBlueprintFunctionGraph {
  String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;
  final List<LuminaBlueprintVariable> localVariables;
  final LuminaBlueprintGraph graph;
  bool pure;
  String category;

  LuminaBlueprintFunctionGraph({
    required this.name,
    List<LuminaBlueprintVariable>? inputs,
    List<LuminaBlueprintVariable>? outputs,
    List<LuminaBlueprintVariable>? localVariables,
    LuminaBlueprintGraph? graph,
    this.pure = false,
    this.category = 'Default',
  })  : inputs = inputs ?? <LuminaBlueprintVariable>[],
        outputs = outputs ?? <LuminaBlueprintVariable>[],
        localVariables = localVariables ?? <LuminaBlueprintVariable>[],
        graph = graph ?? LuminaBlueprintGraph();

  LuminaBlueprintVariable? localVariable(String name) {
    for (final v in localVariables) {
      if (v.name == name) return v;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
        'localVariables': localVariables.map((v) => v.toJson()).toList(),
        'graph': graph.toJson(),
        'pure': pure,
        'category': category,
      };

  factory LuminaBlueprintFunctionGraph.fromJson(Map<String, dynamic> map) => LuminaBlueprintFunctionGraph(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
        localVariables: _variables(map['localVariables']),
        graph: LuminaBlueprintGraph.fromJson(map['graph'] == null ? null : Map<String, dynamic>.from(map['graph'] as Map)),
        pure: map['pure'] as bool? ?? false,
        category: map['category'] as String? ?? 'Default',
      );
}

/// A macro of a Blueprint: exec and data inputs / outputs
/// (`typeName: 'Exec'` for exec pins) and a body graph with a `macro_input`
/// and a `macro_output` node. A `call_macro` node is expanded into its
/// caller by [LuminaBlueprintMacroExpander]; the document keeps it folded.
class LuminaBlueprintMacroGraph {
  String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;
  final LuminaBlueprintGraph graph;

  LuminaBlueprintMacroGraph({
    required this.name,
    List<LuminaBlueprintVariable>? inputs,
    List<LuminaBlueprintVariable>? outputs,
    LuminaBlueprintGraph? graph,
  })  : inputs = inputs ?? <LuminaBlueprintVariable>[],
        outputs = outputs ?? <LuminaBlueprintVariable>[],
        graph = graph ?? LuminaBlueprintGraph();

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
        'graph': graph.toJson(),
      };

  factory LuminaBlueprintMacroGraph.fromJson(Map<String, dynamic> map) => LuminaBlueprintMacroGraph(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
        graph: LuminaBlueprintGraph.fromJson(map['graph'] == null ? null : Map<String, dynamic>.from(map['graph'] as Map)),
      );
}

/// An event dispatcher of a Blueprint: a name and the
/// parameters every bound event receives.
class LuminaBlueprintDispatcher {
  String name;
  final List<LuminaBlueprintVariable> parameters;

  LuminaBlueprintDispatcher({required this.name, List<LuminaBlueprintVariable>? parameters})
      : parameters = parameters ?? <LuminaBlueprintVariable>[];

  Map<String, dynamic> toJson() => {'name': name, 'parameters': parameters.map((v) => v.toJson()).toList()};

  factory LuminaBlueprintDispatcher.fromJson(Map<String, dynamic> map) =>
      LuminaBlueprintDispatcher(name: map['name'] as String? ?? '', parameters: _variables(map['parameters']));
}

/// One function of a Blueprint interface. A function with
/// outputs is implemented as a Blueprint function of that name; one without
/// as an `event_interface_function` event.
class LuminaBlueprintFunctionSignature {
  final String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;

  const LuminaBlueprintFunctionSignature({required this.name, this.inputs = const [], this.outputs = const []});

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
      };

  factory LuminaBlueprintFunctionSignature.fromJson(Map<String, dynamic> map) => LuminaBlueprintFunctionSignature(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
      );
}

/// A Blueprint interface asset: the `.lmas` payload
/// `{"kind": "interface", "name": …, "functions": […]}`.
class LuminaBlueprintInterfaceDocument {
  static const String kind = 'interface';
  final String name;
  final List<LuminaBlueprintFunctionSignature> functions;

  const LuminaBlueprintInterfaceDocument({required this.name, this.functions = const []});

  LuminaBlueprintFunctionSignature? function(String? name) {
    for (final f in functions) {
      if (f.name == name) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'functions': functions.map((f) => f.toJson()).toList()};

  factory LuminaBlueprintInterfaceDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintInterfaceDocument(
        name: map['name'] as String? ?? '',
        functions: [
          for (final f in map['functions'] as List? ?? const [])
            LuminaBlueprintFunctionSignature.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// A Blueprint enum asset: the `.lmas` payload
/// `{"kind": "enum", "name": …, "values": […]}`. Values are their names at
/// run time.
class LuminaBlueprintEnumDocument {
  static const String kind = 'enum';
  final String name;
  final List<String> values;

  const LuminaBlueprintEnumDocument({required this.name, this.values = const []});

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'values': values};

  factory LuminaBlueprintEnumDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintEnumDocument(
        name: map['name'] as String? ?? '',
        values: [for (final v in map['values'] as List? ?? const []) '$v'],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// The kind of Blueprint document a `.lmas` payload holds: `class` (an
/// actor Blueprint), `enum` or `interface`.
String luminaBlueprintDocumentKind(Map<String, dynamic> payload) => payload['kind'] as String? ?? 'class';

/// A Blueprint class document: what an ACTOR `.lmas` carries in its payload.
class LuminaBlueprintDocument {
  String parentClass;
  final List<LuminaBlueprintComponent> components;
  final LuminaBlueprintGraph eventGraph;
  final List<LuminaBlueprintVariable> variables;
  final Map<String, dynamic> classDefaults;

  /// User functions, macros and event dispatchers.
  final List<LuminaBlueprintFunctionGraph> functions;
  final List<LuminaBlueprintMacroGraph> macros;
  final List<LuminaBlueprintDispatcher> dispatchers;

  /// The names of the interface assets this Blueprint implements.
  final List<String> interfaces;

  LuminaBlueprintDocument({
    this.parentClass = 'LuminaActor',
    List<LuminaBlueprintComponent>? components,
    LuminaBlueprintGraph? eventGraph,
    List<LuminaBlueprintVariable>? variables,
    Map<String, dynamic>? classDefaults,
    List<LuminaBlueprintFunctionGraph>? functions,
    List<LuminaBlueprintMacroGraph>? macros,
    List<LuminaBlueprintDispatcher>? dispatchers,
    List<String>? interfaces,
  })  : components = components ?? <LuminaBlueprintComponent>[],
        eventGraph = eventGraph ?? LuminaBlueprintGraph(),
        variables = variables ?? <LuminaBlueprintVariable>[],
        classDefaults = classDefaults ?? <String, dynamic>{},
        functions = functions ?? <LuminaBlueprintFunctionGraph>[],
        macros = macros ?? <LuminaBlueprintMacroGraph>[],
        dispatchers = dispatchers ?? <LuminaBlueprintDispatcher>[],
        interfaces = interfaces ?? <String>[];

  LuminaBlueprintVariable? variable(String name) {
    for (final v in variables) {
      if (v.name == name) return v;
    }
    return null;
  }

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

  LuminaBlueprintDispatcher? dispatcher(String? name) {
    for (final d in dispatchers) {
      if (d.name == name) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'parentClass': parentClass,
        'components': components.map((c) => c.toJson()).toList(),
        'eventGraph': eventGraph.toJson(),
        'variables': variables.map((v) => v.toJson()).toList(),
        'classDefaults': classDefaults,
        if (functions.isNotEmpty) 'functions': functions.map((f) => f.toJson()).toList(),
        if (macros.isNotEmpty) 'macros': macros.map((m) => m.toJson()).toList(),
        if (dispatchers.isNotEmpty) 'dispatchers': dispatchers.map((d) => d.toJson()).toList(),
        if (interfaces.isNotEmpty) 'interfaces': interfaces,
      };

  factory LuminaBlueprintDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintDocument(
        parentClass: map['parentClass'] as String? ?? 'LuminaActor',
        components: (map['components'] as List? ?? const [])
            .map((c) => LuminaBlueprintComponent.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList(),
        eventGraph: LuminaBlueprintGraph.fromJson(
          map['eventGraph'] == null ? null : Map<String, dynamic>.from(map['eventGraph'] as Map),
        ),
        variables: (map['variables'] as List? ?? const [])
            .map((v) => LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        classDefaults: Map<String, dynamic>.from(map['classDefaults'] as Map? ?? const {}),
        functions: [
          for (final f in map['functions'] as List? ?? const [])
            LuminaBlueprintFunctionGraph.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        macros: [
          for (final m in map['macros'] as List? ?? const []) LuminaBlueprintMacroGraph.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        dispatchers: [
          for (final d in map['dispatchers'] as List? ?? const [])
            LuminaBlueprintDispatcher.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
        interfaces: [for (final i in map['interfaces'] as List? ?? const []) '$i'],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Converts a stored literal to the Dart value a [type] pin carries: a
/// `Vector3` for [LuminaPinType.vector], a `Vector2` for
/// [LuminaPinType.vector2D], a [LuminaRotator], a `double`, …; null stays null.
Object? luminaBlueprintLiteral(LuminaPinType type, Object? stored) {
  if (stored == null) return null;
  List<num> nums(Object? v) => v is List ? v.whereType<num>().toList() : const <num>[];
  double at(List<num> v, int i) => v.length > i ? v[i].toDouble() : 0.0;
  switch (type) {
    case LuminaPinType.float:
      return stored is num ? stored.toDouble() : double.tryParse('$stored') ?? 0.0;
    case LuminaPinType.integer:
      return stored is num ? stored.toInt() : int.tryParse('$stored') ?? 0;
    case LuminaPinType.boolean:
      return stored is bool ? stored : '$stored' == 'true';
    case LuminaPinType.string:
    case LuminaPinType.name:
      return '$stored';
    case LuminaPinType.vector:
      final v = nums(stored);
      return Vector3(at(v, 0), at(v, 1), at(v, 2));
    case LuminaPinType.vector2D:
      final v = nums(stored);
      return Vector2(at(v, 0), at(v, 1));
    case LuminaPinType.rotator:
      return LuminaRotator.fromList(nums(stored));
    case LuminaPinType.color:
      final v = nums(stored);
      return <double>[at(v, 0), at(v, 1), at(v, 2), v.length > 3 ? v[3].toDouble() : 1.0];
    case LuminaPinType.array:
      return stored is List ? List<Object?>.from(stored) : <Object?>[];
    case LuminaPinType.transform:
      if (stored is Map) {
        return <String, Object?>{
          'location': nums(stored['location']).map((n) => n.toDouble()).toList(),
          'rotation': nums(stored['rotation']).map((n) => n.toDouble()).toList(),
          'scale': stored['scale'] is List ? nums(stored['scale']).map((n) => n.toDouble()).toList() : [1.0, 1.0, 1.0],
        };
      }
      return stored;
    case LuminaPinType.hitResult:
      return stored is Map ? Map<String, Object?>.from(stored) : stored;
    case LuminaPinType.enumeration:
      return '$stored';
    case LuminaPinType.exec:
    case LuminaPinType.object:
    case LuminaPinType.structEnum:
    case LuminaPinType.wildcard:
    case LuminaPinType.delegate:
    case LuminaPinType.timerHandle:
      return stored;
  }
}

/// The zero value of a pin type: what an unset input reads as, in the VM and
/// in generated code alike.
Object? luminaBlueprintZero(LuminaPinType type) => switch (type) {
      LuminaPinType.float => 0.0,
      LuminaPinType.integer => 0,
      LuminaPinType.boolean => false,
      LuminaPinType.string || LuminaPinType.name || LuminaPinType.enumeration => '',
      LuminaPinType.vector => Vector3.zero(),
      LuminaPinType.vector2D => Vector2.zero(),
      LuminaPinType.rotator => const LuminaRotator.zero(),
      LuminaPinType.color => <double>[0.0, 0.0, 0.0, 1.0],
      LuminaPinType.array => <Object?>[],
      LuminaPinType.transform => <String, Object?>{
          'location': <double>[0.0, 0.0, 0.0],
          'rotation': <double>[0.0, 0.0, 0.0],
          'scale': <double>[1.0, 1.0, 1.0],
        },
      _ => null,
    };
