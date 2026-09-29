import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../collision/collision_query.dart';
import '../collision/collision_subsystem.dart';
import '../components/base/actor_component.dart';
import '../object/actor.dart';
import '../object/pawn.dart';
import '../world/debug_shapes.dart';
import '../world/subsystem/world_subsystem.dart';
import '../world/world.dart';
import '../math/euler.dart';

/// Configuration parameters for the visual perception sense.
class AISenseConfigSight {
  double sightRadius;
  double loseSightRadius;
  double peripheralVisionAngleDegrees;
  double maxAge;
  bool detectEnemies;
  bool detectNeutrals;
  bool detectFriendlies;

  AISenseConfigSight({
    this.sightRadius = 1500.0, // cm
    this.loseSightRadius = 1800.0,
    this.peripheralVisionAngleDegrees = 70.0,
    this.maxAge = 5.0,
    this.detectEnemies = true,
    this.detectNeutrals = true,
    this.detectFriendlies = true,
  });
}

/// Configuration parameters for the auditory perception sense.
class AISenseConfigHearing {
  double hearingRange;
  double maxAge;

  AISenseConfigHearing({
    this.hearingRange = 2000.0, // cm
    this.maxAge = 5.0,
  });
}

/// Category of AI sensory perception.
enum AISenseType {
  sight,
  hearing,
}

/// Record of a sensory stimulus received by an AI perception component.
class AIStimulus {
  final AISenseType type;
  final bool wasSuccessfullySensed;
  final Vector3 stimulusLocation;
  final Vector3 receiverLocation;
  final double strength;
  double age;
  final double maxAge;

  AIStimulus({
    required this.type,
    required this.wasSuccessfullySensed,
    required this.stimulusLocation,
    required this.receiverLocation,
    required this.strength,
    this.age = 0.0,
    this.maxAge = 5.0,
  });

  bool get isExpired => age >= maxAge;
}

/// Actor component providing sight cones, LOS raycasting, and noise hearing perception.
class LuminaAIPerceptionComponent extends LuminaActorComponent {
  AISenseConfigSight? sightConfig;
  AISenseConfigHearing? hearingConfig;
  double updateInterval;
  AISenseType dominantSense;

  /// Records every sight line-of-sight trace in `LuminaWorld.debugShapes`
  /// (debug colours: green up to the hit or the target, red past a
  /// blocking hit), for the viewport's debug draw.
  bool drawDebugSight;

  void Function(LuminaActor target, AIStimulus stimulus)? onTargetPerceptionUpdated;
  void Function(LuminaActor target)? onTargetPerceptionForgotten;

  final Map<LuminaActor, Map<AISenseType, AIStimulus>> _perceived = {};
  double _timeSinceLastSightUpdate = 0.0;

  LuminaAIPerceptionComponent({
    this.sightConfig,
    this.hearingConfig,
    this.updateInterval = 0.25,
    this.dominantSense = AISenseType.sight,
    this.drawDebugSight = false,
  });

  /// Returns all currently perceived actors filtered by optional [sense].
  List<LuminaActor> getCurrentlyPerceivedActors({AISenseType? sense}) {
    final list = <LuminaActor>[];
    for (final entry in _perceived.entries) {
      if (sense != null) {
        final stim = entry.value[sense];
        if (stim != null && stim.wasSuccessfullySensed && !stim.isExpired) {
          list.add(entry.key);
        }
      } else {
        final anyActive = entry.value.values.any((s) => s.wasSuccessfullySensed && !s.isExpired);
        if (anyActive) {
          list.add(entry.key);
        }
      }
    }
    return list;
  }

  /// Retrieves the current stimulus for [target] and [sense].
  AIStimulus? getStimulusFor(LuminaActor target, AISenseType sense) {
    return _perceived[target]?[sense];
  }

  void receiveNoiseStimulus(Vector3 location, double strength, LuminaActor? instigator) {
    if (owner == null) return;
    if (instigator == owner) return; // Self-filter

    final targetActor = instigator ?? LuminaActor(location: location);
    final receiverLoc = owner!.actorLocation;

    final stimulus = AIStimulus(
      type: AISenseType.hearing,
      wasSuccessfullySensed: true,
      stimulusLocation: location.clone(),
      receiverLocation: receiverLoc.clone(),
      strength: strength,
      maxAge: hearingConfig?.maxAge ?? 5.0,
    );

    final targetMap = _perceived.putIfAbsent(targetActor, () => {});
    final prev = targetMap[AISenseType.hearing];
    targetMap[AISenseType.hearing] = stimulus;

    if (prev == null || !prev.wasSuccessfullySensed) {
      onTargetPerceptionUpdated?.call(targetActor, stimulus);
    }
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    final percepSys = ownerActor.world?.subsystems.getSubsystem<LuminaAIPerceptionSystem>();
    percepSys?.registerListener(this);
  }

  @override
  void onUnregister() {
    final percepSys = owner?.world?.subsystems.getSubsystem<LuminaAIPerceptionSystem>();
    percepSys?.unregisterListener(this);
    super.onUnregister();
  }

  @override
  void onTick(double deltaTime) {
    if (owner == null) return;
    final currentOwner = owner!;

    // 1. Age stimuli and prune expired
    final targetsToRemove = <LuminaActor>[];
    for (final entry in _perceived.entries) {
      final target = entry.key;
      final sensesMap = entry.value;

      final sensesToRemove = <AISenseType>[];
      for (final sEntry in sensesMap.entries) {
        sEntry.value.age += deltaTime;
        if (sEntry.value.isExpired) {
          sensesToRemove.add(sEntry.key);
        }
      }
      for (final s in sensesToRemove) {
        sensesMap.remove(s);
      }

      if (sensesMap.isEmpty) {
        targetsToRemove.add(target);
      }
    }

    for (final t in targetsToRemove) {
      _perceived.remove(t);
      onTargetPerceptionForgotten?.call(t);
    }

    // 2. Sight update pass
    if (sightConfig != null) {
      _timeSinceLastSightUpdate += deltaTime;
      if (_timeSinceLastSightUpdate >= updateInterval) {
        _timeSinceLastSightUpdate = 0.0;
        _runSightPass(currentOwner);
      }
    }
  }

  void _debugSightTrace(LuminaActor currentOwner, Vector3 start, Vector3 end, HitResult? hit) {
    final world = currentOwner.world;
    if (world == null) return;
    final until = world.realTimeSeconds + updateInterval;
    const green = [0.0, 1.0, 0.0, 1.0];
    const red = [1.0, 0.0, 0.0, 1.0];
    LuminaDebugShape line(Vector3 a, Vector3 b, List<double> color) =>
        LuminaDebugShape(kind: LuminaDebugShapeKind.line, points: [a.clone(), b.clone()], color: color, duration: updateInterval, expiresAt: until);
    if (hit != null && hit.blockingHit) {
      world.addDebugShape(line(start, hit.impactPoint, green));
      world.addDebugShape(line(hit.impactPoint, end, red));
    } else {
      world.addDebugShape(line(start, end, green));
    }
  }

  void _runSightPass(LuminaActor currentOwner) {
    final percepSys = currentOwner.world?.subsystems.getSubsystem<LuminaAIPerceptionSystem>();
    if (percepSys == null) return;

    final colSys = currentOwner.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();

    final cfg = sightConfig!;
    final sources = percepSys.getSourcesFor(AISenseType.sight);

    Vector3 viewerPos = currentOwner.actorLocation;
    Vector3 viewerForward = Vector3(0.0, 0.0, 1.0);

    if (currentOwner is LuminaPawn && currentOwner.controller != null) {
      // Control rotation yaw: degrees, 0 facing −Z, as the
      // player controller and LuminaPawn.faceRotation read it.
      final yaw = currentOwner.controller!.controlRotation.y * math.pi / 180.0;
      viewerForward = Vector3(math.sin(yaw), 0.0, -math.cos(yaw));
    } else {
      // The actor's drawn +Z (a rotation means what it draws).
      viewerForward = currentOwner.actorRotation.rotateVector(Vector3(0.0, 0.0, 1.0));
      viewerForward.y = 0.0;
      if (viewerForward.length > 1e-6) {
        viewerForward.normalize();
      }
    }

    final eyes = currentOwner is LuminaPawn ? currentOwner.getActorEyesViewPoint().location : viewerPos.clone();
    final cosThreshold = math.cos(cfg.peripheralVisionAngleDegrees * math.pi / 180.0);

    for (final target in sources) {
      if (target == currentOwner) continue; // Self-filter

      final targetPos = target.actorLocation;
      final delta = targetPos - viewerPos;
      final dist = delta.length;

      final targetMap = _perceived.putIfAbsent(target, () => {});
      final prevSight = targetMap[AISenseType.sight];
      final wasSensed = prevSight != null && prevSight.wasSuccessfullySensed && !prevSight.isExpired;

      // Gate 1: Range check with hysteresis
      final maxRange = wasSensed ? cfg.loseSightRadius : cfg.sightRadius;
      if (dist > maxRange) {
        if (wasSensed) {
          final stimulus = AIStimulus(
            type: AISenseType.sight,
            wasSuccessfullySensed: false,
            stimulusLocation: targetPos.clone(),
            receiverLocation: viewerPos.clone(),
            strength: 0.0,
            maxAge: cfg.maxAge,
          );
          targetMap[AISenseType.sight] = stimulus;
          onTargetPerceptionUpdated?.call(target, stimulus);
        }
        continue;
      }

      // Gate 2: Vision cone check
      if (dist > 1e-6) {
        final dirToTarget = delta / dist;
        final cosAngle = viewerForward.dot(dirToTarget);
        if (cosAngle < cosThreshold) {
          if (wasSensed) {
            final stimulus = AIStimulus(
              type: AISenseType.sight,
              wasSuccessfullySensed: false,
              stimulusLocation: targetPos.clone(),
              receiverLocation: viewerPos.clone(),
              strength: 0.0,
              maxAge: cfg.maxAge,
            );
            targetMap[AISenseType.sight] = stimulus;
            onTargetPerceptionUpdated?.call(target, stimulus);
          }
          continue;
        }
      }

      // Gate 3: LOS raycast check
      // From the viewer's eyes (`baseEyeHeight` above a pawn's capsule
      // centre) to the target's location.
      bool hasLOS = true;
      if (colSys != null) {
        final hit = HitResult();
        final blocked = colSys.lineTraceSingle(
          start: eyes,
          end: targetPos,
          out: hit,
          ignoreActors: [currentOwner, target],
        );
        if (blocked) {
          hasLOS = false;
        }
        if (drawDebugSight) _debugSightTrace(currentOwner, eyes, targetPos, blocked ? hit : null);
      }

      if (hasLOS) {
        final stimulus = AIStimulus(
          type: AISenseType.sight,
          wasSuccessfullySensed: true,
          stimulusLocation: targetPos.clone(),
          receiverLocation: viewerPos.clone(),
          strength: 1.0 - (dist / cfg.sightRadius).clamp(0.0, 1.0),
          maxAge: cfg.maxAge,
        );
        targetMap[AISenseType.sight] = stimulus;
        if (!wasSensed) {
          onTargetPerceptionUpdated?.call(target, stimulus);
        }
      } else {
        if (wasSensed) {
          final stimulus = AIStimulus(
            type: AISenseType.sight,
            wasSuccessfullySensed: false,
            stimulusLocation: targetPos.clone(),
            receiverLocation: viewerPos.clone(),
            strength: 0.0,
            maxAge: cfg.maxAge,
          );
          targetMap[AISenseType.sight] = stimulus;
          onTargetPerceptionUpdated?.call(target, stimulus);
        }
      }
    }
  }
}

/// Central world subsystem maintaining registries of perception sources and listeners and routing stimuli.
class LuminaAIPerceptionSystem extends LuminaWorldSubsystem {
  final Map<LuminaActor, Set<AISenseType>> _sources = {};
  final List<LuminaAIPerceptionComponent> _listeners = [];

  void registerSource(
    LuminaActor actor, {
    Set<AISenseType> senses = const {AISenseType.sight, AISenseType.hearing},
  }) {
    _sources[actor] = Set.from(senses);
  }

  void unregisterSource(LuminaActor actor) {
    _sources.remove(actor);
  }

  void registerListener(LuminaAIPerceptionComponent listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void unregisterListener(LuminaAIPerceptionComponent listener) {
    _listeners.remove(listener);
  }

  List<LuminaActor> getSourcesFor(AISenseType sense) {
    final list = <LuminaActor>[];
    for (final entry in _sources.entries) {
      if (entry.value.contains(sense)) {
        list.add(entry.key);
      }
    }
    return list;
  }

  /// Broadcasts a sound noise event to all perception listeners in the world.
  static void reportNoiseEvent(
    LuminaWorld world,
    Vector3 location, {
    double loudness = 1.0,
    LuminaActor? instigator,
    double maxRange = 0.0,
  }) {
    final percepSys = world.subsystems.getSubsystem<LuminaAIPerceptionSystem>();
    if (percepSys == null) return;

    final listenersCopy = List<LuminaAIPerceptionComponent>.from(percepSys._listeners);
    for (final listener in listenersCopy) {
      if (listener.hearingConfig == null) continue;
      if (listener.owner == instigator) continue;

      final receiverLoc = listener.owner?.actorLocation ?? Vector3.zero();
      final dist = (receiverLoc - location).length;
      final hearingRange = listener.hearingConfig!.hearingRange * loudness;

      if (maxRange > 0.0 && dist > maxRange) continue;
      if (dist <= hearingRange) {
        final strength = 1.0 - (dist / hearingRange);
        listener.receiveNoiseStimulus(location, strength, instigator);
      }
    }
  }
}
