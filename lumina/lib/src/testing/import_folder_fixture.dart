import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumina_smoke/lumina_smoke.dart';

/// A real nested source folder for the folder importer,
/// built from `test-assets/Props` in a temp directory (test-assets is never
/// written to):
///
/// ```
/// <dest>/Source/
///   Props/Barrels/*.glb            (copied)
///   Props/AC_units/*.glb           (copied)
///   Props/Access_cards/*.glb       (copied)
///   Props/Banana Bunch/*.glb       (copied, a folder name with a space)
///   Props/Gltf/lootbarrel_split.gltf + .bin + textures/<image>  (unpacked from lootbarrel_junk.glb)
///   Props/Textures/loot_barrel_bc.tga   (that barrel's texture as TGA)
///   Props/Source/barrel_texture.psd     (unsupported)
///   Props/orphan_buffer.bin             (a buffer no .gltf references)
///   .hidden/radbarrel.glb               (a hidden folder)
///   .DS_Store                           (OS junk)
/// ```
class ImportFolderFixture {
  ImportFolderFixture._(this.root);

  /// `<dest>/Source`, the folder to pick.
  final String root;

  static const Map<String, List<String>> copied = {
    'Props/Barrels': ['bent_barrel.glb', 'dented_barrel.glb', 'empty_barrel.glb'],
    'Props/AC_units': ['aircon_small.glb', 'ac_unit_a_300x300.glb'],
    'Props/Access_cards': ['access_card_blue.glb', 'access_card_red.glb'],
    'Props/Banana Bunch': ['banana_bunch_short.glb'],
  };

  /// The GLB unpacked into the `.gltf` + `.bin` pair.
  static const String splitSource = 'Props/Barrels/lootbarrel_junk.glb';

  /// The GLB copied into the hidden folder (which the importer ignores).
  static const String hiddenSource = 'Props/Barrels/radbarrel.glb';

  /// test-assets paths the fixture copies from (for smoke badges).
  static List<String> get usedAssets => [
        for (final e in copied.entries)
          for (final f in e.value) '${e.key}/$f',
        splitSource,
        hiddenSource,
      ];

  /// Primary files the importer should find, relative to [root].
  static List<String> get expectedPrimaries => [
        for (final e in copied.entries)
          for (final f in e.value) '${e.key}/$f',
        'Props/Gltf/lootbarrel_split.gltf',
        'Props/Textures/loot_barrel_bc.tga',
      ]..sort();

  /// Whether test-assets has every file the fixture needs.
  static bool get available => usedAssets.every((a) => File('${SmokeArtifacts.testAssetsDir.path}/$a').existsSync());

  static ImportFolderFixture build(Directory dest) {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final root = '${dest.path}/Source';
    for (final e in copied.entries) {
      Directory('$root/${e.key}').createSync(recursive: true);
      for (final f in e.value) {
        File('$assets/${e.key}/$f').copySync('$root/${e.key}/$f');
      }
    }
    final image = unpackGlb(File('$assets/$splitSource').readAsBytesSync(), '$root/Props/Gltf', 'lootbarrel_split');
    if (image != null) {
      final decoded = img.decodeImage(image.bytes);
      if (decoded != null) {
        Directory('$root/Props/Textures').createSync(recursive: true);
        File('$root/Props/Textures/loot_barrel_bc.tga').writeAsBytesSync(img.encodeTga(decoded));
      }
    }
    Directory('$root/Props/Source').createSync(recursive: true);
    // An (unsupported) Photoshop document: the PSD signature and header.
    File('$root/Props/Source/barrel_texture.psd').writeAsBytesSync([
      ...ascii.encode('8BPS'), 0, 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 16, 0, 0, 0, 16, 0, 8, 0, 3, //
    ]);
    File('$root/Props/orphan_buffer.bin').writeAsBytesSync(Uint8List(64));
    Directory('$root/.hidden').createSync(recursive: true);
    File('$assets/$hiddenSource').copySync('$root/.hidden/radbarrel.glb');
    File('$root/.DS_Store').writeAsBytesSync(Uint8List(16));
    return ImportFolderFixture._(root);
  }

  /// Writes [glb] as `<dir>/<name>.gltf` + `<name>.bin`, its first embedded
  /// image moved to `textures/<image name>` (referenced by uri). Returns
  /// that image (its file name and bytes), or null when it has none.
  static ({String name, Uint8List bytes})? unpackGlb(Uint8List glb, String dir, String name) {
    final data = ByteData.sublistView(glb);
    final jsonLength = data.getUint32(12, Endian.little);
    final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
    final binStart = 20 + jsonLength;
    final binLength = data.getUint32(binStart, Endian.little);
    final bin = glb.sublist(binStart + 8, binStart + 8 + binLength);
    Directory('$dir/textures').createSync(recursive: true);
    File('$dir/$name.bin').writeAsBytesSync(bin);
    (json['buffers'] as List).first['uri'] = '$name.bin';

    ({String name, Uint8List bytes})? first;
    final views = json['bufferViews'] as List;
    for (final image in (json['images'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final view = image['bufferView'] as int?;
      if (view == null) continue;
      final v = views[view] as Map<String, dynamic>;
      final offset = v['byteOffset'] as int? ?? 0;
      final bytes = bin.sublist(offset, offset + (v['byteLength'] as int));
      final mime = image['mimeType'] as String? ?? 'image/png';
      final ext = mime.split('/').last == 'jpeg' ? 'jpg' : mime.split('/').last;
      final raw = (image['name'] as String? ?? 'image_$view').replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
      final file = '$raw.$ext';
      File('$dir/textures/$file').writeAsBytesSync(bytes);
      image.remove('bufferView');
      image['uri'] = 'textures/${Uri.encodeComponent(file)}';
      first ??= (name: file, bytes: bytes);
    }
    File('$dir/$name.gltf').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    return first;
  }
}
