part of '../blueprint_component_registry.dart';

/// The scene root, the arrow and the collision shapes.
const List<ComponentTypeDescriptor> _coreComponentDescriptors = [
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
];
