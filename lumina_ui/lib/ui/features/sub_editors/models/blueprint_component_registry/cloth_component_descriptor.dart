import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';

/// The cloth component as the Blueprint editor adds it: a sheet (or a mesh
/// asset) simulated as a soft body, pinned on an edge, with wind. Its
/// properties are the keys `LuminaClothComponent.fromProperties` reads;
/// [wind] is in authoring axes (Z up, cm/s).
const ComponentTypeDescriptor clothComponentDescriptor = ComponentTypeDescriptor(
  typeName: 'LuminaClothComponent',
  displayName: 'Cloth',
  category: 'Physics',
  isSceneComponent: true,
  icon: LucideIcons.flag,
  properties: [
    ComponentPropertySchema(group: 'TRANSFORM', name: 'Location', dartField: 'location', type: ComponentPropertyType.vector3, defaultValue: [0.0, 0.0, 0.0]),
    ComponentPropertySchema(group: 'TRANSFORM', name: 'Rotation', dartField: 'rotation', type: ComponentPropertyType.vector3, defaultValue: [0.0, 0.0, 0.0]),
    ComponentPropertySchema(group: 'TRANSFORM', name: 'Scale', dartField: 'scale', type: ComponentPropertyType.vector3, defaultValue: [1.0, 1.0, 1.0]),
    ComponentPropertySchema(group: 'CLOTH SHAPE', name: 'Mesh Asset', dartField: 'meshAsset', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'CLOTH SHAPE', name: 'Grid Width', dartField: 'gridWidth', type: ComponentPropertyType.number, defaultValue: 200.0, min: 10.0, max: 1000.0),
    ComponentPropertySchema(group: 'CLOTH SHAPE', name: 'Grid Height', dartField: 'gridHeight', type: ComponentPropertyType.number, defaultValue: 150.0, min: 10.0, max: 1000.0),
    ComponentPropertySchema(group: 'CLOTH SHAPE', name: 'Grid Columns', dartField: 'gridColumns', type: ComponentPropertyType.number, defaultValue: 24, min: 1.0, max: 64.0),
    ComponentPropertySchema(group: 'CLOTH SHAPE', name: 'Grid Rows', dartField: 'gridRows', type: ComponentPropertyType.number, defaultValue: 18, min: 1.0, max: 64.0),
    ComponentPropertySchema(
      group: 'CLOTH SHAPE',
      name: 'Pinning',
      dartField: 'pinning',
      type: ComponentPropertyType.enumType,
      defaultValue: 'topEdge',
      enumOptions: ['none', 'topEdge', 'bottomEdge', 'leftEdge', 'rightEdge', 'topCorners'],
    ),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Cloth Settings', dartField: 'clothSettingsAsset', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Mass (kg)', dartField: 'massKg', type: ComponentPropertyType.number, defaultValue: 1.0, min: 0.01, max: 50.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Stiffness', dartField: 'stiffness', type: ComponentPropertyType.number, defaultValue: 0.95, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Bend Stiffness', dartField: 'bendStiffness', type: ComponentPropertyType.number, defaultValue: 0.3, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Damping', dartField: 'damping', type: ComponentPropertyType.number, defaultValue: 0.5, min: 0.0, max: 5.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Friction', dartField: 'friction', type: ComponentPropertyType.number, defaultValue: 0.5, min: 0.0, max: 2.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Thickness (cm)', dartField: 'thickness', type: ComponentPropertyType.number, defaultValue: 1.0, min: 0.0, max: 10.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Iterations', dartField: 'iterations', type: ComponentPropertyType.number, defaultValue: 8, min: 1.0, max: 32.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Gravity Scale', dartField: 'gravityScale', type: ComponentPropertyType.number, defaultValue: 1.0, min: 0.0, max: 3.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Color', dartField: 'color', type: ComponentPropertyType.color, defaultValue: '#E0615A'),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Texture', dartField: 'baseColorTexture', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Material', dartField: 'materialAsset', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Self Collision', dartField: 'selfCollision', type: ComponentPropertyType.boolean, defaultValue: false),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Self Collision Distance (cm)', dartField: 'selfCollisionDistance', type: ComponentPropertyType.number, defaultValue: 2.0, min: 0.1, max: 20.0),
    ComponentPropertySchema(group: 'CLOTH WIND', name: 'Wind (cm/s)', dartField: 'wind', type: ComponentPropertyType.vector3, defaultValue: [0.0, 0.0, 0.0]),
    ComponentPropertySchema(group: 'CLOTH WIND', name: 'Wind Drag', dartField: 'windDrag', type: ComponentPropertyType.number, defaultValue: 1.0, min: 0.0, max: 10.0),
    ComponentPropertySchema(group: 'CLOTH WIND', name: 'Wind Turbulence', dartField: 'windTurbulence', type: ComponentPropertyType.number, defaultValue: 0.3, min: 0.0, max: 1.0),
    ComponentPropertySchema(group: 'CLOTH MOTION', name: 'Inertia Scale', dartField: 'inertiaScale', type: ComponentPropertyType.number, defaultValue: 1.0, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'CLOTH MOTION', name: 'Teleport Distance (cm)', dartField: 'teleportDistance', type: ComponentPropertyType.number, defaultValue: 100.0, min: 1.0, max: 1000.0),
    ComponentPropertySchema(group: 'CLOTH MOTION', name: 'Teleport Rotation (deg)', dartField: 'teleportRotation', type: ComponentPropertyType.number, defaultValue: 60.0, min: 1.0, max: 180.0),
    ComponentPropertySchema(group: 'CLOTH SIMULATION', name: 'Simulate', dartField: 'simulate', type: ComponentPropertyType.boolean, defaultValue: true),
    ComponentPropertySchema(group: 'CLOTH SIMULATION', name: 'Cast Shadows', dartField: 'castShadows', type: ComponentPropertyType.boolean, defaultValue: true),
  ],
);
