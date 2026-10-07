import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world_partition.dart';

/// Operational state of a streaming source.
enum LuminaStreamingSourceState {
  active,
  disabled,
}

/// Target residency state requested by a streaming source for its covered cells.
enum LuminaStreamingSourceTargetState {
  loaded,
  activated,
}

/// Streaming Source Component attached to Player Pawns, Controllers, or Cinematic Cameras.
///
/// Drives spatial cell loading and activation across World Partition.
class LuminaStreamingSourceComponent extends LuminaActorComponent {
  /// Radial boundary within which this source requests cell residency.
  double loadingRadius;

  /// Priority weighting used to order cell transitions under constrained frame budgets.
  int priority;

  /// Whether this source contributes to the cell loading union.
  bool bShapesCellLoading;

  /// Desired state cap for cells covered by this source (`loaded` or `activated`).
  LuminaStreamingSourceTargetState targetState;

  /// Whether this streaming source is currently active.
  bool bEnabled;

  /// Optional manual coordinate override for detached or cinematic camera sources.
  Vector3? overrideLocation;

  LuminaStreamingSourceComponent({
    this.loadingRadius = 25000.0, // cm
    this.priority = 1,
    this.bShapesCellLoading = true,
    this.targetState = LuminaStreamingSourceTargetState.activated,
    this.bEnabled = true,
    this.overrideLocation,
  });

  /// Current 3D world position of this streaming source.
  Vector3 get location {
    if (overrideLocation != null) {
      return overrideLocation!;
    }
    final root = owner?.rootComponent;
    if (root != null) {
      return root.worldLocation;
    }
    final actor = owner;
    if (actor != null) {
      return actor.actorLocation;
    }
    return Vector3.zero();
  }

  set location(Vector3 v) => overrideLocation = v;

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    final world = ownerActor.world;
    if (world != null) {
      final partition = world.subsystems.getSubsystem<LuminaWorldPartitionSubsystem>();
      partition?.registerSource(this);
    }
  }

  @override
  void onInitialize() {
    super.onInitialize();
    final world = owner?.world;
    if (world != null) {
      final partition = world.subsystems.getSubsystem<LuminaWorldPartitionSubsystem>();
      partition?.registerSource(this);
    }
  }

  @override
  void onUnregister() {
    final world = owner?.world;
    if (world != null) {
      final partition = world.subsystems.getSubsystem<LuminaWorldPartitionSubsystem>();
      partition?.unregisterSource(this);
    }
    super.onUnregister();
  }
}
