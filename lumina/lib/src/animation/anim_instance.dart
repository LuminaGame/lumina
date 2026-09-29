import 'dart:math' as math;
import '../components/mesh/skeletal_mesh_component.dart';
import 'animation_clip.dart';
import 'anim_montage.dart';

enum _MontageBlendState {
  inactive,
  blendingIn,
  fullWeight,
  blendingOut,
}

/// Single node in an animation state machine holding an animation clip or blend space and playback settings.
class AnimState {
  final String name;
  final AnimPoseSource poseSource;
  final bool looping;
  final double playRate;

  AnimState({
    required this.name,
    AnimPoseSource? poseSource,
    LuminaAnimationClip? clip,
    this.looping = true,
    this.playRate = 1.0,
  }) : poseSource = poseSource ?? clip ?? (throw ArgumentError('Either poseSource or clip must be provided'));

  LuminaAnimationClip? get clip => poseSource is LuminaAnimationClip ? poseSource as LuminaAnimationClip : null;
}

/// Transition rule connecting two animation states with a condition and cross-fade duration.
class AnimTransition {
  final String from;
  final String to;
  final bool Function(LuminaAnimInstance anim) condition;
  final double blendDuration;
  final int priority;

  AnimTransition({
    required this.from,
    required this.to,
    required this.condition,
    this.blendDuration = 0.2,
    this.priority = 0,
  });
}

/// Gameplay-driven animation state machine evaluating transitions and driving skeletal bone poses.
class LuminaAnimInstance {
  final LuminaSkinnedMeshComponent mesh;
  final List<AnimState> _states;
  final Map<String, AnimState> _stateMap = {};
  final List<AnimTransition> _transitions;

  /// Generic gameplay variables inspected by transition conditions.
  final Map<String, double> variables = {};

  /// Optional per-frame hook to compute variables from gameplay state before evaluating transitions.
  void Function(LuminaAnimInstance anim, double dt)? nativeUpdateAnimation;

  // State machine fields
  String _currentStateName;
  double _currentStateTime = 0.0;

  bool _isBlending = false;
  String? _sourceStateName;
  double _sourceStateTime = 0.0;
  double _blendElapsed = 0.0;
  double _blendDuration = 0.0;

  // Montage fields
  LuminaAnimMontage? _activeMontage;
  double _montagePosition = 0.0;
  double _montagePlayRate = 1.0;
  double _montageWeight = 0.0;
  _MontageBlendState _montageBlendState = _MontageBlendState.inactive;
  double _montageBlendInElapsed = 0.0;
  double _montageBlendOutDuration = 0.0;
  double _montageBlendOutElapsed = 0.0;
  double _montageBlendOutStartWeight = 1.0;
  bool _isStopInterrupted = false;
  final Map<String, String?> _sectionNextMap = {};

  /// Callback fired when an active montage begins blending out to the underlying base pose.
  void Function(LuminaAnimMontage montage, bool interrupted)? onMontageBlendingOut;

  /// Callback fired when an active montage finishes blending out and stops.
  void Function(LuminaAnimMontage montage, bool interrupted)? onMontageEnded;

  LuminaAnimInstance({
    required this.mesh,
    required List<AnimState> states,
    required List<AnimTransition> transitions,
    required String initialState,
  })  : _states = states,
        _transitions = transitions,
        _currentStateName = initialState {
    for (final s in states) {
      _stateMap[s.name] = s;
    }
    if (!_stateMap.containsKey(initialState)) {
      throw ArgumentError.value(
        initialState,
        'initialState',
        'Initial state "$initialState" not found in provided states',
      );
    }
  }

  /// Sets a gameplay variable by name.
  void setVariable(String name, double value) {
    variables[name] = value;
  }

  /// Retrieves a gameplay variable by name, returning [defaultValue] if unset.
  double getVariable(String name, [double defaultValue = 0.0]) {
    return variables[name] ?? defaultValue;
  }

  /// The active state machine state name.
  String get currentStateName => _currentStateName;

  /// Whether the state machine is currently cross-fading between two states.
  bool get isBlending => _isBlending;

  /// Accumulated time in seconds within the active state.
  double get currentStateTime => _currentStateTime;

  /// Remaining seconds before the active state clip ends (clamps to 0 for non-looping clips).
  double get currentStateTimeRemaining {
    final s = _stateMap[_currentStateName];
    if (s == null) return 0.0;
    return (s.poseSource.phaseDuration - _currentStateTime).clamp(0.0, s.poseSource.phaseDuration);
  }

  // --- Montage Public API ---

  /// Whether an animation montage is currently active and blending or playing over the base pose.
  bool get isMontagePlaying => _activeMontage != null && _montageBlendState != _MontageBlendState.inactive;

  /// Current playback position in seconds within the active montage clip.
  double get montagePosition => _montagePosition;

  /// Name of the montage section currently containing [montagePosition].
  String? get currentMontageSection {
    if (_activeMontage == null) return null;
    final sections = _activeMontage!.sections;
    if (sections.isEmpty) return 'default';
    for (int i = sections.length - 1; i >= 0; i--) {
      if (_montagePosition >= sections[i].startTime) {
        return sections[i].name;
      }
    }
    return sections.first.name;
  }

  /// Starts playback of [montage], returning total length in seconds (or 0.0 on failure).
  double montagePlay(
    LuminaAnimMontage montage, {
    double playRate = 1.0,
    String? startSection,
  }) {
    if (montage.clip.duration <= 0.0) return 0.0;

    double startTime = 0.0;
    if (startSection != null) {
      final sec = montage.sections.where((s) => s.name == startSection).firstOrNull;
      if (sec == null) return 0.0;
      startTime = sec.startTime;
    }

    if (_activeMontage != null && _montageBlendState != _MontageBlendState.inactive) {
      final old = _activeMontage!;
      _activeMontage = null;
      _montageBlendState = _MontageBlendState.inactive;
      onMontageEnded?.call(old, true);
    }

    _sectionNextMap.clear();
    for (final s in montage.sections) {
      _sectionNextMap[s.name] = s.nextSection;
    }

    _activeMontage = montage;
    _montagePosition = startTime;
    _montagePlayRate = playRate;
    _isStopInterrupted = false;

    if (montage.blendInTime <= 0.0) {
      _montageWeight = 1.0;
      _montageBlendState = _MontageBlendState.fullWeight;
    } else {
      _montageWeight = 0.0;
      _montageBlendInElapsed = 0.0;
      _montageBlendState = _MontageBlendState.blendingIn;
    }

    return montage.clip.duration / playRate.abs();
  }

  /// Stops the currently playing montage and ramps its weight to zero over [blendOutTime].
  void montageStop({double? blendOutTime}) {
    if (!isMontagePlaying) return;

    final duration = blendOutTime ?? _activeMontage!.blendOutTime;
    _isStopInterrupted = true;

    if (duration <= 0.0) {
      final m = _activeMontage!;
      _activeMontage = null;
      _montageWeight = 0.0;
      _montageBlendState = _MontageBlendState.inactive;
      onMontageBlendingOut?.call(m, true);
      onMontageEnded?.call(m, true);
    } else {
      _montageBlendOutDuration = duration;
      _montageBlendOutElapsed = 0.0;
      _montageBlendOutStartWeight = _montageWeight;
      _montageBlendState = _MontageBlendState.blendingOut;
      onMontageBlendingOut?.call(_activeMontage!, true);
    }
  }

  /// Immediately seeks montage playback to the beginning of section [sectionName] without firing intervening notifies.
  void montageJumpToSection(String sectionName) {
    if (_activeMontage == null) return;
    final sec = _activeMontage!.sections.where((s) => s.name == sectionName).firstOrNull;
    if (sec != null) {
      _montagePosition = sec.startTime;
    }
  }

  /// Dynamically changes which section follows section [from] when it reaches its end.
  void montageSetNextSection(String from, String to) {
    _sectionNextMap[from] = to;
  }

  /// Advances the animation state machine and any active montage by [deltaTime] seconds.
  void update(double deltaTime) {
    // 1. Native update hook
    nativeUpdateAnimation?.call(this, deltaTime);

    // 2. Evaluate state machine transitions in priority order
    final activeSource = _currentStateName;
    final availableTransitions = _transitions
        .where((t) => t.from == activeSource)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final t in availableTransitions) {
      if (t.condition(this)) {
        if (t.to != _currentStateName) {
          if (t.blendDuration <= 0.0) {
            _isBlending = false;
            _sourceStateName = null;
            _currentStateName = t.to;
            _currentStateTime = 0.0;
          } else {
            _sourceStateName = _currentStateName;
            _sourceStateTime = _currentStateTime;
            _currentStateName = t.to;
            _currentStateTime = 0.0;
            _blendElapsed = 0.0;
            _blendDuration = t.blendDuration;
            _isBlending = true;
          }
          break;
        }
      }
    }

    // 3. Advance state machine times
    final currState = _stateMap[_currentStateName]!;
    _currentStateTime += deltaTime * currState.playRate;
    currState.poseSource.advance(deltaTime * currState.playRate);

    if (_isBlending && _sourceStateName != null) {
      _blendElapsed += deltaTime;
      final srcState = _stateMap[_sourceStateName]!;
      _sourceStateTime += deltaTime * srcState.playRate;
      srcState.poseSource.advance(deltaTime * srcState.playRate);
      if (_blendElapsed >= _blendDuration) {
        _isBlending = false;
        _sourceStateName = null;
      }
    }

    // 4. Sample base state machine pose into skeletal mesh localTransforms
    final skel = mesh.skeleton;
    if (skel == null) return;

    final outPose = [for (int i = 0; i < skel.boneCount; i++) skel[i].localTransform];

    if (!_isBlending || _sourceStateName == null) {
      currState.poseSource.samplePose(
        _currentStateTime,
        outPose,
        looping: currState.looping,
      );
    } else {
      final srcState = _stateMap[_sourceStateName]!;
      final alpha = _blendDuration > 1e-8 ? (_blendElapsed / _blendDuration).clamp(0.0, 1.0) : 1.0;

      srcState.poseSource.samplePose(
        _sourceStateTime,
        outPose,
        looping: srcState.looping,
      );

      currState.poseSource.samplePose(
        _currentStateTime,
        outPose,
        looping: currState.looping,
        weight: alpha,
      );
    }

    // 5. Process active montage
    final deferredCallbacks = <void Function()>[];

    if (_activeMontage != null && _montageBlendState != _MontageBlendState.inactive) {
      final montage = _activeMontage!;
      final prevPos = _montagePosition;
      final step = deltaTime * _montagePlayRate;
      var newPos = prevPos + step;

      // Section boundary and chaining handling
      final currentSecName = currentMontageSection;
      if (currentSecName != null) {
        final secIdx = montage.sections.indexWhere((s) => s.name == currentSecName);
        final secEnd = (secIdx + 1 < montage.sections.length)
            ? montage.sections[secIdx + 1].startTime
            : montage.clip.duration;

        if (newPos >= secEnd) {
          final nextSecName = _sectionNextMap[currentSecName];
          if (nextSecName != null) {
            final nextSec = montage.sections.where((s) => s.name == nextSecName).firstOrNull;
            if (nextSec != null) {
              final overflow = newPos - secEnd;
              newPos = nextSec.startTime + overflow;
            }
          }
        }
      }

      // Collect notifies in interval (prevPos, newPos]
      for (final notify in montage.notifies) {
        if (notify.time > prevPos && notify.time <= newPos) {
          deferredCallbacks.add(() => notify.callback?.call(this));
        }
      }

      _montagePosition = newPos;

      // Auto blend-out trigger check
      final remaining = montage.clip.duration - _montagePosition;
      if ((_montageBlendState == _MontageBlendState.fullWeight || _montageBlendState == _MontageBlendState.blendingIn) &&
          remaining <= montage.blendOutTime) {
        _montageBlendState = _MontageBlendState.blendingOut;
        _montageBlendOutDuration = montage.blendOutTime;
        _montageBlendOutElapsed = montage.blendOutTime - remaining;
        _montageBlendOutStartWeight = _montageWeight;
        _isStopInterrupted = false;
        deferredCallbacks.add(() => onMontageBlendingOut?.call(montage, false));
      }

      // Update blend weights
      if (_montageBlendState == _MontageBlendState.blendingIn) {
        _montageBlendInElapsed += deltaTime;
        _montageWeight = (_montageBlendInElapsed / montage.blendInTime).clamp(0.0, 1.0);
        if (_montageBlendInElapsed >= montage.blendInTime) {
          _montageWeight = 1.0;
          _montageBlendState = _MontageBlendState.fullWeight;
        }
      } else if (_montageBlendState == _MontageBlendState.blendingOut) {
        _montageBlendOutElapsed += deltaTime;
        final p = _montageBlendOutDuration > 1e-8
            ? (_montageBlendOutElapsed / _montageBlendOutDuration).clamp(0.0, 1.0)
            : 1.0;
        _montageWeight = _montageBlendOutStartWeight * (1.0 - p);

        if (p >= 1.0 || _montagePosition >= montage.clip.duration) {
          _montageWeight = 0.0;
          _montageBlendState = _MontageBlendState.inactive;
          final endedMontage = _activeMontage!;
          final interrupted = _isStopInterrupted;
          _activeMontage = null;
          deferredCallbacks.add(() => onMontageEnded?.call(endedMontage, interrupted));
        }
      }

      // Layer montage pose over base pose
      if (_montageWeight > 0.0) {
        montage.clip.samplePose(
          _montagePosition,
          outPose,
          looping: false,
          weight: _montageWeight,
        );
      }
    }

    // 6. Recompute forward kinematics
    skel.updateGlobalTransforms();

    // 7. Execute deferred callbacks
    for (final cb in deferredCallbacks) {
      cb();
    }
  }
}
