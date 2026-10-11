part of 'viewport_runtime.dart';

/// The preview's camera: the description's orbit, `Frame Node` requests
/// (deferred until the meshes load) and the automatic framing of a
/// description that never placed its camera.
mixin _ViewportCamera {
  LuminaViewportCamera get orbit;
  Map<String, _RuntimeNode> get _nodes;
  int get _pending;
  LuminaViewportScene? get shown;
  Aabb3? _worldBounds(_RuntimeNode node);

  int _frameSerial = 0;
  String? _deferredFrame;

  /// The orbit as last placed by the description or an automatic framing;
  /// a different one means the player moved the camera (pitch, distance,
  /// target: auto-rotation turns the yaw on its own, and framing keeps it).
  String? _placedOrbit;

  /// The meshes (and the viewport size) the last automatic framing fitted.
  String? _framedMeshes;

  String get _orbitSignature => '${orbit.pitch}/${orbit.distance}/${orbit.target}/${orbit.orthographic}';

  void _applyCamera(LuminaViewportScene next) {
    orbit.readFrom(next);
    _placedOrbit = _orbitSignature;
    final c = next.camera;
    final serial = c['frameSerial'] is int ? c['frameSerial']! as int : 0;
    if (serial != _frameSerial) {
      _frameSerial = serial;
      final target = c['frame'];
      if (target is String) frameNode(target);
    }
  }

  /// Frames node [id] ('*': every mesh); waits for the meshes to load.
  void frameNode(String id) {
    final box = boundsOf(id);
    if (box != null) {
      orbit.frame(box);
      return;
    }
    if (_pending > 0) _deferredFrame = id;
  }

  /// The world bounds (runtime frame) of node [id] or ('*') every mesh.
  Aabb3? boundsOf(String id) {
    Aabb3? out;
    for (final node in _nodes.values) {
      if (id != '*' && node.id != id) continue;
      final b = _worldBounds(node);
      if (b == null) continue;
      if (out == null) {
        out = b;
      } else {
        out.hull(b);
      }
    }
    return out;
  }

  /// Once every mesh has loaded: a deferred `Frame Node`, else, while the
  /// description never placed its camera ([LuminaViewportScene.autoFrame])
  /// and the player has not moved it, fits every mesh whenever
  /// the set of meshes or the viewport's size changes — a mesh a Blueprint
  /// adds is in view, whatever the Viewport's shape.
  void _frameWhenReady() {
    if (_pending > 0) return;
    final deferred = _deferredFrame;
    if (deferred != null) {
      _deferredFrame = null;
      frameNode(deferred);
      _placedOrbit = _orbitSignature;
      return;
    }
    if (shown?.autoFrame != true) return;
    final placed = _placedOrbit ??= _orbitSignature;
    if (placed != _orbitSignature) return;
    final meshes = [
      for (final n in _nodes.values)
        if (n.mesh != null && n.loaded && !n.failed) '${n.id}:${n.meshAsset}',
      '${orbit.width.round()}x${orbit.height.round()}',
    ].join('|');
    if (meshes == _framedMeshes) return;
    _framedMeshes = meshes;
    final box = boundsOf('*');
    if (box == null) return;
    orbit.frame(box);
    _placedOrbit = _orbitSignature;
  }
}
