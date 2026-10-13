import 'package:flutter_jolt/flutter_jolt.dart';

import 'package:lumina/src/collision/collision_query_accelerator.dart';
import 'package:lumina/src/physics/jolt/jolt_collision_queries.dart';
import 'package:lumina/src/physics/jolt/jolt_physics_backend.dart';
import 'package:lumina/src/physics/physics_backend.dart';

/// Whether the Jolt backend can run here: on the web, once
/// `JoltPhysics.ensureInitialized` loaded the WebAssembly module
/// (`flutter_jolt.js` + `.wasm`); until then the Dart solver runs.
bool get joltPhysicsAvailable => JoltPhysics.isAvailable;

/// No environment variables on the web (the `LUMINA_PHYSICS_BACKEND`
/// dart-define still applies).
String? physicsBackendEnvironment() => null;

/// A Jolt backend over the WebAssembly module, or null when it is not loaded.
LuminaPhysicsBackend? createJoltPhysicsBackend() => JoltPhysics.isAvailable ? LuminaJoltPhysicsBackend() : null;

/// Jolt's broad phase for the collision subsystem's queries, or null when the
/// module is not loaded.
LuminaCollisionQueryAccelerator? createJoltCollisionQueries() =>
    JoltPhysics.isAvailable ? LuminaJoltCollisionQueries() : null;

/// Loads the WebAssembly module (`flutter_jolt.js` + `.wasm` from
/// [moduleUrl]'s directory); a page without it keeps the Dart solver.
Future<bool> loadJoltPhysics(String moduleUrl) async {
  try {
    await JoltPhysics.ensureInitialized(moduleUrl: moduleUrl);
  } catch (_) {
    // No module served next to the page: the Dart solver runs.
  }
  return JoltPhysics.isAvailable;
}
