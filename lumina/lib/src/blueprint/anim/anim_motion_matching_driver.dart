import 'dart:async';
import 'dart:developer' as developer;

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/animation/motion_matching/motion_matching_component.dart';
import 'package:lumina/src/animation/motion_matching/motion_matching_player.dart';
import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';

/// Runs an Animation Blueprint's Motion Matching states: loads each pose
/// search database once (in the background; a state holds the pose until
/// its database is ready), drives one [LuminaMotionMatchingPlayer] on the
/// mesh while such a state is active, and hands the mesh back to gltfio at
/// the matched clip and time when the state is left.
class LuminaAnimMotionMatchingDriver {
  final LuminaAnimatedMeshComponent mesh;

  /// The databases' documents by asset path (the generated class carries
  /// them inline; the VM reads them from the project). A path missing here
  /// is read from its `.lmas`.
  final Map<String, LuminaPoseSearchDatabaseDocument> documents;

  LuminaAnimMotionMatchingDriver(this.mesh, this.documents);

  final Map<String, LuminaPoseSearchDatabaseRuntime> _ready = {};
  final Map<String, Future<LuminaPoseSearchDatabaseRuntime>> _loading = {};
  LuminaMotionMatchingPlayer? _player;
  bool _active = false;

  /// The player of the last Motion Matching state, if one ran.
  LuminaMotionMatchingPlayer? get player => _player;

  /// Whether a Motion Matching state drives the mesh now.
  bool get active => _active;

  /// Whether [database] has loaded.
  bool isLoaded(String database) => _ready.containsKey(database);

  /// Why the last database failed to load, if one did.
  String? lastError;

  /// Starts loading [database] (once) and completes when it is ready.
  Future<LuminaPoseSearchDatabaseRuntime> load(String database) => _loading.putIfAbsent(database, () {
        final future = LuminaPoseSearchDatabaseRuntime.load(database, document: documents[database]);
        future.then((r) => _ready[database] = r, onError: (Object e) {
          lastError = '$e';
          developer.log('Motion matching: cannot load $database: $e', name: 'LuminaAnimBlueprint', level: 900);
        });
        return future;
      });

  /// One frame of a Motion Matching [pose] for [owner]: returns the clip it
  /// plays (null while its database loads).
  String? drive(LuminaActor owner, LuminaAnimPose pose, double deltaTime) {
    final path = pose.database ?? '';
    final runtime = _ready[path];
    if (runtime == null) {
      if (path.isNotEmpty) unawaited(load(path).then((_) {}, onError: (_) {}));
      return null;
    }
    var player = _player;
    if (player == null || player.database != runtime) {
      // From another Motion Matching state: keep its trajectory history and
      // blend from the pose it shows.
      final previous = _active ? player : null;
      player = _player = LuminaMotionMatchingPlayer(runtime, blendTime: pose.blendTime, predictor: previous?.predictor);
      if (previous != null) player.continueFrom(previous);
    } else if (!_active) {
      player.forceSearch();
    }
    player
      ..blendTime = pose.blendTime
      ..poseWeight = pose.poseWeight
      ..trajectoryWeight = pose.trajectoryWeight
      ..requiredTags = pose.requiredTags.toSet();
    mesh.poseDriver = player;
    _active = true;
    final input = LuminaMotionMatchingCharacter.inputFor(owner, mesh,
        desiredYaw: pose.orientToMovement ? null : LuminaMotionMatchingCharacter.facingYaw(owner));
    player.input = input;
    if (pose.orientToMovement) LuminaMotionMatchingCharacter.orientToMovement(owner, player, input, deltaTime);
    if (pose.debugDraw) LuminaMotionMatchingCharacter.drawDebug(owner, player);
    return player.matchedClip;
  }

  /// Leaves motion matching: gltfio takes the joints back, starting from the
  /// matched clip at the matched time (a mirrored frame has no gltfio clip;
  /// the next crossfade starts from whatever the mesh played before).
  void leave() {
    if (!_active) return;
    _active = false;
    final player = _player;
    if (player == null) return;
    if (mesh.poseDriver == player) mesh.poseDriver = null;
    final clip = player.matchedClip;
    if (clip != null && !player.matchedMirrored && mesh.hasClip(clip)) {
      mesh.play(clip, startTime: player.matchedTime, loop: player.database.document.clips[player.clip].loop);
    }
  }
}
