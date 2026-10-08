import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_export.dart';

/// A pose search database the example project builds: its asset name, the
/// sample databases it merges and the gait tag each contributes.
class GaspDatabasePlan {
  /// `PSD_<name>` asset name.
  final String name;

  /// Sample database name → tag added to its clips (the gait or stance).
  final Map<String, String> sources;

  const GaspDatabasePlan(this.name, this.sources);
}

/// The example's databases from the sample's dense set: one per stance
/// (a stand database covering idle, walk, run and sprint lets the capsule's
/// speed pick the gait), crouch, the jumps and the landings. Each sample
/// database's own tags (`Stops`, `Pivots`, `TurnInPlace`, `Loops`) are kept.
abstract final class GaspDatabases {
  static const String stand = 'PSD_Stand';
  static const String crouch = 'PSD_Crouch';
  static const String jump = 'PSD_Jump';
  static const String land = 'PSD_Land';

  static const List<GaspDatabasePlan> plans = [
    GaspDatabasePlan(stand, {
      'PSD_Dense_Stand_Idles': 'Idle',
      'PSD_Dense_Stand_TurnInPlace': 'Idle',
      'PSD_Dense_Stand_Walk_Loops': 'Walk',
      'PSD_Dense_Stand_Walk_Starts': 'Walk',
      'PSD_Dense_Stand_Walk_Stops': 'Walk',
      'PSD_Dense_Stand_Walk_Pivots': 'Walk',
      'PSD_Dense_Stand_Walk_SpinTransition': 'Walk',
      'PSD_Dense_Stand_Run_Loops': 'Run',
      'PSD_Dense_Stand_Run_Starts': 'Run',
      'PSD_Dense_Stand_Run_Stops': 'Run',
      'PSD_Dense_Stand_Run_Pivots': 'Run',
      'PSD_Dense_Stand_Run_SpinTransition': 'Run',
      'PSD_Dense_Stand_Sprint_Loops': 'Sprint',
      'PSD_Dense_Stand_Sprint_Starts': 'Sprint',
      'PSD_Dense_Stand_Sprint_Stops': 'Sprint',
      'PSD_Dense_Stand_Sprint_Pivots': 'Sprint',
    }),
    GaspDatabasePlan(crouch, {
      'PSD_Dense_Crouch_Idles': 'Idle',
      'PSD_Dense_Crouch_TurnInPlace': 'Idle',
      'PSD_Dense_Crouch_Walk_Loops': 'Crouch',
      'PSD_Dense_Crouch_Walk_Starts': 'Crouch',
      'PSD_Dense_Crouch_Walk_Stops': 'Crouch',
      'PSD_Dense_Crouch_Walk_Pivots': 'Crouch',
    }),
    GaspDatabasePlan(jump, {
      'PSD_Dense_Jumps': 'Jump',
      'PSD_Dense_Jumps_Far': 'Jump',
    }),
    GaspDatabasePlan(land, {
      'PSD_Dense_Stand_Idle_Lands_Light': 'Idle',
      'PSD_Dense_Stand_Idle_Lands_Heavy': 'Idle',
      'PSD_Dense_Stand_Walk_Lands_Light': 'Walk',
      'PSD_Dense_Stand_Walk_Lands_Heavy': 'Walk',
      'PSD_Dense_Stand_Run_Lands_Light': 'Run',
      'PSD_Dense_Stand_Run_Lands_Heavy': 'Run',
      'PSD_Dense_Stand_Sprint_Lands_Light': 'Sprint',
      'PSD_Dense_Stand_Sprint_Lands_Heavy': 'Sprint',
    }),
  ];

  /// The sample's default schema as far as the engine follows it: future
  /// trajectory samples at 0.35, 0.7 and 1.0 s and a short past sample
  /// (-0.05 s; the engine has no present sample: features are relative to
  /// the current frame), feet position + velocity and pelvis velocity.
  static const LuminaPoseSearchSchema schema = LuminaPoseSearchSchema(
    trajectoryTimes: [-0.05, 0.35, 0.7, 1.0],
    bones: [
      LuminaPoseSearchBone('foot_l', position: 1.0, velocity: 1.0),
      LuminaPoseSearchBone('foot_r', position: 1.0, velocity: 1.0),
      LuminaPoseSearchBone('pelvis', position: 0.0, velocity: 1.0),
    ],
  );

  /// Whether the clip loops: the sample's loops say so in their names.
  static bool loops(String clip) => clip.contains('_Loop') || clip.endsWith('Loop');

  /// [plan] as a database document for [targetMesh]: every clip of its
  /// source databases that [available] has (once; the first source wins),
  /// tagged with the source's gait tag and its own tags, the source's
  /// looping cost bias on loops as the clip's bias, and its sampling range.
  ///
  /// The sample's base cost biases are left out: they rank a database
  /// against the others its chooser picked for the same moment (turn in
  /// place −0.2, spins −0.5, idles +0.1), and merged into one stance
  /// database they would make a standing character turn and spin forever. Returns the document and the clips it wanted that
  /// are missing.
  static (LuminaPoseSearchDatabaseDocument, List<String>) document(
    GaspDatabasePlan plan,
    GaspExport export, {
    required String targetMesh,
    required Set<String> available,
  }) {
    final clips = <LuminaPoseSearchClip>[];
    final added = <String>{};
    final missing = <String>[];
    for (final MapEntry(key: source, value: gait) in plan.sources.entries) {
      final db = export.databases[source];
      if (db == null) {
        missing.add(source);
        continue;
      }
      for (final c in db.clips) {
        if (!c.enabled || added.contains(c.clip)) continue;
        if (!available.contains(c.clip)) {
          missing.add(c.clip);
          continue;
        }
        added.add(c.clip);
        final loop = loops(c.clip);
        clips.add(LuminaPoseSearchClip(
          c.clip,
          loop: loop,
          mirror: c.mirror != null && c.mirror != 'UnmirroredOnly',
          tags: {gait, ...db.tags}.toList(),
          costBias: loop ? db.loopingCostBias : 0.0,
          samplingStart: c.samplingStart,
          samplingEnd: c.samplingEnd,
        ));
      }
    }
    return (
      LuminaPoseSearchDatabaseDocument(
        targetMesh: targetMesh,
        clips: clips,
        schema: schema,
        // The sample's biases are per database (on the clips above).
        loopingCostBias: 0.0,
      ),
      missing,
    );
  }

  /// Every clip the plans use, by name.
  static Set<String> clipsUsed(GaspExport export) => {
        for (final plan in plans)
          for (final source in plan.sources.keys)
            for (final c in export.databases[source]?.clips ?? const <GaspDatabaseClip>[])
              if (c.enabled) c.clip,
      };
}
