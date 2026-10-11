import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/samples/metaxr_posing/metaxr_posing_content.dart';

/// `L_Room`: the user's own room through passthrough, no floor or sky. The
/// XR origin (the player start, at LOCAL_FLOOR) is where the user stands;
/// the character stands [characterDistance] cm in front of it (+Y) facing
/// the user; a key light like a room's ceiling light and a soft fill.
abstract final class MetaXrPosingLevel {
  static const String levelName = 'L_Room';
  static const String levelPath = 'contents/levels/$levelName.lmas';

  /// How far in front of the user the character stands (cm).
  static const double characterDistance = 120.0;

  static Map<String, dynamic> _actor({
    required String id,
    required String name,
    required String type,
    List<double> location = const [0.0, 0.0, 0.0],
    List<double> rotation = const [0.0, 0.0, 0.0],
    String? blueprintClass,
    List<Map<String, dynamic>> components = const [],
    Map<String, dynamic> extra = const {},
  }) =>
      {
        'id': id,
        'name': name,
        'type': type,
        'parentId': null,
        'location': location,
        'rotation': rotation,
        'scale': [1.0, 1.0, 1.0],
        'isVisible': true,
        'isLocked': false,
        'mobility': 'Movable',
        'blueprintClass': ?blueprintClass,
        'components': components,
        ...extra,
      };

  static Map<String, dynamic> _light(String id, String name, List<double> rotation, double intensity, String color,
          {bool shadows = false}) =>
      _actor(
        id: id,
        name: name,
        type: 'DirectionalLight',
        location: const [0.0, 0.0, 300.0],
        rotation: rotation,
        extra: {'lightIntensity': intensity, 'lightColorHex': color, 'castShadows': shadows},
        components: [
          {
            'id': '${id}_light',
            'type': 'LuminaDirectionalLightComponent',
            'name': name,
            'enabled': true,
            'properties': <String, dynamic>{'intensity': intensity, 'effectiveColorHex': color, 'castShadows': shadows},
          },
        ],
      );

  /// The level's actors.
  static List<Map<String, dynamic>> actors() => [
        luminaTemplatePlayerStart(
          location: const [0.0, 0.0, 0.0],
          components: [
            {
              'id': 'act_player_start_gamemode',
              'type': 'LuminaGameModeBinding',
              'name': 'Game Mode',
              'enabled': true,
              'properties': <String, dynamic>{'gameModeBlueprint': MetaXrPosingContent.gameModePath},
            },
          ],
        ),
        _light('act_key_light', 'KeyLight', const [-60.0, 0.0, 30.0], 60000.0, '#FFF4E6', shadows: true),
        _light('act_fill_light', 'FillLight', const [-20.0, 0.0, 200.0], 20000.0, '#E6EEFF'),
        _actor(
          id: 'act_passthrough',
          name: 'RoomPassthrough',
          type: 'Actor',
          blueprintClass: MetaXrPosingContent.passthroughPath,
          // What the Blueprint holds, as the level lists it.
          components: [
            {
              'id': 'act_passthrough_component',
              'type': 'LuminaMetaPassthroughComponent',
              'name': 'Passthrough',
              'enabled': true,
              'properties': <String, dynamic>{'enabled': true, 'placement': 'underlay'},
            },
          ],
        ),
        _actor(
          id: 'act_character',
          name: 'PosedCharacter',
          type: 'Actor',
          location: const [0.0, characterDistance, 0.0],
          blueprintClass: MetaXrPosingContent.characterPath,
        ),
      ];

  /// The level container (`LuminaLevelDocument` JSON).
  static Map<String, dynamic> levelContainer() => {
        'assetId': 'level_$levelName',
        'name': levelName,
        'type': 'level',
        'relativePath': levelPath,
        'rawPayload': null,
        'metadata': {'actors': actors()},
      };
}
