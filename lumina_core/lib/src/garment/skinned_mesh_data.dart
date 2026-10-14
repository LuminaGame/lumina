import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/services/glb_animation_merger.dart' show GlbDocument;
import 'package:lumina_core/src/services/glb_reader.dart' show GlbDracoDecoder;

part 'package:lumina_core/src/garment/skinned_mesh_accessors.dart';

/// Where one glTF primitive sits in a [LuminaSkinnedMeshData]: its vertices
/// and triangles in the combined arrays, its material and its index
/// accessor (null when it is Draco-compressed and cannot be patched).
class LuminaGlbPrimitiveRef {
  const LuminaGlbPrimitiveRef({
    required this.mesh,
    required this.primitive,
    required this.node,
    required this.firstVertex,
    required this.vertexCount,
    required this.firstTriangle,
    required this.triangleCount,
    required this.material,
    required this.indexAccessor,
  });

  final int mesh, primitive, node;
  final int firstVertex, vertexCount, firstTriangle, triangleCount;
  final int? material, indexAccessor;
}

/// The geometry of a GLB in one set of arrays, in **centimetres** (glTF
/// metres × 100), the space the meshes are drawn in at rest: a skinned
/// primitive's bind-pose positions, a rigid one's positions through its
/// node's world transform. Skins become per-vertex joints (glTF node
/// indices, the four strongest of up to eight influences, normalised) with
/// each joint's rest world transform and inverse bind matrix.
///
/// Pure Dart, for work on a worker isolate (garment fitting, body masks).
class LuminaSkinnedMeshData {
  LuminaSkinnedMeshData._({
    required this.document,
    required this.positions,
    required this.normals,
    required this.uvs,
    required this.triangles,
    required this.joints,
    required this.weights,
    required this.nodeNames,
    required this.nodeParents,
    required this.nodeWorld,
    required this.inverseBind,
    required this.primitives,
    this.colors,
  });

  /// The parsed GLB the arrays were read from.
  final GlbDocument document;

  /// xyz per vertex (cm), normals (unit) and uvs (2 per vertex).
  final Float64List positions;
  final Float32List normals;
  final Float32List uvs;
  final Uint32List triangles;

  /// Four node indices and weights per vertex; null for an unskinned GLB.
  final Uint16List? joints;
  final Float32List? weights;

  /// Every node's name ('' unnamed), parent (-1 root) and rest world
  /// transform (16 column-major values per node, translation in cm).
  final List<String> nodeNames;
  final Int32List nodeParents;
  final Float64List nodeWorld;

  /// Inverse bind matrices of the joints by node index (cm), from the skins.
  final Map<int, Float64List> inverseBind;

  final List<LuminaGlbPrimitiveRef> primitives;

  /// Vertex colours (RGBA per vertex, linear, from `COLOR_0`; white where a
  /// primitive has none), or null when no primitive has them. A garment
  /// coloured per vertex keeps its colours through a fit.
  final Float32List? colors;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => triangles.length ~/ 3;
  bool get isSkinned => joints != null;

  /// A finer copy for fitting: every triangle split in four (edge
  /// midpoints shared) until the mean edge is at most [maxEdge] cm or
  /// another split would pass [maxVertices]; positions, normals and uvs
  /// interpolated, skin weights left out (a fit computes its own). The
  /// primitives keep their order and materials; the GLB is the same.
  LuminaSkinnedMeshData refined({double maxEdge = 2.5, int maxVertices = 40000}) {
    var p = positions.toList(), nrm = normals.toList(), uv = uvs.toList(), tri = triangles.toList();
    final col = colors?.toList();
    var prims = primitives;
    double meanEdge() {
      var sum = 0.0;
      for (var t = 0; t + 2 < tri.length; t += 3) {
        final a = tri[t] * 3, b = tri[t + 1] * 3;
        final dx = p[a] - p[b], dy = p[a + 1] - p[b + 1], dz = p[a + 2] - p[b + 2];
        sum += math.sqrt(dx * dx + dy * dy + dz * dz);
      }
      return tri.isEmpty ? 0 : sum / (tri.length ~/ 3);
    }

    while (tri.isNotEmpty && meanEdge() > maxEdge) {
      final vertices = p.length ~/ 3;
      final edges = (tri.length ~/ 3) * 3 ~/ 2;
      if (vertices + edges > maxVertices) break;
      final mid = <int, int>{};
      int midpoint(int a, int b) => mid.putIfAbsent(a < b ? a * 0x200000 + b : b * 0x200000 + a, () {
        final i = p.length ~/ 3;
        for (var k = 0; k < 3; k++) {
          p.add((p[a * 3 + k] + p[b * 3 + k]) / 2);
          nrm.add((nrm[a * 3 + k] + nrm[b * 3 + k]) / 2);
        }
        for (var k = 0; k < 2; k++) {
          uv.add((uv[a * 2 + k] + uv[b * 2 + k]) / 2);
        }
        if (col != null) {
          for (var k = 0; k < 4; k++) {
            col.add((col[a * 4 + k] + col[b * 4 + k]) / 2);
          }
        }
        return i;
      });
      final next = <int>[];
      for (var t = 0; t + 2 < tri.length; t += 3) {
        final a = tri[t], b = tri[t + 1], c = tri[t + 2];
        final ab = midpoint(a, b), bc = midpoint(b, c), ca = midpoint(c, a);
        next.addAll([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]);
      }
      tri = next;
      prims = [
        for (final r in prims)
          LuminaGlbPrimitiveRef(
            mesh: r.mesh,
            primitive: r.primitive,
            node: r.node,
            firstVertex: r.firstVertex,
            vertexCount: r.vertexCount,
            firstTriangle: r.firstTriangle * 4,
            triangleCount: r.triangleCount * 4,
            material: r.material,
            indexAccessor: null,
          ),
      ];
    }
    final n = Float32List.fromList(nrm);
    _normalize(n);
    return LuminaSkinnedMeshData._(
      document: document,
      positions: Float64List.fromList(p),
      normals: n,
      uvs: Float32List.fromList(uv),
      triangles: Uint32List.fromList(tri),
      joints: null,
      weights: null,
      nodeNames: nodeNames,
      nodeParents: nodeParents,
      nodeWorld: nodeWorld,
      inverseBind: inverseBind,
      primitives: prims,
      colors: col == null ? null : Float32List.fromList(col),
    );
  }

  /// Parts of a character mesh that are not skin, by node, mesh or
  /// material name: grooms (hair, eyebrows, eyelashes, beards), eyes and
  /// their shells, teeth, tongue, saliva, cartilage.
  static final RegExp notSkinNames = RegExp(
    r'groom|hair|brow|lash|beard|mustache|moustache|fuzz|peachfuzz|eye|cornea|iris|pupil|tear|teeth|tooth|tongue|saliva|cartilage',
    caseSensitive: false,
  );

  /// Whether primitive [p] is skin: not a groom, eye, tooth and the like by
  /// its node, mesh or material name ([notSkinNames]), and not drawn with an
  /// alpha-masked or blended material (hair cards) when the body has opaque
  /// skin (a body whose every material is masked, as some mannequins are,
  /// is judged by names only). Garments fit to skin and only skin is masked
  /// under them; a body's separate sub-meshes (nipples, hands) are skin.
  bool isSkin(LuminaGlbPrimitiveRef p) {
    final i = primitives.indexOf(p);
    return i < 0 || _skinPrimitives[i];
  }

  late final List<bool> _skinPrimitives = _classifySkin();

  List<bool> _classifySkin() {
    final json = document.json;
    final meshes = json['meshes'] as List?;
    final materials = json['materials'] as List?;
    final named = <bool>[], opaque = <bool>[];
    for (final p in primitives) {
      final names = <String>[
        if (p.node >= 0 && p.node < nodeNames.length) nodeNames[p.node],
        if (meshes != null && p.mesh < meshes.length) ((meshes[p.mesh] as Map)['name'] as String? ?? ''),
      ];
      final material = p.material != null && materials != null && p.material! < materials.length ? materials[p.material!] as Map : null;
      if (material != null) names.add(material['name'] as String? ?? '');
      named.add(!names.any(notSkinNames.hasMatch));
      opaque.add((material?['alphaMode'] as String? ?? 'OPAQUE') == 'OPAQUE');
    }
    var opaqueSkin = false;
    for (var i = 0; i < named.length; i++) {
      if (named[i] && opaque[i]) opaqueSkin = true;
    }
    return [for (var i = 0; i < named.length; i++) named[i] && (opaque[i] || !opaqueSkin)];
  }

  /// 1 for every vertex of a skin primitive ([isSkin]); all ones for a
  /// mesh without primitives.
  Uint8List skinVertices() {
    final out = Uint8List(vertexCount);
    if (primitives.isEmpty || !_skinPrimitives.contains(true)) return out..fillRange(0, out.length, 1);
    for (var i = 0; i < primitives.length; i++) {
      final p = primitives[i];
      if (_skinPrimitives[i]) out.fillRange(p.firstVertex, p.firstVertex + p.vertexCount, 1);
    }
    return out;
  }

  /// Only the skin primitives ([isSkin]), with their joints, nodes and
  /// document; this mesh itself when every primitive is skin (or none is,
  /// so a body is never emptied).
  LuminaSkinnedMeshData skin() {
    final keep = [for (var i = 0; i < primitives.length; i++) if (_skinPrimitives[i]) primitives[i]];
    if (keep.length == primitives.length || keep.isEmpty) return this;
    final pos = <double>[], nor = <double>[], uv = <double>[], tri = <int>[];
    final js = <int>[], ws = <double>[];
    final prims = <LuminaGlbPrimitiveRef>[];
    for (final p in keep) {
      final first = pos.length ~/ 3, firstTriangle = tri.length ~/ 3;
      for (var v = p.firstVertex; v < p.firstVertex + p.vertexCount; v++) {
        for (var k = 0; k < 3; k++) {
          pos.add(positions[v * 3 + k]);
          nor.add(normals[v * 3 + k]);
        }
        uv
          ..add(uvs[v * 2])
          ..add(uvs[v * 2 + 1]);
        if (joints != null) {
          for (var k = 0; k < 4; k++) {
            js.add(joints![v * 4 + k]);
            ws.add(weights![v * 4 + k]);
          }
        }
      }
      for (var t = p.firstTriangle; t < p.firstTriangle + p.triangleCount; t++) {
        for (var k = 0; k < 3; k++) {
          tri.add(triangles[t * 3 + k] - p.firstVertex + first);
        }
      }
      prims.add(LuminaGlbPrimitiveRef(
        mesh: p.mesh,
        primitive: p.primitive,
        node: p.node,
        firstVertex: first,
        vertexCount: p.vertexCount,
        firstTriangle: firstTriangle,
        triangleCount: p.triangleCount,
        material: p.material,
        indexAccessor: p.indexAccessor,
      ));
    }
    return LuminaSkinnedMeshData._(
      document: document,
      positions: Float64List.fromList(pos),
      normals: Float32List.fromList(nor),
      uvs: Float32List.fromList(uv),
      triangles: Uint32List.fromList(tri),
      joints: joints == null ? null : Uint16List.fromList(js),
      weights: weights == null ? null : Float32List.fromList(ws),
      nodeNames: nodeNames,
      nodeParents: nodeParents,
      nodeWorld: nodeWorld,
      inverseBind: inverseBind,
      primitives: prims,
    );
  }

  /// The index of the node named [name], or -1.
  int nodeNamed(String name) => nodeNames.indexOf(name);

  /// The rest world position (cm) of node [node].
  (double, double, double) nodePosition(int node) =>
      (nodeWorld[node * 16 + 12], nodeWorld[node * 16 + 13], nodeWorld[node * 16 + 14]);

  /// A mesh from arrays (positions in cm; normals computed when null; uvs
  /// two per vertex, zero when null), not
  /// read from a GLB: it has no nodes, skin or primitives to patch.
  factory LuminaSkinnedMeshData.fromArrays(List<double> positions, List<int> triangles, {List<double>? normals, List<double>? uvs}) {
    final n = Float32List(positions.length);
    if (normals != null) {
      for (var i = 0; i < n.length; i++) {
        n[i] = normals[i];
      }
    } else {
      final acc = List<double>.filled(positions.length, 0);
      _accumulateNormals(positions, acc, triangles, 0);
      for (var i = 0; i < n.length; i++) {
        n[i] = acc[i];
      }
    }
    _normalize(n);
    return LuminaSkinnedMeshData._(
      document: GlbDocument(const {}, Uint8List(0)),
      positions: Float64List.fromList(positions),
      normals: n,
      uvs: uvs == null ? Float32List(positions.length ~/ 3 * 2) : Float32List.fromList(uvs),
      triangles: Uint32List.fromList(triangles),
      joints: null,
      weights: null,
      nodeNames: const [],
      nodeParents: Int32List(0),
      nodeWorld: Float64List(0),
      inverseBind: const {},
      primitives: const [],
    );
  }

  /// Reads [glb]; a Draco-compressed primitive needs [draco] (its normals
  /// are then computed).
  factory LuminaSkinnedMeshData.fromGlb(Uint8List glb, {GlbDracoDecoder? draco}) =>
      LuminaSkinnedMeshData.fromDocument(GlbDocument.parse(glb), draco: draco);

  factory LuminaSkinnedMeshData.fromDocument(GlbDocument doc, {GlbDracoDecoder? draco}) {
    final json = doc.json;
    final nodes = (json['nodes'] as List? ?? const []).cast<Map<String, dynamic>>();
    final names = [for (final n in nodes) n['name'] as String? ?? ''];
    final parents = Int32List(nodes.length)..fillRange(0, nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final c in (nodes[i]['children'] as List? ?? const [])) {
        parents[(c as num).toInt()] = i;
      }
    }
    final world = Float64List(nodes.length * 16);
    final done = List<bool>.filled(nodes.length, false);
    void resolve(int i) {
      if (done[i]) return;
      final local = _localMatrix(nodes[i]);
      final p = parents[i];
      if (p >= 0) {
        resolve(p);
        _multiply(world, i * 16, world, p * 16, local, 0);
      } else {
        world.setRange(i * 16, i * 16 + 16, local);
      }
      done[i] = true;
    }

    for (var i = 0; i < nodes.length; i++) {
      resolve(i);
    }
    final reader = _Accessors(doc);
    final inverseBind = <int, Float64List>{};
    final skins = (json['skins'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (final skin in skins) {
      final jointNodes = [for (final j in skin['joints'] as List) (j as num).toInt()];
      final ibmAccessor = skin['inverseBindMatrices'] as num?;
      final ibm = ibmAccessor == null ? null : reader.floats(ibmAccessor.toInt());
      for (var k = 0; k < jointNodes.length; k++) {
        if (inverseBind.containsKey(jointNodes[k])) continue;
        final m = Float64List(16);
        if (ibm != null) {
          for (var e = 0; e < 16; e++) {
            m[e] = ibm[k * 16 + e];
          }
          m[12] *= 100;
          m[13] *= 100;
          m[14] *= 100;
        } else {
          m[0] = m[5] = m[10] = m[15] = 1;
        }
        inverseBind[jointNodes[k]] = m;
      }
    }

    final positions = <double>[], normals = <double>[], uvs = <double>[], colors = <double>[];
    var coloured = false;
    final triangles = <int>[];
    final joints = <int>[], weights = <double>[];
    var skinned = false;
    final prims = <LuminaGlbPrimitiveRef>[];
    final meshes = (json['meshes'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (var n = 0; n < nodes.length; n++) {
      final meshIndex = nodes[n]['mesh'] as num?;
      if (meshIndex == null) continue;
      final skinIndex = nodes[n]['skin'] as num?;
      final skinJoints = skinIndex == null
          ? null
          : [for (final j in skins[skinIndex.toInt()]['joints'] as List) (j as num).toInt()];
      final mesh = meshes[meshIndex.toInt()];
      final primitiveList = (mesh['primitives'] as List).cast<Map<String, dynamic>>();
      for (var pi = 0; pi < primitiveList.length; pi++) {
        final prim = primitiveList[pi];
        if ((prim['mode'] as num? ?? 4) != 4) continue;
        final attributes = (prim['attributes'] as Map).cast<String, dynamic>();
        final dracoExt = (prim['extensions'] as Map?)?['KHR_draco_mesh_compression'] as Map?;
        List<double> pos;
        List<double>? nor, uv, col;
        var colComponents = 4;
        List<int> idx;
        int? indexAccessor;
        if (dracoExt != null) {
          final decoded = draco == null ? null : draco(reader.bufferView((dracoExt['bufferView'] as num).toInt()));
          if (decoded == null) throw UnsupportedError('a Draco-compressed primitive needs a Draco decoder');
          pos = decoded.positions;
          uv = decoded.uvs.isEmpty ? null : decoded.uvs;
          idx = decoded.indices;
        } else {
          pos = reader.floats((attributes['POSITION'] as num).toInt());
          final na = attributes['NORMAL'] as num?;
          nor = na == null ? null : reader.floats(na.toInt());
          final ua = attributes['TEXCOORD_0'] as num?;
          uv = ua == null ? null : reader.floats(ua.toInt());
          final ca = attributes['COLOR_0'] as num?;
          if (ca != null) {
            col = reader.floats(ca.toInt());
            colComponents = (json['accessors'] as List)[ca.toInt()]['type'] == 'VEC3' ? 3 : 4;
            coloured = true;
          }
          final ia = prim['indices'] as num?;
          indexAccessor = ia?.toInt();
          idx = ia == null ? [for (var i = 0; i < pos.length ~/ 3; i++) i] : reader.ints(ia.toInt());
        }
        final first = positions.length ~/ 3;
        final count = pos.length ~/ 3;
        final rigid = skinJoints == null;
        for (var v = 0; v < count; v++) {
          var x = pos[v * 3], y = pos[v * 3 + 1], z = pos[v * 3 + 2];
          if (rigid) {
            final o = n * 16;
            final tx = world[o] * x + world[o + 4] * y + world[o + 8] * z + world[o + 12];
            final ty = world[o + 1] * x + world[o + 5] * y + world[o + 9] * z + world[o + 13];
            final tz = world[o + 2] * x + world[o + 6] * y + world[o + 10] * z + world[o + 14];
            x = tx;
            y = ty;
            z = tz;
          }
          positions
            ..add(x * 100)
            ..add(y * 100)
            ..add(z * 100);
          if (nor != null) {
            var nx = nor[v * 3], ny = nor[v * 3 + 1], nz = nor[v * 3 + 2];
            if (rigid) {
              final o = n * 16;
              final tx = world[o] * nx + world[o + 4] * ny + world[o + 8] * nz;
              final ty = world[o + 1] * nx + world[o + 5] * ny + world[o + 9] * nz;
              final tz = world[o + 2] * nx + world[o + 6] * ny + world[o + 10] * nz;
              nx = tx;
              ny = ty;
              nz = tz;
            }
            normals
              ..add(nx)
              ..add(ny)
              ..add(nz);
          } else {
            normals
              ..add(0)
              ..add(0)
              ..add(0);
          }
          uvs
            ..add(uv == null ? 0 : uv[v * 2])
            ..add(uv == null ? 0 : uv[v * 2 + 1]);
          for (var k = 0; k < 4; k++) {
            colors.add(col == null || k >= colComponents ? 1 : col[v * colComponents + k]);
          }
        }
        if (nor == null) _accumulateNormals(positions, normals, idx, first);
        final firstTriangle = triangles.length ~/ 3;
        for (final i in idx) {
          triangles.add(first + i);
        }
        // Skin: up to two sets of four influences, the four strongest kept.
        final j0 = attributes['JOINTS_0'] as num?, w0 = attributes['WEIGHTS_0'] as num?;
        if (skinJoints != null && j0 != null && w0 != null && dracoExt == null) {
          skinned = true;
          final sets = <(List<int>, List<double>)>[(reader.ints(j0.toInt()), reader.floats(w0.toInt()))];
          final j1 = attributes['JOINTS_1'] as num?, w1 = attributes['WEIGHTS_1'] as num?;
          if (j1 != null && w1 != null) sets.add((reader.ints(j1.toInt()), reader.floats(w1.toInt())));
          for (var v = 0; v < count; v++) {
            final best = <(int, double)>[];
            for (final (js, ws) in sets) {
              for (var k = 0; k < 4; k++) {
                final w = ws[v * 4 + k];
                if (w > 0) best.add((skinJoints[js[v * 4 + k]], w));
              }
            }
            best.sort((a, b) => b.$2.compareTo(a.$2));
            var total = 0.0;
            for (var k = 0; k < math.min(4, best.length); k++) {
              total += best[k].$2;
            }
            for (var k = 0; k < 4; k++) {
              if (k < best.length && total > 0) {
                joints.add(best[k].$1);
                weights.add(best[k].$2 / total);
              } else {
                joints.add(k == 0 && best.isNotEmpty ? best[0].$1 : 0);
                weights.add(0);
              }
            }
          }
        } else {
          for (var v = 0; v < count; v++) {
            joints.addAll(const [0, 0, 0, 0]);
            weights.addAll(const [0, 0, 0, 0]);
          }
        }
        prims.add(LuminaGlbPrimitiveRef(
          mesh: meshIndex.toInt(),
          primitive: pi,
          node: n,
          firstVertex: first,
          vertexCount: count,
          firstTriangle: firstTriangle,
          triangleCount: idx.length ~/ 3,
          material: (prim['material'] as num?)?.toInt(),
          indexAccessor: indexAccessor,
        ));
      }
    }
    final normalArray = Float32List.fromList(normals);
    _normalize(normalArray);
    return LuminaSkinnedMeshData._(
      document: doc,
      positions: Float64List.fromList(positions),
      normals: normalArray,
      uvs: Float32List.fromList(uvs),
      triangles: Uint32List.fromList(triangles),
      joints: skinned ? Uint16List.fromList(joints) : null,
      weights: skinned ? Float32List.fromList(weights) : null,
      colors: coloured ? Float32List.fromList(colors) : null,
      nodeNames: names,
      nodeParents: parents,
      nodeWorld: centimetres(world),
      inverseBind: inverseBind,
      primitives: prims,
    );
  }

  static void _accumulateNormals(List<double> p, List<double> n, List<int> idx, int first) {
    for (var t = 0; t + 2 < idx.length; t += 3) {
      final a = first + idx[t], b = first + idx[t + 1], c = first + idx[t + 2];
      final ux = p[b * 3] - p[a * 3], uy = p[b * 3 + 1] - p[a * 3 + 1], uz = p[b * 3 + 2] - p[a * 3 + 2];
      final vx = p[c * 3] - p[a * 3], vy = p[c * 3 + 1] - p[a * 3 + 1], vz = p[c * 3 + 2] - p[a * 3 + 2];
      final nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      for (final v in [a, b, c]) {
        n[v * 3] += nx;
        n[v * 3 + 1] += ny;
        n[v * 3 + 2] += nz;
      }
    }
  }

  static void _normalize(Float32List n) {
    for (var i = 0; i + 2 < n.length; i += 3) {
      final l = math.sqrt(n[i] * n[i] + n[i + 1] * n[i + 1] + n[i + 2] * n[i + 2]);
      if (l > 1e-12) {
        n[i] /= l;
        n[i + 1] /= l;
        n[i + 2] /= l;
      } else {
        n[i + 1] = 1;
      }
    }
  }

  /// A node's local matrix (column-major), from `matrix` or TRS (metres).
  static Float64List _localMatrix(Map<String, dynamic> node) {
    final m = Float64List(16);
    final matrix = node['matrix'] as List?;
    if (matrix != null && matrix.length == 16) {
      for (var i = 0; i < 16; i++) {
        m[i] = (matrix[i] as num).toDouble();
      }
      return m;
    }
    final t = (node['translation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0];
    final r = (node['rotation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0, 1.0];
    final s = (node['scale'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [1.0, 1.0, 1.0];
    final x = r[0], y = r[1], z = r[2], w = r[3];
    m[0] = (1 - 2 * (y * y + z * z)) * s[0];
    m[1] = 2 * (x * y + w * z) * s[0];
    m[2] = 2 * (x * z - w * y) * s[0];
    m[4] = 2 * (x * y - w * z) * s[1];
    m[5] = (1 - 2 * (x * x + z * z)) * s[1];
    m[6] = 2 * (y * z + w * x) * s[1];
    m[8] = 2 * (x * z + w * y) * s[2];
    m[9] = 2 * (y * z - w * x) * s[2];
    m[10] = (1 - 2 * (x * x + y * y)) * s[2];
    m[12] = t[0];
    m[13] = t[1];
    m[14] = t[2];
    m[15] = 1;
    return m;
  }

  /// out[o..] = a[ao..] · b[bo..] (4×4 column-major).
  static void _multiply(Float64List out, int o, List<double> a, int ao, List<double> b, int bo) {
    final r = Float64List(16);
    for (var c = 0; c < 4; c++) {
      for (var row = 0; row < 4; row++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[ao + k * 4 + row] * b[bo + c * 4 + k];
        }
        r[c * 4 + row] = sum;
      }
    }
    out.setRange(o, o + 16, r);
  }

  /// The world matrices with translations in centimetres (as stored).
  static Float64List centimetres(Float64List world) {
    final out = Float64List.fromList(world);
    for (var i = 0; i + 15 < out.length; i += 16) {
      out[i + 12] *= 100;
      out[i + 13] *= 100;
      out[i + 14] *= 100;
    }
    return out;
  }
}
