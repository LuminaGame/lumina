import 'package:lumina_core/src/services/game_template_service.dart';

/// The three templates `File → New Level…` offers.
///
/// These are *level* templates (what a single `.lmas` starts with), as opposed
/// to [GameTemplateCatalog]'s *project* templates (what `flutter create` plus
/// the scaffolder lay down). They reuse the same actor builders so the two
/// cannot drift apart.
///
/// **Units**: every location and size below is in centimetres, Z up — the
/// editor's convention; the level code generator converts to the runtime's
/// Y up.
const String kEmptyLevelTemplateId = 'empty';
const String kDefaultLevelTemplateId = 'default';
const String kOpenWorldLevelTemplateId = 'open_world';

/// Component `type` string of the runtime `LuminaStreamingSourceComponent`, as
/// it is persisted inside a level actor's `components` list.
const String kStreamingSourceComponentType = 'LuminaStreamingSourceComponent';

/// Grid cell edge length in world units (cm; 128 m). 1:1 with
/// `LuminaWorldPartitionSubsystem.cellSize`'s constructor default (12800).
const double kWorldPartitionDefaultCellSize = 12800.0;

/// Cell state transitions the subsystem is allowed to run per tick. 1:1 with
/// `LuminaWorldPartitionSubsystem.maxCellTransitionsPerTick`'s default (10).
const int kWorldPartitionDefaultMaxCellTransitionsPerTick = 10;

/// Default streaming radius in world units (cm; 250 m), applied to streaming
/// sources that do not author their own. 1:1 with
/// `LuminaStreamingSourceComponent.loadingRadius`'s default (25000).
const double kWorldPartitionDefaultLoadingRange = 25000.0;

/// A fresh `metadata.worldPartition` section carrying the runtime's own
/// defaults and no data layers (a level authors those itself).
Map<String, dynamic> defaultWorldPartitionSection() => <String, dynamic>{
      'enabled': true,
      'cellSize': kWorldPartitionDefaultCellSize,
      'loadingRange': kWorldPartitionDefaultLoadingRange,
      'maxCellTransitionsPerTick': kWorldPartitionDefaultMaxCellTransitionsPerTick,
      'dataLayers': <Map<String, dynamic>>[],
    };

/// One entry in the New Level dialog.
class LevelTemplate {
  final String id;
  final String title;

  /// One line describing exactly what this template seeds — shown in the
  /// dialog, so it must stay truthful.
  final String description;

  final List<Map<String, dynamic>> Function() _levelActorsBuilder;
  final Map<String, dynamic>? Function() _worldPartitionBuilder;

  const LevelTemplate({
    required this.id,
    required this.title,
    required this.description,
    required List<Map<String, dynamic>> Function() levelActors,
    required Map<String, dynamic>? Function() worldPartition,
  })  : _levelActorsBuilder = levelActors,
        _worldPartitionBuilder = worldPartition;

  /// Fresh actor maps (`EditorActorNode.toMap()` shape) for a new level.
  List<Map<String, dynamic>> get levelActors => _levelActorsBuilder();

  /// Fresh `metadata.worldPartition` section, or null when the template does
  /// not author one (`Empty`, `Default`).
  Map<String, dynamic>? get worldPartition => _worldPartitionBuilder();
}

List<Map<String, dynamic>> _emptyLevelActors() => const <Map<String, dynamic>>[];

List<Map<String, dynamic>> _defaultLevelActors() => [
      luminaTemplatePlayerStart(location: const [0.0, -600.0, 100.0]),
      luminaTemplateSunActor(),
      luminaTemplateSkyActor(),
      // 20 m square floor, the same slab the First Person test room stands on.
      luminaTemplateGroundPlane(),
    ];

List<Map<String, dynamic>> _openWorldLevelActors() => [
      luminaTemplatePlayerStart(
        location: const [0.0, 0.0, 100.0],
        components: [
          {
            'id': 'act_player_start_streaming',
            'type': kStreamingSourceComponentType,
            'name': 'Streaming Source',
            'enabled': true,
            // No `loadingRadius` here on purpose: the source inherits the
            // level section's `loadingRange`, which is what the World
            // Partition details panel edits.
            'properties': <String, dynamic>{
              'priority': 1,
              'bShapesCellLoading': true,
              'targetState': 'activated',
            },
          },
        ],
      ),
      luminaTemplateSunActor(),
      luminaTemplateSkyActor(),
      // 256 m square ground = exactly 2×2 cells at the default 128 m cellSize,
      // so the authored partition grid is visible against real geometry. This
      // is a plain `Primitive`, not a Landscape actor — terrain is handled
      // separately.
      luminaTemplateGroundPlane(
        id: 'act_ground',
        name: 'Ground',
        size: 25600.0,
        colorHex: '#5F6A57',
      ),
    ];

Map<String, dynamic>? _noWorldPartition() => null;

/// The templates `File → New Level…` offers, in dialog order.
class LevelTemplateCatalog {
  const LevelTemplateCatalog._();

  static const LevelTemplate empty = LevelTemplate(
    id: kEmptyLevelTemplateId,
    title: 'Empty',
    description: 'Nothing at all: no sun, no sky, no ground. A void you fill yourself.',
    levelActors: _emptyLevelActors,
    worldPartition: _noWorldPartition,
  );

  static const LevelTemplate standard = LevelTemplate(
    id: kDefaultLevelTemplateId,
    title: 'Default',
    description: 'Sun, sky, a 20 m floor and a PlayerStart — renderable the moment it opens.',
    levelActors: _defaultLevelActors,
    worldPartition: _noWorldPartition,
  );

  static const LevelTemplate openWorld = LevelTemplate(
    id: kOpenWorldLevelTemplateId,
    title: 'Open World',
    description:
        'Default lighting on a 256 m ground, plus a 128 m world-partition grid and a streaming source on the PlayerStart.',
    levelActors: _openWorldLevelActors,
    worldPartition: defaultWorldPartitionSection,
  );

  static const List<LevelTemplate> all = [empty, standard, openWorld];

  /// Resolves [id] to a template; unknown ids fall back to [standard].
  static LevelTemplate byId(String? id) {
    if (id == null) return standard;
    final normalized = id.trim().toLowerCase().replaceAll(' ', '_');
    for (final t in all) {
      if (t.id == normalized) return t;
    }
    return standard;
  }
}
