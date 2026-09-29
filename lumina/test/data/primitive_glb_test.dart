import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// `Primitive` actors (the template test rooms, and "spawn a cube") carry a
/// shape and a size rather than an imported model. The editor still needs real
/// geometry to draw, so the shape is turned into a real glTF binary that goes
/// through the same parser and the same renderer as any imported mesh.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a box GLB parses back with the requested size and colour', () async {
    final bytes = PrimitiveGlbFactory.build(
      shape: 'box',
      sizeX: 2.0,
      sizeY: 1.0,
      sizeZ: 4.0,
      colorHex: '#FF8800',
    );
    // A real glTF binary container, not a blob we invented.
    expect(bytes.length, greaterThan(12));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'glTF');

    final mesh = await GlbParserService.parseGlb(bytes);
    expect(mesh, isNotNull);
    // The parser hands back de-indexed triangles, so a box is 12 triangles of
    // 3 vertices; the 24 split vertices it was authored with are expanded.
    expect(mesh!.indices.length, 36);
    expect(mesh.positions.length ~/ 3, 36);
    expect(mesh.minBounds[0], closeTo(-1.0, 1e-5));
    expect(mesh.maxBounds[0], closeTo(1.0, 1e-5));
    expect(mesh.minBounds[1], closeTo(-0.5, 1e-5));
    expect(mesh.maxBounds[1], closeTo(0.5, 1e-5));
    expect(mesh.minBounds[2], closeTo(-2.0, 1e-5));
    expect(mesh.maxBounds[2], closeTo(2.0, 1e-5));
    // The requested colour rides on the primitive's material slot, which is
    // where the renderer reads it from.
    expect(mesh.subPrimitives, isNotEmpty);
    final slot = mesh.subPrimitives.first.baseColor;
    expect(slot[0], closeTo(1.0, 0.02));
    expect(slot[1], closeTo(0x88 / 255, 0.02));
    expect(slot[2], closeTo(0.1, 0.02), reason: 'the parser clamps a channel to 0.1');
    expect(mesh.rawPayload, isNotNull, reason: 'the viewport feeds rawPayload to Filament');
  });

  test('every shape produces parseable geometry with sane winding and normals', () async {
    for (final shape in ['box', 'plane', 'sphere', 'cylinder']) {
      final mesh = await GlbParserService.parseGlb(
        PrimitiveGlbFactory.build(shape: shape, sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0),
      );
      expect(mesh, isNotNull, reason: '$shape must parse');
      expect(mesh!.positions.length, greaterThan(0), reason: '$shape has vertices');
      expect(mesh.indices.length % 3, 0, reason: '$shape is a triangle list');
      expect(mesh.indices.length, greaterThan(0));
      final maxIndex = mesh.indices.reduce((a, b) => a > b ? a : b);
      expect(maxIndex, lessThan(mesh.positions.length ~/ 3), reason: '$shape indices stay in range');
      // Bounds are centred on the origin so the actor transform places it.
      expect(mesh.minBounds[1], lessThanOrEqualTo(0.0));
      expect(mesh.maxBounds[1], greaterThanOrEqualTo(0.0));
    }
  });

  test('a plane is flat and a sphere is round', () async {
    final plane = (await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'plane', sizeX: 10.0, sizeY: 1.0, sizeZ: 10.0),
    ))!;
    expect(plane.maxBounds[1] - plane.minBounds[1], closeTo(0.0, 1e-6), reason: 'no thickness');
    expect(plane.maxBounds[0] - plane.minBounds[0], closeTo(10.0, 1e-5));

    final sphere = (await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'sphere', sizeX: 2.0, sizeY: 2.0, sizeZ: 2.0),
    ))!;
    expect(sphere.maxBounds[0] - sphere.minBounds[0], closeTo(2.0, 0.05));
    expect(sphere.maxBounds[1] - sphere.minBounds[1], closeTo(2.0, 0.05));
    expect(sphere.maxBounds[2] - sphere.minBounds[2], closeTo(2.0, 0.05));
  });

  test('an unknown shape falls back to a box rather than throwing', () async {
    final mesh = await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'dodecahedron', sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0),
    );
    expect(mesh, isNotNull);
    expect(mesh!.indices.length, 36);
  });

  test('the same request produces byte-identical output', () {
    final a = PrimitiveGlbFactory.build(shape: 'cylinder', sizeX: 1.5, sizeY: 3.0, sizeZ: 1.5);
    final b = PrimitiveGlbFactory.build(shape: 'cylinder', sizeX: 1.5, sizeY: 3.0, sizeZ: 1.5);
    expect(a, b, reason: 'deterministic, so the editor can cache by shape+size');
  });
}
