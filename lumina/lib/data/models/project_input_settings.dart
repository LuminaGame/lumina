/// The project's input actions and mapping contexts, and its maps and
/// modes (`.lmproject` `input`, `maps_and_modes`).
library;

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
