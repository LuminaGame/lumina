import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// An absolute reference for texture orientation: a 64 × 64 image with four
/// coloured quadrants, a glTF quad that maps the image's top-left corner to
/// its own top-left corner, and the reader that tells, from a read-back
/// frame, which quadrant colour lands on each corner of the quad on screen.
///
/// Screen up and right are taken from where the quad lands in the frame, not
/// from the read-back row order (a GL swap chain reads back bottom row first,
/// Vulkan top row first): aim the camera below and left of the quad so it
/// sits in the upper right of the frame.
enum TextureQuadrant { topLeft, topRight, bottomLeft, bottomRight }

class TextureOrientationFixture {
  TextureOrientationFixture._();

  /// The quadrants' colours, as the image is written (row 0 at the top):
  /// red, green, blue, yellow.
  static const Map<TextureQuadrant, List<int>> colours = {
    TextureQuadrant.topLeft: [230, 20, 20],
    TextureQuadrant.topRight: [20, 210, 30],
    TextureQuadrant.bottomLeft: [20, 40, 230],
    TextureQuadrant.bottomRight: [235, 225, 20],
  };

  /// Every corner showing its own quadrant: the texture drawn upright.
  static const Map<TextureQuadrant, TextureQuadrant> upright = {
    TextureQuadrant.topLeft: TextureQuadrant.topLeft,
    TextureQuadrant.topRight: TextureQuadrant.topRight,
    TextureQuadrant.bottomLeft: TextureQuadrant.bottomLeft,
    TextureQuadrant.bottomRight: TextureQuadrant.bottomRight,
  };

  /// The four-quadrant image as a PNG.
  static Uint8List quadrantsPng() {
    final image = img.Image(width: 64, height: 64);
    for (final MapEntry(key: q, value: c) in colours.entries) {
      final x0 = q == TextureQuadrant.topLeft || q == TextureQuadrant.bottomLeft ? 0 : 32;
      final y0 = q == TextureQuadrant.topLeft || q == TextureQuadrant.topRight ? 0 : 32;
      img.fillRect(image, x1: x0, y1: y0, x2: x0 + 31, y2: y0 + 31, color: img.ColorRgb8(c[0], c[1], c[2]));
    }
    return img.encodePng(image);
  }

  /// Which quadrant colour a lit, tone-mapped sample is; null for black or
  /// anything in between.
  static TextureQuadrant? classify(List<int> rgb) {
    final [r, g, b] = rgb;
    if (r + g + b < 30) return null;
    final max = [r, g, b].reduce((a, c) => a > c ? a : c);
    final hi = [r > 0.55 * max, g > 0.55 * max, b > 0.55 * max];
    if (hi[0] && hi[1] && !hi[2]) return TextureQuadrant.bottomRight;
    if (hi[0] && !hi[1] && !hi[2]) return TextureQuadrant.topLeft;
    if (!hi[0] && hi[1] && !hi[2]) return TextureQuadrant.topRight;
    if (!hi[0] && !hi[1] && hi[2]) return TextureQuadrant.bottomLeft;
    return null;
  }

  /// The quadrant colour at each corner of the lit quad in [rgba] (a
  /// [width] × [height] read-back on a black clear colour), sampled a quarter
  /// of the way in from each edge. Null when nothing lit is in frame.
  static Map<TextureQuadrant, TextureQuadrant?>? quadCorners(Uint8List rgba, int width, int height) {
    List<int> at(int x, int y) => [for (var c = 0; c < 3; c++) rgba[(y * width + x) * 4 + c]];
    var x0 = width, x1 = -1, y0 = height, y1 = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (at(x, y).reduce((a, b) => a + b) < 30) continue;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
    if (x1 <= x0) return null;
    // The quad sits in the upper right: its rows are nearer the "up" end.
    final upIsHighRow = (y0 + y1) / 2 > height / 2;
    final rightIsHighColumn = (x0 + x1) / 2 > width / 2;
    int col(double f) => (rightIsHighColumn ? x0 + (x1 - x0) * f : x1 - (x1 - x0) * f).round();
    int row(double f) => (upIsHighRow ? y1 - (y1 - y0) * f : y0 + (y1 - y0) * f).round(); // f from the top
    return {
      TextureQuadrant.topLeft: classify(at(col(0.25), row(0.25))),
      TextureQuadrant.topRight: classify(at(col(0.75), row(0.25))),
      TextureQuadrant.bottomLeft: classify(at(col(0.25), row(0.75))),
      TextureQuadrant.bottomRight: classify(at(col(0.75), row(0.75))),
    };
  }

  /// Writes a glTF quad to [path]: x −1…1, y 0…2, facing +Z, V down (glTF),
  /// so the image's top-left (uv 0, 0) sits at the quad's top-left corner
  /// (−1, 2, 0). [png] is embedded as the material's base colour texture.
  static String writeGltfQuad(String path, Uint8List png) {
    const positions = [-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 2.0, 0.0, -1.0, 2.0, 0.0];
    const uvs = [0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0];
    const normals = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0];
    final imageOffset = 48 + 48 + 32 + 12;
    final pad = (4 - png.length % 4) % 4;
    final bin = ByteData(imageOffset + png.length + pad);
    var o = 0;
    for (final v in [...positions, ...normals, ...uvs]) {
      bin.setFloat32(o, v, Endian.little);
      o += 4;
    }
    for (final i in [0, 1, 2, 0, 2, 3]) {
      bin.setUint16(o, i, Endian.little);
      o += 2;
    }
    bin.buffer.asUint8List().setRange(imageOffset, imageOffset + png.length, png);
    final json = {
      'asset': {'version': '2.0'},
      'buffers': [{'byteLength': bin.lengthInBytes}],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 48},
        {'buffer': 0, 'byteOffset': 48, 'byteLength': 48},
        {'buffer': 0, 'byteOffset': 96, 'byteLength': 32},
        {'buffer': 0, 'byteOffset': 128, 'byteLength': 12},
        {'buffer': 0, 'byteOffset': imageOffset, 'byteLength': png.length},
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-1, 0, 0], 'max': [1, 2, 0]},
        {'bufferView': 1, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
        {'bufferView': 2, 'componentType': 5126, 'count': 4, 'type': 'VEC2'},
        {'bufferView': 3, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
      ],
      'images': [{'bufferView': 4, 'mimeType': 'image/png', 'name': 'quadrants'}],
      'samplers': [{'magFilter': 9728, 'minFilter': 9728}],
      'textures': [{'source': 0, 'sampler': 0}],
      'materials': [
        {
          'name': 'Quadrants',
          'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        },
      ],
      'meshes': [
        {
          'name': 'Quad',
          'primitives': [
            {'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0},
          ],
        },
      ],
      'nodes': [{'mesh': 0, 'name': 'Quad'}],
      'scenes': [{'nodes': [0]}],
      'scene': 0,
    };
    var jsonBytes = utf8.encode(jsonEncode(json));
    jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled((4 - jsonBytes.length % 4) % 4, 0x20)]);
    ByteData u32s(List<int> v) {
      final d = ByteData(v.length * 4);
      for (var i = 0; i < v.length; i++) {
        d.setUint32(i * 4, v[i], Endian.little);
      }
      return d;
    }

    final total = 12 + 8 + jsonBytes.length + 8 + bin.lengthInBytes;
    File(path).writeAsBytesSync([
      ...u32s([0x46546C67, 2, total]).buffer.asUint8List(),
      ...u32s([jsonBytes.length, 0x4E4F534A]).buffer.asUint8List(),
      ...jsonBytes,
      ...u32s([bin.lengthInBytes, 0x004E4942]).buffer.asUint8List(),
      ...bin.buffer.asUint8List(),
    ]);
    return path;
  }
}
