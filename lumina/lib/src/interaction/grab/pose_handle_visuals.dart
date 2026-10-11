import 'dart:math' as math;

import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/interaction/grab/pose_grab_interactor.dart';
import 'package:lumina/src/umg/viewport/viewport_overlay_lines.dart';

/// Draws the pose handles a [LuminaPoseGrabInteractor] can reach as small
/// rings (three circles) of Filament lines over the meshes: idle handles
/// faint ([LuminaPoseGrabInteractor.idleAlpha], hidden at 0), a hovered one
/// in the accent colour and 1.3× larger, a held one bright with a line to
/// the grabber holding it. Only handles near a grabber (or near its ray)
/// show, so a posed character is not cluttered.
class LuminaPoseHandleVisuals {
  LuminaPoseHandleVisuals(FilamentEngine engine, FilamentScene scene) : _lines = LuminaViewportOverlayLines(engine, scene);

  final LuminaViewportOverlayLines _lines;

  static const List<double> hoverColor = [0.25, 0.75, 1.0, 1.0];
  static const List<double> heldColor = [1.0, 0.84, 0.25, 1.0];

  /// How near a grabber (cm, or degrees off its ray) a handle shows.
  static const double showDistance = 60.0, showRayDegrees = 12.0;

  /// Lines drawn by the last [update].
  int get lineCount => _lines.lineCount;

  void update(LuminaPoseGrabInteractor interactor) => _lines.update(segmentsFor(interactor));

  void dispose() => _lines.dispose();

  /// The segments [interactor]'s handles need now.
  static List<LuminaViewportSegment> segmentsFor(LuminaPoseGrabInteractor interactor) {
    final out = <LuminaViewportSegment>[];
    final grabbers = interactor.grabbers;
    for (final poser in interactor.posers) {
      for (final name in poser.handles.keys) {
        final at = poser.handleWorldLocation(name);
        if (at == null) continue;
        var held = false, hovered = false, near = false;
        for (final g in grabbers) {
          final h = interactor.heldBy(g), o = interactor.hoveredBy(g);
          if (h != null && identical(h.poser, poser) && h.handle == name) {
            held = true;
            out.add(LuminaViewportSegment(g.worldTransform.getTranslation(), at, heldColor));
          }
          if (o != null && identical(o.poser, poser) && o.handle == name) hovered = true;
          if (g.worldTransform.getTranslation().distanceTo(at) <= showDistance) near = true;
          final ray = g.ray;
          if (ray != null) {
            final v = at - ray.origin;
            final d = v.length;
            if (d > 1e-6 && math.acos((v.dot(ray.direction) / d).clamp(-1.0, 1.0)) <= showRayDegrees * math.pi / 180) near = true;
          }
        }
        final List<double> color;
        var radius = interactor.radiusOf(name) * 0.5;
        if (held) {
          color = heldColor;
        } else if (hovered) {
          color = hoverColor;
          radius *= 1.3;
        } else if (near && interactor.idleAlpha > 0) {
          color = [0.92, 0.92, 0.92, interactor.idleAlpha];
        } else {
          continue;
        }
        _ring(out, at, radius, color);
      }
    }
    return out;
  }

  static void _ring(List<LuminaViewportSegment> out, Vector3 at, double radius, List<double> color) {
    const n = 10;
    for (final axes in const [(0, 1), (0, 2), (1, 2)]) {
      Vector3 point(int i) {
        final a = i * 2 * math.pi / n;
        final v = Vector3.zero();
        v[axes.$1] = math.cos(a) * radius;
        v[axes.$2] = math.sin(a) * radius;
        return at + v;
      }

      for (var i = 0; i < n; i++) {
        out.add(LuminaViewportSegment(point(i), point(i + 1), color));
      }
    }
  }
}
