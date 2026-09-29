import 'package:lumina/lumina.dart' show LuminaProceduralSkyDescription;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../details/models/editor_component_node.dart';
import '../services/environment_actor_properties.dart';
import '../services/light_actor_properties.dart';
import '../../../core/theme/editor_theme.dart';

/// One actor type the editor can place in a level.
class EditorActorType {
  /// The string stored in `metadata.actors[].type` and switched on by the code
  /// generator, the viewport painter and the PIE mapper.
  final String id;

  /// What the user sees in the spawn menu.
  final String label;

  /// One short line saying what placing it does.
  final String description;

  /// Menu grouping, e.g. `Lights`.
  final String category;

  final IconData icon;
  final Color color;

  /// True when a level may hold at most one (the sky/atmosphere).
  final bool unique;

  /// Default light intensity for light types, 0 for everything else.
  final double lightIntensity;

  /// Components the spawned actor starts with — how a `Primitive` carries its
  /// shape, for instance.
  final List<EditorComponentNode> Function(String actorId)? componentsBuilder;

  const EditorActorType({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    this.unique = false,
    this.lightIntensity = 0,
    this.componentsBuilder,
  });
}

/// The single answer to "what can this editor place in a level".
///
/// The spawn dialog, the outliner's icons and the details panel all read this,
/// so they cannot drift apart the way they did when each kept its own list
/// (the dialog once offered five of ten supported types, so a sky, a spot
/// light and a skeletal mesh could not be placed at all).
class EditorActorCatalog {
  const EditorActorCatalog._();

  static const Color _geometry = EditorColors.accent;
  static const Color _light = EditorColors.warning;
  static const Color _gameplay = EditorColors.chart3;
  static const Color _world = EditorColors.chart4;
  static const Color _visualEffects = EditorColors.chart2;

  static final List<EditorActorType> all = [
    // --- Geometry -----------------------------------------------------------
    EditorActorType(
      id: 'Primitive',
      label: 'Cube',
      description: 'An engine-drawn box. Change its shape and size in Details.',
      category: 'Geometry',
      icon: LucideIcons.box,
      color: _geometry,
      componentsBuilder: (actorId) => [
        EditorComponentNode(
          id: '${actorId}_mesh',
          type: 'LuminaProceduralMeshComponent',
          name: 'Shape',
          properties: <String, dynamic>{
            'shape': 'box',
            'sizeX': 1.0,
            'sizeY': 1.0,
            'sizeZ': 1.0,
            'colorHex': '#9AA3AE',
          },
        ),
      ],
    ),
    const EditorActorType(
      id: 'StaticMesh',
      label: 'Static Mesh',
      description:
          'An imported mesh. Pick the asset in Details or drag one from the Content Browser.',
      category: 'Geometry',
      icon: LucideIcons.box,
      color: _geometry,
    ),
    const EditorActorType(
      id: 'SkeletalMesh',
      label: 'Skeletal Mesh',
      description: 'An imported rigged mesh that can play animations.',
      category: 'Geometry',
      icon: LucideIcons.personStanding,
      color: _geometry,
    ),

    // --- Lights -------------------------------------------------------------
    EditorActorType(
      id: 'DirectionalLight',
      label: 'Directional Light',
      description: 'A sun-like light: direction matters, position does not.',
      category: 'Lights',
      icon: LucideIcons.sun,
      color: _light,
      lightIntensity: 100000,
      componentsBuilder: (actorId) => [
        LightActorProperties.seedComponent(
          actorId,
          'DirectionalLight',
          intensity: 100000,
        ),
      ],
    ),
    EditorActorType(
      id: 'PointLight',
      label: 'Point Light',
      description: 'A light radiating in every direction from its position.',
      category: 'Lights',
      icon: LucideIcons.lightbulb,
      color: _light,
      lightIntensity: 50000,
      componentsBuilder: (actorId) => [
        LightActorProperties.seedComponent(
          actorId,
          'PointLight',
          intensity: 50000,
        ),
      ],
    ),
    EditorActorType(
      id: 'SpotLight',
      label: 'Spot Light',
      description: 'A cone of light pointing along the actor.',
      category: 'Lights',
      icon: LucideIcons.flashlight,
      color: _light,
      lightIntensity: 50000,
      componentsBuilder: (actorId) => [
        LightActorProperties.seedComponent(
          actorId,
          'SpotLight',
          intensity: 50000,
        ),
      ],
    ),

    // --- Gameplay -----------------------------------------------------------
    const EditorActorType(
      id: 'PlayerStart',
      label: 'Player Start',
      description: 'Where the game mode spawns the player pawn.',
      category: 'Gameplay',
      icon: LucideIcons.flag,
      color: _gameplay,
    ),
    const EditorActorType(
      id: 'Pawn',
      label: 'Pawn',
      description:
          'A bare possessable pawn. Templates use a Player Start and a game mode instead.',
      category: 'Gameplay',
      icon: LucideIcons.user,
      color: _gameplay,
    ),
    const EditorActorType(
      id: 'Camera',
      label: 'Camera',
      description: 'A camera actor for cinematics and viewport piloting.',
      category: 'Gameplay',
      icon: LucideIcons.camera,
      color: _gameplay,
    ),

    // --- World --------------------------------------------------------------
    EditorActorType(
      id: 'Environment',
      label: 'Sky & Atmosphere',
      description:
          'The level\'s sky, sun colour and image-based lighting. One per level.',
      category: 'World',
      icon: LucideIcons.cloudSun,
      color: _world,
      unique: true,
      componentsBuilder: (actorId) => [
        EditorComponentNode(
          id: '${actorId}_sky',
          type: 'LuminaSkyComponent',
          name: 'Sky & Atmosphere',
          properties: <String, dynamic>{
            'mode': 'color',
            'colorHex': '#5C7FB8',
            'skyIntensity': 30000.0,
            'iblIntensity': 30000.0,
            'rotationDegrees': 0.0,
            'showSun': false,
          },
        ),
      ],
    ),
    EditorActorType(
      id: 'ProceduralSky',
      label: 'Procedural Sky & Ocean',
      description:
          'An animated atmospheric sky with volumetric clouds, a day/night cycle and an ocean '
          'reflection. Lights nothing on its own — pair it with Sky & Atmosphere.',
      category: 'World',
      icon: LucideIcons.waves,
      color: _world,
      unique: true,
      // Seeded with LuminaProceduralSkyDescription.defaults, so a freshly
      // placed actor already serialises, code-generates and plays.
      componentsBuilder: (actorId) => [
        EditorComponentNode(
          id: '${actorId}_proceduralsky',
          type: 'LuminaProceduralSkyComponent',
          name: 'Procedural Sky',
          properties: LuminaProceduralSkyDescription.defaults.toProperties(),
        ),
      ],
    ),
    EditorActorType(
      id: 'PcgVolume',
      label: 'PCG Volume',
      description:
          'A procedural content generation volume that scatters meshes according to a PCG Graph.',
      category: 'World',
      icon: LucideIcons.boxes,
      color: _world,
      componentsBuilder: (actorId) => [
        EditorComponentNode(
          id: '${actorId}_pcg',
          type: 'LuminaPcgComponent',
          name: 'PCG Component',
          properties: <String, dynamic>{
            'graphPath': '',
            'seed': 1,
            'sizeX': 2000.0,
            'sizeY': 2000.0,
            'sizeZ': 500.0,
            'instanceCount': 0,
          },
        ),
      ],
    ),
    // --- Visual Effects ------------------------------------------------------
    // Filament's limits, stated in the descriptions: one global fog per view,
    // one post-process state per view (volumes blend by camera position),
    // no volumetric scattering (a local fog volume is a shell approximation).
    EditorActorType(
      id: EnvironmentActorProperties.heightFogType,
      label: 'Exponential Height Fog',
      description:
          'Global height-based fog. Its Z is the fog height. One per level; '
          'overrides the Environment editor\'s Height Fog section.',
      category: 'Visual Effects',
      icon: LucideIcons.cloudFog,
      color: _visualEffects,
      unique: true,
      componentsBuilder: (actorId) => [
        EnvironmentActorProperties.seedHeightFog(actorId),
      ],
    ),
    EditorActorType(
      id: EnvironmentActorProperties.postProcessVolumeType,
      label: 'Post Process Volume',
      description:
          'Bloom, vignette, depth of field, ambient occlusion, colour grading and TAA '
          'inside a box (or everywhere when unbound). Blends by camera position: Filament '
          'applies one post-process state to the whole view.',
      category: 'Visual Effects',
      icon: LucideIcons.squareDashed,
      color: _visualEffects,
      componentsBuilder: (actorId) => [
        EnvironmentActorProperties.seedPostProcessVolume(actorId),
      ],
    ),
    EditorActorType(
      id: EnvironmentActorProperties.localFogVolumeType,
      label: 'Local Fog Volume',
      description:
          'A translucent fog shell with a tinted interior that also thickens the global '
          'fog while the camera is inside. Approximation: no volumetric scattering. One per area.',
      category: 'Visual Effects',
      icon: LucideIcons.cloud,
      color: _visualEffects,
      componentsBuilder: (actorId) => [
        EnvironmentActorProperties.seedLocalFogVolume(actorId),
      ],
    ),

    const EditorActorType(
      id: 'NavMeshBoundsVolume',
      label: 'Nav Mesh Bounds',
      description: 'The volume the navigation grid is baked inside.',
      category: 'World',
      icon: LucideIcons.grid3x3,
      color: _world,
    ),
  ];

  /// Categories in menu order.
  static List<String> get categories {
    final seen = <String>[];
    for (final t in all) {
      if (!seen.contains(t.category)) seen.add(t.category);
    }
    return seen;
  }

  static List<EditorActorType> inCategory(String category) =>
      all.where((t) => t.category == category).toList();

  static EditorActorType? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Icon for any type string, including ones no longer in the catalog (old
  /// levels can hold anything).
  static IconData iconFor(String type) {
    final known = byId(type);
    if (known != null) return known.icon;
    if (type == 'Folder') return LucideIcons.folder;
    if (type.contains('Light')) return LucideIcons.sun;
    if (type.contains('Camera')) return LucideIcons.camera;
    if (type.contains('Pawn')) return LucideIcons.user;
    return LucideIcons.box;
  }

  static Color colorFor(String type) {
    final known = byId(type);
    if (known != null) return known.color;
    if (type.contains('Light')) return _light;
    if (type.contains('Camera') || type.contains('Pawn')) return _gameplay;
    return _geometry;
  }
}
