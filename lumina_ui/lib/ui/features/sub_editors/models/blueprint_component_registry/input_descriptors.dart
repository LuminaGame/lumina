part of '../blueprint_component_registry.dart';

/// The player and input components.
const List<ComponentTypeDescriptor> _inputComponentDescriptors = [
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
];
