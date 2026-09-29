import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// The brush cursor draped on the terrain: its rings sit at the
/// brush's radii, every vertex stays above the triangulated terrain, the fill
/// fades across the falloff band, and the component moves it in place.

/// A real sculpted terrain: a ridge, a bowl and ripples, so a flat cursor
/// would sink into it somewhere.
LandscapeData _terrain() {
  final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);
  const half = 64.0;
  for (var r = 0; r < 129; r++) {
    for (var c = 0; c < 129; c++) {
      final u = (c - half) / half;
      final v = (r - half) / half;
      final ridge = math.exp(-((u - v) * (u - v)) * 6.0) * 40.0;
      final bowl = -math.exp(-(u * u + v * v) * 3.0) * 18.0;
      final ripple = math.sin(c * 0.9) * math.cos(r * 0.7) * 2.5;
      data.setHeight(c, r, (25.0 + ridge + bowl + ripple).clamp(0.0, 100.0));
    }
  }
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LandscapeBrushCursorGeometry', () {
    final data = _terrain();
    const cx = 12.0, cz = -7.0, radius = 30.0;

    LandscapeBrushCursorGeometry build(double falloff) => LandscapeBrushCursorGeometry.build(
          data,
          centerX: cx,
          centerZ: cz,
          radius: radius,
          falloff: falloff,
          color: Vector3(1.0, 0.8, 0.2),
        );

    double distOf(LandscapeBrushCursorGeometry g, int v) {
      final dx = g.positions[v * 3] - cx;
      final dz = g.positions[v * 3 + 2] - cz;
      return math.sqrt(dx * dx + dz * dz);
    }

    test('the outer ring lies at the radius and the inner ring at radius × (1 − falloff)', () {
      final g = build(0.4);
      final outer = g.verticesOf(LandscapeCursorRing.outerEdge);
      final inner = g.verticesOf(LandscapeCursorRing.innerLine);
      expect(outer, isNotEmpty);
      expect(inner, isNotEmpty);
      for (final v in outer) {
        expect(distOf(g, v), closeTo(radius, 1e-3), reason: 'outer-ring vertex $v');
      }
      for (final v in inner) {
        expect(distOf(g, v), closeTo(radius * 0.6, g.lineWidth), reason: 'inner-ring vertex $v');
      }
      for (final v in g.verticesOf(LandscapeCursorRing.outerLine)) {
        expect(g.colors[v * 4 + 3], greaterThan(200), reason: 'the outer ring is crisp');
      }
      for (final v in inner) {
        expect(g.colors[v * 4 + 3], greaterThan(200), reason: 'the inner ring is crisp');
      }
    });

    test('with no falloff there is no inner ring', () {
      final g = build(0.01);
      for (final v in g.verticesOf(LandscapeCursorRing.innerLine)) {
        expect(g.colors[v * 4 + 3], 0, reason: 'a hard brush has only its outer ring');
      }
    });

    test('every vertex is draped on the terrain under it', () {
      final g = build(0.5);
      for (var v = 0; v < g.vertexCount; v++) {
        final x = g.positions[v * 3], y = g.positions[v * 3 + 1], z = g.positions[v * 3 + 2];
        final ground = data.sampleHeight(x, z);
        expect(y, greaterThan(ground), reason: 'vertex $v sinks into the terrain');
        expect(y - ground, lessThanOrEqualTo(math.max(data.cellSize * 0.05, 0.05) + 1e-4),
            reason: 'vertex $v floats above the terrain');
      }
    });

    test('colours are premultiplied by their alpha', () {
      final g = build(0.5);
      for (var v = 0; v < g.vertexCount; v++) {
        final a = g.colors[v * 4 + 3];
        expect(g.colors[v * 4], closeTo(255 * a / 255, 1.0), reason: 'red of vertex $v');
        expect(g.colors[v * 4 + 2], closeTo(0.2 * 255 * a / 255, 1.0), reason: 'blue of vertex $v');
      }
    });

    test('the fill is solid inside the inner radius and fades across the falloff band', () {
      final g = build(0.5);
      final fill = g.verticesOf(LandscapeCursorRing.fill);
      // One alpha per ring (every vertex of a ring shares it), ordered by t.
      final byT = <double, int>{};
      for (final v in fill) {
        byT[g.ringTOf(v)] = g.colors[v * 4 + 3];
      }
      final ts = byT.keys.toList()..sort();
      final coreAlpha = byT[ts.first]!;
      expect(coreAlpha, greaterThan(20));
      for (final t in ts.where((t) => t <= 0.5)) {
        expect(byT[t], coreAlpha, reason: 'the core (t = $t) is full strength');
      }
      var previous = coreAlpha;
      for (final t in ts.where((t) => t > 0.5)) {
        expect(byT[t]!, lessThanOrEqualTo(previous), reason: 'the band fades outwards (t = $t)');
        previous = byT[t]!;
      }
      expect(byT[ts.last], lessThanOrEqualTo(2), reason: 'the fill has faded out at the rim');
    });
  });

  test('the component shows, moves and hides one shadowless renderable', () async {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    world.initializeNativeContext(engine, scene);
    final landscape = LuminaLandscapeComponent.editable(unitsPerMetre: 1.0);
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.mountPayload(_terrain());
    final rm = FilamentRenderableManager(engine);

    expect(landscape.brushCursor, isNull);
    final before = scene.renderableCount;
    landscape.showBrushCursor(LandscapeBrushCursor(centerX: 0, centerZ: 0, radius: 20, falloff: 0.5, color: Vector3(1, 0.8, 0.2)));
    final mesh = landscape.brushCursorMesh!;
    final entity = mesh.sectionEntity(0);
    final vertices = mesh.sectionVertexCount(0);
    expect(entity, isNot(0));
    expect(scene.renderableCount, before + 1);
    expect(scene.hasEntity(entity), isTrue);
    expect(rm.isShadowCaster(entity), isFalse, reason: 'the cursor must never throw a shadow');
    expect(rm.isShadowReceiver(entity), isFalse);

    landscape.showBrushCursor(LandscapeBrushCursor(centerX: 40, centerZ: -30, radius: 35, falloff: 0.2, color: Vector3(1, 0.3, 0.3)));
    expect(mesh.sectionEntity(0), entity, reason: 'moving the cursor updates it in place');
    expect(mesh.sectionVertexCount(0), vertices);
    expect(scene.renderableCount, before + 1);
    expect(landscape.brushCursor!.centerX, 40);

    landscape.hideBrushCursor();
    expect(landscape.brushCursor, isNull);
    expect(scene.hasEntity(entity), isFalse, reason: 'a hidden cursor is out of the scene');

    world.cleanup();
    scene.dispose();
    engine.dispose();
  });
}
