import 'dart:math' as math;

import 'package:flutter_filament/filament.dart';
import 'package:lumina/src/umg/viewport/viewport_runtime.dart';
import 'package:lumina/src/umg/viewport/viewport_scene.dart';
import 'package:lumina/src/umg/viewport/viewport_skeleton_overlay.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// One line of a Viewport's overlay, in the runtime frame (Y up, cm), with
/// its colour (`[r, g, b, a]`, 0–1).
class LuminaViewportSegment {
  const LuminaViewportSegment(this.from, this.to, this.color);
  final Vector3 from;
  final Vector3 to;
  final List<double> color;
}

/// A Viewport's overlays drawn by Filament in the 3D view: skeletons, ghost
/// poses, markers and the gizmo as lines in the preview's own scene, drawn
/// last and without depth testing, so the meshes never hide them. Moving
/// overlays therefore never repaint the Flutter UI — on the Direct path the
/// captured UI stays as it is while a skeleton animates — and they need no
/// view of their own in either presentation path.
///
/// Lines are a pool of unit segments, each placed by its transform every
/// rendered frame; unused ones collapse to nothing.
class LuminaViewportOverlayLines {
  LuminaViewportOverlayLines(this.engine, this.scene);

  final FilamentEngine engine;

  /// The preview's scene the lines are added to.
  final FilamentScene scene;

  final List<FilamentWireframeMesh> _pool = [];
  final List<List<double>?> _colors = [];
  int _shown = 0;
  bool _disposed = false;

  /// Lines drawn by the last [update].
  int get lineCount => _shown;

  /// Places [segments]; the rest of the pool is collapsed.
  void update(List<LuminaViewportSegment> segments) {
    if (_disposed) return;
    final tm = FilamentTransformManager(engine);
    while (_pool.length < segments.length) {
      final mesh = FilamentWireframeMesh.createLineSegments(engine: engine, positions: const [0, 0, 0, 0, 0, 1], lineIndices: const [0, 1]);
      if (mesh == null) break;
      // Over the meshes: no depth test or write, in the last channel (after
      // every opaque and translucent mesh).
      final renderables = FilamentRenderableManager(engine);
      renderables.getMaterialInstanceAt(mesh.entityId, 0)
        ?..setDepthCulling(false)
        ..setDepthWrite(false);
      renderables
        ..setChannel(mesh.entityId, 7)
        ..setPriority(mesh.entityId, 7);
      _pool.add(mesh);
      _colors.add(null);
      scene.addEntity(mesh.entityId);
    }
    final count = math.min(segments.length, _pool.length);
    for (var i = 0; i < count; i++) {
      final s = segments[i];
      final c = s.color;
      final known = _colors[i];
      if (known == null || known[0] != c[0] || known[1] != c[1] || known[2] != c[2] || known[3] != c[3]) {
        _pool[i].setColor(c[0], c[1], c[2], c[3]);
        _colors[i] = c;
      }
      tm.setTransform(_pool[i].entityId, _placement(s.from, s.to).storage.toList());
    }
    final collapsed = Matrix4.diagonal3Values(0, 0, 0).storage.toList();
    for (var i = count; i < _shown; i++) {
      tm.setTransform(_pool[i].entityId, collapsed);
    }
    _shown = count;
  }

  /// The transform taking the unit segment (0,0,0)–(0,0,1) onto [a]–[b].
  static Matrix4 _placement(Vector3 a, Vector3 b) {
    final d = b - a;
    final len = d.length;
    if (len < 1e-6) return Matrix4.diagonal3Values(0, 0, 0);
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 0, 1), d / len);
    return Matrix4.compose(a, rotation, Vector3(1, 1, len));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final m in _pool) {
      scene.removeEntity(m.entityId);
      m.dispose();
    }
    _pool.clear();
  }

  // --- What the description shows ------------------------------------------

  static List<double> _rgba(Object? v, List<double> fallback) {
    if (v is! List || v.length < 3) return fallback;
    double at(int i, double d) => i < v.length && v[i] is num ? (v[i] as num).toDouble() : d;
    return [at(0, 1), at(1, 1), at(2, 1), at(3, 1)];
  }

  /// The selected bones and joints' colour.
  static const List<double> selectedColor = [1.0, 0.84, 0.31, 1.0];

  /// The overlay segments of [scene] shown by [runtime]: each skeleton
  /// overlay's bones and joint crosses (the selected branch highlighted),
  /// its ghost poses, and the markers (points, lines, arrows).
  static List<LuminaViewportSegment> segmentsOf(LuminaViewportSceneRuntime runtime, LuminaViewportScene scene) {
    final out = <LuminaViewportSegment>[];
    final o = runtime.orbit;
    final size = math.max(0.5, o.distance * 0.006);
    // The camera's right and up (runtime frame), for joint crosses and heads.
    final forward = (o.centre - o.eye)..normalize();
    final right = forward.cross(Vector3(0, 1, 0));
    if (right.length2 < 1e-9) right.setValues(1, 0, 0);
    right.normalize();
    final up = right.cross(forward)..normalize();

    void skeleton(List<LuminaViewportJoint> joints, List<double> color, {Set<String>? bones, String? selected, bool crosses = true}) {
      if (joints.isEmpty || color[3] <= 0) return;
      for (final b in LuminaSkeletonOverlay.bones(joints, visible: bones, selected: selected)) {
        out.add(LuminaViewportSegment(joints[b.from].position, joints[b.to].position, b.selected ? selectedColor : color));
      }
      if (!crosses) return;
      final lower = bones?.map((n) => n.toLowerCase()).toSet();
      for (final j in joints) {
        if (lower != null && !lower.contains(j.name.toLowerCase())) continue;
        final s = j.name == selected ? size * 2 : size;
        final c = j.name == selected ? selectedColor : color;
        out
          ..add(LuminaViewportSegment(j.position - right * s, j.position + right * s, c))
          ..add(LuminaViewportSegment(j.position - up * s, j.position + up * s, c));
      }
    }

    for (final overlay in scene.skeletonOverlays) {
      final node = '${overlay['node']}';
      final bones = overlay['bones'] is List ? {for (final b in overlay['bones']! as List) '$b'} : null;
      final selected = overlay['selected'] as String?;
      skeleton(runtime.jointsOf(node), _rgba(overlay['color'], const [1.0, 0.85, 0.2, 1.0]),
          bones: bones, selected: selected, crosses: overlay['joints'] != false);
      final ghost = runtime.ghostPoseFor(node, overlay);
      if (ghost != null) {
        skeleton(runtime.ghostJointsOf(node, ghost), _rgba(overlay['ghostColor'], const [0.4, 0.8, 1.0, 0.6]), bones: bones, crosses: false);
      }
      for (final g in overlay['ghosts'] is List ? overlay['ghosts']! as List : const []) {
        if (g is! Map || g['pose'] is! Map<String, Object?>) continue;
        skeleton(runtime.ghostJointsOf(node, g['pose']! as Map<String, Object?>), _rgba(g['color'], const [0.4, 0.8, 1.0, 0.6]),
            bones: bones, crosses: false);
      }
    }
    for (final m in scene.markers) {
      List<double> v(Object? x) => x is List && x.length >= 3 ? [for (final e in x.take(3)) (e as num).toDouble()] : const [0.0, 0.0, 0.0];
      final c = _rgba(m['color'], const [1.0, 0.33, 0.33, 1.0]);
      final a = LuminaAxes.location(v(m['from']));
      switch (m['kind']) {
        case 'line':
        case 'arrow':
          final b = LuminaAxes.location(v(m['to']));
          out.add(LuminaViewportSegment(a, b, c));
          final d = b - a;
          if (m['kind'] == 'arrow' && d.length > 1e-3) {
            final dir = d.normalized();
            final side = dir.cross(forward);
            if (side.length2 < 1e-9) side.setFrom(right);
            side.normalize();
            final head = math.min(d.length * 0.25, size * 4);
            out
              ..add(LuminaViewportSegment(b, b - dir * head + side * head * 0.5, c))
              ..add(LuminaViewportSegment(b, b - dir * head - side * head * 0.5, c));
          }
        default:
          for (final axis in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]) {
            out.add(LuminaViewportSegment(a - axis * size * 1.5, a + axis * size * 1.5, c));
          }
      }
    }
    return out;
  }
}
