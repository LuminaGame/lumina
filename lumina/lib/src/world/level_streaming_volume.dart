import 'package:vector_math/vector_math_64.dart';

/// The geometric shape type of a [LuminaLevelStreamingVolume].
enum LuminaStreamingVolumeShape {
  aabb,
  sphere,
}

class _PawnVolumeState {
  bool isInside = false;
  double outsideTime = 0.0;

  _PawnVolumeState({required this.isInside});
}

/// Volume trigger used to automatically request level streaming loads/unloads
/// when player pawns enter or exit specified spatial bounds.
class LuminaLevelStreamingVolume {
  final String volumeName;
  final List<String> targetLevelNames;
  final LuminaStreamingVolumeShape shape;

  // AABB properties
  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  // Sphere properties
  final double centerX;
  final double centerY;
  final double centerZ;
  final double sphereRadius;

  final double bufferMargin;
  final Duration exitDelay;
  final double _exitDelaySeconds;
  final bool bEditorPreVisOnly;
  bool bDisabled;

  final Map<Object, _PawnVolumeState> _pawnStates = {};

  void Function(Object pawnId)? onPawnEnteredVolume;
  void Function(Object pawnId)? onPawnExitedVolume;

  LuminaLevelStreamingVolume({
    required this.volumeName,
    required this.targetLevelNames,
    Aabb3? bounds,
    Vector3? sphereCenter,
    double? sphereRadius,
    this.bufferMargin = 500.0, // cm
    this.exitDelay = const Duration(seconds: 2),
    this.bEditorPreVisOnly = false,
    this.bDisabled = false,
  })  : _exitDelaySeconds = exitDelay.inMicroseconds / 1000000.0,
        shape = bounds != null
            ? LuminaStreamingVolumeShape.aabb
            : (sphereRadius != null ? LuminaStreamingVolumeShape.sphere : throw ArgumentError('Must provide either bounds or sphereRadius')),
        minX = bounds?.min.x ?? 0.0,
        minY = bounds?.min.y ?? 0.0,
        minZ = bounds?.min.z ?? 0.0,
        maxX = bounds?.max.x ?? 0.0,
        maxY = bounds?.max.y ?? 0.0,
        maxZ = bounds?.max.z ?? 0.0,
        centerX = sphereCenter?.x ?? 0.0,
        centerY = sphereCenter?.y ?? 0.0,
        centerZ = sphereCenter?.z ?? 0.0,
        sphereRadius = sphereRadius ?? 0.0 {
    if (bounds != null && sphereRadius != null) {
      throw ArgumentError('Cannot provide both bounds and sphereRadius');
    }
  }

  /// Whether any tracked pawn is currently considered inside the volume.
  bool get isAnyPawnInside => _pawnStates.values.any((s) => s.isInside);

  /// Target levels requested by this volume when active and occupied by at least one pawn.
  Iterable<String> get requestedLevels {
    if (bDisabled || !isAnyPawnInside) {
      return const [];
    }
    return targetLevelNames;
  }

  /// Evaluates the position of a specific pawn against this volume's bounds with asymmetric hysteresis.
  ///
  /// - If the pawn was outside: enters when strictly inside tight bounds.
  /// - If the pawn was inside: stays inside as long as within bounds + [bufferMargin].
  ///   Once past the margin, exit is committed only after [exitDelay] has accumulated.
  bool evaluatePawnPosition(Object pawnId, Vector3 pawnPosition, double deltaTime) {
    final state = _pawnStates.putIfAbsent(pawnId, () => _PawnVolumeState(isInside: false));

    final px = pawnPosition.x;
    final py = pawnPosition.y;
    final pz = pawnPosition.z;

    if (!state.isInside) {
      // Test tight bounds
      final isTightInside = _containsPoint(px, py, pz, 0.0);
      if (isTightInside) {
        state.isInside = true;
        state.outsideTime = 0.0;
        onPawnEnteredVolume?.call(pawnId);
      }
      return state.isInside;
    } else {
      // Pawn is currently considered inside: test expanded margin bounds
      final isMarginInside = _containsPoint(px, py, pz, bufferMargin);
      if (isMarginInside) {
        // Reset outside debounce timer if pawn re-enters margin
        state.outsideTime = 0.0;
        return true;
      } else {
        // Pawn is outside the buffer margin: accumulate exit delay
        state.outsideTime += deltaTime;
        if (state.outsideTime >= _exitDelaySeconds) {
          state.isInside = false;
          state.outsideTime = 0.0;
          onPawnExitedVolume?.call(pawnId);
          return false;
        }
        // Still considered inside until debounce timer elapses
        return true;
      }
    }
  }

  bool _containsPoint(double px, double py, double pz, double margin) {
    if (shape == LuminaStreamingVolumeShape.aabb) {
      return px >= (minX - margin) &&
          px <= (maxX + margin) &&
          py >= (minY - margin) &&
          py <= (maxY + margin) &&
          pz >= (minZ - margin) &&
          pz <= (maxZ + margin);
    } else {
      final dx = px - centerX;
      final dy = py - centerY;
      final dz = pz - centerZ;
      final distSq = dx * dx + dy * dy + dz * dz;
      final r = sphereRadius + margin;
      return distSq <= r * r;
    }
  }

  /// Removes a pawn from tracking (e.g. on despawn) without firing exit callbacks.
  void removePawn(Object pawnId) {
    _pawnStates.remove(pawnId);
  }
}
