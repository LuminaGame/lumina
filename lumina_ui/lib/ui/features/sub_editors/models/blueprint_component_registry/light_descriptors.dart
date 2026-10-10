part of '../blueprint_component_registry.dart';

/// The directional, point and spot light components.
const List<ComponentTypeDescriptor> _lightComponentDescriptors = [
  // Gated engine components
  ComponentTypeDescriptor(
    typeName: 'LuminaDirectionalLightComponent',
    displayName: 'Directional Light',
    category: 'Lighting',
    isSceneComponent: true,
    isAvailable: false,
    gapReason: 'Waiting on engine light component support',
  ),
  // A point light that moves with its actor. Keys and units are the level
  // Point Light's: lumens, sRGB `colorHex`, attenuation radius in cm.
  ComponentTypeDescriptor(
    typeName: 'LuminaPointLightComponent',
    displayName: 'Point Light',
    category: 'Lighting',
    isSceneComponent: true,
    icon: LucideIcons.lightbulb,
    properties: [
      ..._transformSchema,
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Intensity',
        dartField: 'intensity',
        type: ComponentPropertyType.number,
        defaultValue: 10000.0, // lumens
        min: 0.0,
        max: 10000000.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Light Color',
        dartField: 'colorHex',
        type: ComponentPropertyType.color,
        defaultValue: '#FFFFFF',
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Attenuation Radius',
        dartField: 'attenuationRadius',
        type: ComponentPropertyType.number,
        defaultValue: 1000.0, // cm
        min: 1.0,
        max: 10000.0,
        hardMin: 1.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Cast Shadows',
        dartField: 'castShadows',
        type: ComponentPropertyType.boolean,
        defaultValue: false,
      ),
    ],
  ),
  // A spot light that moves with its actor. Keys and units are the level
  // Spot Light's: lumens, sRGB `colorHex`, attenuation radius in cm, cone angles in degrees.
  ComponentTypeDescriptor(
    typeName: 'LuminaSpotLightComponent',
    displayName: 'Spot Light',
    category: 'Lighting',
    isSceneComponent: true,
    icon: LucideIcons.flashlight,
    properties: [
      ..._transformSchema,
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Intensity',
        dartField: 'intensity',
        type: ComponentPropertyType.number,
        defaultValue: 10000.0, // lumens
        min: 0.0,
        max: 10000000.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Light Color',
        dartField: 'colorHex',
        type: ComponentPropertyType.color,
        defaultValue: '#FFFFFF',
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Attenuation Radius',
        dartField: 'attenuationRadius',
        type: ComponentPropertyType.number,
        defaultValue: 1000.0, // cm
        min: 1.0,
        max: 10000.0,
        hardMin: 1.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Inner Cone Angle',
        dartField: 'innerConeAngle',
        type: ComponentPropertyType.number,
        defaultValue: 30.0, // degrees
        min: 0.1,
        max: 90.0,
        hardMin: 0.1,
        hardMax: 90.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Outer Cone Angle',
        dartField: 'outerConeAngle',
        type: ComponentPropertyType.number,
        defaultValue: 45.0, // degrees
        min: 0.1,
        max: 90.0,
        hardMin: 0.1,
        hardMax: 90.0,
      ),
      ComponentPropertySchema(
        group: 'LIGHT',
        name: 'Cast Shadows',
        dartField: 'castShadows',
        type: ComponentPropertyType.boolean,
        defaultValue: false,
      ),
    ],
  ),
];
