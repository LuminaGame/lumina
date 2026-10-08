import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

/// A one-triangle GLB whose mesh has a morph target per entry of [targets]
/// (name → the delta added to every vertex, centimetres), names in the mesh's
/// `extras.targetNames`; written to a file under [dir].
File writeMorphGlb(Directory dir, Map<String, List<double>> targets, {String name = 'morph.glb'}) {
  final names = targets.keys.toList();
  final floats = <double>[0, 0, 0, 10, 0, 0, 0, 10, 0];
  for (final delta in targets.values) {
    for (var v = 0; v < 3; v++) {
      floats.addAll(delta);
    }
  }
  final bin = Float32List.fromList(floats).buffer.asUint8List();
  Map<String, Object?> accessor(int index, List<double> min, List<double> max) => {
    'bufferView': index,
    'componentType': 5126,
    'count': 3,
    'type': 'VEC3',
    'min': min,
    'max': max,
  };
  List<double> lo(List<double> d) => [for (var i = 0; i < 3; i++) d[i] < 0 ? d[i] : 0];
  List<double> hi(List<double> d) => [for (var i = 0; i < 3; i++) d[i] > 0 ? d[i] : 0];
  final json = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': [
      {'mesh': 0, 'name': 'Body'},
    ],
    'meshes': [
      {
        'name': 'Body',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'targets': [
              for (var t = 0; t < names.length; t++) {'POSITION': t + 1},
            ],
          },
        ],
        'weights': [for (final _ in names) 0.0],
        'extras': {'targetNames': names},
      },
    ],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': [
      for (var i = 0; i <= names.length; i++) {'buffer': 0, 'byteOffset': i * 36, 'byteLength': 36},
    ],
    'accessors': [
      accessor(0, [0, 0, 0], [10, 10, 0]),
      for (var t = 0; t < names.length; t++) accessor(t + 1, lo(targets[names[t]]!), hi(targets[names[t]]!)),
    ],
  };
  var jsonBytes = utf8.encode(jsonEncode(json));
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled((4 - jsonBytes.length % 4) % 4, 0x20)]);
  final out = BytesBuilder();
  void u32(int v) => out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  u32(0x46546C67);
  u32(2);
  u32(12 + 8 + jsonBytes.length + 8 + bin.length);
  u32(jsonBytes.length);
  u32(0x4E4F534A);
  out.add(jsonBytes);
  u32(bin.length);
  u32(0x004E4942);
  out.add(bin);
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(out.toBytes());
  return file;
}

/// A soft blob for secondary motion: a sphere of [radius] metres resting on
/// its bottom, coloured [color], with targets `Up`, `Down`, `Left`, `Right`,
/// `Forward`, `Back` that move its top half by half the radius (the bottom
/// stays), written under [dir].
File writeJellyGlb(Directory dir, {double radius = 0.3, List<double> color = const [0.85, 0.25, 0.3, 1], String name = 'jelly.glb'}) {
  const rings = 24, segments = 32;
  final positions = <double>[], normals = <double>[];
  for (var r = 0; r <= rings; r++) {
    final phi = r / rings * 3.141592653589793;
    for (var s = 0; s <= segments; s++) {
      final theta = s / segments * 2 * 3.141592653589793;
      final nx = _sin(phi) * _cos(theta), ny = _cos(phi), nz = _sin(phi) * _sin(theta);
      normals.addAll([nx, ny, nz]);
      positions.addAll([nx * radius, ny * radius + radius, nz * radius]);
    }
  }
  final indices = <int>[];
  for (var r = 0; r < rings; r++) {
    for (var s = 0; s < segments; s++) {
      final a = r * (segments + 1) + s, b = a + segments + 1;
      indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
    }
  }
  final count = positions.length ~/ 3;
  const directions = {
    'Up': [0.0, 1.0, 0.0],
    'Down': [0.0, -1.0, 0.0],
    'Right': [1.0, 0.0, 0.0],
    'Left': [-1.0, 0.0, 0.0],
    'Forward': [0.0, 0.0, 1.0],
    'Back': [0.0, 0.0, -1.0],
  };
  final targets = <String, List<double>>{};
  for (final e in directions.entries) {
    final deltas = <double>[];
    for (var v = 0; v < count; v++) {
      final h = (positions[v * 3 + 1] / (2 * radius)).clamp(0.0, 1.0);
      final w = h * h * radius * 0.5;
      deltas.addAll([e.value[0] * w, e.value[1] * w, e.value[2] * w]);
    }
    targets[e.key] = deltas;
  }
  final chunks = <Uint8List>[
    Float32List.fromList(positions).buffer.asUint8List(),
    Float32List.fromList(normals).buffer.asUint8List(),
    Uint16List.fromList(indices).buffer.asUint8List(),
    for (final d in targets.values) Float32List.fromList(d).buffer.asUint8List(),
  ];
  final views = <Map<String, Object?>>[];
  final bin = BytesBuilder();
  for (final c in chunks) {
    views.add({'buffer': 0, 'byteOffset': bin.length, 'byteLength': c.length});
    bin.add(c);
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
  }
  List<double> bound(List<double> values, bool max) => [
    for (var axis = 0; axis < 3; axis++)
      [for (var v = axis; v < values.length; v += 3) values[v]].reduce((a, b) => max ? (a > b ? a : b) : (a < b ? a : b)),
  ];
  Map<String, Object?> vec3(int view, List<double> values) => {
    'bufferView': view,
    'componentType': 5126,
    'count': count,
    'type': 'VEC3',
    'min': bound(values, false),
    'max': bound(values, true),
  };
  final names = targets.keys.toList();
  final json = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': [
      {'mesh': 0, 'name': 'Jelly'},
    ],
    'materials': [
      {
        'pbrMetallicRoughness': {'baseColorFactor': color, 'metallicFactor': 0.0, 'roughnessFactor': 0.35},
      },
    ],
    'meshes': [
      {
        'name': 'Jelly',
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'NORMAL': 1},
            'indices': 2,
            'material': 0,
            'targets': [
              for (var t = 0; t < names.length; t++) {'POSITION': 3 + t},
            ],
          },
        ],
        'weights': [for (final _ in names) 0.0],
        'extras': {'targetNames': names},
      },
    ],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': views,
    'accessors': [
      vec3(0, positions),
      {'bufferView': 1, 'componentType': 5126, 'count': count, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5123, 'count': indices.length, 'type': 'SCALAR'},
      for (var t = 0; t < names.length; t++) vec3(3 + t, targets[names[t]]!),
    ],
  };
  return _writeGlb(dir, name, json, bin.toBytes());
}

double _sin(double x) => math.sin(x);
double _cos(double x) => math.cos(x);

File _writeGlb(Directory dir, String name, Map<String, Object?> json, Uint8List bin) {
  var jsonBytes = utf8.encode(jsonEncode(json));
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled((4 - jsonBytes.length % 4) % 4, 0x20)]);
  final out = BytesBuilder();
  void u32(int v) => out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  u32(0x46546C67);
  u32(2);
  u32(12 + 8 + jsonBytes.length + 8 + bin.length);
  u32(jsonBytes.length);
  u32(0x4E4F534A);
  out.add(jsonBytes);
  u32(bin.length);
  u32(0x004E4942);
  out.add(bin);
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(out.toBytes());
  return file;
}
