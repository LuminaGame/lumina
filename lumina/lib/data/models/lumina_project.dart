import 'project_web_loading_style.dart';
export 'project_web_loading_style.dart';

class ScalabilityCategory {
  final String viewDistance;
  final String shadowQuality;
  final String antiAliasing;
  final String postProcessing;
  final String textureQuality;
  final String shadingQuality;

  const ScalabilityCategory({
    this.viewDistance = 'epic',
    this.shadowQuality = 'high',
    this.antiAliasing = 'fxaa',
    this.postProcessing = 'epic',
    this.textureQuality = 'high',
    this.shadingQuality = 'epic',
  });



  Map<String, dynamic> toMap() {

    return {
      'view_distance': viewDistance,
      'shadow_quality': shadowQuality,
      'anti_aliasing': antiAliasing,
      'post_processing': postProcessing,
      'texture_quality': textureQuality,
      'shading_quality': shadingQuality,
    };
  }

  factory ScalabilityCategory.fromMap(Map<String, dynamic> map) {
    return ScalabilityCategory(
      viewDistance: map['view_distance'] as String? ?? 'epic',
      shadowQuality: map['shadow_quality'] as String? ?? 'high',
      antiAliasing: map['anti_aliasing'] as String? ?? 'fxaa',
      postProcessing: map['post_processing'] as String? ?? 'epic',
      textureQuality: map['texture_quality'] as String? ?? 'high',
      shadingQuality: map['shading_quality'] as String? ?? 'epic',
    );
  }
}

typedef ScalabilitySettings = ScalabilityCategory;

/// Quality presets understood by the editor and
/// the per-category tiers each one expands to. Applying a preset in the UI
/// must update every category instantly; Apply commits them to disk/engine.
const List<String> kQualityPresets = ['Low', 'Medium', 'High', 'Epic', 'Cinematic'];

extension ScalabilityPresets on ScalabilityCategory {
  static ScalabilityCategory forPreset(String preset) {
    switch (preset.toLowerCase()) {
      case 'low':
        return const ScalabilityCategory(
          viewDistance: 'low', shadowQuality: 'low', antiAliasing: 'none',
          postProcessing: 'low', textureQuality: 'low', shadingQuality: 'low',
        );
      case 'medium':
        return const ScalabilityCategory(
          viewDistance: 'medium', shadowQuality: 'medium', antiAliasing: 'fxaa',
          postProcessing: 'medium', textureQuality: 'medium', shadingQuality: 'medium',
        );
      case 'high':
        return const ScalabilityCategory(
          viewDistance: 'high', shadowQuality: 'high', antiAliasing: 'fxaa',
          postProcessing: 'high', textureQuality: 'high', shadingQuality: 'high',
        );
      case 'cinematic':
        return const ScalabilityCategory(
          viewDistance: 'cinematic', shadowQuality: 'cinematic', antiAliasing: 'taa',
          postProcessing: 'cinematic', textureQuality: 'cinematic', shadingQuality: 'cinematic',
        );
      case 'epic':
      default:
        return const ScalabilityCategory();
    }
  }
}

/// Value type of an Enhanced-Input style action.
enum ProjectInputValueType { digital, axis1D, axis2D }

class ProjectInputAction {
  final String name;
  final ProjectInputValueType valueType;
  const ProjectInputAction({required this.name, this.valueType = ProjectInputValueType.digital});

  Map<String, dynamic> toMap() => {'name': name, 'value_type': valueType.name};

  factory ProjectInputAction.fromMap(Map<String, dynamic> map) => ProjectInputAction(
        name: map['name'] as String? ?? '',
        valueType: ProjectInputValueType.values.firstWhere(
          (v) => v.name == (map['value_type'] as String? ?? 'digital'),
          orElse: () => ProjectInputValueType.digital,
        ),
      );

  ProjectInputAction copyWith({String? name, ProjectInputValueType? valueType}) =>
      ProjectInputAction(name: name ?? this.name, valueType: valueType ?? this.valueType);
}

/// One key binding inside a mapping context. [keyId] is the stable
/// `LogicalKeyboardKey.keyId` and [keyLabel] its debug/display name; the
/// runtime input task maps `keyId` back to its own key abstraction.
class ProjectInputMapping {
  final String action;
  final int keyId;
  final String keyLabel;
  final double scale;
  /// `X`, `Y` (axis component the key drives) or empty for digital actions.
  final String axis;
  const ProjectInputMapping({
    required this.action,
    required this.keyId,
    required this.keyLabel,
    this.scale = 1.0,
    this.axis = '',
  });

  Map<String, dynamic> toMap() =>
      {'action': action, 'key_id': keyId, 'key': keyLabel, 'scale': scale, 'axis': axis};

  factory ProjectInputMapping.fromMap(Map<String, dynamic> map) => ProjectInputMapping(
        action: map['action'] as String? ?? '',
        keyId: (map['key_id'] as num?)?.toInt() ?? 0,
        keyLabel: map['key'] as String? ?? '',
        scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
        axis: map['axis'] as String? ?? '',
      );

  ProjectInputMapping copyWith({String? action, int? keyId, String? keyLabel, double? scale, String? axis}) =>
      ProjectInputMapping(
        action: action ?? this.action,
        keyId: keyId ?? this.keyId,
        keyLabel: keyLabel ?? this.keyLabel,
        scale: scale ?? this.scale,
        axis: axis ?? this.axis,
      );
}

class ProjectMappingContext {
  final String name;
  final int priority;
  final List<ProjectInputMapping> mappings;
  const ProjectMappingContext({required this.name, this.priority = 0, this.mappings = const []});

  Map<String, dynamic> toMap() =>
      {'name': name, 'priority': priority, 'mappings': mappings.map((m) => m.toMap()).toList()};

  factory ProjectMappingContext.fromMap(Map<String, dynamic> map) => ProjectMappingContext(
        name: map['name'] as String? ?? '',
        priority: (map['priority'] as num?)?.toInt() ?? 0,
        mappings: (map['mappings'] as List? ?? const [])
            .map((m) => ProjectInputMapping.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );

  ProjectMappingContext copyWith({String? name, int? priority, List<ProjectInputMapping>? mappings}) =>
      ProjectMappingContext(
        name: name ?? this.name,
        priority: priority ?? this.priority,
        mappings: mappings ?? this.mappings,
      );
}

class ProjectInputSettings {
  final List<ProjectInputAction> actions;
  final List<ProjectMappingContext> mappingContexts;
  const ProjectInputSettings({this.actions = const [], this.mappingContexts = const []});

  Map<String, dynamic> toMap() => {
        'actions': actions.map((a) => a.toMap()).toList(),
        'mapping_contexts': mappingContexts.map((c) => c.toMap()).toList(),
      };

  factory ProjectInputSettings.fromMap(Map<String, dynamic> map) => ProjectInputSettings(
        actions: (map['actions'] as List? ?? const [])
            .map((a) => ProjectInputAction.fromMap(Map<String, dynamic>.from(a as Map)))
            .toList(),
        mappingContexts: (map['mapping_contexts'] as List? ?? const [])
            .map((c) => ProjectMappingContext.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
      );

  ProjectInputSettings copyWith({List<ProjectInputAction>? actions, List<ProjectMappingContext>? mappingContexts}) =>
      ProjectInputSettings(actions: actions ?? this.actions, mappingContexts: mappingContexts ?? this.mappingContexts);
}

class ProjectMapsAndModes {
  /// `contents/`-relative path of the level the editor opens on startup.
  final String editorStartupMap;
  /// `contents/`-relative path of the level the shipped game starts in.
  final String gameDefaultMap;
  /// The game mode: a Dart class name (built-in `LuminaGameMode` or a class
  /// under `lib/`), or the project-relative `.lmas` path of a GameMode
  /// Blueprint.
  final String defaultGameMode;

  /// The `.lmas` path of a Blueprint pawn class. When set it overrides the
  /// selected game mode's pawn, the way Maps & Modes edits the selected
  /// mode's Default Pawn Class.
  final String defaultPawnClass;

  const ProjectMapsAndModes({
    this.editorStartupMap = '',
    this.gameDefaultMap = '',
    this.defaultGameMode = 'LuminaGameMode',
    this.defaultPawnClass = '',
  });

  /// Whether [defaultGameMode] names a GameMode Blueprint.
  bool get gameModeIsBlueprint => defaultGameMode.endsWith('.lmas');

  Map<String, dynamic> toMap() => {
        'editor_startup_map': editorStartupMap,
        'game_default_map': gameDefaultMap,
        'default_game_mode': defaultGameMode,
        'default_pawn_class': defaultPawnClass,
      };

  factory ProjectMapsAndModes.fromMap(Map<String, dynamic> map) => ProjectMapsAndModes(
        editorStartupMap: map['editor_startup_map'] as String? ?? '',
        gameDefaultMap: map['game_default_map'] as String? ?? '',
        defaultGameMode: map['default_game_mode'] as String? ?? 'LuminaGameMode',
        defaultPawnClass: map['default_pawn_class'] as String? ?? '',
      );

  ProjectMapsAndModes copyWith({
    String? editorStartupMap,
    String? gameDefaultMap,
    String? defaultGameMode,
    String? defaultPawnClass,
  }) =>
      ProjectMapsAndModes(
        editorStartupMap: editorStartupMap ?? this.editorStartupMap,
        gameDefaultMap: gameDefaultMap ?? this.gameDefaultMap,
        defaultGameMode: defaultGameMode ?? this.defaultGameMode,
        defaultPawnClass: defaultPawnClass ?? this.defaultPawnClass,
      );
}

class ProjectPhysicsSettings {
  /// World gravity along Z in cm/s² (default -980).
  final double gravityZ;
  final double fixedTimestep;
  const ProjectPhysicsSettings({this.gravityZ = -980.0, this.fixedTimestep = 1 / 60});

  Map<String, dynamic> toMap() => {'gravity_z': gravityZ, 'fixed_timestep': fixedTimestep};

  factory ProjectPhysicsSettings.fromMap(Map<String, dynamic> map) => ProjectPhysicsSettings(
        gravityZ: (map['gravity_z'] as num?)?.toDouble() ?? -980.0,
        fixedTimestep: (map['fixed_timestep'] as num?)?.toDouble() ?? 1 / 60,
      );

  ProjectPhysicsSettings copyWith({double? gravityZ, double? fixedTimestep}) =>
      ProjectPhysicsSettings(gravityZ: gravityZ ?? this.gravityZ, fixedTimestep: fixedTimestep ?? this.fixedTimestep);
}

/// World units and up axis of a project's stored transforms.
const String kWorldUnitsCentimetres = 'cm';
const String kWorldUnitsMetres = 'm';
const String kUpAxisZ = 'z';
const String kUpAxisY = 'y';

/// The UMG widget library a project's generated widgets use.
const String kUmgWidgetLibraryShadcn = 'shadcn';
const String kUmgWidgetLibraryFlutter = 'flutter';
const List<String> kUmgWidgetLibraries = [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter];

/// The shadcn_flutter version a game depends on when its widgets use it:
/// exactly the editor's, whose API the UMG codegen emits.
const String kGameShadcnFlutterVersion = '0.0.55';

/// `ui` section: how the project's UMG widgets are generated.
class ProjectUiSettings {
  /// [kUmgWidgetLibraryShadcn] (the game depends on shadcn_flutter) or
  /// [kUmgWidgetLibraryFlutter] (plain Flutter widgets plus the runtime's
  /// `LuminaUmg*` set, no extra dependency).
  final String widgetLibrary;
  const ProjectUiSettings({this.widgetLibrary = kUmgWidgetLibraryShadcn});

  Map<String, dynamic> toMap() => {'widget_library': widgetLibrary};

  /// Manifests written before the setting existed read [kUmgWidgetLibraryShadcn],
  /// which is what the codegen emitted then.
  factory ProjectUiSettings.fromMap(Map<String, dynamic> map) {
    final library = map['widget_library'];
    return ProjectUiSettings(widgetLibrary: kUmgWidgetLibraries.contains(library) ? library as String : kUmgWidgetLibraryShadcn);
  }

  ProjectUiSettings copyWith({String? widgetLibrary}) => ProjectUiSettings(widgetLibrary: widgetLibrary ?? this.widgetLibrary);
}

/// Platforms a project can be packaged for, in display order.
const List<String> kPackagingPlatforms = ['linux', 'windows', 'macos', 'android', 'ios', 'web'];

/// The name a platform id is shown under.
String packagingPlatformLabel(String id) => switch (id) {
      'linux' => 'Linux',
      'windows' => 'Windows',
      'macos' => 'macOS',
      'android' => 'Android',
      'ios' => 'iOS',
      'web' => 'Web',
      _ => id,
    };

/// The `flutter build` subcommand that packages [id] (`android` builds an APK).
String flutterBuildSubcommand(String id) => id == 'android' ? 'apk' : id;

/// The single `target_os` labels manifests stored before multi-target packaging, and
/// the platform each one migrates to.
const Map<String, String> kLegacyPackagingTargetLabels = {
  'Linux x64': 'linux',
  'Windows x64': 'windows',
  'Android APK': 'android',
};

/// The legacy single-target label → `flutter build` subcommand map.
@Deprecated('Use kPackagingPlatforms with flutterBuildSubcommand')
const Map<String, String> kPackagingTargets = {
  'Linux x64': 'linux',
  'Windows x64': 'windows',
  'Android APK': 'apk',
};

/// `packaging` section: the platforms Package Project builds, and where the
/// packages go.
class ProjectPackagingSettings {
  /// Platform ids ([kPackagingPlatforms] order, no duplicates). Ids this
  /// editor does not know are kept, so validation can name them.
  final List<String> targets;

  /// Relative to the project, or absolute.
  final String outputDir;

  /// The web build's HTML loading screen.
  final ProjectWebLoadingStyle webLoadingStyle;

  const ProjectPackagingSettings({
    this.targets = const ['linux'],
    this.outputDir = 'build',
    this.webLoadingStyle = const ProjectWebLoadingStyle(),
  });

  /// [ids] in [kPackagingPlatforms] order, unknown ids last, no duplicates.
  static List<String> ordered(Iterable<String> ids) {
    final unique = <String>{...ids};
    return [
      for (final p in kPackagingPlatforms)
        if (unique.contains(p)) p,
      for (final id in unique)
        if (!kPackagingPlatforms.contains(id)) id,
    ];
  }

  bool isSelected(String id) => targets.contains(id);

  /// The selection with [id] ticked or unticked.
  ProjectPackagingSettings withTarget(String id, bool selected) => copyWith(
        targets: ordered(selected ? [...targets, id] : targets.where((t) => t != id)),
      );

  /// [outputDir] resolved against [projectDir] (empty means `build`).
  String outputDirIn(String projectDir) {
    String trim(String p) => p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final out = outputDir.trim().isEmpty ? 'build' : trim(outputDir.trim());
    return out.startsWith('/') ? out : '${trim(projectDir)}/$out';
  }

  /// Where [id]'s package is copied: `<output dir>/package/<id>`. Not
  /// `<output dir>/<id>`: with the default `build`, `build/linux` and
  /// `build/web` are Flutter's own build trees.
  String packageDirFor(String projectDir, String id) => '${outputDirIn(projectDir)}/package/$id';

  /// The legacy single-target label of the first target, for code that still
  /// reads the single-target field.
  @Deprecated('Use targets')
  String get targetOs {
    if (targets.isEmpty) return '';
    final first = targets.first;
    return kLegacyPackagingTargetLabels.entries.firstWhere((e) => e.value == first, orElse: () => MapEntry(first, first)).key;
  }

  Map<String, dynamic> toMap() => {'targets': targets, 'output_dir': outputDir, 'web_loading_style': webLoadingStyle.toMap()};

  /// A manifest with `targets` reads it; one written before multi-target
  /// packaging migrates its `target_os` label; one with neither reads `['linux']`.
  factory ProjectPackagingSettings.fromMap(Map<String, dynamic> map) {
    final raw = map['targets'];
    final legacy = map['target_os'];
    final List<String> targets;
    if (raw is List) {
      targets = ordered(raw.whereType<String>());
    } else if (legacy is String && legacy.isNotEmpty) {
      targets = [kLegacyPackagingTargetLabels[legacy] ?? legacy];
    } else {
      targets = const ['linux'];
    }
    final style = map['web_loading_style'];
    return ProjectPackagingSettings(
      targets: targets,
      outputDir: map['output_dir'] as String? ?? 'build',
      webLoadingStyle: style is Map ? ProjectWebLoadingStyle.fromMap(Map<String, dynamic>.from(style)) : const ProjectWebLoadingStyle(),
    );
  }

  ProjectPackagingSettings copyWith({
    List<String>? targets,
    String? outputDir,
    ProjectWebLoadingStyle? webLoadingStyle,
    @Deprecated('Use targets') String? targetOs,
  }) =>
      ProjectPackagingSettings(
        targets: targets ?? (targetOs != null ? [kLegacyPackagingTargetLabels[targetOs] ?? targetOs] : this.targets),
        outputDir: outputDir ?? this.outputDir,
        webLoadingStyle: webLoadingStyle ?? this.webLoadingStyle,
      );
}

/// `branding` section: the project's app icon.
class ProjectBrandingSettings {
  /// Project-relative path of the icon (SVG, PNG, JPG or WebP); empty means
  /// the Lumina logo.
  final String icon;

  /// `#RRGGBB` behind the icon where a platform needs an opaque one
  /// (Android adaptive, iOS, web maskable).
  final String iconBackground;

  const ProjectBrandingSettings({this.icon = '', this.iconBackground = '#000000'});

  bool get usesDefaultIcon => icon.trim().isEmpty;

  /// [iconBackground] as opaque ARGB, or null when it is not `#RRGGBB`.
  int? get iconBackgroundArgb => parseHexColor(iconBackground);

  static int? parseHexColor(String value) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
    return m == null ? null : 0xFF000000 | int.parse(m.group(1)!, radix: 16);
  }

  Map<String, dynamic> toMap() => {'icon': icon, 'icon_background': iconBackground};

  factory ProjectBrandingSettings.fromMap(Map<String, dynamic> map) => ProjectBrandingSettings(
        icon: map['icon'] as String? ?? '',
        iconBackground: map['icon_background'] as String? ?? '#000000',
      );

  ProjectBrandingSettings copyWith({String? icon, String? iconBackground}) =>
      ProjectBrandingSettings(icon: icon ?? this.icon, iconBackground: iconBackground ?? this.iconBackground);
}

class EditorSnapSettings {
  final bool translateSnapEnabled;
  final bool rotateSnapEnabled;
  final bool scaleSnapEnabled;
  final bool surfaceSnapEnabled;
  final bool gridVisible;
  final double translateSnapStep;
  final double rotateSnapStep;
  final double scaleSnapStep;
  final double gridStep;
  final double gridExtent;

  const EditorSnapSettings({
    this.translateSnapEnabled = true,
    this.rotateSnapEnabled = true,
    this.scaleSnapEnabled = true,
    this.surfaceSnapEnabled = false,
    this.gridVisible = true,
    this.translateSnapStep = 10.0,
    this.rotateSnapStep = 10.0,
    this.scaleSnapStep = 0.25,
    this.gridStep = 100.0, // cm: 1 m squares
    // cm: ±20 m. The grid has no distance fade, so a wider default turns
    // the far lines into a white haze over the horizon.
    this.gridExtent = 2000.0,
  });

  EditorSnapSettings copyWith({
    bool? translateSnapEnabled,
    bool? rotateSnapEnabled,
    bool? scaleSnapEnabled,
    bool? surfaceSnapEnabled,
    bool? gridVisible,
    double? translateSnapStep,
    double? rotateSnapStep,
    double? scaleSnapStep,
    double? gridStep,
    double? gridExtent,
  }) {
    return EditorSnapSettings(
      translateSnapEnabled: translateSnapEnabled ?? this.translateSnapEnabled,
      rotateSnapEnabled: rotateSnapEnabled ?? this.rotateSnapEnabled,
      scaleSnapEnabled: scaleSnapEnabled ?? this.scaleSnapEnabled,
      surfaceSnapEnabled: surfaceSnapEnabled ?? this.surfaceSnapEnabled,
      gridVisible: gridVisible ?? this.gridVisible,
      translateSnapStep: translateSnapStep ?? this.translateSnapStep,
      rotateSnapStep: rotateSnapStep ?? this.rotateSnapStep,
      scaleSnapStep: scaleSnapStep ?? this.scaleSnapStep,
      gridStep: gridStep ?? this.gridStep,
      gridExtent: gridExtent ?? this.gridExtent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'translate_snap_enabled': translateSnapEnabled,
      'rotate_snap_enabled': rotateSnapEnabled,
      'scale_snap_enabled': scaleSnapEnabled,
      'surface_snap_enabled': surfaceSnapEnabled,
      'grid_visible': gridVisible,
      'translate_snap_step': translateSnapStep,
      'rotate_snap_step': rotateSnapStep,
      'scale_snap_step': scaleSnapStep,
      'grid_step': gridStep,
      'grid_extent': gridExtent,
    };
  }

  factory EditorSnapSettings.fromMap(Map<String, dynamic> map) {
    return EditorSnapSettings(
      translateSnapEnabled: map['translate_snap_enabled'] as bool? ?? true,
      rotateSnapEnabled: map['rotate_snap_enabled'] as bool? ?? true,
      scaleSnapEnabled: map['scale_snap_enabled'] as bool? ?? true,
      surfaceSnapEnabled: map['surface_snap_enabled'] as bool? ?? false,
      gridVisible: map['grid_visible'] as bool? ?? true,
      translateSnapStep: (map['translate_snap_step'] as num?)?.toDouble() ?? 10.0,
      rotateSnapStep: (map['rotate_snap_step'] as num?)?.toDouble() ?? 10.0,
      scaleSnapStep: (map['scale_snap_step'] as num?)?.toDouble() ?? 0.25,
      gridStep: (map['grid_step'] as num?)?.toDouble() ?? 100.0,
      gridExtent: (map['grid_extent'] as num?)?.toDouble() ?? 2000.0,
    );
  }
}

class EngineScalabilitySettings {
  final int targetFps;
  final bool vsyncEnabled;
  final String qualityPreset;
  final ScalabilityCategory scalability;
  final bool autoOrganizeFiles;
  final int autoSaveIntervalSeconds;

  const EngineScalabilitySettings({
    // Unlimited frame rate and VSync off by default.
    this.targetFps = 0,
    this.vsyncEnabled = false,
    this.qualityPreset = 'epic',
    this.scalability = const ScalabilityCategory(),
    this.autoOrganizeFiles = true,
    this.autoSaveIntervalSeconds = 60,
  });

  Map<String, dynamic> toMap() {
    return {
      'target_fps': targetFps,
      'vsync_enabled': vsyncEnabled,
      'quality_preset': qualityPreset,
      'scalability': scalability.toMap(),
      'auto_organize_files': autoOrganizeFiles,
      'auto_save_interval_seconds': autoSaveIntervalSeconds,
    };
  }

  factory EngineScalabilitySettings.fromMap(Map<String, dynamic> map) {
    return EngineScalabilitySettings(
      targetFps: map['target_fps'] as int? ?? 0,
      vsyncEnabled: map['vsync_enabled'] as bool? ?? false,
      qualityPreset: map['quality_preset'] as String? ?? 'epic',
      scalability: map['scalability'] != null
          ? ScalabilityCategory.fromMap(map['scalability'] as Map<String, dynamic>)
          : const ScalabilityCategory(),
      autoOrganizeFiles: map['auto_organize_files'] as bool? ?? true,
      autoSaveIntervalSeconds: map['auto_save_interval_seconds'] as int? ?? 60,
    );
  }
}

const String kLuminaEngineVersion = '0.0.1';
/// The version the editor shows when it is not a release build.
const String kLuminaEngineDisplayVersion = 'v0.0.1-dev';

class EditorViewportSettings {
  final String cameraMode;
  final String viewMode;
  final String bufferVisualization;
  final Map<String, bool> showFlags;

  const EditorViewportSettings({
    this.cameraMode = 'Perspective',
    this.viewMode = 'Lit',
    this.bufferVisualization = 'None',
    this.showFlags = const {
      'Grid': true,
      'Transform Gizmo': true,
      'Selection Bounds': true,
      'Collision': false,
      'Actor Icons & Labels': true,
      'Ground Drop Shadows': true,
    },
  });

  EditorViewportSettings copyWith({
    String? cameraMode,
    String? viewMode,
    String? bufferVisualization,
    Map<String, bool>? showFlags,
  }) {
    return EditorViewportSettings(
      cameraMode: cameraMode ?? this.cameraMode,
      viewMode: viewMode ?? this.viewMode,
      bufferVisualization: bufferVisualization ?? this.bufferVisualization,
      showFlags: showFlags ?? this.showFlags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'camera_mode': cameraMode,
      'view_mode': viewMode,
      'buffer_visualization': bufferVisualization,
      'show_flags': showFlags,
    };
  }

  factory EditorViewportSettings.fromMap(Map<String, dynamic> map) {
    return EditorViewportSettings(
      cameraMode: map['camera_mode'] as String? ?? 'Perspective',
      viewMode: map['view_mode'] as String? ?? 'Lit',
      bufferVisualization: map['buffer_visualization'] as String? ?? 'None',
      showFlags: map['show_flags'] != null
          ? Map<String, bool>.from(map['show_flags'] as Map)
          : const {
              'Grid': true,
              'Transform Gizmo': true,
              'Selection Bounds': true,
              'Collision': false,
              'Actor Icons & Labels': true,
              'Ground Drop Shadows': true,
            },
    );
  }
}

class LuminaProject {
  final String projectName;
  final String engineVersion;
  final String activeLevel;
  final bool isDirty;
  final String lastModifiedTimestamp;
  final String lastCodeGeneratedTimestamp;
  final EngineScalabilitySettings settings;
  final EditorSnapSettings editorSnap;
  final EditorViewportSettings editorViewport;
  final List<String>? enabledPlugins;
  final String description;

  /// Id of the game template the project was scaffolded from
  /// (`blank_3d` | `first_person` | `third_person`, see
  /// `data/services/game_template_service.dart`). Manifests written before
  /// templates existed default to `blank_3d`.
  final String template;
  final ProjectInputSettings input;
  final ProjectMapsAndModes mapsAndModes;
  final ProjectPhysicsSettings physics;
  final ProjectPackagingSettings packaging;

  /// UMG widget generation.
  final ProjectUiSettings ui;

  /// The app icon every packaged target uses.
  final ProjectBrandingSettings branding;

  /// World units the project was authored in: `cm` since Lumina
  /// switched to centimetres. Manifests written before that have
  /// no `world_units` and read `m`; they are not migrated.
  final String worldUnits;

  /// The up axis of stored transforms: `z` (legacy manifests: `y`).
  final String upAxis;

  /// Per-plugin project settings: `plugin_settings.<plugin>.<key>`,
  /// edited in Project Settings ▸ Plugins. Never holds secrets.
  final Map<String, Map<String, Object?>> pluginSettings;

  /// Top-level manifest keys this version does not know (a newer engine's,
  /// a tool's): written back unchanged so a save never drops them.
  final Map<String, Object?> extraFields;

  /// Whether the project predates centimetre, Z-up authoring.
  bool get isLegacyMetreProject => worldUnits != kWorldUnitsCentimetres;

  const LuminaProject({
    required this.projectName,
    this.engineVersion = '0.0.1',
    this.activeLevel = 'contents/levels/L_DefaultLevel.lmas',
    this.isDirty = false,
    this.lastModifiedTimestamp = '',
    this.lastCodeGeneratedTimestamp = '',
    this.settings = const EngineScalabilitySettings(),
    this.editorSnap = const EditorSnapSettings(),
    this.editorViewport = const EditorViewportSettings(),
    this.enabledPlugins,
    this.description = '',
    this.template = 'blank_3d',
    this.input = const ProjectInputSettings(),
    this.mapsAndModes = const ProjectMapsAndModes(),
    this.physics = const ProjectPhysicsSettings(),
    this.packaging = const ProjectPackagingSettings(),
    this.ui = const ProjectUiSettings(),
    this.branding = const ProjectBrandingSettings(),
    this.worldUnits = kWorldUnitsCentimetres,
    this.upAxis = kUpAxisZ,
    this.pluginSettings = const {},
    this.extraFields = const {},
  });

  LuminaProject copyWith({
    String? projectName,
    String? engineVersion,
    String? activeLevel,
    bool? isDirty,
    String? lastModifiedTimestamp,
    String? lastCodeGeneratedTimestamp,
    EngineScalabilitySettings? settings,
    EditorSnapSettings? editorSnap,
    EditorViewportSettings? editorViewport,
    List<String>? enabledPlugins,
    String? description,
    String? template,
    ProjectInputSettings? input,
    ProjectMapsAndModes? mapsAndModes,
    ProjectPhysicsSettings? physics,
    ProjectPackagingSettings? packaging,
    ProjectUiSettings? ui,
    ProjectBrandingSettings? branding,
    String? worldUnits,
    String? upAxis,
    Map<String, Map<String, Object?>>? pluginSettings,
  }) {
    return LuminaProject(
      projectName: projectName ?? this.projectName,
      engineVersion: engineVersion ?? this.engineVersion,
      activeLevel: activeLevel ?? this.activeLevel,
      isDirty: isDirty ?? this.isDirty,
      lastModifiedTimestamp: lastModifiedTimestamp ?? this.lastModifiedTimestamp,
      lastCodeGeneratedTimestamp:
          lastCodeGeneratedTimestamp ?? this.lastCodeGeneratedTimestamp,
      settings: settings ?? this.settings,
      editorSnap: editorSnap ?? this.editorSnap,
      editorViewport: editorViewport ?? this.editorViewport,
      enabledPlugins: enabledPlugins ?? this.enabledPlugins,
      description: description ?? this.description,
      template: template ?? this.template,
      input: input ?? this.input,
      mapsAndModes: mapsAndModes ?? this.mapsAndModes,
      physics: physics ?? this.physics,
      packaging: packaging ?? this.packaging,
      ui: ui ?? this.ui,
      branding: branding ?? this.branding,
      worldUnits: worldUnits ?? this.worldUnits,
      upAxis: upAxis ?? this.upAxis,
      pluginSettings: pluginSettings ?? this.pluginSettings,
      extraFields: extraFields,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Unknown keys first: the known ones below always win.
      ...extraFields,
      'project_name': projectName,
      'engine_version': engineVersion,
      'active_level': activeLevel,
      'is_dirty': isDirty,
      'last_modified_timestamp': lastModifiedTimestamp,
      'last_code_generated_timestamp': lastCodeGeneratedTimestamp,
      'settings': settings.toMap(),
      'editor_snap': editorSnap.toMap(),
      'editor_viewport': editorViewport.toMap(),
      if (enabledPlugins != null) 'enabled_plugins': enabledPlugins,
      'description': description,
      'template': template,
      'input': input.toMap(),
      'maps_and_modes': mapsAndModes.toMap(),
      'physics': physics.toMap(),
      'packaging': packaging.toMap(),
      'ui': ui.toMap(),
      'branding': branding.toMap(),
      'world_units': worldUnits,
      'up_axis': upAxis,
      if (pluginSettings.isNotEmpty)
        'plugin_settings': {for (final e in pluginSettings.entries) e.key: Map<String, Object?>.from(e.value)},
    };
  }

  /// The top-level keys [toMap] writes (plus `plugin_settings`); anything
  /// else read from a manifest is kept in [extraFields].
  static const Set<String> knownKeys = {
    'project_name', 'engine_version', 'active_level', 'is_dirty', 'last_modified_timestamp',
    'last_code_generated_timestamp', 'settings', 'editor_snap', 'editor_viewport', 'enabled_plugins',
    'description', 'template', 'input', 'maps_and_modes', 'physics', 'packaging', 'ui', 'branding',
    'world_units', 'up_axis', 'plugin_settings',
  };

  factory LuminaProject.fromMap(Map<String, dynamic> map) {
    final plugins = map['plugin_settings'];
    return LuminaProject(
      pluginSettings: plugins is Map
          ? {
              for (final e in plugins.entries)
                if (e.value is Map) '${e.key}': Map<String, Object?>.from(e.value as Map),
            }
          : const {},
      extraFields: {
        for (final e in map.entries)
          if (!knownKeys.contains(e.key)) e.key: e.value,
      },
      projectName: map['project_name'] as String? ?? '',
      engineVersion: map['engine_version'] as String? ?? '0.0.1',
      activeLevel: map['active_level'] as String? ?? '',
      isDirty: map['is_dirty'] as bool? ?? false,
      lastModifiedTimestamp: map['last_modified_timestamp'] as String? ?? '',
      lastCodeGeneratedTimestamp:
          map['last_code_generated_timestamp'] as String? ?? '',
      settings: map['settings'] != null
          ? EngineScalabilitySettings.fromMap(
              map['settings'] as Map<String, dynamic>)
          : const EngineScalabilitySettings(),
      editorSnap: map['editor_snap'] != null
          ? EditorSnapSettings.fromMap(map['editor_snap'] as Map<String, dynamic>)
          : const EditorSnapSettings(),
      editorViewport: map['editor_viewport'] != null
          ? EditorViewportSettings.fromMap(map['editor_viewport'] as Map<String, dynamic>)
          : const EditorViewportSettings(),
      enabledPlugins: map['enabled_plugins'] != null
          ? List<String>.from(map['enabled_plugins'] as List)
          : null,
      description: map['description'] as String? ?? '',
      template: map['template'] as String? ?? 'blank_3d',
      input: map['input'] is Map
          ? ProjectInputSettings.fromMap(Map<String, dynamic>.from(map['input'] as Map))
          : const ProjectInputSettings(),
      mapsAndModes: map['maps_and_modes'] is Map
          ? ProjectMapsAndModes.fromMap(Map<String, dynamic>.from(map['maps_and_modes'] as Map))
          : const ProjectMapsAndModes(),
      physics: map['physics'] is Map
          ? ProjectPhysicsSettings.fromMap(Map<String, dynamic>.from(map['physics'] as Map))
          : const ProjectPhysicsSettings(),
      packaging: map['packaging'] is Map
          ? ProjectPackagingSettings.fromMap(Map<String, dynamic>.from(map['packaging'] as Map))
          : const ProjectPackagingSettings(),
      ui: map['ui'] is Map ? ProjectUiSettings.fromMap(Map<String, dynamic>.from(map['ui'] as Map)) : const ProjectUiSettings(),
      branding: map['branding'] is Map
          ? ProjectBrandingSettings.fromMap(Map<String, dynamic>.from(map['branding'] as Map))
          : const ProjectBrandingSettings(),
      worldUnits: map['world_units'] as String? ?? kWorldUnitsMetres,
      upAxis: map['up_axis'] as String? ?? kUpAxisY,
    );
  }
}
