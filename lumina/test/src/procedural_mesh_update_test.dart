import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/ffi.dart' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// `updateMeshSection` must honour the normals it is given (the
/// tangent frame a lit material shades with) and grow the section's bounds
/// to the positions it writes.

/// Normal encoded by a packed Filament tangent frame (the quaternion's third
/// column, as `toTangentFrame` in Filament's shaders computes it).
(double, double, double) _normalOf(Int16List q) {
  final x = q[0] / 32767.0, y = q[1] / 32767.0, z = q[2] / 32767.0, w = q[3] / 32767.0;
  return (2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an update re-derives the tangent frames from the new normals and grows the bounds', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    expect(engine, isNotNull);
    final scene = engine!.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    world.initializeNativeContext(engine, scene);
    final mesh = LuminaProceduralMeshComponent();
    world.persistentLevel.registerActor(LuminaActor(root: mesh));

    // A flat 3×3 grid facing up.
    final positions = Float32List(9 * 3);
    final normals = Float32List(9 * 3);
    final colors = Uint8List(9 * 4)..fillRange(0, 36, 255);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final v = r * 3 + c;
        positions[v * 3] = c.toDouble();
        positions[v * 3 + 2] = r.toDouble();
        normals[v * 3 + 1] = 1.0;
      }
    }
    final indices = Uint32List.fromList([0, 3, 1, 1, 3, 4, 1, 4, 2, 2, 4, 5, 3, 6, 4, 4, 6, 7, 4, 7, 5, 5, 7, 8]);
    mesh.createMeshSection(0, positions: positions, normals: normals, colors: colors, indices: indices);
    expect(mesh.sectionBounds(0)!.max.y, 0.0);

    // Raise the centre vertex to y = 50 and tilt every normal 45° towards +X.
    final moved = Float32List.fromList(positions);
    moved[4 * 3 + 1] = 50.0;
    final tilted = Float32List(9 * 3);
    final s = math.sqrt(0.5);
    for (var v = 0; v < 9; v++) {
      tilted[v * 3] = s;
      tilted[v * 3 + 1] = s;
    }
    mesh.updateMeshSection(0, positions: moved, normals: tilted);

    // The tangent frames the GPU buffer holds must encode the new normals.
    final stride = mesh.getSectionStride(0);
    final bytes = ffi.Pointer<ffi.Uint8>.fromAddress(mesh.getSectionStagingPointerAddress(0))
        .asTypedList(stride * mesh.sectionVertexCount(0));
    final view = ByteData.sublistView(bytes);
    for (var v = 0; v < 9; v++) {
      final q = Int16List(4);
      for (var k = 0; k < 4; k++) {
        q[k] = view.getInt16(v * stride + 12 + k * 2, Endian.host);
      }
      final n = _normalOf(q);
      expect(n.$1, closeTo(s, 0.01), reason: 'vertex $v still shades with its creation-time normal (x = ${n.$1})');
      expect(n.$2, closeTo(s, 0.01), reason: 'vertex $v still shades with its creation-time normal (y = ${n.$2})');
      expect(n.$3, closeTo(0.0, 0.01));
    }

    // The bounds — the Dart copy and the renderable Filament culls with.
    expect(mesh.sectionBounds(0)!.max.y, greaterThanOrEqualTo(50.0),
        reason: 'the section keeps its creation-time box');
    final box = FilamentRenderableManager(engine).getAxisAlignedBoundingBox(mesh.sectionEntity(0));
    expect(box.center.y + box.halfExtent.y, greaterThanOrEqualTo(50.0 - 1e-3),
        reason: 'the renderable is culled and shadow-fitted against its creation-time box');

    world.cleanup();
    scene.dispose();
    engine.dispose();
  });
}
