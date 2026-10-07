import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as imglib;
import 'package:lumina/lumina.dart' show LuminaGlbLoader;
import 'package:lumina_core/lumina_core.dart';

part 'glb_parser_service/texture_conversion.dart';
part 'glb_parser_service/skinning_sanitizer.dart';

class GlbParserService {
  static final EngineLoggerService _logger = EngineLoggerService();
  /// Mesh data read from a GLB (or a `.lmas` wrapping one): [GlbReader] with
  /// the engine's decoders ([LuminaGlbLoader.decoders]: Filament's Draco
  /// decoder and the platform image codec), after this service's sanitizer
  /// ([convertGlbTgaToPngAsync]: TGA to PNG, the texture budget, four
  /// normalised skin influences).
  static Future<GlbMeshData?> parseGlb(Uint8List bytes) =>
      GlbReader.parse(bytes, decoders: LuminaGlbLoader.decoders.withPrepare(convertGlbTgaToPngAsync));

  /// Largest edge, in pixels, an imported texture may keep. Source art above this
  /// is downscaled on import: Filament uploads PNG-sourced images as uncompressed
  /// RGBA8 with a full mip chain, so one 8192x8192 image costs ~341 MB of VRAM and
  /// a handful of them exhaust the device heap.
  /// At 2048 the same image costs ~21 MB.
  static const int defaultMaxTextureSize = 2048;

  /// Version of [convertGlbTgaToPng]'s output. Part of every persisted
  /// derived-data key (`DerivedDataCache.sanitizedGlbKey`), so
  /// bump it whenever the sanitizer's output for the same input changes (the
  /// budget's resampling or encoder settings, the skinning rules, the image
  /// branches): entries written by an older converter then miss and rebuild.
  static const int sanitizerVersion = 3;

  static int _decodingConversions = 0;

  /// How many times this isolate ran the sanitizer on its expensive path — an
  /// asset whose images had to be decoded (over budget, TGA, unrecognised or
  /// resolved from disk). A load served by the derived-data cache never adds
  /// to it, which is how tests prove a cached session skipped the downscale.
  static int get decodingConversionCount => _decodingConversions;

  /// [convertGlbTgaToPng] run on a background isolate.
  ///
  /// Enforcing the texture budget means decoding and resizing every oversized
  /// source image — ~37 s for an asset carrying fourteen 8192x8192 PNGs. On the UI
  /// isolate that freezes the editor for the whole load, so callers that are already
  /// asynchronous (the asset load path) should use this instead.
  ///
  /// The worker isolate owns its own [EngineLoggerService] singleton, so its log
  /// lines would otherwise never reach the editor's Output Log. They are captured
  /// inside the worker and replayed here, keeping their original timestamps.
  static Future<Uint8List> convertGlbTgaToPngAsync(
    Uint8List glbBytes, {
    List<String>? searchDirs,
    int maxTextureSize = defaultMaxTextureSize,
  }) async {
    // Spawning a worker for an asset that needs no decoding costs more than the
    // work itself, and an isolate never completes inside a widget test's
    // fake-async zone — so only hand off when there is real work to do.
    if (!inspectImageWork(glbBytes, maxTextureSize: maxTextureSize).needsDecoding) {
      return convertGlbTgaToPng(
        glbBytes,
        searchDirs: searchDirs,
        maxTextureSize: maxTextureSize,
      );
    }

    _decodingConversions++;
    final result = await Isolate.run(() {
      late Uint8List sanitized;
      final logs = EngineLoggerService().captureLogs(() {
        sanitized = convertGlbTgaToPng(
          glbBytes,
          searchDirs: searchDirs,
          maxTextureSize: maxTextureSize,
        );
      });
      return (bytes: sanitized, logs: logs);
    });

    _logger.replay(result.logs);
    return result.bytes;
  }

  /// What sanitizing [glbBytes] costs, read from image headers only.
  ///
  /// `needsDecoding`: some image has to be decoded — an embedded image over
  /// [maxTextureSize], a TGA needing transcoding, an image whose header this
  /// pipeline does not recognise, or one that still has to be resolved from
  /// disk. Otherwise [convertGlbTgaToPng] is cheap and runs inline.
  ///
  /// `selfContained`: every image is embedded through a bufferView, so the
  /// sanitizer's output depends on [glbBytes] alone. Only such sources can be
  /// cached by their content hash (`DerivedDataCache`); an
  /// image referenced by `uri` is read from files the hash does not cover.
  static ({bool needsDecoding, bool selfContained}) inspectImageWork(
    Uint8List glbBytes, {
    int maxTextureSize = defaultMaxTextureSize,
  }) {
    try {
      if (glbBytes.length < 20) return (needsDecoding: false, selfContained: true);
      final byteData = ByteData.sublistView(glbBytes);
      if (byteData.getUint32(0, Endian.little) != 0x46546C67) {
        return (needsDecoding: false, selfContained: true);
      }

      final jsonLength = byteData.getUint32(12, Endian.little);
      if (byteData.getUint32(16, Endian.little) != 0x4E4F534A) {
        return (needsDecoding: false, selfContained: true);
      }

      final json = jsonDecode(utf8.decode(glbBytes.sublist(20, 20 + jsonLength)));
      if (json is! Map) return (needsDecoding: false, selfContained: true);

      final images = json['images'] as List?;
      if (images == null || images.isEmpty) return (needsDecoding: false, selfContained: true);

      final bufferViews = json['bufferViews'] as List? ?? const [];
      final binStart = 20 + jsonLength + 8;

      var needsDecoding = false;
      for (final entry in images) {
        if (entry is! Map) continue;
        final bvIdx = entry['bufferView'] as int?;
        if (bvIdx == null || bvIdx >= bufferViews.length) {
          // No bufferView means the image still has to be resolved from disk.
          return (needsDecoding: true, selfContained: false);
        }
        if (needsDecoding) continue; // Only self-containment is still open.
        final bv = bufferViews[bvIdx] as Map;
        final offset = binStart + ((bv['byteOffset'] as int?) ?? 0);
        final length = bv['byteLength'] as int? ?? 0;
        if (offset + length > glbBytes.length) continue;

        final head = glbBytes.sublist(offset, offset + math.min(length, 64));
        if (TgaDecoderService.isTga(head)) {
          needsDecoding = true;
          continue;
        }

        final size = _peekImageSize(head);
        if (size == null ||
            (maxTextureSize > 0 &&
                (size.width > maxTextureSize || size.height > maxTextureSize))) {
          // Unknown format: only a decode can tell. Or simply over budget.
          needsDecoding = true;
        }
      }
      return (needsDecoding: needsDecoding, selfContained: true);
    } catch (_) {
      // Anything unexpected: take the safe, off-thread path, and never cache it.
      return (needsDecoding: true, selfContained: false);
    }
  }
  /// Inspects GLB binary for any embedded or referenced TGA textures and external URIs,
  /// converts them to standard PNGs, and embeds them directly into internal bufferViews.
  /// This ensures Filament (and Flutter) will natively load and render all textures without
  /// "Missing texture provider for image/TGA" or "Unable to open ..." filesystem errors.
  ///
  /// Images whose longest edge exceeds [maxTextureSize] are downscaled in place,
  /// preserving aspect ratio. Pass `0` to keep source resolution.
  static const convertGlbTgaToPng = _convertGlbTgaToPng;
}

class _JointWeightPair {
  final int joint;
  final double weight;
  const _JointWeightPair(this.joint, this.weight);
}
