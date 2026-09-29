import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';


/// A decoded heightmap image: normalised `[0, 1]` samples, one per pixel.
class DecodedHeightmap {
  final int width;
  final int height;
  final Float32List samples;
  final int bitDepth;

  const DecodedHeightmap({
    required this.width,
    required this.height,
    required this.samples,
    required this.bitDepth,
  });
}

/// Reads and writes `LANDSCAPE` `.lmas` assets and imports heightmap PNGs.
///
/// The heightmap and the foliage layers live in the asset's `raw_payload`
/// (raw little-endian binary — see [LandscapeData.toBytes]); each foliage
/// layer additionally emits an `AssetReference` in slot `foliage_<i>` so the
/// reference graph, the cook and the content browser see the mesh dependency.
class LandscapeAssetService {
  const LandscapeAssetService._();

  static const String assetIdPrefix = 'landscape_';

  /// Loads the landscape payload of a `.lmas`, or null when the file is
  /// missing / carries no landscape payload.
  static LandscapeData? load(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      final payload = asset.rawPayload;
      if (payload == null || payload.length < 4) return null;
      final data = LandscapeData.fromBytes(payload);
      if (data.samplesAreExternal) {
        // Large terrains keep their heights in a streamed sidecar next to the
        // asset (a `.lmas` base64-encodes its payload inside JSON, which an
        // 8129² heightmap would turn into ~176 MB of text).
        final sidecar = File(LandscapeData.sidecarPathFor(path));
        if (!sidecar.existsSync()) {
          throw ArgumentError('landscape heights sidecar missing: ${sidecar.path}');
        }
        data.readSidecar(sidecar);
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Writes [data] as a `LANDSCAPE` `.lmas` at [path] (creating folders).
  static Future<void> save({
    required String path,
    required String name,
    required LandscapeData data,
    String? assetId,
  }) async {
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final references = <AssetReference>[];
    for (var i = 0; i < data.layers.length; i++) {
      final layer = data.layers[i];
      references.add(AssetReference(
        slotName: 'foliage_$i',
        assetId: layer.meshAssetId,
        assetPath: layer.meshAssetPath,
      ));
    }
    final inline = data.vertexCount <= LandscapeData.maxInlineSamples;
    if (inline) {
      final stale = File(LandscapeData.sidecarPathFor(path));
      if (stale.existsSync()) stale.deleteSync();
    } else {
      await data.writeSidecar(File(LandscapeData.sidecarPathFor(path)));
    }
    final asset = LuminaAsset(
      assetId: assetId ?? '$assetIdPrefix$name',
      name: name,
      type: AssetType.landscape,
      rawPayload: data.toBytes(inlineSamples: inline),
      references: references,
      metadata: {
        'height_storage': inline ? 'inline_uint16' : 'sidecar_uint16',
        'height_bytes': '${data.heightBytes}',
        'grid_resolution': '${data.gridResolution}',
        'world_size_m': data.worldSize.toStringAsFixed(2),
        'max_height_m': data.maxHeight.toStringAsFixed(2),
        'height_min_m': data.heightMin.toStringAsFixed(3),
        'height_max_m': data.heightMax.toStringAsFixed(3),
        'foliage_layers': '${data.layers.length}',
        'foliage_instances': '${data.layers.fold<int>(0, (s, l) => s + l.instanceCount)}',
      },
    );
    await file.writeAsBytes(asset.toProtoBufferBytes(), flush: true);
  }

  /// Creates a flat-terrain `LANDSCAPE` asset on disk — what
  /// `Content Browser → New Asset → Landscape` produces, a valid, openable
  /// terrain rather than an empty shell.
  static Future<String> createFlatAsset({
    required String projectDirPath,
    String subFolder = 'landscapes',
    String fileName = 'NewLandscape.lmas',
    int gridResolution = 129,
    double worldSize = 256.0,
    double maxHeight = 100.0,
  }) async {
    final dir = Directory('$projectDirPath/contents/$subFolder');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var target = File('${dir.path}/$fileName');
    var counter = 1;
    final base = fileName.endsWith('.lmas') ? fileName.substring(0, fileName.length - 5) : fileName;
    while (target.existsSync()) {
      target = File('${dir.path}/${base}_$counter.lmas');
      counter++;
    }
    final name = target.uri.pathSegments.last.replaceAll('.lmas', '');
    await save(
      path: target.path,
      name: name,
      data: LandscapeData.flat(gridResolution: gridResolution, worldSize: worldSize, maxHeight: maxHeight),
    );
    ProjectRepository.ensurePubspecAssets(projectDirPath);
    return target.path;
  }

  /// Decodes a grayscale heightmap PNG (8- or 16-bit) into a terrain.
  ///
  /// The image must be square and its side must be a real terrain resolution —
  /// `n × 64 + 1`, from 65² up to [LandscapeData.maxGridResolution]², the
  /// tiling the section map uses. Anything else is rejected by name with the
  /// nearest sizes that would work, rather than by a blanket cap. A 16-bit PNG
  /// keeps all 16 bits: the payload stores normalized `uint16`, so nothing is
  /// quantised to 8 on the way in.
  static LandscapeData importHeightmap({
    required Uint8List pngBytes,
    required double worldSize,
    required double maxHeight,
  }) {
    final decoded = decodeHeightmapSamples(pngBytes);
    return _terrainFrom(decoded, worldSize: worldSize, maxHeight: maxHeight);
  }

  static LandscapeData _terrainFrom(
    DecodedHeightmapSamples decoded, {
    required double worldSize,
    required double maxHeight,
  }) {
    if (decoded.width != decoded.height) {
      throw ArgumentError('heightmap must be square (got ${decoded.width}×${decoded.height})');
    }
    final reason = LandscapeData.describeInvalidResolution(decoded.width);
    if (reason != null) throw ArgumentError(reason);
    return LandscapeData(
      gridResolution: decoded.width,
      worldSize: worldSize,
      maxHeight: maxHeight,
      samples: decoded.samples,
    );
  }

  /// Imports a heightmap file without blocking the calling isolate.
  ///
  /// The PNG decode — the part that really costs seconds on a large map — runs
  /// in a background isolate; [onProgress] is called on the caller's isolate
  /// with a real fraction as each stage completes, so the editor can show a
  /// progress bar instead of freezing.
  static Future<LandscapeData> importHeightmapFileAsync({
    required String path,
    required double worldSize,
    required double maxHeight,
    void Function(double progress, String stage)? onProgress,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('heightmap not found at $path');
    }
    onProgress?.call(0.0, 'Reading $path');
    final bytes = await file.readAsBytes();
    onProgress?.call(0.15, 'Decoding ${bytes.length ~/ 1024} KB of PNG');
    final decoded = await Isolate.run(() => decodeHeightmapSamples(bytes));
    onProgress?.call(0.85, 'Building ${decoded.width}² terrain');
    final data = _terrainFrom(decoded, worldSize: worldSize, maxHeight: maxHeight);
    onProgress?.call(1.0, 'Imported ${decoded.width}² heightmap (${decoded.bitDepth}-bit)');
    return data;
  }

  /// Decodes a PNG straight into normalized `uint16` samples.
  ///
  /// This is the import path for large maps: it never materialises a
  /// `Float32List` of the whole image (at 8129² that alone is 264 MB).
  static DecodedHeightmapSamples decodeHeightmapSamples(Uint8List bytes) {
    final raw = _decodePngRaw(bytes);
    final samples = Uint16List(raw.width * raw.height);
    final stride = raw.stride;
    final bpp = raw.bytesPerPixel;
    if (raw.bitDepth == 16) {
      for (var y = 0; y < raw.height; y++) {
        for (var x = 0; x < raw.width; x++) {
          final base = y * stride + x * bpp;
          // All 16 bits survive: the payload's own sample space is uint16.
          samples[y * raw.width + x] = (raw.pixels[base] << 8) | raw.pixels[base + 1];
        }
      }
    } else {
      for (var y = 0; y < raw.height; y++) {
        for (var x = 0; x < raw.width; x++) {
          final base = y * stride + x * bpp;
          final v = raw.pixels[base];
          // 0..255 → 0..65535 with 255 mapping exactly to full height.
          samples[y * raw.width + x] = v * 257;
        }
      }
    }
    return DecodedHeightmapSamples(
      width: raw.width,
      height: raw.height,
      samples: samples,
      bitDepth: raw.bitDepth,
    );
  }

  /// Decodes a non-interlaced PNG into normalised `[0, 1]` luminance samples.
  ///
  /// Kept for callers that want floats; [decodeHeightmapSamples] is the one
  /// the importer uses.
  static DecodedHeightmap decodeHeightmapPng(Uint8List bytes) {
    final s = decodeHeightmapSamples(bytes);
    final out = Float32List(s.samples.length);
    for (var i = 0; i < out.length; i++) {
      out[i] = s.samples[i] / 65535.0;
    }
    return DecodedHeightmap(width: s.width, height: s.height, samples: out, bitDepth: s.bitDepth);
  }

  /// Unfilters a non-interlaced PNG into raw pixel bytes.
  ///
  /// Written here rather than pulled from a decoder package because the editor
  /// must keep 16-bit precision (a `dart:ui` round-trip would quantise heights
  /// to 8 bits) — greyscale, RGB and RGBA, 8 or 16 bits per channel.
  static _RawPng _decodePngRaw(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 8) throw ArgumentError('heightmap is not a readable PNG');
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != signature[i]) throw ArgumentError('heightmap is not a readable PNG');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    var offset = 8;
    int width = 0, height = 0, bitDepth = 0, colorType = 0, interlace = 0;
    final idat = BytesBuilder();
    while (offset + 8 <= bytes.length) {
      final length = view.getUint32(offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final dataStart = offset + 8;
      if (type == 'IHDR') {
        width = view.getUint32(dataStart);
        height = view.getUint32(dataStart + 4);
        bitDepth = bytes[dataStart + 8];
        colorType = bytes[dataStart + 9];
        interlace = bytes[dataStart + 12];
      } else if (type == 'IDAT') {
        idat.add(bytes.sublist(dataStart, dataStart + length));
      } else if (type == 'IEND') {
        break;
      }
      offset = dataStart + length + 4;
    }
    if (width == 0 || height == 0) throw ArgumentError('heightmap PNG has no IHDR');
    if (interlace != 0) throw ArgumentError('interlaced heightmap PNGs are not supported');
    if (bitDepth != 8 && bitDepth != 16) {
      throw ArgumentError('heightmap PNG must be 8- or 16-bit (got $bitDepth)');
    }
    const channelsFor = {0: 1, 2: 3, 4: 2, 6: 4};
    final channels = channelsFor[colorType];
    if (channels == null) {
      throw ArgumentError('heightmap PNG colour type $colorType is not supported (use greyscale or RGB)');
    }

    final raw = Uint8List.fromList(ZLibDecoder().convert(idat.toBytes()));
    final bytesPerSample = bitDepth ~/ 8;
    final bpp = channels * bytesPerSample;
    final stride = width * bpp;
    final out = Uint8List(height * stride);
    var pos = 0;
    for (var y = 0; y < height; y++) {
      if (pos >= raw.length) break;
      final filter = raw[pos++];
      final rowStart = y * stride;
      for (var x = 0; x < stride; x++) {
        final rawByte = pos < raw.length ? raw[pos++] : 0;
        final a = x >= bpp ? out[rowStart + x - bpp] : 0;
        final b = y > 0 ? out[rowStart - stride + x] : 0;
        final c = (x >= bpp && y > 0) ? out[rowStart - stride + x - bpp] : 0;
        int value;
        switch (filter) {
          case 0:
            value = rawByte;
            break;
          case 1:
            value = rawByte + a;
            break;
          case 2:
            value = rawByte + b;
            break;
          case 3:
            value = rawByte + ((a + b) >> 1);
            break;
          case 4:
            final p = a + b - c;
            final pa = (p - a).abs();
            final pb = (p - b).abs();
            final pc = (p - c).abs();
            final pred = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
            value = rawByte + pred;
            break;
          default:
            throw ArgumentError('unsupported PNG filter $filter');
        }
        out[rowStart + x] = value & 0xFF;
      }
    }

    return _RawPng(
      width: width,
      height: height,
      bitDepth: bitDepth,
      bytesPerPixel: bpp,
      stride: stride,
      pixels: out,
    );
  }

  /// Reads a heightmap PNG from disk (real file I/O — no mock loaders).
  static LandscapeData importHeightmapFile({
    required String path,
    required double worldSize,
    required double maxHeight,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('heightmap not found at $path');
    }
    return importHeightmap(pngBytes: file.readAsBytesSync(), worldSize: worldSize, maxHeight: maxHeight);
  }
}

/// A heightmap decoded straight into the payload's own `uint16` sample space.
class DecodedHeightmapSamples {
  final int width;
  final int height;
  final Uint16List samples;
  final int bitDepth;

  const DecodedHeightmapSamples({
    required this.width,
    required this.height,
    required this.samples,
    required this.bitDepth,
  });
}

/// Unfiltered PNG pixel bytes.
class _RawPng {
  final int width;
  final int height;
  final int bitDepth;
  final int bytesPerPixel;
  final int stride;
  final Uint8List pixels;

  const _RawPng({
    required this.width,
    required this.height,
    required this.bitDepth,
    required this.bytesPerPixel,
    required this.stride,
    required this.pixels,
  });
}
