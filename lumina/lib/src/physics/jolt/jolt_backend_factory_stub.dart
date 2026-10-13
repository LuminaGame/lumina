import 'package:lumina/src/collision/collision_query_accelerator.dart';
import 'package:lumina/src/physics/physics_backend.dart';

/// Whether the Jolt backend can run here: never without `dart:ffi`.
bool get joltPhysicsAvailable => false;

/// The `LUMINA_PHYSICS_BACKEND` environment variable (none on the web).
String? physicsBackendEnvironment() => null;

/// A Jolt backend, or null where Jolt cannot run.
LuminaPhysicsBackend? createJoltPhysicsBackend() => null;

/// Jolt's broad phase for collision queries: never without `dart:ffi`.
LuminaCollisionQueryAccelerator? createJoltCollisionQueries() => null;

/// Jolt never loads without `dart:ffi` or the web.
Future<bool> loadJoltPhysics(String moduleUrl) async => false;
