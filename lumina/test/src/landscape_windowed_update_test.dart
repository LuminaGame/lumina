import 'dart:typed_data';

import 'package:flutter_filament/ffi.dart' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A sculpt's windowed upload must land on the vertices of the rows
/// it was computed for. Every tile's vertex buffer is read back after the
/// stroke and compared with the heightmap's own grid positions.

/// A terrain whose every sample has a distinct height, so a vertex written
/// into the wrong slot is visible in the read-back.
LandscapeData _terrain() {
  final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);
  for (var r = 0; r < 129; r++) {
    for (var c = 0; c < 129; c++) {
      data.setHeight(c, r, 10.0 + ((r * 7 + c * 3) % 11) * 0.5);
    }
  }
  return data;
}

/// The positions a tile's GPU buffer really holds, read from its staging copy.
List<(double, double, double)> _readBack(LuminaProceduralMeshComponent mesh, int section) {
  final stride = mesh.getSectionStride(section);
  final count = mesh.sectionVertexCount(section);
  final bytes = ffi.Pointer<ffi.Uint8>.fromAddress(mesh.getSectionStagingPointerAddress(section))
      .asTypedList(stride * count);
  final view = ByteData.sublistView(bytes);
  return [
    for (var i = 0; i < count; i++)
      (
        view.getFloat32(i * stride, Endian.host),
        view.getFloat32(i * stride + 4, Endian.host),
        view.getFloat32(i * stride + 8, Endian.host),
      ),
  ];
}

String _key((double, double, double) p) =>
    '${p.$1.toStringAsFixed(3)},${p.$2.toStringAsFixed(3)},${p.$3.toStringAsFixed(3)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a windowed sculpt across a tile seam leaves every tile holding exactly its heightmap grid', () async {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    expect(engine, isNotNull);
    final scene = engine!.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    world.initializeNativeContext(engine, scene);

    final data = _terrain();
    final landscape = LuminaLandscapeComponent.editable(unitsPerMetre: 1.0);
    world.persistentLevel.registerActor(LuminaActor(root: landscape));
    await landscape.mountPayload(data);
    final map = landscape.sectionMap!;
    expect(map.sectionCount, 4);

    // A tile that accepts windowed uploads promises that vertex slot k holds
    // heightmap grid point k (row k ~/ 65, column k % 65): the editor computes
    // every window's vertex offset from that. Check the promise on the tiles
    // as mounted, before any stroke.
    void expectRowsAddressable(String when) {
      for (var i = 0; i < map.sectionCount; i++) {
        if (!landscape.supportsPartialUpdate(i)) continue;
        final expected = LandscapeMeshBuilder.buildSection(data, map, i, unitsPerMetre: 1.0);
        final got = _readBack(landscape.terrainMesh!, i);
        expect(got.length, expected.vertexCount);
        final wrong = <int>[];
        for (var v = 0; v < expected.vertexCount; v++) {
          final want = (expected.positions[v * 3], expected.positions[v * 3 + 1], expected.positions[v * 3 + 2]);
          if (_key(got[v]) != _key(want)) wrong.add(v);
        }
        expect(wrong, isEmpty,
            reason: '$when: tile $i accepts windowed uploads, but ${wrong.length} of its vertex slots hold '
                'another grid point (first: slot ${wrong.isEmpty ? '-' : wrong.first}, '
                'which holds ${wrong.isEmpty ? '-' : _key(got[wrong.first])}) — a sculpt window written '
                'there moves the wrong vertices and cracks the tile');
      }
    }

    expectRowsAddressable('as mounted');

    // A stamp centred on the point where all four tiles meet: raise a 9×9
    // block of samples, then upload it the way the editor does — a windowed
    // update where the tile accepts one, a whole-tile rebuild where it does not.
    const rect = HeightRect(60, 60, 68, 68);
    for (var r = rect.minRow; r <= rect.maxRow; r++) {
      for (var c = rect.minCol; c <= rect.maxCol; c++) {
        data.setHeight(c, r, data.heightAt(c, r) + 20.0);
      }
    }
    for (final window in map.windowsFor(rect)) {
      if (!landscape.supportsPartialUpdate(window.sectionIndex)) {
        expect(landscape.rebuildResidentSection(window.sectionIndex), isTrue);
        continue;
      }
      final count = window.verticesPerRow * window.rowCount;
      final positions = Float32List(count * 3);
      final normals = Float32List(count * 3);
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
      landscape.updateTerrainSection(window, positions: positions, normals: normals);
    }

    expectRowsAddressable('after the stroke');
    for (var i = 0; i < map.sectionCount; i++) {
      final expected = LandscapeMeshBuilder.buildSection(data, map, i, unitsPerMetre: 1.0);
      final want = <String, int>{};
      for (var v = 0; v < expected.vertexCount; v++) {
        final k = _key((expected.positions[v * 3], expected.positions[v * 3 + 1], expected.positions[v * 3 + 2]));
        want[k] = (want[k] ?? 0) + 1;
      }
      final got = <String, int>{};
      for (final p in _readBack(landscape.terrainMesh!, i)) {
        got[_key(p)] = (got[_key(p)] ?? 0) + 1;
      }
      final missing = want.keys.where((k) => got[k] != want[k]).length;
      expect(missing, 0,
          reason: 'tile $i: $missing grid positions are missing or duplicated in its vertex buffer — '
              'the stroke wrote rows into vertices that belong to other grid points');
    }

    world.cleanup();
    scene.dispose();
    engine.dispose();
  });
}
