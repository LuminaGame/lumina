import 'package:lumina/src/physics/contact_solver.dart';
import 'package:lumina/src/physics/jolt/jolt_backend_factory.dart';
import 'package:lumina/src/physics/physics_joint.dart';
import 'package:lumina/src/physics/rigid_body.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';

/// Which engine steps a [LuminaPhysicsSubsystem]'s bodies.
enum LuminaPhysicsBackendKind {
  /// Jolt where its native library is available, else Dart.
  auto,

  /// The pure-Dart solver (every platform, the web's only one).
  dart,

  /// Jolt Physics through `flutter_jolt` (native desktop).
  jolt;

  /// Parses `dart` / `jolt` / `auto` (case-insensitive); null otherwise.
  static LuminaPhysicsBackendKind? parse(String? value) {
    final key = value?.trim().toLowerCase();
    for (final k in values) {
      if (k.name == key) return k;
    }
    return null;
  }
}

/// The solver behind a [LuminaPhysicsSubsystem]. The subsystem owns the
/// bodies ([LuminaRigidBody]: pose, velocities, mass, material, locks, sleep
/// state), the joints and the fixed-step clock; a backend advances them by
/// one fixed step at a time and reports the step's contacts.
///
/// Gameplay reads and pushes the Dart bodies between steps; a backend that
/// keeps its own copy (Jolt) takes the changes before a step and writes its
/// results back after it. Units are the runtime's: cm, kg, s, Y up.
abstract class LuminaPhysicsBackend {
  /// `dart` or `jolt`.
  String get name;

  /// The kind this backend is.
  LuminaPhysicsBackendKind get kind;

  /// Called once, when the subsystem takes this backend.
  void attach(LuminaPhysicsSubsystem physics);

  /// A body joined the subsystem (after it is fully set up).
  void bodyAdded(LuminaRigidBody body);

  /// A body left the subsystem (its joints are removed first).
  void bodyRemoved(LuminaRigidBody body);

  void jointAdded(LuminaPhysicsJoint joint);
  void jointRemoved(LuminaPhysicsJoint joint);

  /// One fixed step of [dt] seconds: forces and gravity, contacts, joints,
  /// integration, sleep. Records hit candidates through
  /// [LuminaPhysicsSubsystem.recordHit].
  void step(double dt);

  /// The contacts of the last step; [LuminaContactManifold.a] is always a
  /// body, [LuminaContactManifold.b] null for a static collider.
  List<LuminaContactManifold> get contacts;

  /// Frees what the backend holds (the subsystem shut down).
  void dispose();
}

/// Picks the backend kind for a new subsystem: [requested] unless it is
/// [LuminaPhysicsBackendKind.auto], else the `LUMINA_PHYSICS_BACKEND`
/// dart-define or environment variable, else Jolt when it is available.
LuminaPhysicsBackendKind resolvePhysicsBackendKind(LuminaPhysicsBackendKind requested) {
  if (requested != LuminaPhysicsBackendKind.auto) return requested;
  final override = LuminaPhysicsBackendKind.parse(const String.fromEnvironment('LUMINA_PHYSICS_BACKEND')) ??
      LuminaPhysicsBackendKind.parse(physicsBackendEnvironment());
  if (override != null && override != LuminaPhysicsBackendKind.auto) return override;
  return joltPhysicsAvailable ? LuminaPhysicsBackendKind.jolt : LuminaPhysicsBackendKind.dart;
}
