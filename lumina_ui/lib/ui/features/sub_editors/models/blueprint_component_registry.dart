import 'package:shadcn_flutter/shadcn_flutter.dart' show IconData, LucideIcons;

enum ComponentPropertyType {
  number,
  boolean,
  string,
  enumType,
  vector3,
  assetReference,
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
    ComponentTypeDescriptor(
      typeName: 'LuminaSceneComponent',
      displayName: 'Scene Component',
      category: 'Core',
      isSceneComponent: true,
      properties: [
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
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaArrowComponent',
      displayName: 'Arrow',
      category: 'Utility',
      isSceneComponent: true,
      properties: [
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
        ComponentPropertySchema(
          group: 'ARROW',
          name: 'Arrow Size',
          dartField: 'arrowSize',
          type: ComponentPropertyType.number,
          defaultValue: 1.0,
          min: 0.1,
          max: 10.0,
        ),
        ComponentPropertySchema(
          group: 'ARROW',
          name: 'Arrow Color',
          dartField: 'arrowColor',
          type: ComponentPropertyType.string,
          defaultValue: '#0088ffff',
        ),
      ],
    ),
    // The shape collision components. Shape keys are lumina's component mapping keys: `boxExtent`
    // (authoring X/Y/Z half extents, cm), `radius`, `halfHeight` and
    // `hullAsset` (a static mesh whose simple collision hulls the convex
    // wraps); the collision JSON keys come from the Collision section.
    ComponentTypeDescriptor(
      typeName: 'LuminaBoxComponent',
      displayName: 'Box Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.box,
      properties: [
        ..._transformSchema,
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Box Extent',
          dartField: 'boxExtent',
          type: ComponentPropertyType.vector3,
          defaultValue: [50.0, 50.0, 50.0], // cm half extents
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaSphereComponent',
      displayName: 'Sphere Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.circle,
      properties: [
        ..._transformSchema,
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Sphere Radius',
          dartField: 'radius',
          type: ComponentPropertyType.number,
          defaultValue: 50.0, // cm
          min: 1.0,
          max: 2000.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaCylinderComponent',
      displayName: 'Cylinder Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.cylinder,
      properties: [
        ..._transformSchema,
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Cylinder Radius',
          dartField: 'radius',
          type: ComponentPropertyType.number,
          defaultValue: 50.0, // cm
          min: 1.0,
          max: 2000.0,
        ),
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Cylinder Half Height',
          dartField: 'halfHeight',
          type: ComponentPropertyType.number,
          defaultValue: 80.0, // cm
          min: 1.0,
          max: 2000.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaConeComponent',
      displayName: 'Cone Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.cone,
      properties: [
        ..._transformSchema,
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Cone Radius',
          dartField: 'radius',
          type: ComponentPropertyType.number,
          defaultValue: 50.0, // cm
          min: 1.0,
          max: 2000.0,
        ),
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Cone Half Height',
          dartField: 'halfHeight',
          type: ComponentPropertyType.number,
          defaultValue: 80.0, // cm
          min: 1.0,
          max: 2000.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaConvexComponent',
      displayName: 'Convex Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.hexagon,
      properties: [
        ..._transformSchema,
        ComponentPropertySchema(
          group: 'SHAPE',
          name: 'Convex Hull Mesh',
          dartField: 'hullAsset',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaCapsuleComponent',
      displayName: 'Capsule Collision',
      category: 'Collision',
      isSceneComponent: true,
      collisionCapable: true,
      icon: LucideIcons.pill,
      properties: [
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
        ComponentPropertySchema(
          group: 'SHAPE / COLLISION',
          name: 'Capsule Radius',
          dartField: 'capsuleRadius',
          type: ComponentPropertyType.number,
          defaultValue: 40.0, // cm
          min: 5.0,
          max: 500.0,
        ),
        ComponentPropertySchema(
          group: 'SHAPE / COLLISION',
          name: 'Capsule Half Height',
          dartField: 'capsuleHalfHeight',
          type: ComponentPropertyType.number,
          defaultValue: 88.0, // cm
          min: 10.0,
          max: 1000.0,
        ),
        ComponentPropertySchema(
          group: 'PHYSICS',
          name: 'Simulate Physics',
          dartField: 'simulatePhysics',
          type: ComponentPropertyType.boolean,
          defaultValue: false,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaCameraComponent',
      displayName: 'Camera',
      category: 'Camera',
      isSceneComponent: true,
      properties: [
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
        ComponentPropertySchema(
          group: 'CAMERA SETTINGS',
          name: 'Field of View',
          dartField: 'fieldOfView',
          type: ComponentPropertyType.number,
          defaultValue: 90.0,
          min: 30.0,
          max: 120.0,
          hardMin: 5.0,
          hardMax: 170.0,
        ),
        ComponentPropertySchema(
          group: 'CAMERA SETTINGS',
          name: 'Near Clip Plane',
          dartField: 'nearClipPlane',
          type: ComponentPropertyType.number,
          defaultValue: 10.0, // cm
          min: 1.0,
          max: 1000.0,
        ),
        ComponentPropertySchema(
          group: 'CAMERA SETTINGS',
          name: 'Far Clip Plane',
          dartField: 'farClipPlane',
          type: ComponentPropertyType.number,
          defaultValue: 100000.0, // cm
          min: 1000.0,
          max: 1000000.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaSpringArmComponent',
      displayName: 'Spring Arm',
      category: 'Camera',
      isSceneComponent: true,
      properties: [
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
        ComponentPropertySchema(
          group: 'CAMERA BOOM',
          name: 'Target Arm Length',
          dartField: 'targetArmLength',
          type: ComponentPropertyType.number,
          defaultValue: 300.0, // cm
          min: 50.0,
          max: 2000.0,
        ),
        ComponentPropertySchema(
          group: 'LAG',
          name: 'Enable Camera Lag',
          dartField: 'enableCameraLag',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
        ComponentPropertySchema(
          group: 'LAG',
          name: 'Camera Lag Speed',
          dartField: 'cameraLagSpeed',
          type: ComponentPropertyType.number,
          defaultValue: 10.0,
          min: 1.0,
          max: 50.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaCharacterMovementComponent',
      displayName: 'Character Movement',
      category: 'Movement',
      isSceneComponent: false,
      properties: [
        // GENERAL SETTINGS
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Gravity Scale',
          dartField: 'gravityScale',
          type: ComponentPropertyType.number,
          defaultValue: 1.0,
          min: 0.0,
          max: 5.0,
        ),
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Max Acceleration',
          dartField: 'maxAcceleration',
          type: ComponentPropertyType.number,
          defaultValue: 2048.0,
          min: 100.0,
          max: 10000.0,
        ),
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Braking Friction Factor',
          dartField: 'brakingFrictionFactor',
          type: ComponentPropertyType.number,
          defaultValue: 2.0,
          min: 0.0,
          max: 10.0,
        ),
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Crouched Half Height',
          dartField: 'crouchedHalfHeight',
          type: ComponentPropertyType.number,
          defaultValue: 40.0,
          min: 10.0,
          max: 100.0,
        ),
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Mass (kg)',
          dartField: 'mass',
          type: ComponentPropertyType.number,
          defaultValue: 100.0,
          min: 10.0,
          max: 1000.0,
        ),
        ComponentPropertySchema(
          group: 'GENERAL SETTINGS',
          name: 'Default Land Movement Mode',
          dartField: 'defaultLandMovementMode',
          type: ComponentPropertyType.enumType,
          defaultValue: 'Walking',
          enumOptions: ['Walking', 'Falling', 'Swimming', 'Flying', 'Custom', 'None'],
        ),

        // WALKING
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Max Walk Speed',
          dartField: 'maxWalkSpeed',
          type: ComponentPropertyType.number,
          defaultValue: 500.0,
          min: 50.0,
          max: 2000.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Max Walk Speed Crouched',
          dartField: 'maxWalkSpeedCrouched',
          type: ComponentPropertyType.number,
          defaultValue: 300.0,
          min: 50.0,
          max: 1000.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Max Step Height',
          dartField: 'maxStepHeight',
          type: ComponentPropertyType.number,
          defaultValue: 45.0,
          min: 10.0,
          max: 100.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Walkable Floor Angle',
          dartField: 'walkableFloorAngle',
          type: ComponentPropertyType.number,
          defaultValue: 44.76,
          min: 0.0,
          max: 90.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Ground Friction',
          dartField: 'groundFriction',
          type: ComponentPropertyType.number,
          defaultValue: 8.0,
          min: 0.0,
          max: 20.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Braking Deceleration Walking',
          dartField: 'brakingDecelerationWalking',
          type: ComponentPropertyType.number,
          defaultValue: 2048.0,
          min: 100.0,
          max: 10000.0,
        ),
        ComponentPropertySchema(
          group: 'WALKING',
          name: 'Can Walk Off Ledges',
          dartField: 'canWalkOffLedges',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),

        // JUMPING / FALLING
        ComponentPropertySchema(
          group: 'JUMPING / FALLING',
          name: 'Jump Z Velocity',
          dartField: 'jumpZVelocity',
          type: ComponentPropertyType.number,
          defaultValue: 700.0,
          min: 100.0,
          max: 2000.0,
        ),
        ComponentPropertySchema(
          group: 'JUMPING / FALLING',
          name: 'Braking Deceleration Falling',
          dartField: 'brakingDecelerationFalling',
          type: ComponentPropertyType.number,
          defaultValue: 1500.0,
          min: 0.0,
          max: 5000.0,
        ),
        ComponentPropertySchema(
          group: 'JUMPING / FALLING',
          name: 'Air Control',
          dartField: 'airControl',
          type: ComponentPropertyType.number,
          defaultValue: 0.35,
          min: 0.0,
          max: 1.0,
        ),
        ComponentPropertySchema(
          group: 'JUMPING / FALLING',
          name: 'Air Control Boost Multiplier',
          dartField: 'airControlBoostMultiplier',
          type: ComponentPropertyType.number,
          defaultValue: 2.0,
          min: 0.0,
          max: 10.0,
        ),

        // ROTATION / ORIENTATION
        ComponentPropertySchema(
          group: 'ROTATION / ORIENTATION',
          name: 'Orient Rotation to Movement',
          dartField: 'orientRotationToMovement',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
        ComponentPropertySchema(
          group: 'ROTATION / ORIENTATION',
          name: 'Rotation Rate Yaw',
          dartField: 'rotationRateYaw',
          type: ComponentPropertyType.number,
          defaultValue: 540.0,
          min: 0.0,
          max: 1080.0,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaSkeletalMeshComponent',
      displayName: 'Skeletal Mesh',
      category: 'Rendering',
      isSceneComponent: true,
      properties: [
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
        ComponentPropertySchema(
          group: 'MESH & GEOMETRY',
          name: 'Skeletal Mesh Asset',
          dartField: 'skeletalMeshAsset',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        ComponentPropertySchema(
          group: 'ANIMATION',
          name: 'Animation Mode',
          dartField: 'animMode',
          type: ComponentPropertyType.enumType,
          defaultValue: 'Use Animation Blueprint',
          enumOptions: ['Use Animation Blueprint', 'Use Animation Asset', 'Disabled'],
        ),
        ComponentPropertySchema(
          group: 'ANIMATION',
          name: 'Anim to Play',
          dartField: 'animToPlay',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        // The Animation Blueprint that animates the
        // mesh when Animation Mode is Use Animation Blueprint (lumina
        // reads it in PIE and the generated game).
        ComponentPropertySchema(
          group: 'ANIMATION',
          name: 'Anim Class',
          dartField: 'animClass',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        ComponentPropertySchema(
          group: 'MATERIALS',
          name: 'Material Override',
          dartField: 'materialOverride',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        ComponentPropertySchema(
          group: 'LIGHTING',
          name: 'Cast Shadows',
          dartField: 'castShadows',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
        ComponentPropertySchema(
          group: 'LIGHTING',
          name: 'Receive Shadows',
          dartField: 'receiveShadows',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaStaticMeshComponent',
      displayName: 'Static Mesh',
      category: 'Rendering',
      isSceneComponent: true,
      properties: [
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
        ComponentPropertySchema(
          group: 'MESH & GEOMETRY',
          name: 'Static Mesh Asset',
          dartField: 'staticMeshAsset',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        ComponentPropertySchema(
          group: 'MATERIALS',
          name: 'Material Override',
          dartField: 'materialOverride',
          type: ComponentPropertyType.assetReference,
          defaultValue: '',
        ),
        ComponentPropertySchema(
          group: 'LIGHTING',
          name: 'Cast Shadows',
          dartField: 'castShadows',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
        ComponentPropertySchema(
          group: 'LIGHTING',
          name: 'Receive Shadows',
          dartField: 'receiveShadows',
          type: ComponentPropertyType.boolean,
          defaultValue: true,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaPlayerComponent',
      displayName: 'Player Controller Binding',
      category: 'Input & Player',
      isSceneComponent: false,
      properties: [
        ComponentPropertySchema(
          group: 'POSSESSION',
          name: 'Auto Possess Player',
          dartField: 'autoPossessPlayer',
          type: ComponentPropertyType.number,
          defaultValue: 0,
          min: 0,
          max: 8,
          hardMax: 8,
        ),
      ],
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaInputComponent',
      displayName: 'Input Component',
      category: 'Input & Player',
      isSceneComponent: false,
      properties: [
        ComponentPropertySchema(
          group: 'INPUT',
          name: 'Block Input',
          dartField: 'blockInput',
          type: ComponentPropertyType.boolean,
          defaultValue: false,
        ),
      ],
    ),
    // Gated engine components
    ComponentTypeDescriptor(
      typeName: 'LuminaDirectionalLightComponent',
      displayName: 'Directional Light',
      category: 'Lighting',
      isSceneComponent: true,
      isAvailable: false,
      gapReason: 'Waiting on engine light component support',
    ),
    ComponentTypeDescriptor(
      typeName: 'LuminaPointLightComponent',
      displayName: 'Point Light',
      category: 'Lighting',
      isSceneComponent: true,
      isAvailable: false,
      gapReason: 'Waiting on engine light component support',
    ),
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
