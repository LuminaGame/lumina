import 'dart:typed_data';

import 'package:lumina_core/src/garment/garment_fitter.dart';
import 'package:lumina_core/src/garment/skinned_mesh_data.dart';
import 'package:lumina_core/src/services/glb_animation_merger.dart' show GlbDocument;

/// Writes a fitted garment as a skinned GLB over the target body's
/// skeleton: the body's nodes (names, rest transforms, hierarchy; its own
/// meshes left out), one skin over the joints the garment uses with the
/// body's inverse bind matrices, and the garment mesh (metres) with one
/// primitive per source primitive and the source's materials, textures and
/// images. A pose follower of the body animates it by bone name.
abstract final class LuminaGarmentGlbWriter {
  static Uint8List write({
    required LuminaGarmentFit fit,
    required LuminaSkinnedMeshData source,
    required LuminaSkinnedMeshData targetBody,
    String name = 'garment',
  }) {
    final bin = BytesBuilder();
    final views = <Map<String, Object?>>[];
    final accessors = <Map<String, Object?>>[];

    int view(Uint8List bytes, {int? target}) {
      while (bin.length % 4 != 0) {
        bin.addByte(0);
      }
      final offset = bin.length;
      bin.add(bytes);
      views.add({'buffer': 0, 'byteOffset': offset, 'byteLength': bytes.length, 'target': ?target});
      return views.length - 1;
    }

    int accessor(Uint8List bytes, int componentType, int count, String type, {List<double>? min, List<double>? max, int? target}) {
      accessors.add({
        'bufferView': view(bytes, target: target),
        'componentType': componentType,
        'count': count,
        'type': type,
        'min': ?min,
        'max': ?max,
      });
      return accessors.length - 1;
    }

    final n = fit.vertexCount;
    // Joints the garment uses, in node order; per-vertex joints become
    // indices into this list.
    final used = <int>{};
    for (var i = 0; i < fit.joints.length; i++) {
      if (fit.weights[i] > 0) used.add(fit.joints[i]);
    }
    if (used.isEmpty && fit.joints.isNotEmpty) used.add(fit.joints[0]);
    final skinJoints = used.toList()..sort();
    final jointIndex = {for (var i = 0; i < skinJoints.length; i++) skinJoints[i]: i};

    final positions = Float32List(n * 3);
    final min = [double.infinity, double.infinity, double.infinity], max = [-double.infinity, -double.infinity, -double.infinity];
    for (var i = 0; i < n * 3; i++) {
      final v = fit.positions[i] / 100;
      positions[i] = v;
      final k = i % 3;
      if (v < min[k]) min[k] = v;
      if (v > max[k]) max[k] = v;
    }
    final joints = Uint16List(n * 4);
    for (var i = 0; i < n * 4; i++) {
      joints[i] = fit.weights[i] > 0 ? jointIndex[fit.joints[i]]! : 0;
    }
    final attributes = {
      'POSITION': accessor(positions.buffer.asUint8List(), 5126, n, 'VEC3', min: min, max: max, target: 34962),
      'NORMAL': accessor(Float32List.fromList(fit.normals).buffer.asUint8List(), 5126, n, 'VEC3', target: 34962),
      'TEXCOORD_0': accessor(Float32List.fromList(fit.uvs).buffer.asUint8List(), 5126, n, 'VEC2', target: 34962),
      'JOINTS_0': accessor(joints.buffer.asUint8List(), 5123, n, 'VEC4', target: 34962),
      'WEIGHTS_0': accessor(Float32List.fromList(fit.weights).buffer.asUint8List(), 5126, n, 'VEC4', target: 34962),
      // The source's vertex colours (a garment coloured per vertex).
      if (source.colors case final c? when c.length == n * 4)
        'COLOR_0': accessor(Float32List.fromList(c).buffer.asUint8List(), 5126, n, 'VEC4', target: 34962),
    };

    // The source's materials with their textures and images.
    final src = source.document.json;
    final images = <Map<String, Object?>>[];
    for (final image in (src['images'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final copy = Map<String, Object?>.of(image);
      final v = image['bufferView'] as num?;
      if (v != null) {
        final sv = (src['bufferViews'] as List)[v.toInt()] as Map<String, dynamic>;
        final offset = (sv['byteOffset'] as num? ?? 0).toInt();
        copy['bufferView'] = view(Uint8List.sublistView(source.document.bin, offset, offset + (sv['byteLength'] as num).toInt()));
      }
      images.add(copy);
    }
    final primitives = <Map<String, Object?>>[];
    final refs = source.primitives.isEmpty
        ? [LuminaGlbPrimitiveRef(mesh: 0, primitive: 0, node: 0, firstVertex: 0, vertexCount: n, firstTriangle: 0, triangleCount: fit.triangles.length ~/ 3, material: null, indexAccessor: null)]
        : source.primitives;
    for (final ref in refs) {
      final indices = Uint32List.sublistView(fit.triangles, ref.firstTriangle * 3, (ref.firstTriangle + ref.triangleCount) * 3);
      primitives.add({
        'attributes': attributes,
        'indices': accessor(Uint32List.fromList(indices).buffer.asUint8List(), 5125, indices.length, 'SCALAR', target: 34963),
        'material': ?ref.material,
      });
    }

    // The body's nodes without their meshes, then the garment's node.
    final bodyJson = targetBody.document.json;
    final nodes = <Map<String, Object?>>[
      for (final node in (bodyJson['nodes'] as List? ?? const []).cast<Map<String, dynamic>>())
        {
          for (final e in node.entries)
            if (const {'name', 'translation', 'rotation', 'scale', 'matrix', 'children', 'extras'}.contains(e.key)) e.key: e.value,
        },
    ];
    final ibm = Float32List(skinJoints.length * 16);
    for (var j = 0; j < skinJoints.length; j++) {
      final m = targetBody.inverseBind[skinJoints[j]] ?? _inverseOfWorld(targetBody, skinJoints[j]);
      for (var e = 0; e < 16; e++) {
        ibm[j * 16 + e] = (e >= 12 && e <= 14) ? m[e] / 100 : m[e];
      }
    }
    final skin = {
      'name': '${name}_skin',
      'joints': skinJoints,
      'inverseBindMatrices': accessor(ibm.buffer.asUint8List(), 5126, skinJoints.length, 'MAT4'),
    };
    nodes.add({'name': name, 'mesh': 0, 'skin': 0});
    final roots = <int>[];
    final scenes = bodyJson['scenes'] as List?;
    final scene = (bodyJson['scene'] as num?)?.toInt() ?? 0;
    if (scenes != null && scenes.isNotEmpty) {
      roots.addAll([for (final r in ((scenes[scene] as Map)['nodes'] as List? ?? const [])) (r as num).toInt()]);
    } else {
      for (var i = 0; i < targetBody.nodeParents.length; i++) {
        if (targetBody.nodeParents[i] < 0) roots.add(i);
      }
    }
    roots.add(nodes.length - 1);

    final extensionsUsed = [
      for (final e in (src['extensionsUsed'] as List? ?? const []))
        if (e != 'KHR_draco_mesh_compression' && e != 'KHR_mesh_quantization') e,
    ];
    final json = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'Lumina garment fitter'},
      'extensionsUsed': ?(extensionsUsed.isEmpty ? null : extensionsUsed),
      'extensionsRequired': ?_required(src, extensionsUsed),
      'scene': 0,
      'scenes': [
        {'nodes': roots},
      ],
      'nodes': nodes,
      'meshes': [
        {'name': name, 'primitives': primitives},
      ],
      'skins': [skin],
      'accessors': accessors,
      'bufferViews': views,
      'buffers': [
        {'byteLength': (bin.length + 3) & ~3},
      ],
      'materials': ?src['materials'],
      'textures': ?src['textures'],
      'samplers': ?src['samplers'],
      'images': images.isEmpty ? null : images,
    }..removeWhere((_, v) => v == null);
    final body = bin.takeBytes();
    final padded = Uint8List((body.length + 3) & ~3)..setRange(0, body.length, body);
    return GlbDocument(json, padded).encode();
  }

  static List<Object?>? _required(Map<String, dynamic> src, List<Object?> used) {
    final required = [
      for (final e in (src['extensionsRequired'] as List? ?? const []))
        if (used.contains(e)) e,
    ];
    return required.isEmpty ? null : required;
  }

  static List<double> _inverseOfWorld(LuminaSkinnedMeshData body, int node) {
    final m = Float64List.sublistView(body.nodeWorld, node * 16, node * 16 + 16);
    // Rigid inverse (rotation transposed), good for rest poses without shear.
    final out = List<double>.filled(16, 0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        out[c * 4 + r] = m[r * 4 + c];
      }
    }
    for (var r = 0; r < 3; r++) {
      out[12 + r] = -(out[r] * m[12] + out[4 + r] * m[13] + out[8 + r] * m[14]);
    }
    out[15] = 1;
    return out;
  }
}
