import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// A `.gltf` whose image files are not beside it: an import refuses it
/// (naming the file), a preview packs it with a stand-in image so the
/// geometry still draws.
void main() {
  late Directory temp;
  late String gltfPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('gltf_packer_');
    File('${temp.path}/mesh.bin').writeAsBytesSync(Uint8List(12));
    gltfPath = '${temp.path}/mesh.gltf';
    File(gltfPath).writeAsStringSync(jsonEncode({
      'asset': {'version': '2.0'},
      'buffers': [
        {'uri': 'mesh.bin', 'byteLength': 12},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 12},
      ],
      'images': [
        {'uri': 'missing_basecolor.png'},
      ],
    }));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Map<String, dynamic> jsonChunk(Uint8List glb) {
    final data = ByteData.sublistView(glb);
    final length = data.getUint32(12, Endian.little);
    return jsonDecode(utf8.decode(glb.sublist(20, 20 + length))) as Map<String, dynamic>;
  }

  test('a missing image file is an error by default, naming it', () {
    expect(() => GltfPacker.packFile(gltfPath),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('missing_basecolor.png'))));
  });

  test('with a stand-in, the missing image gets its bytes and the GLB is complete', () {
    final standIn = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
    final glb = GltfPacker.packFile(gltfPath, missingImage: standIn);
    expect(String.fromCharCodes(glb.sublist(0, 4)), 'glTF');
    expect(ByteData.sublistView(glb).getUint32(8, Endian.little), glb.length);
    final json = jsonChunk(glb);
    final image = (json['images'] as List).single as Map;
    expect(image.containsKey('uri'), isFalse);
    final view = (json['bufferViews'] as List)[image['bufferView'] as int] as Map;
    expect(view['byteLength'], standIn.length);
  });
}
