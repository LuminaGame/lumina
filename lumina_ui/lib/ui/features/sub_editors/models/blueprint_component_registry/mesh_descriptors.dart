part of '../blueprint_component_registry.dart';

/// The skeletal and static mesh components.
const List<ComponentTypeDescriptor> _meshComponentDescriptors = [
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
        assetTypes: [AssetType.filameshSk],
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
        assetTypes: [AssetType.animation],
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
        assetTypes: [AssetType.filamat],
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
      // A character's swappable part: its slot name, and the skeletal
      // mesh whose pose it follows by bone name.
      ComponentPropertySchema(
        group: 'CHARACTER',
        name: 'Slot',
        dartField: 'slot',
        type: ComponentPropertyType.string,
        defaultValue: '',
      ),
      ComponentPropertySchema(
        group: 'CHARACTER',
        name: 'Pose From',
        dartField: 'poseFrom',
        type: ComponentPropertyType.componentReference,
        defaultValue: '',
        referenceTypes: ['LuminaSkeletalMeshComponent', 'LuminaAnimatedMeshComponent'],
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
        assetTypes: [AssetType.filamesh],
        defaultValue: '',
      ),
      ComponentPropertySchema(
        group: 'MATERIALS',
        name: 'Material Override',
        dartField: 'materialOverride',
        type: ComponentPropertyType.assetReference,
        assetTypes: [AssetType.filamat],
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
];
