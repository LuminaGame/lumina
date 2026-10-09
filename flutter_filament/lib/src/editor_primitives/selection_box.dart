part of '../editor_primitives.dart';

/// Manages native Filament 3D GPU Selection Bounding Box around active actor.
class FilamentSelectionBox {
  final FilamentEngine engine;
  FilamentWireframeMesh? _mesh;
  bool _disposed = false;
  bool _isInScene = false;

  FilamentSelectionBox(this.engine);

  int? get entityId => _mesh?.entityId;
  bool get isDisposed => _disposed;
  bool get isInScene => _isInScene;

  /// Updates 3D bounding box corners and rebuilds GPU wireframe lines.
  void updateBounds({
    required FilamentScene scene,
    required List<double> minBounds,
    required List<double> maxBounds,
    double baseScale = 1.0,
  }) {
    if (_disposed) return;

    if (_mesh != null) {
      if (_isInScene) {
        scene.removeEntity(_mesh!.entityId);
      }
      _mesh!.dispose();
      _mesh = null;
    }

    final double minX = minBounds[0] * baseScale;
    final double minY = minBounds[1] * baseScale;
    final double minZ = minBounds[2] * baseScale;
    final double maxX = maxBounds[0] * baseScale;
    final double maxY = maxBounds[1] * baseScale;
    final double maxZ = maxBounds[2] * baseScale;

    // 8 Box Corner Vertices
    final List<double> positions = [
      minX, minY, minZ, // 0
      maxX, minY, minZ, // 1
      maxX, maxY, minZ, // 2
      minX, maxY, minZ, // 3
      minX, minY, maxZ, // 4
      maxX, minY, maxZ, // 5
      maxX, maxY, maxZ, // 6
      minX, maxY, maxZ, // 7
    ];

    // 12 Edges (24 indices)
    final List<int> lineIndices = [
      // Bottom 4 edges
      0, 1, 1, 2, 2, 3, 3, 0,
      // Top 4 edges
      4, 5, 5, 6, 6, 7, 7, 4,
      // Vertical 4 pillars
      0, 4, 1, 5, 2, 6, 3, 7,
    ];

    _mesh = FilamentWireframeMesh.createLineSegments(
      engine: engine,
      positions: positions,
      lineIndices: lineIndices,
    );

    if (_mesh != null && _isInScene) {
      scene.addEntity(_mesh!.entityId);
    }
  }

  /// Sets world transform matrix for the selection bounding box entity.
  void setTransform(List<double> transformMatrix16) {
    if (_mesh != null && !_disposed) {
      FilamentTransformManager(
        engine,
      ).setTransform(_mesh!.entityId, transformMatrix16);
    }
  }

  void addToScene(FilamentScene scene) {
    if (_isInScene) return;
    _isInScene = true;
    if (_mesh != null && !_disposed) {
      scene.addEntity(_mesh!.entityId);
    }
  }

  void removeFromScene(FilamentScene scene) {
    if (!_isInScene) return;
    _isInScene = false;
    if (_mesh != null && !_disposed) {
      scene.removeEntity(_mesh!.entityId);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _mesh?.dispose();
    _mesh = null;
  }
}
