import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/ffi.dart' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The terrain's albedo comes from the local slope (so a tile's
/// colours depend only on its own samples), and a windowed sculpt upload can
/// carry those colours.

/// A ridge along X: flat ground on both sides, a 60° flank in the middle.
LandscapeData _ridge({int resolution = 129}) {
  final data = LandscapeData.flat(gridResolution: resolution, worldSize: 128.0, maxHeight: 100.0);
  final slope = math.tan(60 * math.pi / 180);
  for (var r = 0; r < resolution; r++) {
    final z = data.worldZOf(r);
    final h = (20.0 - z.abs() * slope).clamp(0.0, 20.0);
    for (var c = 0; c < resolution; c++) {
      data.setHeight(c, r, h + 5.0);
    }
  }
  return data;
}

/// The RGBA a tile's vertex [v] holds in its GPU buffer.
List<int> _colourOf(LuminaProceduralMeshComponent mesh, int section, int v, int colorOffset) {
  final stride = mesh.getSectionStride(section);
  final bytes = ffi.Pointer<ffi.Uint8>.fromAddress(mesh.getSectionStagingPointerAddress(section))
      .asTypedList(stride * mesh.sectionVertexCount(section));
  return bytes.sublist(v * stride + colorOffset, v * stride + colorOffset + 4).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the albedo follows the local slope, never the terrain\'s global height range', () {
    final data = _ridge();
    final map = LandscapeSectionMap(gridResolution: data.gridResolution);
    // Tile 0 covers rows 0..64: row 10 is flat ground, the rows near 64 are
    // on the 60° flank.
    List<int> colourAt(LandscapeData d, int col, int row) {
      final geo = LandscapeMeshBuilder.buildSection(d, map, 0);
      final v = row * geo.verticesPerRow + col;
      return geo.colors.sublist(v * 4, v * 4 + 4).toList();
    }

    final flat = colourAt(data, 20, 10);
    final flankRow = List.generate(65, (r) => r).firstWhere((r) => data.sampleSlopeDegrees(data.worldXOf(20), data.worldZOf(r)) > 55);
    final steep = colourAt(data, 20, flankRow);
    expect(flat, LandscapeMeshBuilder.grassAlbedo, reason: 'flat ground is grass');
    expect(steep, LandscapeMeshBuilder.rockAlbedo, reason: 'a 60° flank is rock');

    // Raising a far corner by 50 m changes the global height range but no
    // colour elsewhere.
    final raised = _ridge();
    for (var r = 120; r < 129; r++) {
      for (var c = 120; c < 129; c++) {
        raised.setHeight(c, r, 75.0);
      }
    }
    expect(colourAt(raised, 20, 10), flat);
    expect(colourAt(raised, 20, flankRow), steep);
  });

  test('a windowed update that carries colours writes them into the tile', () async {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    world.initializeNativeContext(engine, scene);
    final data = _ridge();
    final landscape = LuminaLandscapeComponent.editable(unitsPerMetre: 1.0);
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.mountPayload(data);
    final map = landscape.sectionMap!;
    final window = map.windowsFor(const HeightRect(10, 10, 12, 12)).single;
    final count = window.verticesPerRow * window.rowCount;
    final positions = Float32List(count * 3);
    final normals = Float32List(count * 3);
    final colors = Uint8List(count * 4);
    LandscapeMeshBuilder.fillVertices(
      data,
      map,
      window.sectionIndex,
      firstLocalRow: window.firstLocalRow,
      rowCount: window.rowCount,
      positions: positions,
      normals: normals,
      unitsPerMetre: 1.0,
    );
    for (var i = 0; i < count; i++) {
      colors.setRange(i * 4, i * 4 + 4, [200, 10, 20, 255]);
    }
    landscape.updateTerrainSection(window, positions: positions, normals: normals, colors: colors);
    final mesh = landscape.terrainMesh!;
    // pos(12) + tangents(8) + uv0(8) → colour at byte 28.
    expect(_colourOf(mesh, window.sectionIndex, window.vertexOffset, 28), [200, 10, 20, 255]);
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });
}
