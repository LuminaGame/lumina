import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_core/lumina_core.dart';

/// A solid [width]×[height] KTX2 (Basis Universal) texture with its whole
/// mip chain, encoded by flutter_filament's Basis encoder: [rgb] are linear
/// values (a colour texture is stored as sRGB, a [linear] one as is).
Uint8List solidKtx2(List<double> rgb, {int width = 16, int height = 16, bool linear = false, bool uastc = true}) {
  final sizes = <(int, int)>[(width, height)];
  while (sizes.last.$1 > 1 || sizes.last.$2 > 1) {
    final (w, h) = sizes.last;
    sizes.add((w > 1 ? w ~/ 2 : 1, h > 1 ? h ~/ 2 : 1));
  }
  final builder = BasisEncoderBuilder(mipCount: sizes.length, linear: linear)..useUastc(uastc);
  final images = <LinearImage>[];
  try {
    for (var level = 0; level < sizes.length; level++) {
      final (w, h) = sizes[level];
      final image = LinearImage(w, h, 3);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          for (var c = 0; c < 3; c++) {
            image.setPixel(x, y, c, rgb[c]);
          }
        }
      }
      images.add(image);
      builder.mipLevel(level, image);
    }
    return builder.buildAndEncode();
  } finally {
    for (final image in images) {
      image.destroy();
    }
  }
}

/// A one-quad GLB whose textures are KTX2 images referenced only through
/// `KHR_texture_basisu` (no `source`), the way a mobile export writes them:
/// image 0 is the normal map ([normalKtx2]), image 1 the base colour
/// ([baseColorKtx2]), and the textures name them crosswise (texture 0, the
/// base colour, is image 1), so a lookup that falls back to the texture
/// index finds the wrong image.
Uint8List ktx2TexturedQuadGlb({required Uint8List baseColorKtx2, required Uint8List normalKtx2}) {
  final bin = BytesBuilder();
  final views = <Map<String, dynamic>>[];
  int addView(Uint8List bytes, {int? target}) {
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    views.add({'buffer': 0, 'byteOffset': bin.length, 'byteLength': bytes.length, 'target': ?target});
    bin.add(bytes);
    return views.length - 1;
  }

  final positions = Float32List.fromList([-0.5, 0, -0.5, 0.5, 0, -0.5, 0.5, 0, 0.5, -0.5, 0, 0.5]);
  final normals = Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]);
  final uvs = Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]);
  final indices = Uint16List.fromList([0, 2, 1, 0, 3, 2]);
  final positionView = addView(positions.buffer.asUint8List(), target: 34962);
  final normalView = addView(normals.buffer.asUint8List(), target: 34962);
  final uvView = addView(uvs.buffer.asUint8List(), target: 34962);
  final indexView = addView(indices.buffer.asUint8List(), target: 34963);
  final normalImageView = addView(normalKtx2);
  final baseImageView = addView(baseColorKtx2);
  while (bin.length % 4 != 0) {
    bin.addByte(0);
  }

  final json = <String, dynamic>{
    'asset': {'version': '2.0', 'generator': 'lumina ktx2 fixture'},
    'extensionsUsed': ['KHR_texture_basisu'],
    'extensionsRequired': ['KHR_texture_basisu'],
    'scene': 0,
    'scenes': [
      {'nodes': [0]},
    ],
    'nodes': [
      {'name': 'Quad', 'mesh': 0},
    ],
    'meshes': [
      {
        'name': 'Quad',
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2},
            'indices': 3,
            'material': 0,
          },
        ],
      },
    ],
    'materials': [
      {
        'name': 'M_Ktx2',
        'pbrMetallicRoughness': {
          'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
          'baseColorTexture': {'index': 0},
          'metallicFactor': 0.0,
          'roughnessFactor': 0.8,
        },
        'normalTexture': {'index': 1},
      },
    ],
    'textures': [
      {
        'sampler': 0,
        'extensions': {
          'KHR_texture_basisu': {'source': 1},
        },
      },
      {
        'sampler': 0,
        'extensions': {
          'KHR_texture_basisu': {'source': 0},
        },
      },
    ],
    'samplers': [
      {'magFilter': 9729, 'minFilter': 9987},
    ],
    'images': [
      {'name': 'T_Ktx2_Normal', 'bufferView': normalImageView, 'mimeType': 'image/ktx2'},
      {'name': 'T_Ktx2_BaseColor', 'bufferView': baseImageView, 'mimeType': 'image/ktx2'},
    ],
    'accessors': [
      {'bufferView': positionView, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-0.5, 0, -0.5], 'max': [0.5, 0, 0.5]},
      {'bufferView': normalView, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
      {'bufferView': uvView, 'componentType': 5126, 'count': 4, 'type': 'VEC2'},
      {'bufferView': indexView, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
    ],
    'bufferViews': views,
    'buffers': [
      {'byteLength': bin.length},
    ],
  };
  return GlbDocument(json, bin.toBytes()).encode();
}
