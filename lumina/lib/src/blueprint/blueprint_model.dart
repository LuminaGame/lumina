import 'dart:convert';

import 'package:vector_math/vector_math_64.dart';

part 'blueprint_model/pin_types.dart';
part 'blueprint_model/graph.dart';
part 'blueprint_model/documents.dart';

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
