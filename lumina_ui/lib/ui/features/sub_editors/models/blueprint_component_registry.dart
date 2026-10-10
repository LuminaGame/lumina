import 'package:shadcn_flutter/shadcn_flutter.dart' show IconData, LucideIcons;

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry/traversal_component_descriptor.dart';

part 'blueprint_component_registry/core_descriptors.dart';
part 'blueprint_component_registry/camera_descriptors.dart';
part 'blueprint_component_registry/movement_descriptors.dart';
part 'blueprint_component_registry/mesh_descriptors.dart';
part 'blueprint_component_registry/input_descriptors.dart';
part 'blueprint_component_registry/light_descriptors.dart';

enum ComponentPropertyType {
  number,
  boolean,
  string,
  enumType,
  vector3,
  assetReference,

  /// An sRGB `#RRGGBB` string, edited with the colour picker.
  color,
}

class ComponentPropertySchema {
  final String group;
  final String name;
  final String dartField;
  final ComponentPropertyType type;
  final dynamic defaultValue;
  /// The Details slider's range for a number.
  final double min;
  final double max;

  /// A typed number's hard limits (where [min] / [max] are its slider
  /// range). Null: a slider that starts at or
  /// above zero is never negative ([lowerLimit] 0), and there is no upper
  /// limit.
  final double? hardMin;
  final double? hardMax;
  final List<String> enumOptions;

  const ComponentPropertySchema({
    required this.group,
    required this.name,
    required this.dartField,
    required this.type,
    this.defaultValue,
    this.min = 0.0,
    this.max = 100.0,
    this.hardMin,
    this.hardMax,
    this.enumOptions = const [],
  });

  /// The lowest value a number may take (typed values go past the slider).
  double get lowerLimit => hardMin ?? (min >= 0 ? 0.0 : double.negativeInfinity);

  /// The highest value a number may take.
  double get upperLimit => hardMax ?? double.infinity;

  /// [value] within the hard limits.
  double clampToLimits(double value) => value.clamp(lowerLimit, upperLimit).toDouble();
}

class ComponentTypeDescriptor {
  final String typeName;
  final String displayName;
  final String category;
  final bool isSceneComponent;
  final bool isAvailable;
  final String? gapReason;
  final List<ComponentPropertySchema> properties;

  /// A collision shape: Details shows its Collision
  /// section (preset, object type, response grid) writing lumina's collision
  /// JSON keys (`preset`, `objectType`, `responses`, `generateOverlapEvents`,
  /// `collisionEnabled`) into the component's properties.
  final bool collisionCapable;

  /// The Add Component menu's and the component tree's icon; null falls back
  /// to the generic scene / actor component icon.
  final IconData? icon;

  const ComponentTypeDescriptor({
    required this.typeName,
    required this.displayName,
    required this.category,
    required this.isSceneComponent,
    this.isAvailable = true,
    this.gapReason,
    this.properties = const [],
    this.collisionCapable = false,
    this.icon,
  });
}

/// The transform rows every scene component starts with.
const List<ComponentPropertySchema> _transformSchema = [
  ComponentPropertySchema(
    group: 'TRANSFORM',
    name: 'Location',
    dartField: 'location',
    type: ComponentPropertyType.vector3,
    defaultValue: [0.0, 0.0, 0.0],
  ),
  ComponentPropertySchema(
    group: 'TRANSFORM',
    name: 'Rotation',
    dartField: 'rotation',
    type: ComponentPropertyType.vector3,
    defaultValue: [0.0, 0.0, 0.0],
  ),
  ComponentPropertySchema(
    group: 'TRANSFORM',
    name: 'Scale',
    dartField: 'scale',
    type: ComponentPropertyType.vector3,
    defaultValue: [1.0, 1.0, 1.0],
  ),
];

class BlueprintComponentRegistry {
  static const List<ComponentTypeDescriptor> registeredComponents = [
    ..._coreComponentDescriptors,
    ..._cameraComponentDescriptors,
    ..._movementComponentDescriptors,
    ..._meshComponentDescriptors,
    ..._inputComponentDescriptors,
    ..._lightComponentDescriptors,
    traversalComponentDescriptor,
  ];

  static ComponentTypeDescriptor? getDescriptor(String typeName) {
    try {
      final normalized = typeName.toLowerCase().replaceAll('lumina', '').replaceAll('component', '');
      return registeredComponents.firstWhere((d) {
        final dNorm = d.typeName.toLowerCase().replaceAll('lumina', '').replaceAll('component', '');
        if (d.typeName == typeName) return true;
        if (dNorm == normalized) return true;
        if (dNorm.contains('skeletal') && (normalized.contains('skeletal') || normalized.contains('skinned'))) return true;
        if (dNorm.contains('skinned') && (normalized.contains('skeletal') || normalized.contains('skinned'))) return true;
        if (dNorm.contains('staticmesh') && normalized.contains('mesh')) return true;
        return false;
      });
    } catch (_) {
      return null;
    }
  }

  /// Whether [typeName] is a collision shape with a Collision section.
  static bool isCollisionCapable(String typeName) => getDescriptor(typeName)?.collisionCapable ?? false;

  static List<ComponentPropertySchema> getSchema(String typeName) {
    return getDescriptor(typeName)?.properties ?? const [];
  }
}
