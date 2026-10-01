import '../models/lumina_project.dart';
import 'dart_identifiers.dart';

/// Template ids persisted in the `.lmproject` manifest (`template` key).
const String kBlank3dTemplateId = 'blank_3d';
const String kFirstPersonTemplateId = 'first_person';
const String kThirdPersonTemplateId = 'third_person';

/// `LogicalKeyboardKey.keyId` values for the keys the gameplay contexts bind.
/// Project Settings edits these as ordinary [ProjectInputMapping]s, so they are
/// the real ids and not display strings.
const int kKeyIdW = 0x00000077;
const int kKeyIdA = 0x00000061;
const int kKeyIdS = 0x00000073;
const int kKeyIdD = 0x00000064;
const int kKeyIdSpace = 0x00000020;

/// `LogicalKeyboardKey.shiftLeft.keyId` (sprint) and
/// `LogicalKeyboardKey.controlLeft.keyId` (dash).
const int kKeyIdShiftLeft = 0x200000102;
const int kKeyIdControlLeft = 0x200000100;
const int kKeyIdAltLeft = 0x200000104;

/// Mouse axes are not logical keyboard keys; they carry these sentinel ids so
/// a mapping can still round-trip through the manifest and the settings editor.
const int kMouseXAxisKeyId = -1;
const int kMouseYAxisKeyId = -2;

/// The gamepad's right face button (B / Circle) and left thumbstick press are
/// no keyboard keys either; `IA_Dash` / `IA_Sprint` bind them through these
/// sentinels.
const int kGamepadFaceButtonRightKeyId = -3;
const int kGamepadLeftThumbstickKeyId = -4;
const int kGamepadRightThumbstickKeyId = -5;

/// Which runtime pawn shape a template scaffolds.
enum GameTemplateKind {
  /// No generated gameplay source — the classic empty scene.
  blank,

  /// `LuminaCharacter` + camera at `baseEyeHeight`.
  firstPerson,

  /// `LuminaCharacter` + `LuminaSpringArmComponent` boom + camera.
  thirdPerson,
}

/// One entry of the shared template catalog.
///
/// This is the single source of truth both the launcher UI and
/// `ProjectRepository.createProjectStream` read: the chip label and blurb, the
/// actors seeded into `contents/levels/L_DefaultLevel.lmas`, the input actions
/// and mapping context written into the manifest, and whether user-owned
/// character / game-mode source is generated.
class GameTemplate {
  final String id;
  final String title;
  final String description;

  /// Short icon hint the launcher maps to a shadcn icon.
  final String icon;

  final GameTemplateKind kind;

  final List<Map<String, dynamic>> Function() _levelActorsBuilder;
  final ProjectInputSettings Function() _inputBuilder;

  const GameTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.kind,
    required List<Map<String, dynamic>> Function() levelActors,
    required ProjectInputSettings Function() input,
  })  : _levelActorsBuilder = levelActors,
        _inputBuilder = input;

  /// A fresh, independently mutable copy of the seeded actor maps
  /// (`EditorActorNode.toMap()` shape).
  List<Map<String, dynamic>> get levelActors => _levelActorsBuilder();

  /// A fresh copy of the input actions and mapping contexts for the manifest.
  ProjectInputSettings get input => _inputBuilder();

  /// Whether this template writes `lib/pawns/…` and `lib/game/…` source the
  /// user owns.
  bool get generatesGameSource => kind != GameTemplateKind.blank;

  /// Whether a new project gets the animated character
  /// (`LuminaThirdPersonContent`) in its `contents/`.
  bool get shipsMannequin => kind == GameTemplateKind.thirdPerson;

  /// `my_first_game` → `MyFirstGame` ([dartTypeName]).
  static String classPrefix(String projectName) => dartTypeName(projectName, fallback: 'Lumina');

  /// Dart class name of the generated character for [projectName].
  String characterClass(String projectName) => '${classPrefix(projectName)}Character';

  /// Dart class name of the generated game mode, or the engine default for the
  /// blank template. This is what lands in
  /// [ProjectMapsAndModes.defaultGameMode].
  String gameModeClass(String projectName) =>
      generatesGameSource ? '${classPrefix(projectName)}GameMode' : 'LuminaGameMode';

  /// Project-relative path of the generated character file
  /// (`lib/pawns/my_game_character.dart`).
  String characterPath(String projectName) => 'lib/pawns/${dartFileName(characterClass(projectName))}';

  /// Project-relative path of the generated game mode file
  /// (`lib/game/my_game_game_mode.dart`).
  String gameModePath(String projectName) => 'lib/game/${dartFileName(gameModeClass(projectName))}';

  /// Human-readable step lines the creation progress log names for this
  /// template, so the user sees what is actually being written.
  List<String> manifestStepMessages(String projectName) {
    if (!generatesGameSource) {
      return const ['Writing project manifest and default level...'];
    }
    return [
      'Writing project manifest, $title input actions and mapping context...',
      kind == GameTemplateKind.thirdPerson
          ? 'Seeding $title level actors (player start, sun, sky, walled yard with stairs, crates and pillars)...'
          : 'Seeding $title level actors (player start, sun, sky, test room)...',
      kind == GameTemplateKind.thirdPerson
          ? 'Writing and compiling the BP_ThirdPersonCharacter, BP_ThirdPersonGameMode and ABP_Character Blueprints...'
          : 'Generating ${characterClass(projectName)} and ${gameModeClass(projectName)}...',
    ];
  }
}

/// The three templates offered by the launcher.
class GameTemplateCatalog {
  const GameTemplateCatalog._();

  static const GameTemplate blank3d = GameTemplate(
    id: kBlank3dTemplateId,
    title: 'Blank 3D',
    description: 'An empty lit scene: sun, sky and one placeholder mesh. Bring your own gameplay.',
    icon: 'box',
    kind: GameTemplateKind.blank,
    levelActors: _blankLevelActors,
    input: _noInput,
  );

  static const GameTemplate firstPerson = GameTemplate(
    id: kFirstPersonTemplateId,
    title: 'First Person',
    description: 'A walkable test room with an eye-height camera, WASD movement, mouse look and jump.',
    icon: 'eye',
    kind: GameTemplateKind.firstPerson,
    levelActors: _firstPersonLevelActors,
    input: _gameplayInput,
  );

  static const GameTemplate thirdPerson = GameTemplate(
    id: kThirdPersonTemplateId,
    title: 'Third Person',
    description: 'Play as an animated character (idle, 8-way walk and jog, jump) in a walled yard with stairs, crates and pillars to explore.',
    icon: 'user',
    kind: GameTemplateKind.thirdPerson,
    levelActors: _thirdPersonLevelActors,
    input: _gameplayInput,
  );

  static const List<GameTemplate> all = [blank3d, firstPerson, thirdPerson];

  /// Resolves [id] to a template, tolerating the legacy `'Blank 3D'` label and
  /// unknown ids (both fall back to [blank3d]).
  static GameTemplate byId(String? id) {
    if (id == null) return blank3d;
    final normalized = id.trim().toLowerCase().replaceAll(' ', '_');
    for (final t in all) {
      if (t.id == normalized) return t;
    }
    return blank3d;
  }
}

// ---------------------------------------------------------------------------
// Actor map builders (EditorActorNode.toMap() shape)
// ---------------------------------------------------------------------------

Map<String, dynamic> _actor({
  required String id,
  required String name,
  required String type,
  List<double> location = const [0.0, 0.0, 0.0],
  List<double> rotation = const [0.0, 0.0, 0.0],
  List<double> scale = const [1.0, 1.0, 1.0],
  String mobility = 'Movable',
  double lightIntensity = 5000.0,
  bool castShadows = true,
  String lightColorHex = '#FFF2A3',
  List<Map<String, dynamic>> components = const [],
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'type': type,
    'parentId': null,
    'location': List<double>.from(location),
    'rotation': List<double>.from(rotation),
    'scale': List<double>.from(scale),
    'isVisible': true,
    'isLocked': false,
    'mobility': mobility,
    'lightIntensity': lightIntensity,
    'castShadows': castShadows,
    'lightColorHex': lightColorHex,
    'materialPath': null,
    'meshAssetPath': null,
    'components': components.map((c) => Map<String, dynamic>.from(c)).toList(),
  };
}

/// A `Primitive` actor: an engine-drawn box/plane/sphere/cylinder carrying its
/// shape, size and colour on a `LuminaProceduralMeshComponent` entry so the
/// whole thing round-trips through `metadata.actors` untouched. [size] is
/// `[sizeX, sizeY, sizeZ]` in cm, Z up like the location: the last is the
/// height (a plane's is 0).
Map<String, dynamic> _primitive({
  required String id,
  required String name,
  required String shape,
  required List<double> size,
  String colorHex = '#9AA3AE',
  List<double> location = const [0.0, 0.0, 0.0],
  List<double> rotation = const [0.0, 0.0, 0.0],
}) {
  return _actor(
    id: id,
    name: name,
    type: 'Primitive',
    location: location,
    rotation: rotation,
    mobility: 'Static',
    components: [
      {
        'id': '${id}_mesh',
        'type': 'LuminaProceduralMeshComponent',
        'name': 'Shape',
        'enabled': true,
        'properties': <String, dynamic>{
          'shape': shape,
          'sizeX': size[0],
          'sizeY': size[1],
          'sizeZ': size[2],
          'colorHex': colorHex,
        },
      },
    ],
  );
}

Map<String, dynamic> _sun() => _actor(
      id: 'act_sun',
      name: 'DirectionalLight_Sun',
      type: 'DirectionalLight',
      location: const [0.0, -400.0, 800.0],
      rotation: const [-50.0, 0.0, 30.0],
      lightIntensity: 100000.0,
      lightColorHex: '#FFF2E0',
      components: [
        {
          'id': 'act_sun_light',
          'type': 'LuminaDirectionalLightComponent',
          'name': 'Sun',
          'enabled': true,
          'properties': <String, dynamic>{
            'intensity': 100000.0,
            'effectiveColorHex': '#FFF2E0',
            'castShadows': true,
          },
        },
      ],
    );

Map<String, dynamic> _sky() => _actor(
      id: 'act_sky',
      name: 'SkyAtmosphere_Env',
      type: 'Environment',
      components: [
        {
          'id': 'act_sky_sky',
          'type': 'LuminaSkyComponent',
          'name': 'Sky',
          'enabled': true,
          'properties': <String, dynamic>{
            'mode': 'color',
            'colorHex': '#5A86C6',
            'skyIntensity': 30000.0,
            'iblIntensity': 30000.0,
          },
        },
      ],
    );

/// Floor plane plus four walls — the shared shell of both test rooms.
/// Centimetres, Z up: exactly what the editor's Details panel shows.
List<Map<String, dynamic>> _testRoom() => [
      _primitive(
        id: 'act_floor',
        name: 'Floor',
        shape: 'plane',
        size: const [2000.0, 2000.0, 0.0],
        colorHex: '#6E7681',
      ),
      _primitive(
        id: 'act_wall_n',
        name: 'Wall_North',
        shape: 'box',
        size: const [2000.0, 30.0, 300.0],
        colorHex: '#8B93A1',
        location: const [0.0, 1000.0, 150.0],
      ),
      _primitive(
        id: 'act_wall_s',
        name: 'Wall_South',
        shape: 'box',
        size: const [2000.0, 30.0, 300.0],
        colorHex: '#8B93A1',
        location: const [0.0, -1000.0, 150.0],
      ),
      _primitive(
        id: 'act_wall_e',
        name: 'Wall_East',
        shape: 'box',
        size: const [30.0, 2000.0, 300.0],
        colorHex: '#8B93A1',
        location: const [1000.0, 0.0, 150.0],
      ),
      _primitive(
        id: 'act_wall_w',
        name: 'Wall_West',
        shape: 'box',
        size: const [30.0, 2000.0, 300.0],
        colorHex: '#8B93A1',
        location: const [-1000.0, 0.0, 150.0],
      ),
    ];

List<Map<String, dynamic>> _blankLevelActors() => [
      _actor(
        id: 'act_1',
        name: 'PlayerPawn_Default',
        type: 'Pawn',
        location: const [-60.0, 40.0, 0.0],
      ),
      _actor(
        id: 'act_2',
        name: 'DirectionalLight_Sun',
        type: 'Light',
        location: const [0.0, 150.0, 180.0],
      ),
      _actor(
        id: 'act_3',
        name: 'SkyAtmosphere_Env',
        type: 'Environment',
      ),
      _actor(
        id: 'act_4',
        name: 'StaticMesh_Rock_01',
        type: 'Mesh',
        location: const [80.0, -40.0, 0.0],
      ),
    ];

List<Map<String, dynamic>> _firstPersonLevelActors() => [
      _actor(
        id: 'act_player_start',
        name: 'PlayerStart',
        type: 'PlayerStart',
        location: const [0.0, -600.0, 100.0],
      ),
      _sun(),
      _sky(),
      ..._testRoom(),
      _primitive(
        id: 'act_crate_a',
        name: 'Crate_A',
        shape: 'box',
        size: const [100.0, 100.0, 100.0],
        colorHex: '#B07A45',
        location: const [-300.0, 200.0, 50.0],
      ),
      _primitive(
        id: 'act_crate_b',
        name: 'Crate_B',
        shape: 'box',
        size: const [100.0, 100.0, 100.0],
        colorHex: '#B07A45',
        location: const [-300.0, 200.0, 150.0],
      ),
      _primitive(
        id: 'act_crate_c',
        name: 'Crate_C',
        shape: 'box',
        size: const [140.0, 140.0, 60.0],
        colorHex: '#8E6236',
        location: const [300.0, 300.0, 30.0],
      ),
      _primitive(
        id: 'act_pillar',
        name: 'Pillar',
        shape: 'cylinder',
        size: const [80.0, 80.0, 300.0],
        colorHex: '#A8ADB8',
        location: const [400.0, -400.0, 150.0],
      ),
    ];

/// The Third Person map: a 60 × 60 m walled yard to walk the character
/// around. Every piece is a `Primitive` with a collider, so the template needs
/// no art beyond the character. Centimetres, Z up: the editor's convention,
/// converted to the runtime's Y up by the level code generator.
/// Primitive `size` is the mesh's own extent, Z up like the rest: `[x, y, z]`, z the height.
///
/// Heights are chosen against the character's movement: stairs rise 20 cm per
/// step (`maxStepHeight` is 30), the hurdle is 50 cm (a jump clears ~120),
/// and the crates are 100 cm (jump onto, not walk onto).
List<Map<String, dynamic>> _thirdPersonLevelActors() {
  const half = 3000.0;
  const wallHeight = 250.0;
  const wallThickness = 50.0;

  final actors = <Map<String, dynamic>>[
    _actor(
      id: 'act_player_start',
      name: 'PlayerStart',
      type: 'PlayerStart',
      // In the open south half, looking north (+Y) at the course; the 3.5 m
      // boom has room behind.
      location: const [0.0, -1200.0, 100.0],
    ),
    _sun(),
    _sky(),
    _primitive(
      id: 'act_ground',
      name: 'Ground',
      shape: 'plane',
      size: const [2 * half, 2 * half, 0.0],
      colorHex: '#5F6B5C',
    ),
    _primitive(
      id: 'act_wall_n',
      name: 'Wall_North',
      shape: 'box',
      size: const [2 * half, wallThickness, wallHeight],
      colorHex: '#8B93A1',
      location: const [0.0, half, wallHeight / 2],
    ),
    _primitive(
      id: 'act_wall_s',
      name: 'Wall_South',
      shape: 'box',
      size: const [2 * half, wallThickness, wallHeight],
      colorHex: '#8B93A1',
      location: const [0.0, -half, wallHeight / 2],
    ),
    _primitive(
      id: 'act_wall_e',
      name: 'Wall_East',
      shape: 'box',
      size: const [wallThickness, 2 * half, wallHeight],
      colorHex: '#8B93A1',
      location: const [half, 0.0, wallHeight / 2],
    ),
    _primitive(
      id: 'act_wall_w',
      name: 'Wall_West',
      shape: 'box',
      size: const [wallThickness, 2 * half, wallHeight],
      colorHex: '#8B93A1',
      location: const [-half, 0.0, wallHeight / 2],
    ),
  ];

  // North-west lookout: a 2 m platform reached by ten 20 cm steps climbing
  // north (+Y) from y = 500 to its south edge at y = 1000.
  const platformTop = 200.0;
  const stepRise = 20.0;
  const stepDepth = 50.0;
  const stepCount = 10;
  actors.add(_primitive(
    id: 'act_platform',
    name: 'Platform',
    shape: 'box',
    size: const [800.0, 800.0, platformTop],
    colorHex: '#7E8794',
    location: const [-1400.0, 1400.0, platformTop / 2],
  ));
  for (var i = 1; i <= stepCount; i++) {
    final height = stepRise * i;
    actors.add(_primitive(
      id: 'act_stair_${i.toString().padLeft(2, '0')}',
      name: 'Stair_${i.toString().padLeft(2, '0')}',
      shape: 'box',
      size: [300.0, stepDepth, height],
      colorHex: i.isEven ? '#98A0AD' : '#8B93A1',
      location: [-1400.0, 1000.0 - (stepCount - i) * stepDepth - stepDepth / 2, height / 2],
    ));
  }

  // Centre: a low wall to jump.
  actors.add(_primitive(
    id: 'act_hurdle',
    name: 'Hurdle',
    shape: 'box',
    size: const [600.0, 40.0, 50.0],
    colorHex: '#C1613F',
    location: const [0.0, 0.0, 25.0],
  ));

  // East: a crate yard to weave through and jump onto.
  const crates = <List<double>>[
    [1000.0, 600.0, 50.0],
    [1120.0, 600.0, 50.0],
    [1060.0, 600.0, 150.0],
    [1300.0, 900.0, 50.0],
    [900.0, 1100.0, 50.0],
    [1500.0, 400.0, 50.0],
  ];
  for (var i = 0; i < crates.length; i++) {
    actors.add(_primitive(
      id: 'act_crate_${i + 1}',
      name: 'Crate_${(i + 1).toString().padLeft(2, '0')}',
      shape: 'box',
      size: const [100.0, 100.0, 100.0],
      colorHex: i.isEven ? '#B07A45' : '#8E6236',
      location: crates[i],
    ));
  }

  // South-east: a colonnade to walk between.
  const pillarHeight = 400.0;
  var pillar = 0;
  for (final x in const [1200.0, 1700.0, 2200.0]) {
    for (final y in const [-1000.0, -1600.0]) {
      pillar++;
      actors.add(_primitive(
        id: 'act_pillar_$pillar',
        name: 'Pillar_${pillar.toString().padLeft(2, '0')}',
        shape: 'cylinder',
        size: const [80.0, 80.0, pillarHeight],
        colorHex: '#A8ADB8',
        location: [x, y, pillarHeight / 2],
      ));
    }
  }

  // West: a wall to walk around, and a landmark to walk towards.
  actors.add(_primitive(
    id: 'act_divider',
    name: 'Divider_Wall',
    shape: 'box',
    size: const [40.0, 1000.0, 200.0],
    colorHex: '#8B93A1',
    location: const [-1200.0, -1200.0, 100.0],
  ));
  actors.add(_primitive(
    id: 'act_ball',
    name: 'Marker_Sphere',
    shape: 'sphere',
    size: const [160.0, 160.0, 160.0],
    colorHex: '#4F8FD1',
    location: const [-2200.0, -2200.0, 80.0],
  ));
  return actors;
}

// ---------------------------------------------------------------------------
// Input settings builders
// ---------------------------------------------------------------------------

ProjectInputSettings _noInput() => const ProjectInputSettings();

/// `IA_Move` / `IA_Look` / `IA_Jump` / `IA_Sprint` / `IA_Dash` plus the
/// `Gameplay` mapping context both character templates share (the Dart First
/// Person character leaves `IA_Sprint` / `IA_Dash` unbound;
/// BP_ThirdPersonCharacter sprints while Sprint is held and dashes on Dash).
/// The Project Settings input editor edits exactly these
/// structures, so the user can rebind afterwards.
ProjectInputSettings _gameplayInput() => const ProjectInputSettings(
      actions: [
        ProjectInputAction(name: 'IA_Move', valueType: ProjectInputValueType.axis2D),
        ProjectInputAction(name: 'IA_Look', valueType: ProjectInputValueType.axis2D),
        ProjectInputAction(name: 'IA_Jump', valueType: ProjectInputValueType.digital),
        ProjectInputAction(name: 'IA_Sprint', valueType: ProjectInputValueType.digital),
        ProjectInputAction(name: 'IA_Dash', valueType: ProjectInputValueType.digital),
        ProjectInputAction(name: 'IA_FreeLook', valueType: ProjectInputValueType.digital),
      ],
      mappingContexts: [
        ProjectMappingContext(
          name: 'Gameplay',
          priority: 0,
          mappings: [
            // Forward / back on the movement Y axis.
            ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdW, keyLabel: 'W', scale: 1.0, axis: 'Y'),
            ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdS, keyLabel: 'S', scale: -1.0, axis: 'Y'),
            // Strafe on the movement X axis.
            ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdA, keyLabel: 'A', scale: -1.0, axis: 'X'),
            ProjectInputMapping(action: 'IA_Move', keyId: kKeyIdD, keyLabel: 'D', scale: 1.0, axis: 'X'),
            // Mouse look: X yaws, Y pitches (inverted so pushing the mouse
            // forward looks up is *off* by default).
            ProjectInputMapping(action: 'IA_Look', keyId: kMouseXAxisKeyId, keyLabel: 'Mouse X', scale: 1.0, axis: 'X'),
            ProjectInputMapping(action: 'IA_Look', keyId: kMouseYAxisKeyId, keyLabel: 'Mouse Y', scale: -1.0, axis: 'Y'),
            ProjectInputMapping(action: 'IA_Jump', keyId: kKeyIdSpace, keyLabel: 'Space', scale: 1.0),
            // Sprint while held: Left Shift or the left thumbstick press;
            // Dash: Left Ctrl or the right face button.
            ProjectInputMapping(action: 'IA_Sprint', keyId: kKeyIdShiftLeft, keyLabel: 'Left Shift', scale: 1.0),
            ProjectInputMapping(
                action: 'IA_Sprint', keyId: kGamepadLeftThumbstickKeyId, keyLabel: 'Gamepad Left Thumbstick', scale: 1.0),
            ProjectInputMapping(action: 'IA_Dash', keyId: kKeyIdControlLeft, keyLabel: 'Left Ctrl', scale: 1.0),
            ProjectInputMapping(
                action: 'IA_Dash', keyId: kGamepadFaceButtonRightKeyId, keyLabel: 'Gamepad Face Button Right', scale: 1.0),
            // Free look: held Left Alt / the right thumbstick press.
            ProjectInputMapping(action: 'IA_FreeLook', keyId: kKeyIdAltLeft, keyLabel: 'Left Alt', scale: 1.0),
            ProjectInputMapping(
                action: 'IA_FreeLook', keyId: kGamepadRightThumbstickKeyId, keyLabel: 'Gamepad Right Thumbstick', scale: 1.0),
          ],
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Shared actor builders reused by the editor's New Level templates
// ---------------------------------------------------------------------------
//
// `LevelTemplateCatalog` (level_template_service.dart) seeds new levels from
// exactly the builders the launcher's project templates use, so the two cannot
// drift apart. Every coordinate is in centimetres, Z up, like the templates
// above and the editor.

/// The directional sun actor map shared by the game and level templates.
Map<String, dynamic> luminaTemplateSunActor() => _sun();

/// The sky/atmosphere actor map shared by the game and level templates.
Map<String, dynamic> luminaTemplateSkyActor() => _sky();

/// A flat ground plane primitive, [size] cm square, centred on the origin.
Map<String, dynamic> luminaTemplateGroundPlane({
  String id = 'act_floor',
  String name = 'Floor',
  double size = 2000.0,
  String colorHex = '#6E7681',
}) =>
    _primitive(
      id: id,
      name: name,
      shape: 'plane',
      size: [size, size, 0.0],
      colorHex: colorHex,
    );

/// A `PlayerStart` actor at [location] (cm, Z up), carrying [components].
Map<String, dynamic> luminaTemplatePlayerStart({
  String id = 'act_player_start',
  String name = 'PlayerStart',
  List<double> location = const [0.0, -600.0, 100.0],
  List<Map<String, dynamic>> components = const [],
}) =>
    _actor(
      id: id,
      name: name,
      type: 'PlayerStart',
      location: location,
      components: components,
    );
