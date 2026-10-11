import 'package:lumina_core/lumina_core.dart';

/// The sample's default pose search schema as far as the engine follows it:
/// future trajectory samples at 0.35, 0.7 and 1.0 s and a short past sample
/// (-0.05 s; the engine has no present sample: features are relative to the
/// current frame), feet position + velocity and pelvis velocity.
///
/// Kept apart from the databases (which read the export) so the traversal
/// rows the export parses can measure warp points on the same schema.
const LuminaPoseSearchSchema gaspPoseSearchSchema = LuminaPoseSearchSchema(
  trajectoryTimes: [-0.05, 0.35, 0.7, 1.0],
  bones: [
    LuminaPoseSearchBone('foot_l', position: 1.0, velocity: 1.0),
    LuminaPoseSearchBone('foot_r', position: 1.0, velocity: 1.0),
    LuminaPoseSearchBone('pelvis', position: 0.0, velocity: 1.0),
  ],
);
