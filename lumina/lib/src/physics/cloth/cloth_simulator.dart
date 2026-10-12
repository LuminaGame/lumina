import 'dart:typed_data';

import 'package:lumina/src/physics/cloth/cloth_component.dart';

/// The part of a physics backend that simulates cloth. The Jolt backend has
/// one; the pure-Dart solver (the web, the fallback) has none, and cloth
/// components then draw their rest pose.
abstract class LuminaClothSimulator {
  /// Starts simulating [cloth] at its current pose (its geometry is ready).
  void add(LuminaClothComponent cloth);

  /// Stops simulating [cloth] and frees what it held.
  void remove(LuminaClothComponent cloth);

  /// Rebuilds [cloth]'s simulation from its rest pose and settings (after a
  /// reset or a settings change).
  void rebuild(LuminaClothComponent cloth);

  /// Writes [cloth]'s simulated vertices and normals in its local frame (cm)
  /// into [positions] / [normals] (3 values per simulation vertex); false when
  /// it is not simulated.
  bool read(LuminaClothComponent cloth, Float32List positions, Float32List normals);

  /// Pins simulation vertex [vertex] of [cloth] where it is now, or frees it,
  /// without rebuilding the simulation.
  void setPinned(LuminaClothComponent cloth, int vertex, bool pinned);

  /// Whether [cloth] is simulated now.
  bool contains(LuminaClothComponent cloth);
}
