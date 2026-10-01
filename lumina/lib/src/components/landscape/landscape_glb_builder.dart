import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../data/models/landscape_data.dart';
import '../../../data/models/lumina_asset.dart';
import '../../../data/services/glb_parser_service.dart';

/// Turns a landscape payload into an ordinary glTF 2.0 binary.
///
/// The main level viewport draws actors through `FilamentAssetLoader`, i.e.
/// from glTF payloads, not from lumina scene components. Rather than teach it
/// a second terrain path, a placed `Landscape` actor carries a glTF proxy of
/// its own heightmap built here — the same heights, the same height ramp in
/// `COLOR_0` as [LandscapeMeshBuilder] bakes into the runtime tiles — so the
/// terrain the designer sculpted is what they see in the level, and picking,
/// bounds and the triangle counter all work unchanged.
///
/// This is a *viewport proxy*: at play time (and in generated game code) the
/// terrain is drawn by `LuminaLandscapeComponent` from the same payload, with
/// its tiles, foliage and partial updates. The proxy carries no foliage.
class LandscapeGlbBuilder {
  const LandscapeGlbBuilder._();

  /// Proxy units per terrain metre: **1**, i.e. glTF metres.
  ///
  /// The level viewport draws every glTF mesh × the asset unit scale (100),
  /// so a proxy emitted in metres lands in centimetres exactly
  /// where Play's `LuminaLandscapeComponent` draws the terrain: its surface
  /// at height 0 on the actor's origin. Emitting centimetres here drew the
  /// terrain a hundred times too large.
  static const double proxyUnitsPerMetre = 1.0;

  /// The old name of [proxyUnitsPerMetre].
  @Deprecated('use proxyUnitsPerMetre')
  static const double editorUnitsPerMetre = proxyUnitsPerMetre;

  /// Vertices per side the proxy is capped at.
  ///
  /// A 257² grid is 66 049 vertices / 131 072 triangles — heavy enough to read
  /// as the sculpted terrain, light enough that dropping one into a level does
  /// not stall the editor. Larger heightmaps are sampled down **for the proxy
  /// only**; the payload, the runtime component and the saved asset keep every
  /// sample.
  static const int maxProxyResolution = 257;

  /// Builds a `.glb` for [data].
  static Uint8List build(
    LandscapeData data, {
    double unitsPerMetre = proxyUnitsPerMetre,
    int maxResolution = maxProxyResolution,
  }) {
    final full = data.gridResolution;
    final step = _stepFor(full, maxResolution);
    final side = ((full - 1) ~/ step) + 1;

    final positions = Float32List(side * side * 3);
    final normals = Float32List(side * side * 3);
    final colors = Uint8List(side * side * 4);

    final lo = data.heightMin;
    final hi = data.heightMax;
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;

    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;

    var v = 0;
    for (var r = 0; r < side; r++) {
      final gr = r * step >= full ? full - 1 : r * step;
      for (var c = 0; c < side; c++) {
        final gc = c * step >= full ? full - 1 : c * step;
        final wx = data.worldXOf(gc);
        final wz = data.worldZOf(gr);
        final wy = data.heightAt(gc, gr);
        final x = wx * unitsPerMetre;
        final y = wy * unitsPerMetre;
        final z = wz * unitsPerMetre;
        positions[v * 3] = x;
        positions[v * 3 + 1] = y;
        positions[v * 3 + 2] = z;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (z < minZ) minZ = z;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
        if (z > maxZ) maxZ = z;

        final n = data.sampleNormal(wx, wz);
        normals[v * 3] = n.x;
        normals[v * 3 + 1] = n.y;
        normals[v * 3 + 2] = n.z;

        final t = ((wy - lo) / span).clamp(0.0, 1.0);
        colors[v * 4] = (60 + 150 * t).round();
        colors[v * 4 + 1] = (95 + 120 * t).round();
        colors[v * 4 + 2] = (55 + 90 * t).round();
        colors[v * 4 + 3] = 255;
        v++;
      }
    }

    final quads = (side - 1) * (side - 1);
    final vertexCount = side * side;
    final useShortIndices = vertexCount <= 65535;
    final indexCount = quads * 6;
    final indices = useShortIndices ? Uint16List(indexCount) : Uint32List(indexCount);
    var k = 0;
    for (var r = 0; r < side - 1; r++) {
      for (var c = 0; c < side - 1; c++) {
        final a = r * side + c;
        final b = a + 1;
        final d = a + side;
        final e = d + 1;
        indices[k++] = a;
        indices[k++] = d;
        indices[k++] = b;
        indices[k++] = b;
        indices[k++] = d;
        indices[k++] = e;
      }
    }

    final bin = BytesBuilder();
    void pad() {
      while (bin.length % 4 != 0) {
        bin.addByte(0);
      }
    }

    const posOffset = 0;
    bin.add(positions.buffer.asUint8List());
    pad();
    final normOffset = bin.length;
    bin.add(normals.buffer.asUint8List());
    pad();
    final colorOffset = bin.length;
    bin.add(colors);
    pad();
    final idxOffset = bin.length;
    final indexBytes = indices.buffer.asUint8List(0, indices.lengthInBytes);
    bin.add(indexBytes);
    pad();
    final binBytes = bin.toBytes();

    final gltf = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'lumina LandscapeGlbBuilder'},
      'scene': 0,
      'scenes': [
        {
          'nodes': [0]
        }
      ],
      'nodes': [
        {'mesh': 0, 'name': 'Landscape'}
      ],
      'meshes': [
        {
          'name': 'Landscape',
          'primitives': [
            {
              'attributes': {'POSITION': 0, 'NORMAL': 1, 'COLOR_0': 2},
              'indices': 3,
              'material': 0,
              'mode': 4,
            }
          ],
        }
      ],
      'materials': [
        {
          'name': 'M_Landscape',
          'doubleSided': true,
          'pbrMetallicRoughness': {
            'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
            'metallicFactor': 0.0,
            'roughnessFactor': 0.95,
          },
        }
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': vertexCount,
          'type': 'VEC3',
          'min': [minX, minY, minZ],
          'max': [maxX, maxY, maxZ],
        },
        {'bufferView': 1, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC3'},
        {
          'bufferView': 2,
          'componentType': 5121,
          'normalized': true,
          'count': vertexCount,
          'type': 'VEC4',
        },
        {
          'bufferView': 3,
          'componentType': useShortIndices ? 5123 : 5125,
          'count': indexCount,
          'type': 'SCALAR',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': posOffset, 'byteLength': positions.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': normOffset, 'byteLength': normals.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': colorOffset, 'byteLength': colors.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': idxOffset, 'byteLength': indexBytes.length, 'target': 34963},
      ],
      'buffers': [
        {'byteLength': binBytes.length}
      ],
    };

    final jsonBuilder = BytesBuilder()..add(utf8.encode(jsonEncode(gltf)));
    while (jsonBuilder.length % 4 != 0) {
      jsonBuilder.addByte(0x20);
    }
    final jsonBytes = jsonBuilder.toBytes();

    final total = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
    final out = BytesBuilder();
    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little) // "glTF"
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, total, Endian.little);
    out.add(header.buffer.asUint8List());
    final jsonHeader = ByteData(8)
      ..setUint32(0, jsonBytes.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little); // "JSON"
    out.add(jsonHeader.buffer.asUint8List());
    out.add(jsonBytes);
    final binHeader = ByteData(8)
      ..setUint32(0, binBytes.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little); // "BIN\0"
    out.add(binHeader.buffer.asUint8List());
    out.add(binBytes);
    return out.toBytes();
  }

  /// Parsed viewport geometry for the `LANDSCAPE` `.lmas` at [assetPath].
  ///
  /// Returns null when the file is missing or carries no landscape payload —
  /// the caller then behaves exactly as it does for any unreadable asset,
  /// rather than showing a placeholder that pretends to be terrain.
  static Future<GlbMeshData?> proxyMeshFor(
    String assetPath, {
    double unitsPerMetre = proxyUnitsPerMetre,
    int maxResolution = maxProxyResolution,
  }) async {
    try {
      final file = File(assetPath);
      if (!file.existsSync()) return null;
      var bytes = file.readAsBytesSync();
      if (assetPath.toLowerCase().endsWith('.lmas')) {
        final payload = LuminaAsset.fromBytes(bytes).rawPayload;
        if (payload == null || payload.isEmpty) return null;
        bytes = payload;
      }
      final data = LandscapeData.fromBytes(bytes);
      // A large landscape's heights live in the sidecar next to the asset.
      if (data.samplesAreExternal) {
        final sidecar = File(LandscapeData.sidecarPathFor(assetPath));
        if (!sidecar.existsSync()) return null;
        data.readSidecar(sidecar);
      }
      final glb = build(data, unitsPerMetre: unitsPerMetre, maxResolution: maxResolution);
      return await GlbParserService.parseGlb(glb);
    } catch (_) {
      return null;
    }
  }

  /// The sampling step that keeps a [full]² grid within [maxResolution]².
  ///
  /// Only powers of two are used, so the proxy keeps the terrain's seam
  /// samples and its corners land exactly on real heights.
  static int _stepFor(int full, int maxResolution) {
    var step = 1;
    while (((full - 1) ~/ step) + 1 > maxResolution) {
      step *= 2;
    }
    return step;
  }
}
