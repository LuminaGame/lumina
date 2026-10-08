import 'dart:developer' as developer;

import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/mesh/mesh_pose_driver.dart';
import 'package:lumina/src/components/mesh/morph_targets.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';

/// A local-space delta multiplied onto one animated joint every frame:
/// `joint = animated · T(translation) · R(rotation)`.
class LuminaJointOverride {
  final Quaternion rotation;
  final Vector3 translation;

  LuminaJointOverride({Quaternion? rotation, Vector3? translation})
      : rotation = rotation?.clone() ?? Quaternion.identity(),
        translation = translation?.clone() ?? Vector3.zero();

  /// The delta as a matrix (translation, then rotation).
  Matrix4 get matrix => Matrix4.compose(translation, rotation, Vector3.all(1.0));

  /// The rotation's angle in degrees.
  double get rotationDegrees => rotation.radians.abs() * 180.0 / 3.141592653589793;
}

/// A skinned glTF/GLB mesh that plays the animation clips stored in it, through
/// gltfio's animator.
///
/// gltfio only animates the asset a clip is stored in, so every clip the mesh
/// should play must live in the same GLB — see `GlbAnimationMerger`, which
/// builds such a file from one-clip-per-file exports. Each component draws its
/// own asset instance with its own animator, so characters sharing one cached
/// GLB animate independently.
///
/// Clips are addressed by name. A request made before the asset has loaded is
/// remembered and applied on load (an unknown name is then left unplayed and
/// reported through [missingClip]); after load an unknown name throws.
class LuminaAnimatedMeshComponent extends LuminaStaticMeshComponent with LuminaMorphTargets {
  LuminaAnimatedMeshComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required super.meshAssetPath,
    super.castShadows,
    super.receiveShadows,
    super.visible,
    super.assetProvider,
    super.assetUnitScale,
  });

  @override
  bool get drawsSlotMaterials => false;

  FilamentAnimator? _animator;
  List<String> _clipNames = const [];
  List<double> _durations = const [];
  final Map<String, int> _clipIndex = {};

  int _current = -1;
  double _time = 0.0;
  bool _loop = true;

  int _previous = -1;
  double _previousTime = 0.0;
  bool _previousLoop = true;
  double _fadeElapsed = 0.0;
  double _fadeDuration = 0.0;

  String? _pendingClip;
  double _pendingStart = 0.0;
  bool _pendingLoop = true;

  double _playRate = 1.0;

  /// A clip requested before load that the asset turned out not to have.
  String? missingClip;

  /// The skin joint entities, once loaded, and the bones resolved by name
  /// (gltfio finds a node by name; it cannot name an entity without a name
  /// manager, so bones are looked up on first use).
  final Set<int> _jointSet = {};
  final Map<String, int?> _jointEntities = {};
  FilamentAsset? _asset;
  final Map<String, LuminaJointOverride> _jointOverrides = {};
  final Map<String, List<double>> _overrideBase = {};
  final Map<String, List<double>> _overrideWritten = {};
  final Set<String> _warnedBones = {};

  LuminaMeshPoseDriver? _poseDriver;
  List<int?> _driverJoints = const [];

  /// A CPU pose source that replaces gltfio's animator while set (motion
  /// matching): every frame its pose is written to the skin joints of the
  /// same names, then joint overrides apply and the bone matrices update.
  /// Setting null hands the joints back to the playing clip.
  LuminaMeshPoseDriver? get poseDriver => _poseDriver;
  set poseDriver(LuminaMeshPoseDriver? driver) {
    _poseDriver = driver;
    _driverJoints = const [];
  }

  final List<double> _driverMatrix = List<double>.filled(16, 0.0);

  /// Writes the driver's pose onto the joints; false when it gave none.
  bool _applyPoseDriver(FilamentTransformManager tm, double deltaTime) {
    final driver = _poseDriver!;
    final pose = driver.evaluatePose(deltaTime);
    if (pose == null) return false;
    if (_driverJoints.length != driver.poseNodeNames.length) {
      _driverJoints = [for (final name in driver.poseNodeNames) _joint(name)];
    }
    final m = _driverMatrix;
    for (var i = 0; i < _driverJoints.length; i++) {
      final entity = _driverJoints[i];
      if (entity == null) continue;
      final o = i * 10;
      final x = pose[o + 3], y = pose[o + 4], z = pose[o + 5], w = pose[o + 6];
      final sx = pose[o + 7], sy = pose[o + 8], sz = pose[o + 9];
      final xx = x * x, yy = y * y, zz = z * z, xy = x * y, xz = x * z, yz = y * z, wx = w * x, wy = w * y, wz = w * z;
      m[0] = (1 - 2 * (yy + zz)) * sx;
      m[1] = 2 * (xy + wz) * sx;
      m[2] = 2 * (xz - wy) * sx;
      m[3] = 0.0;
      m[4] = 2 * (xy - wz) * sy;
      m[5] = (1 - 2 * (xx + zz)) * sy;
      m[6] = 2 * (yz + wx) * sy;
      m[7] = 0.0;
      m[8] = 2 * (xz + wy) * sz;
      m[9] = 2 * (yz - wx) * sz;
      m[10] = (1 - 2 * (xx + yy)) * sz;
      m[11] = 0.0;
      m[12] = pose[o];
      m[13] = pose[o + 1];
      m[14] = pose[o + 2];
      m[15] = 1.0;
      tm.setTransform(entity, m);
    }
    return true;
  }

  /// The joint overrides in force, by bone name.
  Map<String, LuminaJointOverride> get jointOverrides => Map.unmodifiable(_jointOverrides);

  /// The overridden bones the mesh turned out not to have, each logged once.
  Set<String> get missingJointOverrideBones => Set.unmodifiable(_warnedBones);

  /// Whether the loaded mesh has a skin joint named [bone].
  bool hasJoint(String bone) => _joint(bone) != null;

  /// [bone]'s skin joint entity, or null before load / for a node that is
  /// not a joint of any skin.
  int? _joint(String bone) {
    final asset = _asset;
    if (asset == null) return null;
    return _jointEntities.putIfAbsent(bone, () {
      final entity = asset.getFirstEntityByName(bone);
      return entity != 0 && _jointSet.contains(entity) ? entity : null;
    });
  }

  /// Multiplies a local-space delta onto [bone]'s animated transform every
  /// frame, after the clip is applied and before the bone matrices update
  /// (e.g. an aim offset): `joint = animated · T · R`. Replaces an
  /// earlier override of the same bone; a bone the mesh lacks is logged once
  /// and ignored.
  void setJointOverride(String bone, {Quaternion? rotation, Vector3? translation}) {
    _jointOverrides[bone] = LuminaJointOverride(rotation: rotation, translation: translation);
    if (_asset != null && _joint(bone) == null) _warnMissingBone(bone);
  }

  /// Drops [bone]'s override; the animated transform is restored next frame
  /// (at once when no clip animates the bone).
  void clearJointOverride(String bone) {
    if (_jointOverrides.remove(bone) == null) return;
    final base = _overrideBase.remove(bone);
    _overrideWritten.remove(bone);
    final entity = _joint(bone);
    final engine = owner?.world?.nativeEngine;
    if (base != null && entity != null && engine != null) {
      FilamentTransformManager(engine).setTransform(entity, base);
    }
  }

  /// [bone]'s local transform (relative to its parent joint), as the
  /// transform manager holds it now; null before load or for an unknown bone.
  Matrix4? jointLocalTransform(String bone) {
    final entity = _joint(bone);
    final engine = owner?.world?.nativeEngine;
    if (entity == null || engine == null) return null;
    return Matrix4.fromList(FilamentTransformManager(engine).getTransform(entity));
  }

  /// [bone]'s world transform (Filament's, including the owner's), as the
  /// transform manager holds it now; null before load or for an unknown bone.
  Matrix4? jointWorldTransform(String bone) {
    final entity = _joint(bone);
    final engine = owner?.world?.nativeEngine;
    if (entity == null || engine == null) return null;
    return Matrix4.fromList(FilamentTransformManager(engine).getWorldTransform(entity));
  }

  void _warnMissingBone(String bone) {
    if (!_warnedBones.add(bone)) return;
    developer.log("joint override: the mesh $meshAssetPath has no bone '$bone'", name: 'LuminaAnimatedMeshComponent', level: 900);
  }

  /// Writes every override onto its joint: the animated local transform read
  /// back from the transform manager (or, when the playing clip does not
  /// touch the bone and the read equals what was written last frame, the
  /// transform from before the first override) times the delta.
  void _applyJointOverrides(FilamentTransformManager tm) {
    if (_jointOverrides.isEmpty) return;
    for (final entry in _jointOverrides.entries) {
      final entity = _joint(entry.key);
      if (entity == null) {
        _warnMissingBone(entry.key);
        continue;
      }
      final current = tm.getTransform(entity);
      final written = _overrideWritten[entry.key];
      List<double> base;
      if (written != null && _same(current, written) && _overrideBase.containsKey(entry.key)) {
        base = _overrideBase[entry.key]!;
      } else {
        base = current;
        _overrideBase[entry.key] = current;
      }
      final result = Matrix4.fromList(base)..multiply(entry.value.matrix);
      final out = result.storage.toList();
      tm.setTransform(entity, out);
      _overrideWritten[entry.key] = out;
    }
  }

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < 16; i++) {
      if ((a[i] - b[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// The clips stored in the mesh, in gltfio index order. Empty until loaded.
  List<String> get clipNames => List.unmodifiable(_clipNames);

  bool hasClip(String clip) => _clipIndex.containsKey(clip);

  /// Length of [clip] in seconds.
  double clipDuration(String clip) => _durations[_indexOf(clip)];

  /// The clip playing now (the fade target while cross-fading), or null.
  String? get currentClip => _current >= 0 ? _clipNames[_current] : _pendingClip;

  /// Seconds into [currentClip].
  double get currentTime => _current >= 0 ? _time : _pendingStart;

  bool get isCrossFading => _previous >= 0;

  /// Clip seconds per real second. 0 freezes the pose.
  double get playRate => _playRate;
  set playRate(double value) {
    if (value < 0.0) {
      throw ArgumentError.value(value, 'playRate', 'must not be negative');
    }
    _playRate = value;
  }

  /// Snaps to [clip] at [startTime], dropping any cross-fade in progress.
  void play(String clip, {double startTime = 0.0, bool loop = true}) {
    if (_animator == null) {
      _pendingClip = clip;
      _pendingStart = startTime;
      _pendingLoop = loop;
      return;
    }
    _current = _indexOf(clip);
    _loop = loop;
    _time = _wrap(startTime, _durations[_current], loop);
    _previous = -1;
  }

  /// Blends from the current pose to [clip] over [duration] seconds.
  ///
  /// [syncPhase] starts [clip] at the current clip's normalized phase, so two
  /// walk cycles of different lengths keep their footfalls lined up. Fading to
  /// the clip that is already playing does nothing.
  void crossFadeTo(
    String clip, {
    double duration = 0.2,
    bool syncPhase = false,
    bool loop = true,
  }) {
    if (_animator == null) {
      play(clip, loop: loop);
      return;
    }
    final target = _indexOf(clip);
    if (target == _current) return;
    if (_current < 0 || duration <= 0.0) {
      play(clip, loop: loop);
      return;
    }

    final phase = _durations[_current] > 0.0 ? _time / _durations[_current] : 0.0;
    _previous = _current;
    _previousTime = _time;
    _previousLoop = _loop;
    _fadeElapsed = 0.0;
    _fadeDuration = duration;

    _current = target;
    _loop = loop;
    _time = syncPhase ? _wrap(phase * _durations[target], _durations[target], loop) : 0.0;
  }

  @override
  void onAssetLoaded(FilamentAssetInstance instance) {
    super.onAssetLoaded(instance);
    final animator = instance.animator;
    final count = animator.animationCount;
    _clipNames = [for (var i = 0; i < count; i++) animator.getAnimationName(i)];
    _durations = [for (var i = 0; i < count; i++) animator.getAnimationDuration(i)];
    _clipIndex
      ..clear()
      ..addAll({for (var i = 0; i < count; i++) _clipNames[i]: i});
    _animator = animator;
    _jointSet.clear();
    _jointEntities.clear();
    _driverJoints = const [];
    _overrideBase.clear();
    _overrideWritten.clear();
    _asset = instance.getAsset();
    discoverMorphTargetsOf(_asset!, instance.entities);
    for (var skin = 0; skin < instance.skinCount; skin++) {
      _jointSet.addAll(instance.jointsAt(skin));
    }
    for (final bone in _jointOverrides.keys) {
      if (_joint(bone) == null) _warnMissingBone(bone);
    }

    final pending = _pendingClip;
    _pendingClip = null;
    if (pending != null) {
      if (hasClip(pending)) {
        play(pending, startTime: _pendingStart, loop: _pendingLoop);
        _apply(0.0);
      } else {
        missingClip = pending;
      }
    }
  }

  /// Stops playback: the mesh holds its current pose and [currentClip] is
  /// null until the next [play].
  void stop() {
    _current = -1;
    _previous = -1;
    _pendingClip = null;
    _time = 0.0;
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _apply(deltaTime);
    flushMorphTargets();
  }

  void _apply(double deltaTime) {
    final animator = _animator;
    if (animator == null) return;
    final engine = owner?.world?.nativeEngine;
    if (_poseDriver != null && engine != null && _applyPoseDriver(FilamentTransformManager(engine), deltaTime)) {
      _applyJointOverrides(FilamentTransformManager(engine));
      animator.updateBoneMatrices();
      return;
    }
    if (_current < 0 && _jointOverrides.isEmpty) return;

    if (_current >= 0) {
      final step = deltaTime * _playRate;
      _time = _wrap(_time + step, _durations[_current], _loop);
      animator.applyAnimation(_current, _time);

      if (_previous >= 0) {
        _fadeElapsed += deltaTime;
        _previousTime = _wrap(_previousTime + step, _durations[_previous], _previousLoop);
        final alpha = (_fadeElapsed / _fadeDuration).clamp(0.0, 1.0);
        if (alpha >= 1.0) {
          _previous = -1;
        } else {
          // gltfio: the clip given to applyAnimation is alpha 1, this one alpha 0.
          animator.applyCrossFade(_previous, _previousTime, alpha);
        }
      }
    }
    // Joint overrides go on after the clip and before the bone matrices, or
    // the clip would overwrite them.
    if (engine != null) _applyJointOverrides(FilamentTransformManager(engine));
    animator.updateBoneMatrices();
  }

  int _indexOf(String clip) {
    final index = _clipIndex[clip];
    if (index == null) {
      throw ArgumentError.value(
        clip,
        'clip',
        _clipNames.isEmpty ? 'the mesh has no animation clips' : 'not in the mesh; it has ${_clipNames.join(', ')}',
      );
    }
    return index;
  }

  static double _wrap(double time, double duration, bool loop) {
    if (duration <= 0.0) return 0.0;
    if (!loop) return time.clamp(0.0, duration).toDouble();
    final t = time % duration;
    return t < 0.0 ? t + duration : t;
  }
}
