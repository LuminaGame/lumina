import 'package:vector_math/vector_math_64.dart';
import '../object/actor.dart';
import '../components/collision/collision_component.dart';
import '../world/world.dart';
import '../math/euler.dart';

/// Base volume actor providing oriented bounding box tests and standardized collision component root.
class LuminaVolume extends LuminaActor {
  LuminaVolume({
    Vector3? extent,
    super.key,
    super.location,
    super.rotation,
  }) : super(
          root: LuminaCollisionComponent(
            shapeType: CollisionShapeType.box,
          )..boxExtent.setFrom(extent ?? Vector3(50.0, 50.0, 50.0)),
        );

  /// Typed accessor to the underlying collision component root shape.
  LuminaCollisionComponent get volumeShape => rootComponent as LuminaCollisionComponent;

  /// Performs an oriented bounding box containment check of [worldPoint] against this volume.
  bool encompassesPoint(Vector3 worldPoint, {double tolerance = 0.0}) {
    final localPoint = volumeShape.worldRotation.unrotateVector(worldPoint - volumeShape.worldLocation);
    final ext = volumeShape.boxExtent;
    return localPoint.x.abs() <= (ext.x + tolerance) &&
        localPoint.y.abs() <= (ext.y + tolerance) &&
        localPoint.z.abs() <= (ext.z + tolerance);
  }
}

/// Volume actor that fires scriptable begin/end overlap events when other actors intersect its shape.
class LuminaTriggerVolume extends LuminaVolume {
  bool triggerOnceOnly;
  bool Function(LuminaActor other)? actorFilter;
  void Function(LuminaActor other)? onActorBeginOverlap;
  void Function(LuminaActor other)? onActorEndOverlap;

  final Set<LuminaActor> _overlappingActors = <LuminaActor>{};

  /// Live unmodifiable view of all actors currently intersecting this trigger volume.
  List<LuminaActor> get overlappingActors => List.unmodifiable(_overlappingActors);

  LuminaTriggerVolume({
    this.triggerOnceOnly = false,
    this.actorFilter,
    this.onActorBeginOverlap,
    this.onActorEndOverlap,
    super.extent,
    super.key,
    super.location,
    super.rotation,
  }) {
    volumeShape.response = CollisionResponse.overlap;
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    volumeShape.onComponentBeginOverlap = _handleComponentBeginOverlap;
    volumeShape.onComponentEndOverlap = _handleComponentEndOverlap;
  }

  void _handleComponentBeginOverlap(LuminaCollisionComponent self, LuminaCollisionComponent other) {
    final otherActor = other.owner;
    if (otherActor == null || otherActor == this) return;
    if (actorFilter != null && !actorFilter!(otherActor)) return;

    if (_overlappingActors.add(otherActor)) {
      onActorBeginOverlap?.call(otherActor);
      if (triggerOnceOnly) {
        volumeShape.onComponentBeginOverlap = null;
        volumeShape.onComponentEndOverlap = null;
      }
    }
  }

  void _handleComponentEndOverlap(LuminaCollisionComponent self, LuminaCollisionComponent other) {
    final otherActor = other.owner;
    if (otherActor == null) return;

    if (_overlappingActors.remove(otherActor)) {
      onActorEndOverlap?.call(otherActor);
    }
  }

  @override
  void onUnregister() {
    volumeShape.onComponentBeginOverlap = null;
    volumeShape.onComponentEndOverlap = null;
    _overlappingActors.clear();
    super.onUnregister();
  }
}

/// Static invisible blocking collision volume acting as world boundary or barrier.
class LuminaBlockingVolume extends LuminaVolume {
  LuminaBlockingVolume({
    int collisionLayer = 1 << 0,
    super.extent,
    super.key,
    super.location,
    super.rotation,
  }) {
    volumeShape.response = CollisionResponse.block;
    volumeShape.collisionLayer = collisionLayer;
  }
}

/// Lethal hazard volume that damages and destroys actors entering its bounds.
class LuminaKillZVolume extends LuminaVolume {
  void Function(LuminaActor victim)? onActorKilled;

  LuminaKillZVolume({
    this.onActorKilled,
    super.extent,
    super.key,
    super.location,
    super.rotation,
  }) {
    volumeShape.response = CollisionResponse.overlap;
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    volumeShape.onComponentBeginOverlap = (self, other) {
      final victim = other.owner;
      if (victim == null || victim == this || victim is LuminaVolume) return;

      if (victim.bCanBeDamaged) {
        victim.takeDamage(1e9, damageCauser: this);
      }
      world?.destroyActor(victim);
      onActorKilled?.call(victim);
    };
  }

  @override
  void onUnregister() {
    volumeShape.onComponentBeginOverlap = null;
    super.onUnregister();
  }
}
