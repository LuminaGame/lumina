import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A real test-assets model whose embedded texture (512 × 512 WebP) serves
/// as an app icon in the packaging tests.
final String kIconTestGlb = '${Directory.current.parent.path}/test-assets/Props/Big_button/big_button.glb';

/// The first image embedded in the GLB at [path], decoded and re-encoded as
/// a PNG.
Uint8List glbTexturePng(String path, {int image = 0}) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final jsonLength = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  final view = (json['bufferViews'] as List)[((json['images'] as List)[image] as Map)['bufferView'] as int] as Map;
  final binStart = 20 + jsonLength + 8;
  final offset = binStart + ((view['byteOffset'] as num?)?.toInt() ?? 0);
  final encoded = bytes.sublist(offset, offset + (view['byteLength'] as num).toInt());
  return img.encodePng(img.decodeImage(encoded)!);
}

/// Runs a real `flutter create --no-pub` for [name] under [root].
Future<String> flutterCreate(Directory root, String name) async {
  final dir = '${root.path}/$name';
  final result = await Process.run('flutter', ['create', '--no-pub', '--project-name', name, dir], runInShell: true);
  if (result.exitCode != 0) throw StateError('flutter create failed: ${result.stderr}');
  return dir;
}
