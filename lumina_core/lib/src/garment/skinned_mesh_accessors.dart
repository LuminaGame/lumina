part of 'package:lumina_core/src/garment/skinned_mesh_data.dart';

/// Reads glTF accessors out of a [GlbDocument]'s binary chunk.
class _Accessors {
  _Accessors(this.doc)
      : accessors = (doc.json['accessors'] as List? ?? const []).cast<Map<String, dynamic>>(),
        views = (doc.json['bufferViews'] as List? ?? const []).cast<Map<String, dynamic>>();

  final GlbDocument doc;
  final List<Map<String, dynamic>> accessors, views;

  static const _components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16};

  Uint8List bufferView(int index) {
    final v = views[index];
    final offset = (v['byteOffset'] as num? ?? 0).toInt();
    return Uint8List.sublistView(doc.bin, offset, offset + (v['byteLength'] as num).toInt());
  }

  List<double> floats(int index) {
    final a = accessors[index];
    final n = (a['count'] as num).toInt() * _components[a['type']]!;
    final out = Float64List(n);
    _read(a, (i, value) => out[i] = value);
    return out;
  }

  List<int> ints(int index) {
    final a = accessors[index];
    final n = (a['count'] as num).toInt() * _components[a['type']]!;
    final out = Uint32List(n);
    _read(a, (i, value) => out[i] = value.toInt(), integer: true);
    return out;
  }

  void _read(Map<String, dynamic> a, void Function(int i, double v) put, {bool integer = false}) {
    final count = (a['count'] as num).toInt();
    final comps = _components[a['type']]!;
    final type = (a['componentType'] as num).toInt();
    final normalized = a['normalized'] == true;
    final size = switch (type) { 5126 || 5125 => 4, 5123 || 5122 => 2, _ => 1 };
    final viewIndex = a['bufferView'] as num?;
    if (viewIndex == null) return; // all zeros
    final view = views[viewIndex.toInt()];
    final stride = (view['byteStride'] as num?)?.toInt() ?? comps * size;
    final base = (view['byteOffset'] as num? ?? 0).toInt() + (a['byteOffset'] as num? ?? 0).toInt();
    final data = ByteData.sublistView(doc.bin);
    for (var e = 0; e < count; e++) {
      for (var c = 0; c < comps; c++) {
        final o = base + e * stride + c * size;
        double v;
        switch (type) {
          case 5126:
            v = data.getFloat32(o, Endian.little);
          case 5125:
            v = data.getUint32(o, Endian.little).toDouble();
          case 5123:
            final raw = data.getUint16(o, Endian.little);
            v = normalized && !integer ? raw / 65535 : raw.toDouble();
          case 5122:
            final raw = data.getInt16(o, Endian.little);
            v = normalized && !integer ? math.max(raw / 32767, -1.0) : raw.toDouble();
          case 5121:
            final raw = data.getUint8(o);
            v = normalized && !integer ? raw / 255 : raw.toDouble();
          default:
            final raw = data.getInt8(o);
            v = normalized && !integer ? math.max(raw / 127, -1.0) : raw.toDouble();
        }
        put(e * comps + c, v);
      }
    }
  }
}
