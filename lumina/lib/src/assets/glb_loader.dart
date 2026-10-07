import 'dart:typed_data';

import 'package:flutter_filament/filament.dart' show FilamentDracoDecoder;
import 'package:lumina/src/assets/encoded_image_decoder.dart';
import 'package:lumina_core/lumina_core.dart';

/// Reads GLB mesh data at run time: lumina_core's pure [GlbReader] with the
/// decoders only the engine has.
///
/// - Draco-compressed primitives (`KHR_draco_mesh_compression`) decode with
///   Filament's native decoder (flutter_filament).
/// - Base colour textures decode with [EncodedImageDecoder] (the platform
///   codec on a root isolate, `package:image` elsewhere) and are sampled into
///   vertex colours.
///
/// The landscape's foliage meshes and editor proxy read through it. The
/// editor's `GlbParserService.parseGlb` (lumina_editor_data) adds its import
/// sanitizer as [GlbDecoders.prepare].
abstract final class LuminaGlbLoader {
  /// The engine's decoders, for [GlbReader.parse].
  static const GlbDecoders decoders = GlbDecoders(draco: _decodeDraco, image: _decodeImage);

  /// [bytes] (a `.glb`, or a `.lmas` JSON container wrapping one) read into
  /// mesh data; null when they are not a readable GLB.
  static Future<GlbMeshData?> parse(Uint8List bytes) => GlbReader.parse(bytes, decoders: decoders);

  static GlbDracoMesh? _decodeDraco(Uint8List compressed) {
    final mesh = FilamentDracoDecoder.decode(compressed);
    if (mesh == null) return null;
    return GlbDracoMesh(positions: mesh.positions, uvs: mesh.uvs, indices: mesh.indices);
  }

  static Future<GlbDecodedPixels?> _decodeImage(Uint8List encoded) async {
    final image = await EncodedImageDecoder.decodeRgba(encoded);
    if (image == null) return null;
    return (width: image.width, height: image.height, rgba: image.rgba);
  }
}
