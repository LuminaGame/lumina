import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';

import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_databases.dart';
import 'package:lumina_editor_data/src/services/fbx_import_service.dart';

/// The sample's traversal set read from the export's `metadata.json`: the
/// traversal chooser's nested tables (hurdles, mantles, vaults: obstacle
/// height / depth and speed ranges per montage) and each montage's motion
/// warping windows, blend-out mark and branch-in range, as the rows of a
/// `LuminaTraversalComponent`. Only grounded rows of the neutral style are
/// kept (the catch montages need a falling start).
abstract final class GaspTraversal {
  static const String chooserName = 'CHT_TraversalAnims';

  /// The warp point bone the sample aligns to the front ledge: a bone
  /// parked where the clip's ledge was when it was authored.
  static const String warpPointBone = 'attach';

  /// The bone carrying the clips' root motion.
  static const String rootBone = 'root';

  /// Starts are matched within the montage's branch-in range, at most this
  /// far into the clip.
  static const double maxStartTime = 0.5;

  static final _nested = RegExp(r'Begin Object Name="(\w+)"([\s\S]*?)\n\s*End Object');
  static final _column = RegExp(r'ColumnsStructs\(\d+\)=(\S+?)\(.*?DisplayName="(\w+)".*?RowValues(?:WithAny)?=\((.*)\),bDisabled');
  static final _result = RegExp(r'''ResultsStructs\((\d+)\)=.*?Asset="[^']*'[^'.]*\.(\w+)'"''');
  static final _group = RegExp(r'\(([^()]*)\)');

  /// The chooser rows of [metadata] (the export's `metadata.json`), with
  /// their montages' windows; empty when the export has no traversal set.
  static List<LuminaTraversalAnimation> rows(Map<String, dynamic> metadata) {
    final assets = (metadata['assets'] as Map?) ?? const {};
    final chooser = ((assets['ChooserTable'] as List?) ?? const [])
        .cast<Map>()
        .where((c) => '${c['path']}'.contains('/$chooserName.'))
        .firstOrNull;
    if (chooser == null) return const [];
    final montages = <String, Map>{
      for (final m in ((assets['AnimMontage'] as List?) ?? const []).cast<Map>()) '${m['path']}'.split('.').last: m,
    };
    final out = <LuminaTraversalAnimation>[];
    for (final block in _nested.allMatches('${chooser['t3d'] ?? ''}')) {
      final action = switch (block.group(1)) {
        'Hurdles' => LuminaTraversalActionType.hurdle,
        'Mantles' => LuminaTraversalActionType.mantle,
        'Vaults' => LuminaTraversalActionType.vault,
        _ => LuminaTraversalActionType.none,
      };
      if (action == LuminaTraversalActionType.none) continue;
      final body = block.group(2)!;
      final columns = <String, List<String>>{};
      for (final c in _column.allMatches(body)) {
        columns[c.group(2)!] = [for (final g in _group.allMatches(c.group(3)!)) g.group(1)!];
      }
      final results = <int, String>{for (final r in _result.allMatches(body)) int.parse(r.group(1)!): r.group(2)!};
      for (final MapEntry(key: i, value: montageName) in results.entries) {
        final mode = _cell(columns['MovementMode'], i);
        if (mode != null && ((_number(mode, 'Value') ?? 1).toInt() & 1) == 0) continue;
        if (!montageName.contains('_Neutral_')) continue;
        final montage = montages[montageName];
        if (montage == null) continue;
        final (minH, maxH) = _range(_cell(columns['ObstacleHeight'], i));
        final (minD, maxD) = _range(_cell(columns['ObstacleDepth'], i));
        final (minS, maxS) = _range(_cell(columns['Speed'], i));
        final row = _montageRow(montage, action,
            minHeight: minH, maxHeight: maxH, minDepth: minD, maxDepth: maxD, minSpeed: minS, maxSpeed: maxS);
        if (row != null && !out.any((o) => o.clip == row.clip && o.action == row.action)) out.add(row);
      }
    }
    return out;
  }

  static String? _cell(List<String>? column, int i) => column == null || i >= column.length ? null : column[i];

  static double? _number(String cell, String key) {
    final m = RegExp('(?:^|,)$key=(-?[0-9.]+)').firstMatch(cell);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  /// A chooser float range cell: `Min` defaults to 0 and `Max` to 0 unless
  /// `bNoMin` / `bNoMax`.
  static (double, double) _range(String? cell) {
    if (cell == null) return (0.0, double.infinity);
    final min = cell.contains('bNoMin=True') ? 0.0 : (_number(cell, 'Min') ?? 0.0);
    final max = cell.contains('bNoMax=True') ? double.infinity : (_number(cell, 'Max') ?? 0.0);
    return (min, max);
  }

  static LuminaTraversalAnimation? _montageRow(
    Map montage,
    LuminaTraversalActionType action, {
    required double minHeight,
    required double maxHeight,
    required double minDepth,
    required double maxDepth,
    required double minSpeed,
    required double maxSpeed,
  }) {
    final segments = ((montage['segments'] as List?) ?? const []).cast<Map>();
    if (segments.isEmpty) return null;
    final segment = segments.first;
    final clip = '${segment['anim']}'.split('.').last;
    final offset = ((segment['anim_start_time'] as num?) ?? 0).toDouble() - ((segment['start_pos'] as num?) ?? 0).toDouble();
    final windows = <LuminaWarpWindow>[];
    double? blendOut;
    double? branchEnd;
    for (final n in ((montage['notifies'] as List?) ?? const []).cast<Map>()) {
      final start = ((n['time'] as num?) ?? 0).toDouble() + offset;
      final end = start + ((n['duration'] as num?) ?? 0).toDouble();
      final name = '${n['name']}';
      if (name == 'MotionWarping') {
        final m = ((n['notify_state_class_props'] as Map?)?['root_motion_modifier'] as Map?) ?? const {};
        final bone = m['warp_point_anim_provider'] == 'BONE' ? '${m['warp_point_anim_bone_name']}' : null;
        windows.add(LuminaWarpWindow(
          target: '${m['warp_target_name'] ?? ''}',
          start: start,
          end: end,
          warpTranslation: m['warp_translation'] as bool? ?? true,
          warpRotation: m['warp_rotation'] as bool? ?? false,
          ignoreVertical: m['ignore_z_axis'] as bool? ?? false,
          warpPointBone: bone,
        ));
      } else if (name.contains('TraversalBlendOut')) {
        blendOut = start;
      } else if (name == 'PoseSearchBranchIn') {
        branchEnd = end;
      }
    }
    windows.sort((a, b) => a.start.compareTo(b.start));
    final firstWarp = windows.isEmpty ? maxStartTime : windows.first.start;
    final startLimit = [branchEnd ?? 0.0, firstWarp, maxStartTime].reduce((a, b) => a < b ? a : b);
    return LuminaTraversalAnimation(
      action: action,
      clip: clip,
      minHeight: minHeight,
      maxHeight: maxHeight,
      minDepth: minDepth,
      maxDepth: maxDepth,
      minSpeed: minSpeed,
      maxSpeed: maxSpeed,
      blendOutTime: blendOut,
      blendTime: (((montage['blend_in'] as Map?)?['blend_time'] as num?) ?? 0.25).toDouble(),
      maxStartTime: startLimit < 0 ? 0.0 : startLimit,
      windows: windows,
    );
  }

  /// The clips [rows] play.
  static Set<String> clips(List<LuminaTraversalAnimation> rows) => {for (final r in rows) r.clip};

  /// [rows] with every warp-point window's offset measured on the source
  /// clip ([sourceClips]: clip name → the clip as converted from its FBX,
  /// still on the sample's skeleton, which has the warp point bone): a mesh
  /// the clips were retargeted onto lacks the bone, so the runtime uses the
  /// stored offset. Offsets are in centimetres, in the root's frame of
  /// [schema] (the character's databases' schema).
  static List<LuminaTraversalAnimation> withWarpPointOffsets(
    List<LuminaTraversalAnimation> rows,
    Map<String, Uint8List> sourceClips, {
    LuminaPoseSearchSchema? schema,
    double worldUnitsPerModelUnit = 100.0,
  }) {
    final rootSchema = schema ?? GaspDatabases.schema.copyWith(rootBone: rootBone);
    final rigs = <String, (LuminaPoseSearchRig, int)?>{};
    return [
      for (final row in rows)
        LuminaTraversalAnimation(
          action: row.action,
          clip: row.clip,
          minHeight: row.minHeight,
          maxHeight: row.maxHeight,
          minDepth: row.minDepth,
          maxDepth: row.maxDepth,
          minSpeed: row.minSpeed,
          maxSpeed: row.maxSpeed,
          blendOutTime: row.blendOutTime,
          endTime: row.endTime,
          playRate: row.playRate,
          blendTime: row.blendTime,
          maxStartTime: row.maxStartTime,
          windows: [
            for (final w in row.windows)
              if (w.warpPointBone == null || w.warpPointOffset != null)
                w
              else
                w.withOffset(() {
                  final entry = rigs.putIfAbsent(row.clip, () {
                    final glb = sourceClips[row.clip];
                    if (glb == null) return null;
                    final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
                    final clip = sampler.clipIndex(row.clip) ?? (sampler.clips.isEmpty ? null : 0);
                    return clip == null ? null : (LuminaPoseSearchRig(sampler, rootSchema), clip);
                  });
                  if (entry == null) return null;
                  final (rig, clip) = entry;
                  final node = rig.sampler.indexOfNode(w.warpPointBone!);
                  if (node < 0) return null;
                  return LuminaRootMotionTrack(rig, clip, worldUnitsPerModelUnit: worldUnitsPerModelUnit).boneOffset(node, w.end);
                }()),
          ],
        ),
    ];
  }

  /// Converts the FBX of every clip [rows] play (by [fbxPathOf]) on
  /// background isolates and measures their warp points
  /// ([withWarpPointOffsets]).
  static Future<List<LuminaTraversalAnimation>> measureWarpPoints(
    List<LuminaTraversalAnimation> rows,
    String? Function(String clip) fbxPathOf,
  ) async {
    final sources = <String, Uint8List>{};
    for (final clip in clips(rows)) {
      final fbx = fbxPathOf(clip);
      if (fbx == null) continue;
      try {
        sources[clip] = (await FbxImportService.convert(fbx)).glb;
      } catch (_) {
        // Without its source the clip keeps no offset: its root goes to the ledge.
      }
    }
    return Isolate.run(() => withWarpPointOffsets(rows, sources), debugName: 'traversal warp points');
  }
}
