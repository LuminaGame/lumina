part of '../editor_primitives.dart';

/// Manages native Filament 3D GPU Editor Floor Grid and World Axes.
class FilamentEditorGrid {
  final FilamentEngine engine;
  FilamentWireframeMesh? _mesh;
  bool _disposed = false;

  FilamentEditorGrid._(this.engine, this._mesh);

  /// Creates a native Filament 3D GPU Editor Grid spanning [extent] cm with [step] cm cell size.
  static FilamentEditorGrid create({
    required FilamentEngine engine,
    double extent = 2000.0,
    double step = 100.0,
  }) {
    final List<double> positions = [];
    final List<int> indices = [];

    int vertexIndex = 0;

    // Floor Sub-division Grid Lines on XZ horizontal floor plane (Y = 0)
    final int halfCount = (extent / step).round();
    final double maxExt = halfCount * step;

    for (int i = -halfCount; i <= halfCount; i++) {
      final pos = i * step;

      // Line along X (varying X, constant Z, Y = 0)
      positions.addAll([-maxExt, 0.0, pos]);
      positions.addAll([maxExt, 0.0, pos]);
      indices.addAll([vertexIndex, vertexIndex + 1]);
      vertexIndex += 2;

      // Line along Z (varying Z, constant X, Y = 0)
      positions.addAll([pos, 0.0, -maxExt]);
      positions.addAll([pos, 0.0, maxExt]);
      indices.addAll([vertexIndex, vertexIndex + 1]);
      vertexIndex += 2;
    }

    // Extended Major Coordinate Axes (X: Red, Y: Green/Up, Z: Blue/Depth)
    const double axisExtent = 3000.0;

    // X Axis (Red / Right)
    positions.addAll([-axisExtent, 0.0, 0.0]);
    positions.addAll([axisExtent, 0.0, 0.0]);
    indices.addAll([vertexIndex, vertexIndex + 1]);
    vertexIndex += 2;

    // Z Axis (Blue / Depth)
    positions.addAll([0.0, 0.0, -axisExtent]);
    positions.addAll([0.0, 0.0, axisExtent]);
    indices.addAll([vertexIndex, vertexIndex + 1]);
    vertexIndex += 2;

    // Y Axis (Green / Height / Up)
    positions.addAll([0.0, 0.0, 0.0]);
    positions.addAll([0.0, 1500.0, 0.0]);
    indices.addAll([vertexIndex, vertexIndex + 1]);
    vertexIndex += 2;

    final mesh = FilamentWireframeMesh.createLineSegments(
      engine: engine,
      positions: positions,
      lineIndices: indices,
    );

    return FilamentEditorGrid._(engine, mesh);
  }

  int? get entityId => _mesh?.entityId;
  bool get isDisposed => _disposed;

  /// Sets the grid's RGBA line color.
  void setColor(double r, double g, double b, [double a = 1.0]) {
    _mesh?.setColor(r, g, b, a);
  }

  void addToScene(FilamentScene scene) {
    if (_mesh != null && !_disposed) {
      scene.addEntity(_mesh!.entityId);
    }
  }

  void removeFromScene(FilamentScene scene) {
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
