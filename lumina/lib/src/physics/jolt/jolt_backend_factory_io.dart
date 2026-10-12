import 'dart:io';

import 'package:flutter_jolt/flutter_jolt.dart';

import 'package:lumina/src/physics/jolt/jolt_physics_backend.dart';
import 'package:lumina/src/physics/jolt/jolt_collision_queries.dart';
import 'package:lumina/src/collision/collision_query_accelerator.dart';
import 'package:lumina/src/physics/physics_backend.dart';

/// Whether the Jolt backend can run here: the native library was built for
/// this target and loads.
bool get joltPhysicsAvailable => JoltPhysics.isAvailable;

/// The `LUMINA_PHYSICS_BACKEND` environment variable.
String? physicsBackendEnvironment() => Platform.environment['LUMINA_PHYSICS_BACKEND'];

/// A Jolt backend, or null when the library is missing.
LuminaPhysicsBackend? createJoltPhysicsBackend() => JoltPhysics.isAvailable ? LuminaJoltPhysicsBackend() : null;

/// Jolt's broad phase for the collision subsystem's queries, or null when
/// the library is missing.
LuminaCollisionQueryAccelerator? createJoltCollisionQueries() =>
    JoltPhysics.isAvailable ? LuminaJoltCollisionQueries() : null;
