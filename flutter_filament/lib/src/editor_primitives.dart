import 'dart:math' as math;
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/gltf_loader.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/transform.dart';

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

/// Manages native Filament 3D GPU Transform Gizmo (Translate, Rotate, Scale).
enum GizmoMode { translate, rotate, scale }

class FilamentTransformGizmo {
  final FilamentEngine engine;
  final Map<String, FilamentWireframeMesh> _handles = {};
  final Map<String, List<double>> _handleColors = {};
  bool _disposed = false;
  bool _isInScene = false;
  GizmoMode _mode = GizmoMode.translate;
  FilamentScene? _currentScene;
  List<double> _lastTransform = [
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ];

  FilamentTransformGizmo(this.engine) {
    _buildGizmoMesh();
  }

  bool get isDisposed => _disposed;
  bool get isInScene => _isInScene;
  GizmoMode get mode => _mode;

  /// Handle identifiers currently built for [mode] (e.g. `x`, `y`, `z`, `xy`).
  List<String> get handleIds => List.unmodifiable(_handles.keys);

  /// The 4x4 column-major transform matrix last sent to Filament.
  List<double> get lastTransform => List.unmodifiable(_lastTransform);

  /// Entity ids of every handle mesh, in [handleIds] order.
  List<int> get entityIds =>
      List.unmodifiable(_handles.values.map((m) => m.entityId));

  /// Entity id of the handle named [handleId], or null when it does not exist.
  int? entityIdOf(String handleId) => _handles[handleId]?.entityId;

  void setMode(GizmoMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _buildGizmoMesh();
  }

  /// The colour a handle carries when nothing is hovered: red X, green Y,
  /// blue Z, white for the uniform/centre handle.
  static List<double> defaultHandleColor(String handleId) {
    if (handleId == 'CENTER' || handleId == 'UNIFORM') {
      return const [1.0, 1.0, 1.0, 1.0];
    }
    if (handleId.contains('X')) return const [1.0, 0.2, 0.2, 1.0];
    if (handleId.contains('Y')) return const [0.2, 1.0, 0.2, 1.0];
    if (handleId.contains('Z')) return const [0.2, 0.2, 1.0, 1.0];
    return const [1.0, 1.0, 1.0, 1.0];
  }

  /// Colour of the handle under the pointer.
  static const List<double> highlightColor = [1.0, 1.0, 0.0, 1.0];

  /// Colour of the handles that are not the one being used.
  ///
  /// The manipulator keeps the other axes at full colour and only paints the
  /// active one yellow, so this is only used where a handle is deliberately disabled.
  static const List<double> dimmedColor = [0.3, 0.3, 0.3, 1.0];

  /// Whether every handle owns a compiled material instance. False means the
  /// wireframe material did not compile and the manipulator renders white
  /// whatever colour is set on it.
  bool get handlesAreColourable =>
      _handles.isNotEmpty && _handles.values.every((m) => m.hasMaterial);

  /// The rgba a handle is currently painted, or null when there is no such
  /// handle in the current mode.
  List<double>? colorOf(String handleId) {
    final color = _handleColors[handleId];
    return color == null ? null : List.unmodifiable(color);
  }

  void _applyColor(String handleId, List<double> rgba) {
    final mesh = _handles[handleId];
    if (mesh == null) return;
    _handleColors[handleId] = List<double>.from(rgba);
    mesh.setColor(rgba[0], rgba[1], rgba[2], rgba[3]);
  }

  void setHandleHighlight(String handleId, bool isHighlighted) {
    if (_disposed) return;
    _applyColor(
      handleId,
      isHighlighted ? highlightColor : defaultHandleColor(handleId),
    );
  }

  /// Paints [activeHandle] as the one under the pointer and leaves every other
  /// handle at its axis colour. Passing
  /// null returns all of them to their axis colours.
  void setAllHandlesDimmed(String? activeHandle) {
    if (_disposed) return;
    for (final handleId in _handles.keys) {
      _applyColor(
        handleId,
        handleId == activeHandle
            ? highlightColor
            : defaultHandleColor(handleId),
      );
    }
  }

  void _clearHandles() {
    _handleColors.clear();
    for (final mesh in _handles.values) {
      if (_isInScene && _currentScene != null) {
        _currentScene!.removeEntity(mesh.entityId);
      }
      mesh.dispose();
    }
    _handles.clear();
  }

  static ({List<double> positions, List<int> indices})
  _buildThickArrowGeometry({
    required String axis,
    double axisLen = 65.0,
    double arrowHeadLen = 12.0,
    double arrowRadius = 2.8,
    double shaftRadius = 0.4,
  }) {
    final List<double> positions = [];
    final List<int> indices = [];

    int addVertex(double a, double u, double v) {
      final int idx = positions.length ~/ 3;
      if (axis == 'X') {
        positions.addAll([a, u, v]);
      } else if (axis == 'Y') {
        positions.addAll([u, a, v]);
      } else {
        positions.addAll([u, v, a]);
      }
      return idx;
    }

    void addLine(int i0, int i1) {
      indices.addAll([i0, i1]);
    }

    final double shaftLen = axisLen - arrowHeadLen;
    const int shaftSegments = 4;

    // Central core line from base to tip
    final centerStart = addVertex(0.0, 0.0, 0.0);
    final centerTip = addVertex(axisLen, 0.0, 0.0);
    addLine(centerStart, centerTip);

    // Cylindrical/cross shaft ribs & end rings
    final ring0 = <int>[];
    final ringEnd = <int>[];

    for (int i = 0; i < shaftSegments; i++) {
      final theta = i * 2.0 * math.pi / shaftSegments + (math.pi / 4.0);
      final u = math.cos(theta) * shaftRadius;
      final v = math.sin(theta) * shaftRadius;
      ring0.add(addVertex(0.0, u, v));
      ringEnd.add(addVertex(shaftLen, u, v));
    }

    for (int i = 0; i < shaftSegments; i++) {
      final next = (i + 1) % shaftSegments;
      // Longitudinal shaft lines
      addLine(ring0[i], ringEnd[i]);
      // End rings
      addLine(ring0[i], ring0[next]);
      addLine(ringEnd[i], ringEnd[next]);
    }

    // 3D Crisp Conical Arrowhead
    const int coneSegments = 6;
    final tip = centerTip;
    final baseCenter = addVertex(shaftLen, 0.0, 0.0);
    final coneBaseRing = <int>[];

    for (int i = 0; i < coneSegments; i++) {
      final theta = i * 2.0 * math.pi / coneSegments;
      final cosT = math.cos(theta);
      final sinT = math.sin(theta);

      coneBaseRing.add(
        addVertex(shaftLen, cosT * arrowRadius, sinT * arrowRadius),
      );
    }

    for (int i = 0; i < coneSegments; i++) {
      final next = (i + 1) % coneSegments;
      // Closed base circle
      addLine(coneBaseRing[i], coneBaseRing[next]);
      // Base cap spokes connecting base center to base circle
      addLine(baseCenter, coneBaseRing[i]);
      // Sharp cone ribs from base to tip
      addLine(coneBaseRing[i], tip);
    }

    return (positions: positions, indices: indices);
  }

  static ({List<double> positions, List<int> indices})
  _buildThickPlaneGeometry({
    required String plane,
    double planeDist = 22.0,
    double innerDist = 15.0,
  }) {
    final List<double> positions = [];
    final List<int> indices = [];

    int addVertex(double x, double y, double z) {
      final int idx = positions.length ~/ 3;
      positions.addAll([x, y, z]);
      return idx;
    }

    void addLine(int i0, int i1) {
      indices.addAll([i0, i1]);
    }

    (double, double, double) to3D(double u, double v) {
      if (plane == 'XY') return (u, v, 0.0);
      if (plane == 'XZ') return (u, 0.0, v);
      return (0.0, u, v);
    }

    int add2D(double u, double v) {
      final (x, y, z) = to3D(u, v);
      return addVertex(x, y, z);
    }

    final o0 = add2D(planeDist, 0.0);
    final o1 = add2D(planeDist, planeDist);
    final o2 = add2D(0.0, planeDist);

    final i0 = add2D(innerDist, 0.0);
    final i1 = add2D(innerDist, innerDist);
    final i2 = add2D(0.0, innerDist);

    final midDist = (planeDist + innerDist) * 0.5;
    final m0 = add2D(midDist, 0.0);
    final m1 = add2D(midDist, midDist);
    final m2 = add2D(0.0, midDist);

    addLine(o0, o1);
    addLine(o1, o2);
    addLine(m0, m1);
    addLine(m1, m2);
    addLine(i0, i1);
    addLine(i1, i2);

    addLine(o0, i0);
    addLine(o1, i1);
    addLine(o2, i2);

    return (positions: positions, indices: indices);
  }

  static ({List<double> positions, List<int> indices})
  _buildThickScaleGeometry({
    required String axis,
    double axisLen = 65.0,
    double cubeSize = 4.0,
    double shaftRadius = 0.4,
  }) {
    final List<double> positions = [];
    final List<int> indices = [];

    int addVertex(double a, double u, double v) {
      final int idx = positions.length ~/ 3;
      if (axis == 'X') {
        positions.addAll([a, u, v]);
      } else if (axis == 'Y') {
        positions.addAll([u, a, v]);
      } else {
        positions.addAll([u, v, a]);
      }
      return idx;
    }

    void addLine(int i0, int i1) {
      indices.addAll([i0, i1]);
    }

    final double shaftLen = axisLen - cubeSize;
    const int shaftSegments = 4;

    addLine(addVertex(0.0, 0.0, 0.0), addVertex(shaftLen, 0.0, 0.0));

    final ring0 = <int>[];
    final ringEnd = <int>[];
    for (int i = 0; i < shaftSegments; i++) {
      final theta = i * 2.0 * math.pi / shaftSegments;
      final u = math.cos(theta) * shaftRadius;
      final v = math.sin(theta) * shaftRadius;
      ring0.add(addVertex(0.0, u, v));
      ringEnd.add(addVertex(shaftLen, u, v));
    }
    for (int i = 0; i < shaftSegments; i++) {
      final next = (i + 1) % shaftSegments;
      addLine(ring0[i], ringEnd[i]);
      addLine(ring0[i], ring0[next]);
      addLine(ringEnd[i], ringEnd[next]);
    }

    final double minA = axisLen - cubeSize;
    final double maxA = axisLen + cubeSize;
    final double c = cubeSize;

    final c0 = addVertex(minA, -c, -c);
    final c1 = addVertex(maxA, -c, -c);
    final c2 = addVertex(maxA, c, -c);
    final c3 = addVertex(minA, c, -c);
    final c4 = addVertex(minA, -c, c);
    final c5 = addVertex(maxA, -c, c);
    final c6 = addVertex(maxA, c, c);
    final c7 = addVertex(minA, c, c);

    addLine(c0, c1);
    addLine(c1, c2);
    addLine(c2, c3);
    addLine(c3, c0);
    addLine(c4, c5);
    addLine(c5, c6);
    addLine(c6, c7);
    addLine(c7, c4);
    addLine(c0, c4);
    addLine(c1, c5);
    addLine(c2, c6);
    addLine(c3, c7);

    addLine(c0, c2);
    addLine(c4, c6);
    addLine(c1, c6);
    addLine(c0, c7);

    return (positions: positions, indices: indices);
  }

  static ({List<double> positions, List<int> indices})
  _buildUniformCubeGeometry({double cubeSize = 4.0}) {
    final List<double> positions = [];
    final List<int> indices = [];

    int addVertex(double x, double y, double z) {
      final int idx = positions.length ~/ 3;
      positions.addAll([x, y, z]);
      return idx;
    }

    void addLine(int i0, int i1) {
      indices.addAll([i0, i1]);
    }

    final double c = cubeSize;
    final c0 = addVertex(-c, -c, -c);
    final c1 = addVertex(c, -c, -c);
    final c2 = addVertex(c, c, -c);
    final c3 = addVertex(-c, c, -c);
    final c4 = addVertex(-c, -c, c);
    final c5 = addVertex(c, -c, c);
    final c6 = addVertex(c, c, c);
    final c7 = addVertex(-c, c, c);

    addLine(c0, c1);
    addLine(c1, c2);
    addLine(c2, c3);
    addLine(c3, c0);
    addLine(c4, c5);
    addLine(c5, c6);
    addLine(c6, c7);
    addLine(c7, c4);
    addLine(c0, c4);
    addLine(c1, c5);
    addLine(c2, c6);
    addLine(c3, c7);
    addLine(c0, c2);
    addLine(c4, c6);
    addLine(c1, c6);
    addLine(c0, c7);

    return (positions: positions, indices: indices);
  }

  static ({List<double> positions, List<int> indices}) _buildThickRingGeometry({
    required String axis,
    double radius = 65.0,
    double bandOffset = 1.2,
    int segments = 64,
  }) {
    final List<double> positions = [];
    final List<int> indices = [];

    int addVertex(double u, double v) {
      final int idx = positions.length ~/ 3;
      if (axis == 'X') {
        positions.addAll([0.0, u, v]);
      } else if (axis == 'Y') {
        positions.addAll([u, 0.0, v]);
      } else {
        positions.addAll([u, v, 0.0]);
      }
      return idx;
    }

    void addLine(int i0, int i1) {
      indices.addAll([i0, i1]);
    }

    final rOuter = radius + bandOffset;
    final rInner = radius - bandOffset;
    final rMid = radius;

    final outerRing = <int>[];
    final innerRing = <int>[];
    final midRing = <int>[];

    for (int i = 0; i < segments; i++) {
      final a = (i / segments) * 2 * math.pi;
      final cosA = math.cos(a);
      final sinA = math.sin(a);

      outerRing.add(addVertex(cosA * rOuter, sinA * rOuter));
      innerRing.add(addVertex(cosA * rInner, sinA * rInner));
      midRing.add(addVertex(cosA * rMid, sinA * rMid));
    }

    for (int i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      addLine(outerRing[i], outerRing[next]);
      addLine(innerRing[i], innerRing[next]);
      addLine(midRing[i], midRing[next]);

      if (i % 4 == 0) {
        addLine(innerRing[i], outerRing[i]);
      }
    }

    return (positions: positions, indices: indices);
  }

  void _buildGizmoMesh() {
    _clearHandles();

    const double axisLen = 65.0;
    const double planeDist = 22.0;

    if (_mode == GizmoMode.translate) {
      final xGeo = _buildThickArrowGeometry(axis: 'X', axisLen: axisLen);
      _handles['X'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: xGeo.positions,
        lineIndices: xGeo.indices,
      )!;

      final yGeo = _buildThickArrowGeometry(axis: 'Y', axisLen: axisLen);
      _handles['Y'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: yGeo.positions,
        lineIndices: yGeo.indices,
      )!;

      final zGeo = _buildThickArrowGeometry(axis: 'Z', axisLen: axisLen);
      _handles['Z'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: zGeo.positions,
        lineIndices: zGeo.indices,
      )!;

      final xyGeo = _buildThickPlaneGeometry(plane: 'XY', planeDist: planeDist);
      _handles['XY'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: xyGeo.positions,
        lineIndices: xyGeo.indices,
      )!;

      final xzGeo = _buildThickPlaneGeometry(plane: 'XZ', planeDist: planeDist);
      _handles['XZ'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: xzGeo.positions,
        lineIndices: xzGeo.indices,
      )!;

      final yzGeo = _buildThickPlaneGeometry(plane: 'YZ', planeDist: planeDist);
      _handles['YZ'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: yzGeo.positions,
        lineIndices: yzGeo.indices,
      )!;
    } else if (_mode == GizmoMode.scale) {
      final xGeo = _buildThickScaleGeometry(axis: 'X', axisLen: axisLen);
      _handles['X'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: xGeo.positions,
        lineIndices: xGeo.indices,
      )!;

      final yGeo = _buildThickScaleGeometry(axis: 'Y', axisLen: axisLen);
      _handles['Y'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: yGeo.positions,
        lineIndices: yGeo.indices,
      )!;

      final zGeo = _buildThickScaleGeometry(axis: 'Z', axisLen: axisLen);
      _handles['Z'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: zGeo.positions,
        lineIndices: zGeo.indices,
      )!;

      final uGeo = _buildUniformCubeGeometry();
      _handles['UNIFORM'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: uGeo.positions,
        lineIndices: uGeo.indices,
      )!;
    } else if (_mode == GizmoMode.rotate) {
      final xRing = _buildThickRingGeometry(axis: 'X', radius: axisLen);
      _handles['X'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: xRing.positions,
        lineIndices: xRing.indices,
      )!;

      final yRing = _buildThickRingGeometry(axis: 'Y', radius: axisLen);
      _handles['Y'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: yRing.positions,
        lineIndices: yRing.indices,
      )!;

      final zRing = _buildThickRingGeometry(axis: 'Z', radius: axisLen);
      _handles['Z'] = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: zRing.positions,
        lineIndices: zRing.indices,
      )!;
    }

    setAllHandlesDimmed(null);

    if (_isInScene && _currentScene != null) {
      for (final mesh in _handles.values) {
        _currentScene!.addEntity(mesh.entityId);
      }
      _applyTransform();
    }
  }

  void setPosition(double x, double y, double z, [double scale = 1.0]) {
    setTransform(
      x: x,
      y: y,
      z: z,
      scale: scale,
      qx: 0.0,
      qy: 0.0,
      qz: 0.0,
      qw: 1.0,
    );
  }

  void setTransform({
    required double x,
    required double y,
    required double z,
    required double scale,
    required double qx,
    required double qy,
    required double qz,
    required double qw,
  }) {
    if (_disposed) return;

    final xx = qx * qx, yy = qy * qy, zz = qz * qz;
    final xy = qx * qy, xz = qx * qz, xw = qx * qw;
    final yz = qy * qz, yw = qy * qw, zw = qz * qw;

    final m00 = 1.0 - 2.0 * (yy + zz);
    final m01 = 2.0 * (xy - zw);
    final m02 = 2.0 * (xz + yw);
    final m10 = 2.0 * (xy + zw);
    final m11 = 1.0 - 2.0 * (xx + zz);
    final m12 = 2.0 * (yz - xw);
    final m20 = 2.0 * (xz - yw);
    final m21 = 2.0 * (yz + xw);
    final m22 = 1.0 - 2.0 * (xx + yy);

    final s = scale;
    _lastTransform = [
      m00 * s,
      m20 * s,
      -m10 * s,
      0.0,
      m01 * s,
      m21 * s,
      -m11 * s,
      0.0,
      m02 * s,
      m22 * s,
      -m12 * s,
      0.0,
      x,
      z,
      -y,
      1.0,
    ];

    _applyTransform();
  }

  void _applyTransform() {
    for (final mesh in _handles.values) {
      FilamentTransformManager(
        engine,
      ).setTransform(mesh.entityId, _lastTransform);
    }
  }

  void addToScene(FilamentScene scene) {
    if (_isInScene) return;
    _isInScene = true;
    _currentScene = scene;
    for (final mesh in _handles.values) {
      scene.addEntity(mesh.entityId);
    }
    _applyTransform();
  }

  void removeFromScene(FilamentScene scene) {
    if (!_isInScene) return;
    _isInScene = false;
    _currentScene = null;
    for (final mesh in _handles.values) {
      scene.removeEntity(mesh.entityId);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clearHandles();
  }
}
