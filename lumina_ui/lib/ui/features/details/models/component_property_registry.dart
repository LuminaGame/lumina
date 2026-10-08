import 'package:flutter/widgets.dart';

enum PropertyEditorType {
  float,
  integer,
  vector3,
  boolean,
  dropdown,
  assetRef,
  color,
  curve,
  eventList,
  collisionMatrix,
}

class PropertyDescriptor {
  final String id;
  final String label;
  final String group;
  final PropertyEditorType editor;
  final String? unit;
  final double? min;
  final double? max;
  final double? hardMin;
  final double? hardMax;
  final dynamic defaultValue;
  final List<String>? enumValues;
  final String? type;

  const PropertyDescriptor({
    required this.id,
    required this.label,
    required this.group,
    required this.editor,
    this.unit,
    this.min,
    this.max,
    this.hardMin,
    this.hardMax,
    this.defaultValue,
    this.enumValues,
    this.type,
  });
}

class ComponentDescriptor {
  final String type;
  final IconData? icon;
  final List<String> sections;
  final List<PropertyDescriptor> properties;

  /// A muted line shown above the rows — used to state a limit honestly
  /// (e.g. "Approximation: no volumetric scattering").
  final String? note;

  const ComponentDescriptor({
    required this.type,
    this.icon,
    required this.sections,
    required this.properties,
    this.note,
  });
}

class ComponentPropertyRegistry {
  static const Map<String, ComponentDescriptor> descriptors = {
    'LuminaPlayerComponent': ComponentDescriptor(
      type: 'LuminaPlayerComponent',
      sections: ['Player Settings', 'Camera & Control Rotation', 'Input Event Bindings'],
      properties: [
        PropertyDescriptor(id: 'playerIndex', label: 'Player Index', group: 'Player Settings', editor: PropertyEditorType.dropdown, defaultValue: 'Player 0 / Local Player', enumValues: ['Player 0 / Local Player', 'Player 1', 'Player 2']),
        PropertyDescriptor(id: 'autoReceiveInput', label: 'Auto Receive Input', group: 'Player Settings', editor: PropertyEditorType.dropdown, defaultValue: 'Disabled', enumValues: ['Disabled', 'Player 0', 'Player 1']),
        PropertyDescriptor(id: 'blockInput', label: 'Block Input', group: 'Player Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'useControllerDesiredRotation', label: 'Use Controller Desired Rotation', group: 'Camera & Control Rotation', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'pitchLimit', label: 'Control Rotation Pitch Limit', group: 'Camera & Control Rotation', editor: PropertyEditorType.vector3, defaultValue: [-89.0, 89.0, 0.0]),
      ],
    ),
    'LuminaCharacterMovementComponent': ComponentDescriptor(
      type: 'LuminaCharacterMovementComponent',
      sections: ['Character Movement: Walking', 'Character Movement: Jumping & Falling', 'Character Movement: Rotation Settings'],
      properties: [
        PropertyDescriptor(id: 'maxWalkSpeed', label: 'Max Walk Speed', group: 'Character Movement: Walking', editor: PropertyEditorType.float, unit: 'cm/s', defaultValue: 600.0),
        PropertyDescriptor(id: 'maxSprintSpeed', label: 'Max Sprint Speed', group: 'Character Movement: Walking', editor: PropertyEditorType.float, unit: 'cm/s', defaultValue: 1200.0),
        PropertyDescriptor(id: 'brakingDecelerationWalking', label: 'Braking Deceleration Walking', group: 'Character Movement: Walking', editor: PropertyEditorType.float, defaultValue: 2048.0),
        PropertyDescriptor(id: 'groundFriction', label: 'Ground Friction', group: 'Character Movement: Walking', editor: PropertyEditorType.float, defaultValue: 8.0),
        PropertyDescriptor(id: 'maxAcceleration', label: 'Max Acceleration', group: 'Character Movement: Walking', editor: PropertyEditorType.float, defaultValue: 2048.0),
        PropertyDescriptor(id: 'jumpZVelocity', label: 'Jump Z Velocity', group: 'Character Movement: Jumping & Falling', editor: PropertyEditorType.float, unit: 'cm/s', defaultValue: 700.0),
        PropertyDescriptor(id: 'airControl', label: 'Air Control', group: 'Character Movement: Jumping & Falling', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.35),
        PropertyDescriptor(id: 'gravityScale', label: 'Gravity Scale', group: 'Character Movement: Jumping & Falling', editor: PropertyEditorType.float, unit: 'x', defaultValue: 1.0),
        PropertyDescriptor(id: 'fallingLateralFriction', label: 'Falling Lateral Friction', group: 'Character Movement: Jumping & Falling', editor: PropertyEditorType.float, defaultValue: 0.0),
        PropertyDescriptor(id: 'orientRotationToMovement', label: 'Orient Rotation to Movement', group: 'Character Movement: Rotation Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'rotationRateYaw', label: 'Rotation Rate Yaw', group: 'Character Movement: Rotation Settings', editor: PropertyEditorType.float, unit: '°/s', defaultValue: 540.0),
      ],
    ),
    'LuminaSpringMorphComponent': ComponentDescriptor(
      type: 'LuminaSpringMorphComponent',
      sections: ['Secondary Motion'],
      properties: [
        PropertyDescriptor(id: 'enabled', label: 'Enabled', group: 'Secondary Motion', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'amplitude', label: 'Amplitude', group: 'Secondary Motion', editor: PropertyEditorType.float, unit: 'x', min: 0.0, max: 3.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'stiffnessScale', label: 'Stiffness Scale', group: 'Secondary Motion', editor: PropertyEditorType.float, unit: 'x', min: 0.1, max: 5.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'dampingScale', label: 'Damping Scale', group: 'Secondary Motion', editor: PropertyEditorType.float, unit: 'x', min: 0.1, max: 5.0, defaultValue: 1.0),
      ],
    ),
    'LuminaSkeletalMeshComponent': ComponentDescriptor(
      type: 'LuminaSkeletalMeshComponent',
      sections: ['Mesh & Geometry', 'Materials', 'Transform & Attachment', 'Render Distance & Culling'],
      properties: [
        PropertyDescriptor(id: 'skeletalMeshAsset', label: 'Skeletal Mesh Asset', group: 'Mesh & Geometry', editor: PropertyEditorType.assetRef),
        PropertyDescriptor(id: 'animClass', label: 'Anim Class / Animation Blueprint', group: 'Mesh & Geometry', editor: PropertyEditorType.assetRef),
        PropertyDescriptor(id: 'materials', label: 'Materials', group: 'Materials', editor: PropertyEditorType.assetRef, type: 'LuminaMaterial'),
        PropertyDescriptor(id: 'relativeLocation', label: 'Relative Location', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [0.0, 0.0, 0.0]),
        PropertyDescriptor(id: 'relativeRotation', label: 'Relative Rotation', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [0.0, 0.0, 0.0]),
        PropertyDescriptor(id: 'relativeScale', label: 'Relative Scale', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [1.0, 1.0, 1.0]),
        PropertyDescriptor(id: 'attachParent', label: 'Attach Parent', group: 'Transform & Attachment', editor: PropertyEditorType.dropdown, defaultValue: 'None'),
        PropertyDescriptor(id: 'minDrawDistance', label: 'Min Draw Distance', group: 'Render Distance & Culling', editor: PropertyEditorType.float, unit: 'm', defaultValue: 0.0),
        PropertyDescriptor(id: 'maxDrawDistance', label: 'Max Draw Distance', group: 'Render Distance & Culling', editor: PropertyEditorType.float, unit: 'm', defaultValue: 200.0),
        PropertyDescriptor(id: 'castShadow', label: 'Cast Shadow', group: 'Render Distance & Culling', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'volumetricShadow', label: 'Volumetric Shadow', group: 'Render Distance & Culling', editor: PropertyEditorType.boolean, defaultValue: true),
      ],
    ),
    'LuminaMeshComponent': ComponentDescriptor(
      type: 'LuminaMeshComponent',
      sections: ['Mesh & Geometry', 'Materials', 'Transform & Attachment', 'Render Distance & Culling'],
      properties: [
        PropertyDescriptor(id: 'meshAsset', label: 'Static Mesh Asset', group: 'Mesh & Geometry', editor: PropertyEditorType.assetRef, type: 'LuminaStaticMesh'),
        PropertyDescriptor(id: 'materials', label: 'Materials', group: 'Materials', editor: PropertyEditorType.assetRef, type: 'LuminaMaterial'),
        PropertyDescriptor(id: 'relativeLocation', label: 'Relative Location', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [0.0, 0.0, 0.0]),
        PropertyDescriptor(id: 'relativeRotation', label: 'Relative Rotation', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [0.0, 0.0, 0.0]),
        PropertyDescriptor(id: 'relativeScale', label: 'Relative Scale', group: 'Transform & Attachment', editor: PropertyEditorType.vector3, defaultValue: [1.0, 1.0, 1.0]),
        PropertyDescriptor(id: 'attachParent', label: 'Attach Parent', group: 'Transform & Attachment', editor: PropertyEditorType.dropdown, defaultValue: 'None'),
        PropertyDescriptor(id: 'minDrawDistance', label: 'Min Draw Distance', group: 'Render Distance & Culling', editor: PropertyEditorType.float, unit: 'm', defaultValue: 0.0),
        PropertyDescriptor(id: 'maxDrawDistance', label: 'Max Draw Distance', group: 'Render Distance & Culling', editor: PropertyEditorType.float, unit: 'm', defaultValue: 200.0),
        PropertyDescriptor(id: 'castShadow', label: 'Cast Shadow', group: 'Render Distance & Culling', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'volumetricShadow', label: 'Volumetric Shadow', group: 'Render Distance & Culling', editor: PropertyEditorType.boolean, defaultValue: true),
      ],
    ),
    'LuminaSpringArmComponent': ComponentDescriptor(
      type: 'LuminaSpringArmComponent',
      sections: ['Camera Boom / Spring Arm', 'Camera Collision & Probe', 'Lag & Interpolation'],
      properties: [
        PropertyDescriptor(id: 'targetArmLength', label: 'Target Arm Length', group: 'Camera Boom / Spring Arm', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 400.0),
        PropertyDescriptor(id: 'socketOffset', label: 'Socket Offset', group: 'Camera Boom / Spring Arm', editor: PropertyEditorType.vector3, defaultValue: [0.0, 50.0, 60.0]),
        PropertyDescriptor(id: 'targetOffset', label: 'Target Offset', group: 'Camera Boom / Spring Arm', editor: PropertyEditorType.vector3, defaultValue: [0.0, 0.0, 0.0]),
        PropertyDescriptor(id: 'doCollisionTest', label: 'Do Collision Test', group: 'Camera Collision & Probe', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'probeSize', label: 'Probe Size', group: 'Camera Collision & Probe', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 12.0),
        PropertyDescriptor(id: 'probeChannel', label: 'Probe Channel', group: 'Camera Collision & Probe', editor: PropertyEditorType.dropdown, defaultValue: 'Camera', enumValues: ['Camera', 'Visibility', 'BlockAll']),
        PropertyDescriptor(id: 'enableCameraLag', label: 'Enable Camera Lag', group: 'Lag & Interpolation', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'cameraLagSpeed', label: 'Camera Lag Speed', group: 'Lag & Interpolation', editor: PropertyEditorType.float, defaultValue: 10.0),
        PropertyDescriptor(id: 'enableCameraRotationLag', label: 'Enable Camera Rotation Lag', group: 'Lag & Interpolation', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'cameraRotationLagSpeed', label: 'Camera Rotation Lag Speed', group: 'Lag & Interpolation', editor: PropertyEditorType.float, defaultValue: 12.0),
      ],
    ),
    // A camera component's settings under the names and units the runtime
    // reads (`LuminaCameraSettings`): vertical field of view in degrees, cm,
    // f-stops, seconds, ISO. A placed Camera actor edits the same
    // properties in its own Camera section.
    'LuminaCameraComponent': ComponentDescriptor(
      type: 'LuminaCameraComponent',
      sections: ['Camera Settings', 'Exposure'],
      properties: [
        PropertyDescriptor(id: 'projectionMode', label: 'Projection Mode', group: 'Camera Settings', editor: PropertyEditorType.dropdown, defaultValue: 'Perspective', enumValues: ['Perspective', 'Orthographic']),
        PropertyDescriptor(id: 'fieldOfView', label: 'Field of View (vertical)', group: 'Camera Settings', editor: PropertyEditorType.float, unit: '°', min: 5.0, max: 170.0, defaultValue: 60.0),
        PropertyDescriptor(id: 'orthoWidth', label: 'Ortho Width', group: 'Camera Settings', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 100000.0, defaultValue: 1000.0),
        PropertyDescriptor(id: 'nearClipPlane', label: 'Near Clip Plane', group: 'Camera Settings', editor: PropertyEditorType.float, unit: 'cm', min: 0.01, max: 1000.0, defaultValue: 10.0),
        PropertyDescriptor(id: 'farClipPlane', label: 'Far Clip Plane', group: 'Camera Settings', editor: PropertyEditorType.float, unit: 'cm', min: 1000.0, max: 1000000.0, defaultValue: 100000.0),
        PropertyDescriptor(id: 'autoExposure', label: 'Auto Exposure', group: 'Exposure', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'aperture', label: 'Aperture', group: 'Exposure', editor: PropertyEditorType.float, unit: 'f', min: 0.5, max: 64.0, defaultValue: 16.0),
        PropertyDescriptor(id: 'shutterSpeed', label: 'Shutter Speed', group: 'Exposure', editor: PropertyEditorType.float, unit: 's', min: 0.0001, max: 1.0, defaultValue: 0.008),
        PropertyDescriptor(id: 'sensitivity', label: 'ISO', group: 'Exposure', editor: PropertyEditorType.float, min: 25.0, max: 6400.0, defaultValue: 100.0),
      ],
    ),
    'LuminaCapsuleComponent': ComponentDescriptor(
      type: 'LuminaCapsuleComponent',
      sections: ['Shape', 'Collision Presets & Responses'],
      properties: [
        PropertyDescriptor(id: 'capsuleHalfHeight', label: 'Capsule Half Height', group: 'Shape', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 88.0),
        PropertyDescriptor(id: 'capsuleRadius', label: 'Capsule Radius', group: 'Shape', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 34.0),
        PropertyDescriptor(id: 'collisionPreset', label: 'Collision Preset', group: 'Collision Presets & Responses', editor: PropertyEditorType.dropdown, defaultValue: 'Pawn', enumValues: ['Pawn', 'BlockAll', 'OverlapAll', 'NoCollision', 'Custom']),
        PropertyDescriptor(id: 'collisionResponses', label: 'Collision Responses Matrix', group: 'Collision Presets & Responses', editor: PropertyEditorType.collisionMatrix, defaultValue: {}),
      ],
    ),
    'LuminaAudioComponent': ComponentDescriptor(
      type: 'LuminaAudioComponent',
      sections: ['Sound Properties', '3D Attenuation Overrides'],
      properties: [
        PropertyDescriptor(id: 'soundAsset', label: 'Sound Asset', group: 'Sound Properties', editor: PropertyEditorType.assetRef, type: 'LuminaSound'),
        PropertyDescriptor(id: 'volumeMultiplier', label: 'Volume Multiplier', group: 'Sound Properties', editor: PropertyEditorType.float, defaultValue: 1.0),
        PropertyDescriptor(id: 'pitchMultiplier', label: 'Pitch Multiplier', group: 'Sound Properties', editor: PropertyEditorType.float, defaultValue: 1.0),
        PropertyDescriptor(id: 'autoActivate', label: 'Auto Activate', group: 'Sound Properties', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'overrideAttenuation', label: 'Override Attenuation', group: '3D Attenuation Overrides', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'attenuationInnerRadius', label: 'Inner Radius', group: '3D Attenuation Overrides', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 400.0),
        PropertyDescriptor(id: 'falloffDistance', label: 'Falloff Distance', group: '3D Attenuation Overrides', editor: PropertyEditorType.float, unit: 'cm', defaultValue: 3500.0),
      ],
    ),
    // The light actors' own settings, limited to
    // what the Filament runtime supports: no source radius (Filament point
    // and spot lights are punctual), no temperature (the Environment mixer's
    // kelvin drives the sun instead).
    'LuminaDirectionalLightComponent': ComponentDescriptor(
      type: 'LuminaDirectionalLightComponent',
      sections: ['Light'],
      properties: [
        PropertyDescriptor(id: 'intensity', label: 'Intensity', group: 'Light', editor: PropertyEditorType.float, unit: 'lux', min: 0.0, max: 150000.0, defaultValue: 100000.0),
        PropertyDescriptor(id: 'colorHex', label: 'Light Color', group: 'Light', editor: PropertyEditorType.color, defaultValue: '#FFFFFF'),
        PropertyDescriptor(id: 'sunAngularRadius', label: 'Source Angle', group: 'Light', editor: PropertyEditorType.float, unit: '°', min: 0.1, max: 10.0, defaultValue: 0.545),
        PropertyDescriptor(id: 'castShadows', label: 'Cast Shadows', group: 'Light', editor: PropertyEditorType.boolean, defaultValue: true),
      ],
    ),
    'LuminaPointLightComponent': ComponentDescriptor(
      type: 'LuminaPointLightComponent',
      sections: ['Light'],
      properties: [
        PropertyDescriptor(id: 'intensity', label: 'Intensity', group: 'Light', editor: PropertyEditorType.float, unit: 'lm', min: 0.0, max: 100000.0, defaultValue: 10000.0),
        PropertyDescriptor(id: 'colorHex', label: 'Light Color', group: 'Light', editor: PropertyEditorType.color, defaultValue: '#FFFFFF'),
        PropertyDescriptor(id: 'attenuationRadius', label: 'Attenuation Radius', group: 'Light', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 10000.0, defaultValue: 1000.0),
        PropertyDescriptor(id: 'castShadows', label: 'Cast Shadows', group: 'Light', editor: PropertyEditorType.boolean, defaultValue: false),
      ],
    ),
    'LuminaSpotLightComponent': ComponentDescriptor(
      type: 'LuminaSpotLightComponent',
      sections: ['Light'],
      properties: [
        PropertyDescriptor(id: 'intensity', label: 'Intensity', group: 'Light', editor: PropertyEditorType.float, unit: 'lm', min: 0.0, max: 10000000.0, hardMin: 0.0, hardMax: double.infinity, defaultValue: 10000.0),
        PropertyDescriptor(id: 'colorHex', label: 'Light Color', group: 'Light', editor: PropertyEditorType.color, defaultValue: '#FFFFFF'),
        PropertyDescriptor(id: 'attenuationRadius', label: 'Attenuation Radius', group: 'Light', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 10000.0, defaultValue: 1000.0),
        PropertyDescriptor(id: 'innerConeAngle', label: 'Inner Cone Angle', group: 'Light', editor: PropertyEditorType.float, unit: '°', min: 0.1, max: 90.0, defaultValue: 30.0),
        PropertyDescriptor(id: 'outerConeAngle', label: 'Outer Cone Angle', group: 'Light', editor: PropertyEditorType.float, unit: '°', min: 0.1, max: 90.0, defaultValue: 45.0),
        PropertyDescriptor(id: 'castShadows', label: 'Cast Shadows', group: 'Light', editor: PropertyEditorType.boolean, defaultValue: false),
      ],
    ),
    'LuminaLightComponent': ComponentDescriptor(
      type: 'LuminaLightComponent',
      sections: ['Light'],
      properties: [
        PropertyDescriptor(id: 'lightIntensity', label: 'Intensity', group: 'Light', editor: PropertyEditorType.float, defaultValue: 100000.0),
        PropertyDescriptor(id: 'lightColorHex', label: 'Light Color', group: 'Light', editor: PropertyEditorType.color, defaultValue: '#FFFFFF'),
        PropertyDescriptor(id: 'castShadows', label: 'Cast Shadows', group: 'Light', editor: PropertyEditorType.boolean, defaultValue: true),
      ]
    ),
    // The placeable environment actors' fields, limited to what Filament
    // does: one global fog per view; one
    // post-process state per view (a volume blends by camera position); no
    // volumetric scattering (a local fog volume is a shell approximation).
    'LuminaExponentialHeightFogComponent': ComponentDescriptor(
      type: 'LuminaExponentialHeightFogComponent',
      sections: ['Exponential Height Fog'],
      note: 'The actor\'s Z is the fog height. Filament has one global fog per view; this actor overrides the Environment editor\'s Height Fog section.',
      properties: [
        PropertyDescriptor(id: 'enabled', label: 'Enabled', group: 'Exponential Height Fog', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'fogDensity', label: 'Fog Density', group: 'Exponential Height Fog', editor: PropertyEditorType.float, unit: '/m', min: 0.0, max: 1.0, defaultValue: 0.02),
        PropertyDescriptor(id: 'fogHeightFalloff', label: 'Fog Height Falloff', group: 'Exponential Height Fog', editor: PropertyEditorType.float, unit: '/m', min: 0.0, max: 5.0, defaultValue: 0.2),
        PropertyDescriptor(id: 'startDistance', label: 'Start Distance', group: 'Exponential Height Fog', editor: PropertyEditorType.float, unit: 'cm', min: 0.0, max: 100000.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'fogCutoffDistance', label: 'Fog Cutoff Distance', group: 'Exponential Height Fog', editor: PropertyEditorType.float, unit: 'cm', min: 0.0, max: 1000000.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'fogMaxOpacity', label: 'Fog Max Opacity', group: 'Exponential Height Fog', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'inscatteringColorHex', label: 'Fog Inscattering Color', group: 'Exponential Height Fog', editor: PropertyEditorType.color, defaultValue: '#72A3FF'),
        PropertyDescriptor(id: 'useSkyColor', label: 'Use Sky Color', group: 'Exponential Height Fog', editor: PropertyEditorType.boolean, defaultValue: false),
      ],
    ),
    'LuminaPostProcessVolumeComponent': ComponentDescriptor(
      type: 'LuminaPostProcessVolumeComponent',
      sections: ['Volume', 'Post Process Settings'],
      note: 'Blends by camera position — Filament applies one post-process state to the whole view. Tick "Override" to let a setting take effect.',
      properties: [
        PropertyDescriptor(id: 'extentX', label: 'Extent X', group: 'Volume', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 100000.0, defaultValue: 400.0),
        PropertyDescriptor(id: 'extentY', label: 'Extent Y', group: 'Volume', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 100000.0, defaultValue: 400.0),
        PropertyDescriptor(id: 'extentZ', label: 'Extent Z', group: 'Volume', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 100000.0, defaultValue: 400.0),
        PropertyDescriptor(id: 'unbound', label: 'Infinite Extent (Unbound)', group: 'Volume', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'enabled', label: 'Enabled', group: 'Volume', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'priority', label: 'Priority', group: 'Volume', editor: PropertyEditorType.float, min: -100.0, max: 100.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'blendRadius', label: 'Blend Radius', group: 'Volume', editor: PropertyEditorType.float, unit: 'cm', min: 0.0, max: 100000.0, defaultValue: 100.0),
        PropertyDescriptor(id: 'blendWeight', label: 'Blend Weight', group: 'Volume', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'overrideBloomIntensity', label: 'Override: Bloom Intensity', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'bloomIntensity', label: 'Bloom Intensity', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.0, max: 8.0, defaultValue: 0.675),
        PropertyDescriptor(id: 'overrideBloomThreshold', label: 'Override: Bloom Threshold', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'bloomThreshold', label: 'Bloom Threshold', group: 'Post Process Settings', editor: PropertyEditorType.float, unit: 'lux', min: 0.0, max: 100000.0, defaultValue: 1000.0),
        PropertyDescriptor(id: 'overrideVignette', label: 'Override: Vignette', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'vignette', label: 'Vignette', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'overrideDepthOfFieldEnabled', label: 'Override: Depth of Field', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'depthOfFieldEnabled', label: 'Depth of Field', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'overrideDofFocusDistance', label: 'Override: Focus Distance', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'dofFocusDistance', label: 'Focus Distance', group: 'Post Process Settings', editor: PropertyEditorType.float, unit: 'cm', min: 1.0, max: 100000.0, defaultValue: 1000.0),
        PropertyDescriptor(id: 'overrideDofAperture', label: 'Override: Aperture', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'dofAperture', label: 'Aperture', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.0, max: 2.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'overrideAmbientOcclusionEnabled', label: 'Override: Ambient Occlusion', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'ambientOcclusionEnabled', label: 'Ambient Occlusion', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: true),
        PropertyDescriptor(id: 'overrideAmbientOcclusionIntensity', label: 'Override: AO Intensity', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'ambientOcclusionIntensity', label: 'AO Intensity', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.0, max: 4.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'overrideExposure', label: 'Override: Exposure', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'exposure', label: 'Exposure', group: 'Post Process Settings', editor: PropertyEditorType.float, unit: 'EV', min: -5.0, max: 5.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'overrideContrast', label: 'Override: Contrast', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'contrast', label: 'Contrast', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.5, max: 2.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'overrideSaturation', label: 'Override: Saturation', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'saturation', label: 'Saturation', group: 'Post Process Settings', editor: PropertyEditorType.float, min: 0.0, max: 2.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'overrideTemperature', label: 'Override: Temperature', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'temperature', label: 'Temperature', group: 'Post Process Settings', editor: PropertyEditorType.float, unit: 'cool ↔ warm', min: -1.0, max: 1.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'overrideTaaEnabled', label: 'Override: TAA', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'taaEnabled', label: 'TAA', group: 'Post Process Settings', editor: PropertyEditorType.boolean, defaultValue: false),
      ],
    ),
    'LuminaLocalFogVolumeComponent': ComponentDescriptor(
      type: 'LuminaLocalFogVolumeComponent',
      sections: ['Local Fog Volume'],
      note: 'Approximation: a translucent fog shell tints the interior and thickens the global fog while the camera is inside. Filament has no volumetric scattering.',
      properties: [
        PropertyDescriptor(id: 'shape', label: 'Shape', group: 'Local Fog Volume', editor: PropertyEditorType.dropdown, defaultValue: 'sphere', enumValues: ['sphere', 'box']),
        PropertyDescriptor(id: 'radius', label: 'Radius', group: 'Local Fog Volume', editor: PropertyEditorType.float, unit: 'cm', min: 10.0, max: 10000.0, defaultValue: 500.0),
        PropertyDescriptor(id: 'extentX', label: 'Extent X', group: 'Local Fog Volume', editor: PropertyEditorType.float, unit: 'cm', min: 10.0, max: 10000.0, defaultValue: 500.0),
        PropertyDescriptor(id: 'extentY', label: 'Extent Y', group: 'Local Fog Volume', editor: PropertyEditorType.float, unit: 'cm', min: 10.0, max: 10000.0, defaultValue: 500.0),
        PropertyDescriptor(id: 'extentZ', label: 'Extent Z', group: 'Local Fog Volume', editor: PropertyEditorType.float, unit: 'cm', min: 10.0, max: 10000.0, defaultValue: 500.0),
        PropertyDescriptor(id: 'fogAlbedoHex', label: 'Fog Albedo', group: 'Local Fog Volume', editor: PropertyEditorType.color, defaultValue: '#CCD9E6'),
        PropertyDescriptor(id: 'fogDensity', label: 'Fog Density', group: 'Local Fog Volume', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.35),
        PropertyDescriptor(id: 'heightFalloff', label: 'Height Falloff', group: 'Local Fog Volume', editor: PropertyEditorType.float, unit: '/m', min: 0.0, max: 5.0, defaultValue: 0.5),
        PropertyDescriptor(id: 'radialAttenuation', label: 'Radial Attenuation', group: 'Local Fog Volume', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.7),
        PropertyDescriptor(id: 'enabled', label: 'Enabled', group: 'Local Fog Volume', editor: PropertyEditorType.boolean, defaultValue: true),
      ],
    ),
    // The Procedural Sky & Ocean. Defaults mirror
    // LuminaProceduralSkyDescription.defaults exactly — the catalog seeds the
    // same values onto a freshly placed actor, and the code generator falls
    // back to the same ones, so the three cannot drift.
    'LuminaProceduralSkyComponent': ComponentDescriptor(
      type: 'LuminaProceduralSkyComponent',
      sections: ['Time of Day', 'Atmosphere', 'Clouds', 'Ocean'],
      properties: [
        PropertyDescriptor(id: 'timeOfDay', label: 'Time of Day', group: 'Time of Day', editor: PropertyEditorType.float, unit: 'h', min: 0.0, max: 24.0, defaultValue: 12.0),
        PropertyDescriptor(id: 'dayCycleSpeed', label: 'Day Cycle Speed', group: 'Time of Day', editor: PropertyEditorType.float, unit: 'h/s', min: 0.0, max: 24.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'turbidity', label: 'Turbidity', group: 'Atmosphere', editor: PropertyEditorType.float, min: 1.0, max: 10.0, defaultValue: 2.0),
        PropertyDescriptor(id: 'rayleigh', label: 'Rayleigh Scattering', group: 'Atmosphere', editor: PropertyEditorType.float, min: 0.1, max: 5.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'mieCoefficient', label: 'Mie Coefficient', group: 'Atmosphere', editor: PropertyEditorType.float, min: 0.0, max: 5.0, defaultValue: 1.0),
        PropertyDescriptor(id: 'mieG', label: 'Mie Directionality', group: 'Atmosphere', editor: PropertyEditorType.float, min: 0.0, max: 0.99, defaultValue: 0.8),
        PropertyDescriptor(id: 'cloudCoverage', label: 'Cloud Coverage', group: 'Clouds', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.4),
        PropertyDescriptor(id: 'cloudDensity', label: 'Cloud Density', group: 'Clouds', editor: PropertyEditorType.float, min: 0.0, max: 1.0, defaultValue: 0.15),
        PropertyDescriptor(id: 'waterStrength', label: 'Wave Strength', group: 'Ocean', editor: PropertyEditorType.float, min: 0.0, max: 100.0, defaultValue: 30.0),
        PropertyDescriptor(id: 'waterSpeed', label: 'Wave Speed', group: 'Ocean', editor: PropertyEditorType.float, min: 0.0, max: 5.0, defaultValue: 1.0),
      ],
    ),
    'LuminaSkyComponent': ComponentDescriptor(
      type: 'LuminaSkyComponent',
      sections: ['Sky Background', 'Image-Based Lighting'],
      properties: [
        PropertyDescriptor(id: 'mode', label: 'Mode', group: 'Sky Background', editor: PropertyEditorType.dropdown, defaultValue: 'color', enumValues: ['color', 'environment']),
        PropertyDescriptor(id: 'colorHex', label: 'Sky Color', group: 'Sky Background', editor: PropertyEditorType.color, defaultValue: '#5C7FB8'),
        PropertyDescriptor(id: 'skyIntensity', label: 'Sky Intensity', group: 'Sky Background', editor: PropertyEditorType.float, unit: 'lux', min: 0.0, max: 200000.0, defaultValue: 30000.0),
        PropertyDescriptor(id: 'rotationDegrees', label: 'Rotation', group: 'Sky Background', editor: PropertyEditorType.float, unit: '°', min: 0.0, max: 360.0, defaultValue: 0.0),
        PropertyDescriptor(id: 'showSun', label: 'Render Sun Disc', group: 'Sky Background', editor: PropertyEditorType.boolean, defaultValue: false),
        PropertyDescriptor(id: 'iblIntensity', label: 'Ambient (IBL) Intensity', group: 'Image-Based Lighting', editor: PropertyEditorType.float, unit: 'lux', min: 0.0, max: 200000.0, defaultValue: 30000.0),
        PropertyDescriptor(id: 'environmentAssetPath', label: 'Environment HDRI (.ktx)', group: 'Image-Based Lighting', editor: PropertyEditorType.assetRef, type: 'Texture'),
      ],
    ),
  };
}
