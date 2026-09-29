import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Packs a text `.gltf` and the files it references (its `.bin` buffers and
/// image files) into one self-contained GLB.
///
/// The import pipeline stores a mesh's payload as GLB, so a `.gltf` is
/// staged through [packFile] — without it the payload kept a relative
/// `uri` that no longer resolves once the file is in the project.
class GltfPacker {
  const GltfPacker._();

  /// The relative file URIs (decoded, `/`-separated) [gltf] references:
  /// external buffers first, then images. `data:` URIs are left out.
  static List<String> externalUris(Map<String, dynamic> gltf) {
    final uris = <String>[];
    for (final key in const ['buffers', 'images']) {
      for (final entry in (gltf[key] as List? ?? const [])) {
        if (entry is! Map) continue;
        final uri = entry['uri'];
        if (uri is String && uri.isNotEmpty && !uri.startsWith('data:')) {
          uris.add(_decode(uri));
        }
      }
    }
    return uris;
  }

  /// The files [gltfPath] references, resolved beside it (they need not
  /// exist).
  static List<String> referencedFiles(String gltfPath) {
    final json = jsonDecode(File(gltfPath).readAsStringSync());
    if (json is! Map<String, dynamic>) throw FormatException('${_name(gltfPath)} is not a glTF document');
    final dir = File(gltfPath).parent.path;
    return [for (final uri in externalUris(json)) '$dir/$uri'];
  }

  /// [gltfPath] as GLB bytes: every buffer (external or `data:`) merged into
  /// the BIN chunk, every external or `data:` image moved into a buffer
  /// view. Throws a [FormatException] naming a referenced file that is
  /// missing.
  static Uint8List packFile(String gltfPath) {
    final name = _name(gltfPath);
    final decoded = jsonDecode(File(gltfPath).readAsStringSync());
    if (decoded is! Map<String, dynamic>) throw FormatException('$name is not a glTF document');
    final gltf = decoded;
    final dir = File(gltfPath).parent.path;

    Uint8List readUri(String uri, String what) {
      if (uri.startsWith('data:')) {
        final comma = uri.indexOf(',');
        if (comma < 0) throw FormatException('$name has a malformed data URI for $what');
        return base64Decode(uri.substring(comma + 1));
      }
      final file = File('$dir/${_decode(uri)}');
      if (!file.existsSync()) throw FormatException('$name references $what "${_decode(uri)}", which is missing');
      return file.readAsBytesSync();
    }

    final bin = BytesBuilder(copy: false);
    void align() {
      while (bin.length % 4 != 0) {
        bin.addByte(0);
      }
    }

    // Buffers → one BIN; remember where each one starts.
    final buffers = (gltf['buffers'] as List? ?? const []).cast<Map<String, dynamic>>();
    final starts = <int>[];
    for (var i = 0; i < buffers.length; i++) {
      align();
      starts.add(bin.length);
      final uri = buffers[i]['uri'] as String?;
      if (uri == null) throw FormatException('$name buffer $i has no uri (it is already a GLB buffer)');
      final bytes = readUri(uri, 'buffer');
      final declared = buffers[i]['byteLength'] as int? ?? bytes.length;
      if (bytes.length < declared) {
        throw FormatException('$name buffer "${_decode(uri)}" has ${bytes.length} bytes but declares $declared');
      }
      bin.add(bytes);
    }
    final views = (gltf['bufferViews'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (final view in views) {
      final buffer = view['buffer'] as int? ?? 0;
      if (buffer >= starts.length) throw FormatException('$name has a buffer view on missing buffer $buffer');
      view['buffer'] = 0;
      view['byteOffset'] = (view['byteOffset'] as int? ?? 0) + starts[buffer];
    }

    // Images with a uri → a buffer view each.
    for (final image in (gltf['images'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uri = image.remove('uri') as String?;
      if (uri == null) continue;
      final bytes = readUri(uri, 'image');
      align();
      final offset = bin.length;
      bin.add(bytes);
      views.add({'buffer': 0, 'byteOffset': offset, 'byteLength': bytes.length});
      image['bufferView'] = views.length - 1;
      image['mimeType'] ??= _mimeFor(uri, bytes);
    }
    gltf['bufferViews'] = views;
    align();
    final binBytes = bin.takeBytes();
    gltf['buffers'] = [
      if (binBytes.isNotEmpty) {'byteLength': binBytes.length},
    ];
    if (binBytes.isEmpty) gltf.remove('buffers');

    final jsonBytes = utf8.encode(jsonEncode(gltf));
    final jsonPadded = (jsonBytes.length + 3) & ~3;
    final total = 12 + 8 + jsonPadded + (binBytes.isEmpty ? 0 : 8 + binBytes.length);
    final out = ByteData(total);
    out
      ..setUint32(0, 0x46546C67, Endian.little) // glTF
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, total, Endian.little)
      ..setUint32(12, jsonPadded, Endian.little)
      ..setUint32(16, 0x4E4F534A, Endian.little); // JSON
    final bytes = out.buffer.asUint8List();
    bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
    bytes.fillRange(20 + jsonBytes.length, 20 + jsonPadded, 0x20);
    if (binBytes.isNotEmpty) {
      final at = 20 + jsonPadded;
      out
        ..setUint32(at, binBytes.length, Endian.little)
        ..setUint32(at + 4, 0x004E4942, Endian.little); // BIN
      bytes.setRange(at + 8, at + 8 + binBytes.length, binBytes);
    }
    return bytes;
  }

  static String _decode(String uri) {
    try {
      return Uri.decodeComponent(uri).replaceAll(r'\', '/');
    } catch (_) {
      return uri.replaceAll(r'\', '/');
    }
  }

  static String _name(String path) => path.replaceAll(r'\', '/').split('/').last;

  static String _mimeFor(String uri, Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (uri.startsWith('data:image/jpeg') || uri.toLowerCase().endsWith('.jpg') || uri.toLowerCase().endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'image/png';
  }
}
