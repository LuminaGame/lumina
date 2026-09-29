import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';

/// Builds a GLB carrying a genuinely oversized texture from a real asset.
///
/// No asset under `test-assets/` has an over-budget texture (the props ship
/// 512 px WebP images) and committing a ~200 MB fixture is not an option, so
/// the tests make one in their own temp dir: [sourceGlb]'s first image is
/// decoded, upscaled (nearest neighbour, so it stays cheap) until its long edge
/// is [longEdge] px, and embedded as a PNG. Textures that pointed at the image
/// through `EXT_texture_webp` get a plain `source` instead, and the extension
/// is dropped from `extensionsUsed` / `extensionsRequired`.
///
/// [tint] multiplies the image's RGB channels before the upscale, which gives a
/// "the artist re-exported the texture" variant with different bytes.
/// With [externalImageName] the image is not embedded at all: it is written
/// next to [writeImageNextTo] and referenced by `uri`.
///
/// [encode] and [mimeType] pick the image's container (PNG by default; the
/// image-format tests also embed the same pixels as JPEG and TGA).
Uint8List oversizedGlbFromTestAsset(
  Uint8List sourceGlb, {
  int longEdge = 8192,
  List<double> tint = const [1.0, 1.0, 1.0],
  String? externalImageName,
  Directory? writeImageNextTo,
  Uint8List Function(img.Image image)? encode,
  String mimeType = 'image/png',
}) {
  final parsed = _Glb.parse(sourceGlb);
  final json = parsed.json;
  final images = (json['images'] as List).cast<Map<String, dynamic>>();
  final bufferViews = (json['bufferViews'] as List).cast<Map<String, dynamic>>();
  final view = bufferViews[images.first['bufferView'] as int];
  final offset = (view['byteOffset'] as int?) ?? 0;
  final encoded = parsed.bin.sublist(offset, offset + (view['byteLength'] as int));

  var image = img.decodeImage(encoded)!;
  if (tint.any((c) => c != 1.0)) {
    for (final p in image) {
      p
        ..r = (p.r * tint[0]).clamp(0, 255)
        ..g = (p.g * tint[1]).clamp(0, 255)
        ..b = (p.b * tint[2]).clamp(0, 255);
    }
  }
  final scale = longEdge / (image.width > image.height ? image.width : image.height);
  image = img.copyResize(
    image,
    width: (image.width * scale).round(),
    height: (image.height * scale).round(),
    interpolation: img.Interpolation.nearest,
  );
  final png = encode != null ? encode(image) : Uint8List.fromList(img.encodePng(image, level: 1));

  if (externalImageName != null) {
    File('${writeImageNextTo!.path}/$externalImageName').writeAsBytesSync(png);
    images.first
      ..remove('bufferView')
      ..['uri'] = externalImageName
      ..['mimeType'] = mimeType;
  } else {
    bufferViews.add({'buffer': 0, 'byteOffset': parsed.bin.length, 'byteLength': png.length});
    images.first
      ..['bufferView'] = bufferViews.length - 1
      ..['mimeType'] = mimeType;
  }

  for (final texture in (json['textures'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final extensions = texture['extensions'] as Map<String, dynamic>?;
    final webp = extensions?.remove('EXT_texture_webp') as Map<String, dynamic>?;
    if (webp != null) texture['source'] = webp['source'];
    if (extensions != null && extensions.isEmpty) texture.remove('extensions');
  }
  for (final key in ['extensionsUsed', 'extensionsRequired']) {
    final list = json[key] as List?;
    list?.remove('EXT_texture_webp');
    if (list != null && list.isEmpty) json.remove(key);
  }

  final bin = BytesBuilder()..add(parsed.bin);
  if (externalImageName == null) bin.add(png);
  final binBytes = bin.toBytes();
  (json['buffers'] as List).first['byteLength'] = binBytes.length;
  return _Glb.build(json, binBytes);
}

/// `(width, height)` of every image embedded in [glb], read from PNG headers.
List<(int, int)> embeddedPngSizes(Uint8List glb) {
  final parsed = _Glb.parse(glb);
  final bufferViews = (parsed.json['bufferViews'] as List).cast<Map<String, dynamic>>();
  return [
    for (final image in (parsed.json['images'] as List? ?? const []).cast<Map<String, dynamic>>())
      if (image['bufferView'] != null)
        () {
          final view = bufferViews[image['bufferView'] as int];
          final at = (view['byteOffset'] as int?) ?? 0;
          final header = ByteData.sublistView(parsed.bin, at + 16, at + 24);
          return (header.getUint32(0), header.getUint32(4));
        }(),
  ];
}

/// Writes a minimal real project under [root]: a `.lmproject` manifest and the
/// `contents/` folders the importer would have created.
Directory writeTempProject(Directory root, String name) {
  final project = Directory('${root.path}/$name')..createSync(recursive: true);
  for (final sub in ['meshes/static', 'meshes/skeletal', 'textures', 'levels']) {
    Directory('${project.path}/contents/$sub').createSync(recursive: true);
  }
  File('${project.path}/$name.lmproject').writeAsStringSync(
    jsonEncode(LuminaProject(projectName: name, activeLevel: 'contents/levels/L_Main.lmas').toMap()),
  );
  return project;
}

/// Writes a static mesh asset the way an import before the texture budget left it: a
/// payload-less `.lmas` next to an `.entity.glb` companion holding [glb].
/// Returns the `.lmas` path.
String writeMeshAsset(Directory project, String name, Uint8List glb) {
  final dir = '${project.path}/contents/meshes/static';
  File('$dir/$name.entity.glb').writeAsBytesSync(glb);
  File('$dir/$name.lmas').writeAsBytesSync(LuminaAsset(
    assetId: 'mesh_$name',
    name: name,
    type: AssetType.filamesh,
    metadata: const {'payload_format': 'glb'},
  ).toProtoBufferBytes());
  return '$dir/$name.lmas';
}

class _Glb {
  final Map<String, dynamic> json;
  final Uint8List bin;
  _Glb(this.json, this.bin);

  static _Glb parse(Uint8List glb) {
    final data = ByteData.sublistView(glb);
    final jsonLength = data.getUint32(12, Endian.little);
    final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
    final binStart = 20 + jsonLength;
    final bin = binStart + 8 <= glb.length
        ? glb.sublist(binStart + 8, binStart + 8 + data.getUint32(binStart, Endian.little))
        : Uint8List(0);
    return _Glb(json, bin);
  }

  static Uint8List build(Map<String, dynamic> json, Uint8List bin) {
    var jsonBytes = utf8.encode(jsonEncode(json));
    final jsonPad = (4 - jsonBytes.length % 4) % 4;
    jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled(jsonPad, 0x20)]);
    final binPad = (4 - bin.length % 4) % 4;
    final paddedBin = Uint8List(bin.length + binPad)..setAll(0, bin);
    final total = 12 + 8 + jsonBytes.length + 8 + paddedBin.length;
    final out = BytesBuilder()
      ..add((ByteData(12)
            ..setUint32(0, 0x46546C67, Endian.little)
            ..setUint32(4, 2, Endian.little)
            ..setUint32(8, total, Endian.little))
          .buffer
          .asUint8List())
      ..add((ByteData(8)
            ..setUint32(0, jsonBytes.length, Endian.little)
            ..setUint32(4, 0x4E4F534A, Endian.little))
          .buffer
          .asUint8List())
      ..add(jsonBytes)
      ..add((ByteData(8)
            ..setUint32(0, paddedBin.length, Endian.little)
            ..setUint32(4, 0x004E4942, Endian.little))
          .buffer
          .asUint8List())
      ..add(paddedBin);
    return out.toBytes();
  }
}
