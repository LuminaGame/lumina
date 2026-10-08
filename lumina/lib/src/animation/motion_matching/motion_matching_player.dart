import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/inertializer.dart';
import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/animation/motion_matching/trajectory_predictor.dart';
import 'package:lumina/src/components/mesh/mesh_pose_driver.dart';
import 'package:lumina_core/lumina_core.dart';

/// What a motion matching player needs from the character each frame, in
/// world space (runtime axes, world units).
class LuminaMotionMatchingInput {
  /// The character's position (its ground point: the capsule's bottom).
  final Vector3 position;

  /// World yaw of the character's facing (0 along +Z, positive toward +X).
  final double facingYaw;
  final Vector3 velocity;

  /// Where the input asks the character to go (world units per second).
  final Vector3 desiredVelocity;

  /// The facing the character should turn to; null faces the movement
  /// direction while moving and keeps the facing when stopping.
  final double? desiredYaw;

  /// Model units (the database's) per world unit: 1 / (asset unit scale ×
  /// mesh scale).
  final double modelUnitsPerWorldUnit;

  const LuminaMotionMatchingInput({
    required this.position,
    required this.facingYaw,
    required this.velocity,
    required this.desiredVelocity,
    this.desiredYaw,
    this.modelUnitsPerWorldUnit = 0.01,
  });
}

/// Plays a pose search database by motion matching: every frame it advances
/// the matched clip, every [searchInterval] seconds (and at once when the
/// desired velocity changes sharply or a one-shot clip ends) it searches the
/// frame whose pose and trajectory best match the current pose and the
/// predicted trajectory, switches when that frame beats continuing by the
/// database's bias, and blends the switch by inertialization. It shows the
/// pose through the mesh as a [LuminaMeshPoseDriver]: root motion removed
/// (the capsule moves the character), mirrored frames mirrored.
class LuminaMotionMatchingPlayer implements LuminaMeshPoseDriver {
  final LuminaPoseSearchDatabaseRuntime database;
  final LuminaTrajectoryPredictor predictor;
  final LuminaInertializer inertializer;

  /// Multipliers of the schema weights: pose features and trajectory.
  double poseWeight;
  double trajectoryWeight;

  /// Seconds between searches (the database's by default).
  double searchInterval;

  /// A search only switches to a frame cheaper than continuing by this.
  double continuingPoseBias;

  /// A change of desired velocity larger than this fraction of the larger
  /// speed (and at least [inputChangeMinimum] world units/s) searches at once.
  double inputChangeFraction = 0.3;
  double inputChangeMinimum = 30.0;

  /// Clips whose tags lack these are not searched.
  Set<String> requiredTags = const {};

  /// The input [evaluatePose] plays with; set it every frame.
  LuminaMotionMatchingInput? input;

  LuminaMotionMatchingPlayer(
    this.database, {
    double? blendTime,
    this.poseWeight = 1.0,
    this.trajectoryWeight = 1.0,
    LuminaTrajectoryPredictor? predictor,
  })  : predictor = predictor ?? LuminaTrajectoryPredictor(),
        inertializer = LuminaInertializer(database.sampler.nodeCount,
            halflife: (blendTime ?? database.document.blendTime) / 4.0),
        searchInterval = database.document.searchInterval,
        continuingPoseBias = database.document.continuingPoseBias {
    final n = database.sampler.nodeCount * LuminaPoseMath.trsStride;
    _target = Float64List(n);
    _targetAhead = Float64List(n);
    _shown = Float64List(n);
    _shownPrevious = Float64List(n);
    _shownVelocity = Float64List(database.sampler.nodeCount * 6);
    _targetVelocity = Float64List(database.sampler.nodeCount * 6);
    _query = Float32List(database.index.dimensions);
    _weights = Float32List(database.index.dimensions);
  }

  /// Blend time of a switch (seconds; the inertialization halflife is a
  /// quarter of it).
  double get blendTime => inertializer.halflife * 4.0;
  set blendTime(double value) => inertializer.halflife = math.max(1e-3, value / 4.0);

  late final Float64List _target, _targetAhead, _shown, _shownPrevious, _shownVelocity, _targetVelocity;
  late final Float32List _query, _weights;

  int _clip = -1;
  double _time = 0.0;
  bool _mirrored = false;
  double _sinceSearch = double.infinity;
  Vector3? _desiredAtSearch;
  bool _hasShown = false;

  /// The database clip playing (index into the document's clips), −1 before
  /// the first update.
  int get clip => _clip;

  /// The name of the clip playing, or null.
  String? get matchedClip => _clip < 0 ? null : database.document.clips[_clip].clip;

  /// Seconds into [matchedClip].
  double get matchedTime => _time;
  bool get matchedMirrored => _mirrored;

  /// The row playing now.
  int get row => _clip < 0 ? -1 : database.rowFor(_clip, _time, _mirrored);

  int searchCount = 0;
  int switchCount = 0;
  double lastSearchCost = double.infinity;

  /// The cost of continuing the playing frame at the last search.
  double lastContinuingCost = double.infinity;
  int lastSearchMicroseconds = 0;
  int maxSearchMicroseconds = 0;
  int totalSearchMicroseconds = 0;
  int lastUpdateMicroseconds = 0;
  int maxUpdateMicroseconds = 0;
  int totalUpdateMicroseconds = 0;
  int updateCount = 0;

  /// Every switch in order: (clip, time, mirrored).
  final List<(String, double, bool)> switches = [];

  /// The predicted trajectory of the last update and the matched frame's
  /// trajectory, in world space, for debug drawing.
  List<Vector3> desiredTrajectory = const [];
  List<Vector3> matchedTrajectory = const [];

  /// The matched clip's root speed now, in world units per second (the
  /// capsule's speed should be close to it, or the feet slide).
  double matchedRootSpeed = 0.0;

  @override
  List<String> get poseNodeNames => database.sampler.nodeNames;

  /// The pose shown by the last update (TRS per node).
  Float64List get pose => _shown;

  /// Makes the next update search at once.
  void forceSearch() => _sinceSearch = double.infinity;

  @override
  Float64List? evaluatePose(double deltaTime) {
    final i = input;
    if (i == null) return _hasShown ? _shown : null;
    update(deltaTime, i);
    return _shown;
  }

  /// Advances [deltaTime] seconds with [input]: plays on, searches when due,
  /// switches with inertialization, and updates [pose].
  void update(double deltaTime, LuminaMotionMatchingInput input) {
    final watch = Stopwatch()..start();
    final dt = math.max(0.0, deltaTime);
    var forced = _clip < 0;
    if (_clip >= 0) {
      final entry = database.document.clips[_clip];
      final duration = database.durationOf(_clip);
      _time += dt;
      if (entry.loop && duration > 0) {
        _time %= duration;
      } else if (_time >= duration - 1e-6) {
        _time = duration;
        forced = true;
      }
    }
    _sinceSearch += dt;
    final desired = input.desiredVelocity;
    final previous = _desiredAtSearch;
    if (previous != null) {
      final change = (desired - previous).length;
      final scale = math.max(desired.length, previous.length);
      if (change > math.max(inputChangeMinimum, inputChangeFraction * scale)) forced = true;
    }
    final desiredYaw = input.desiredYaw ??
        (Vector3(desired.x, 0, desired.z).length > 1e-3 ? luminaWorldYaw(desired) : input.facingYaw);
    final times = database.document.schema.trajectoryTimes;
    final trajectory = predictor.predict(
      position: input.position,
      yaw: input.facingYaw,
      velocity: input.velocity,
      desiredVelocity: desired,
      desiredYaw: desiredYaw,
      times: times,
    );
    desiredTrajectory = [for (final p in trajectory) p.position];

    if (forced || _sinceSearch >= searchInterval - 1e-6) {
      _search(input, trajectory);
      _sinceSearch = 0.0;
      _desiredAtSearch = desired.clone();
    }
    predictor.record(input.position, input.facingYaw, input.velocity, dt);

    if (_clip >= 0) {
      final s = database.samplerClips[_clip]!;
      database.poser.pose(s, _time, _mirrored, _target);
      if (!_hasShown) {
        _shown.setAll(0, _target);
        _shownPrevious.setAll(0, _target);
        _hasShown = true;
      } else {
        _shownPrevious.setAll(0, _shown);
        inertializer.update(dt, _target, _shown);
        LuminaInertializer.velocities(_shownPrevious, _shown, dt, database.sampler.nodeCount, _shownVelocity);
      }
      matchedRootSpeed = database.rootSpeed(_clip, _time) / input.modelUnitsPerWorldUnit;
      _matchedTrajectory(input);
    }
    watch.stop();
    lastUpdateMicroseconds = watch.elapsedMicroseconds;
    maxUpdateMicroseconds = math.max(maxUpdateMicroseconds, lastUpdateMicroseconds);
    totalUpdateMicroseconds += lastUpdateMicroseconds;
    updateCount++;
  }

  void _weightsFor(bool cold) {
    final index = database.index;
    final trajectoryDims = index.layout.trajectoryDimensions;
    for (var d = 0; d < index.dimensions; d++) {
      final m = d < trajectoryDims ? trajectoryWeight : (cold ? 0.0 : poseWeight);
      _weights[d] = index.weights[d] * m * m;
    }
  }

  void _search(LuminaMotionMatchingInput input, List<LuminaTrajectoryPoint> trajectory) {
    final watch = Stopwatch()..start();
    final index = database.index;
    final layout = index.layout;
    final cold = _clip < 0;
    _weightsFor(cold);
    final current = cold ? -1 : database.rowFor(_clip, _time, _mirrored);
    for (var d = 0; d < index.dimensions; d++) {
      _query[d] = current >= 0 ? index.features[current * index.dimensions + d] : 0.0;
    }
    final scale = input.modelUnitsPerWorldUnit;
    for (var k = 0; k < trajectory.length; k++) {
      final p = trajectory[k];
      final (dx, dz) = LuminaPoseMath.rotateYaw(
          (p.position.x - input.position.x) * scale, (p.position.z - input.position.z) * scale, -input.facingYaw);
      final rel = p.yaw - input.facingYaw;
      final po = layout.trajectoryPositionOffset(k), fo = layout.trajectoryFacingOffset(k);
      void put(int d, double raw) => _query[d] = (raw - index.mean[d]) * index.inverseScale[d];
      put(po, dx);
      put(po + 1, dz);
      put(fo, math.sin(rel));
      put(fo + 1, math.cos(rel));
    }
    final ended = !cold &&
        !database.document.clips[_clip].loop &&
        _time >= database.durationOf(_clip) - 1e-6;
    final continuing = current >= 0 && !ended && index.isSearchable(current) ? index.cost(_query, current, _weights) : double.infinity;
    final mask = requiredTags.isEmpty ? 0 : index.tagMask(requiredTags);
    final bound = continuing.isFinite ? continuing - continuingPoseBias : double.infinity;
    final found = index.search(_query, weights: _weights, requiredTags: mask, bound: bound);
    searchCount++;
    lastContinuingCost = continuing;
    lastSearchCost = found.row >= 0 ? found.cost : continuing;
    if (found.row >= 0) {
      final clip = index.rowClip[found.row];
      final time = index.rowTime[found.row].toDouble();
      final mirrored = index.isMirrored(found.row);
      final same = clip == _clip && mirrored == _mirrored && (time - _time).abs() < 0.2;
      if (!same && database.samplerClips[clip] != null) _switchTo(clip, time, mirrored);
    }
    watch.stop();
    lastSearchMicroseconds = watch.elapsedMicroseconds;
    maxSearchMicroseconds = math.max(maxSearchMicroseconds, lastSearchMicroseconds);
    totalSearchMicroseconds += lastSearchMicroseconds;
  }

  void _switchTo(int clip, double time, bool mirrored) {
    _clip = clip;
    _time = time;
    _mirrored = mirrored;
    switchCount++;
    switches.add((database.document.clips[clip].clip, time, mirrored));
    if (!_hasShown) return;
    final s = database.samplerClips[clip]!;
    const h = 1.0 / 60.0;
    database.poser.pose(s, time, mirrored, _target);
    database.poser.pose(s, math.min(time + h, database.sampler.clips[s].duration), mirrored, _targetAhead);
    LuminaInertializer.velocities(_target, _targetAhead, h, database.sampler.nodeCount, _targetVelocity);
    inertializer.transition(_shown, _shownVelocity, _target, _targetVelocity);
  }

  void _matchedTrajectory(LuminaMotionMatchingInput input) {
    final r = row;
    if (r < 0) return;
    final index = database.index;
    final layout = index.layout;
    final out = <Vector3>[];
    for (var k = 0; k < layout.trajectorySamples; k++) {
      final po = layout.trajectoryPositionOffset(k);
      final (x, z) = LuminaPoseMath.rotateYaw(index.rawFeature(r, po), index.rawFeature(r, po + 1), input.facingYaw);
      out.add(Vector3(input.position.x + x / input.modelUnitsPerWorldUnit, input.position.y,
          input.position.z + z / input.modelUnitsPerWorldUnit));
    }
    matchedTrajectory = out;
  }

  /// Mean search time in microseconds.
  double get meanSearchMicroseconds => searchCount == 0 ? 0 : totalSearchMicroseconds / searchCount;

  /// Mean update time (search amortized, pose, inertialization) in
  /// microseconds.
  double get meanUpdateMicroseconds => updateCount == 0 ? 0 : totalUpdateMicroseconds / updateCount;
}
