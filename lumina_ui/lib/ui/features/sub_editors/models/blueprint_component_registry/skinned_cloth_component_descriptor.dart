import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';

/// The skinned cloth component as the Blueprint editor adds it: a garment
/// worn by the skeletal mesh it is attached to (a generated skirt, or a
/// skinned garment mesh), swinging within its max distance of the body.
/// Its properties are the keys `LuminaSkinnedClothComponent.fromProperties`
/// reads; a negative backstop distance is no backstop.
const ComponentTypeDescriptor skinnedClothComponentDescriptor = ComponentTypeDescriptor(
  typeName: 'LuminaSkinnedClothComponent',
  displayName: 'Skinned Cloth',
  category: 'Physics',
  isSceneComponent: true,
  icon: LucideIcons.shirt,
  properties: [
    ComponentPropertySchema(group: 'GARMENT', name: 'Garment Mesh', dartField: 'meshAsset', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'GARMENT', name: 'Waist Bone', dartField: 'waistBone', type: ComponentPropertyType.string, defaultValue: 'pelvis'),
    ComponentPropertySchema(group: 'GARMENT', name: 'Skirt Length (cm)', dartField: 'skirtLength', type: ComponentPropertyType.number, defaultValue: 45.0, min: 10.0, max: 150.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Waist Radius (cm)', dartField: 'waistRadius', type: ComponentPropertyType.number, defaultValue: 17.0, min: 5.0, max: 60.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Hem Radius (cm)', dartField: 'hemRadius', type: ComponentPropertyType.number, defaultValue: 34.0, min: 5.0, max: 120.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Waist Offset (cm)', dartField: 'waistOffset', type: ComponentPropertyType.number, defaultValue: 6.0, min: -30.0, max: 30.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Columns', dartField: 'skirtColumns', type: ComponentPropertyType.number, defaultValue: 32, min: 6.0, max: 128.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Rows', dartField: 'skirtRows', type: ComponentPropertyType.number, defaultValue: 12, min: 1.0, max: 64.0),
    ComponentPropertySchema(group: 'GARMENT', name: 'Fit To Body', dartField: 'fitToBody', type: ComponentPropertyType.boolean, defaultValue: true),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Max Distance (cm)', dartField: 'maxDistance', type: ComponentPropertyType.number, defaultValue: 25.0, min: 0.0, max: 100.0),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Leg Follow', dartField: 'legFollow', type: ComponentPropertyType.number, defaultValue: 0.5, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Backstop Distance (cm)', dartField: 'backstopDistance', type: ComponentPropertyType.number, defaultValue: -1.0, min: -1.0, max: 50.0),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Backstop Radius (cm)', dartField: 'backstopRadius', type: ComponentPropertyType.number, defaultValue: 20.0, min: 1.0, max: 100.0),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Painted Maps', dartField: 'paintedMaps', type: ComponentPropertyType.boolean, defaultValue: false),
    ComponentPropertySchema(group: 'GARMENT FREEDOM', name: 'Collide With Body', dartField: 'collideWithBody', type: ComponentPropertyType.boolean, defaultValue: true),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Cloth Settings', dartField: 'clothSettingsAsset', type: ComponentPropertyType.assetReference, defaultValue: ''),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Mass (kg)', dartField: 'massKg', type: ComponentPropertyType.number, defaultValue: 0.6, min: 0.01, max: 50.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Stiffness', dartField: 'stiffness', type: ComponentPropertyType.number, defaultValue: 0.95, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Bend Stiffness', dartField: 'bendStiffness', type: ComponentPropertyType.number, defaultValue: 0.15, min: 0.0, max: 1.0, hardMax: 1.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Damping', dartField: 'damping', type: ComponentPropertyType.number, defaultValue: 0.3, min: 0.0, max: 5.0),
    ComponentPropertySchema(group: 'CLOTH MATERIAL', name: 'Friction', dartField: 'friction', type: ComponentPropertyType.number, defaultValue: 0.3, min: 0.0, max: 2.0),
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
    // A garment slot of a character, worn on the skeletal mesh Pose From names.
    ComponentPropertySchema(group: 'CHARACTER', name: 'Slot', dartField: 'slot', type: ComponentPropertyType.string, defaultValue: ''),
    ComponentPropertySchema(
      group: 'CHARACTER',
      name: 'Pose From',
      dartField: 'poseFrom',
      type: ComponentPropertyType.componentReference,
      defaultValue: '',
      referenceTypes: ['LuminaSkeletalMeshComponent', 'LuminaAnimatedMeshComponent'],
    ),
  ],
);
