part of '../glb_parser_service.dart';

final Uint8List _neutralWhitePng = TgaDecoderService.encodePng(
  Uint8List.fromList([
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
  ]),
  2,
  2,
);

final Uint8List _neutralNormalPng = TgaDecoderService.encodePng(
  Uint8List.fromList([
    128,
    128,
    255,
    255,
    128,
    128,
    255,
    255,
    128,
    128,
    255,
    255,
    128,
    128,
    255,
    255,
  ]),
  2,
  2,
);

/// glTF `mimeType` for [bytes], sniffed from the header. Images resolved from disk
/// may be JPEG even when the pipeline's other branches produce PNG, and glTF
/// validators reject a PNG label on JPEG bytes.
String _sniffImageMimeType(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  return 'image/png';
}

/// Reads an image's pixel dimensions without decoding it. Returns `null` when the
/// format is not one this pipeline recognises by header (the caller then falls back
/// to a full decode).
({int width, int height})? _peekImageSize(Uint8List bytes) {
  // PNG: IHDR is always the first chunk, width/height at bytes 16..23.
  if (bytes.length >= 24 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71) {
    final header = ByteData.sublistView(bytes, 16, 24);
    return (
      width: header.getUint32(0, Endian.big),
      height: header.getUint32(4, Endian.big),
    );
  }

  // WebP (RIFF....WEBP): the first chunk carries the canvas size.
  if (bytes.length >= 30 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 && // RIFF
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) { // WEBP
    final chunk = String.fromCharCodes(bytes, 12, 16);
    final data = ByteData.sublistView(bytes);
    switch (chunk) {
      case 'VP8 ':
        // Lossy: a 3-byte frame tag, the 9d 01 2a start code, then 14-bit sizes.
        if (bytes[23] == 0x9D && bytes[24] == 0x01 && bytes[25] == 0x2A) {
          return (
            width: data.getUint16(26, Endian.little) & 0x3FFF,
            height: data.getUint16(28, Endian.little) & 0x3FFF,
          );
        }
      case 'VP8L':
        // Lossless: signature 0x2f, then width-1 and height-1 in 14 bits each.
        if (bytes[20] == 0x2F) {
          final bits = data.getUint32(21, Endian.little);
          return (width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
        }
      case 'VP8X':
        // Extended: flags, 3 reserved bytes, then 24-bit canvas width-1 / height-1.
        return (
          width: (bytes[24] | bytes[25] << 8 | bytes[26] << 16) + 1,
          height: (bytes[27] | bytes[28] << 8 | bytes[29] << 16) + 1,
        );
    }
    return null;
  }

  // JPEG: walk the marker segments to the first SOF.
  if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      // Standalone markers carry no length field.
      if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      const sofMarkers = {
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, //
        0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
      };
      if (sofMarkers.contains(marker)) {
        final header = ByteData.sublistView(bytes, i + 5, i + 9);
        return (
          width: header.getUint16(2, Endian.big),
          height: header.getUint16(0, Endian.big),
        );
      }
      final segmentLength = ByteData.sublistView(bytes, i + 2, i + 4).getUint16(0, Endian.big);
      if (segmentLength < 2) break;
      i += 2 + segmentLength;
    }
  }

  return null;
}

/// Downscales [bytes] so its longest edge is at most [maxTextureSize], preserving
/// aspect ratio, and returns the re-encoded PNG. Returns `null` when the image is
/// already within budget, when [maxTextureSize] is `0` (budget disabled), or when
/// the image cannot be decoded — in all three cases the caller keeps the original.
///
/// Filament uploads PNG-sourced images as uncompressed RGBA8 with a full mip chain,
/// so this is the difference between ~341 MB and ~21 MB of VRAM for an 8K texture.
Uint8List? _applyTextureBudget(
  Uint8List bytes,
  int maxTextureSize, {
  String? label,
}) {
  if (maxTextureSize <= 0 || bytes.isEmpty) return null;

  final peeked = _peekImageSize(bytes);
  if (peeked != null &&
      peeked.width <= maxTextureSize &&
      peeked.height <= maxTextureSize) {
    return null;
  }

  final decoded = imglib.decodeImage(bytes);
  if (decoded == null) return null;
  if (decoded.width <= maxTextureSize && decoded.height <= maxTextureSize) {
    return null;
  }

  final scale = maxTextureSize / math.max(decoded.width, decoded.height);
  final targetWidth = math.max(1, (decoded.width * scale).round());
  final targetHeight = math.max(1, (decoded.height * scale).round());

  final resized = imglib.copyResize(
    decoded,
    width: targetWidth,
    height: targetHeight,
    interpolation: imglib.Interpolation.average,
  );
  final png = Uint8List.fromList(imglib.encodePng(resized));

  // ~4/3 accounts for the mip chain Filament builds on top of the base level.
  final savedMb =
      ((decoded.width * decoded.height - targetWidth * targetHeight) * 4 * 4 / 3) /
          (1024 * 1024);
  GlbParserService._logger.log(
    'Downscaled ${label ?? 'texture'} ${decoded.width}x${decoded.height} → '
    '${targetWidth}x$targetHeight (budget $maxTextureSize px, '
    '~${savedMb.toStringAsFixed(1)} MB VRAM saved).',
    level: 'info',
    source: 'GlbParserService',
  );
  return png;
}

Uint8List _convertGlbTgaToPng(
  Uint8List glbBytes, {
  List<String>? searchDirs,
  int maxTextureSize = GlbParserService.defaultMaxTextureSize,
}) {
  if (glbBytes.length < 20) return glbBytes;

  try {
    final byteData = ByteData.sublistView(glbBytes);
    final magic = byteData.getUint32(0, Endian.little);
    if (magic != 0x46546C67) return glbBytes; // Not 'glTF'

    final jsonLength = byteData.getUint32(12, Endian.little);
    final jsonChunkType = byteData.getUint32(16, Endian.little);
    if (jsonChunkType != 0x4E4F534A) return glbBytes; // Not 'JSON'

    final jsonBytes = glbBytes.sublist(20, 20 + jsonLength);
    final jsonString = utf8.decode(jsonBytes);
    final json = jsonDecode(jsonString);
    if (json is! Map) return glbBytes;

    final images = json['images'] as List?;
    final materials = json['materials'] as List?;
    final textures = json['textures'] as List?;
    var bufferViews = json['bufferViews'] as List?;
    bufferViews ??= [];
    json['bufferViews'] = bufferViews;

    bool modified = false;
    bool imagesModified = false;

    final binChunkOffset = 20 + jsonLength;
    final binStart = (glbBytes.length >= binChunkOffset + 8)
        ? binChunkOffset + 8
        : glbBytes.length;
    final originalBinBytes = (binStart <= glbBytes.length)
        ? glbBytes.sublist(binStart)
        : Uint8List(0);

    final List<Uint8List> bvDataList = [];

    // Populate existing bufferView slices
    for (int i = 0; i < bufferViews.length; i++) {
      final bv = bufferViews[i] as Map;
      final offset = (bv['byteOffset'] as int?) ?? 0;
      final len = bv['byteLength'] as int;
      if (offset + len <= originalBinBytes.length) {
        bvDataList.add(originalBinBytes.sublist(offset, offset + len));
      } else {
        bvDataList.add(Uint8List(0));
      }
    }

    if (images != null && images.isNotEmpty) {
      for (int imgIdx = 0; imgIdx < images.length; imgIdx++) {
        final img = images[imgIdx] as Map?;
        if (img == null) continue;

        final uri = (img['uri'] as String?);
        final bvIdx = img['bufferView'] as int?;

        // 1. Image has existing bufferView
        if (bvIdx != null && bvIdx < bvDataList.length) {
          final rawData = bvDataList[bvIdx];
          // The bytes decide, not the mimeType label: a PNG labelled
          // image/tga is still a PNG.
          final format = EncodedImageFormat.sniff(rawData);

          if (format == EncodedImageFormat.tga) {
            final png = TgaDecoderService.tgaToPng(rawData);
            if (png != null) {
              bvDataList[bvIdx] =
                  _applyTextureBudget(png, maxTextureSize, label: 'image $imgIdx') ?? png;
              img['mimeType'] = 'image/png';
              img.remove('uri');
              imagesModified = true;
              modified = true;
            }
          } else {
            final budgeted = _applyTextureBudget(
              rawData,
              maxTextureSize,
              label: 'image $imgIdx',
            );
            if (budgeted != null) {
              bvDataList[bvIdx] = budgeted;
              img['mimeType'] = 'image/png';
              imagesModified = true;
              modified = true;
            } else if (format.mimeType != null && img['mimeType'] != format.mimeType) {
              // A label the bytes contradict sends Filament looking for a
              // texture provider the image does not need.
              img['mimeType'] = format.mimeType;
              imagesModified = true;
              modified = true;
            }
            if (img.containsKey('uri')) {
              img.remove('uri');
              imagesModified = true;
              modified = true;
            }
          }
        }
        // 2. Image has external or relative URI without bufferView
        else if (uri != null) {
          Uint8List? resolvedBytes;

          // Search on disk
          final uriFileName = uri.split(RegExp(r'[/\\]')).last;
          final uriBaseName = uriFileName.contains('.')
              ? uriFileName.substring(0, uriFileName.lastIndexOf('.'))
              : uriFileName;

          if (File(uri).existsSync()) {
            resolvedBytes = File(uri).readAsBytesSync();
          } else if (searchDirs != null) {
            for (final dirPath in searchDirs) {
              final d = Directory(dirPath);
              if (!d.existsSync()) continue;

              final candidates = [
                '$dirPath/$uri',
                '$dirPath/$uriFileName',
                '$dirPath/$uriBaseName.png',
                '$dirPath/$uriBaseName.PNG',
                '$dirPath/$uriBaseName.tga',
                '$dirPath/$uriBaseName.TGA',
                '$dirPath/$uriBaseName.jpg',
                '$dirPath/$uriBaseName.jpeg',
              ];

              for (final c in candidates) {
                if (File(c).existsSync()) {
                  resolvedBytes = File(c).readAsBytesSync();
                  break;
                }
              }
              if (resolvedBytes != null) break;
            }
          }

          if (resolvedBytes != null) {
            // A `.tga` uri may resolve to the `.png` the artist converted it
            // to: the bytes decide, not the name.
            if (EncodedImageFormat.sniff(resolvedBytes) == EncodedImageFormat.tga) {
              resolvedBytes =
                  TgaDecoderService.tgaToPng(resolvedBytes) ?? resolvedBytes;
            }
            resolvedBytes = _applyTextureBudget(
                  resolvedBytes,
                  maxTextureSize,
                  label: 'image $imgIdx ($uri)',
                ) ??
                resolvedBytes;
          } else {
            // Determine if this texture is used as normal map
            bool isNormalMap = false;
            if (textures != null && materials != null) {
              for (int tIdx = 0; tIdx < textures.length; tIdx++) {
                final tex = textures[tIdx] as Map?;
                if (tex != null && tex['source'] == imgIdx) {
                  for (final m in materials) {
                    if (m is Map &&
                        m['normalTexture'] is Map &&
                        (m['normalTexture'] as Map)['index'] == tIdx) {
                      isNormalMap = true;
                      break;
                    }
                  }
                }
                if (isNormalMap) break;
              }
            }
            resolvedBytes = isNormalMap
                ? _neutralNormalPng
                : _neutralWhitePng;
          }

          // Allocate new bufferView and embed resolved PNG
          final newBvIdx = bvDataList.length;
          bvDataList.add(resolvedBytes);
          bufferViews.add({
            'buffer': 0,
            'byteOffset': 0,
            'byteLength': resolvedBytes.length,
          });

          img['bufferView'] = newBvIdx;
          img['mimeType'] = _sniffImageMimeType(resolvedBytes);
          img.remove('uri');
          imagesModified = true;
          modified = true;
        }
      }
    }

    // 3. Inspect and strip dummy unpainted black COLOR_0 vertex color attributes
    final meshes = json['meshes'] as List?;
    final accessors = json['accessors'] as List?;
    if (meshes != null && accessors != null) {
      for (final mesh in meshes) {
        if (mesh is! Map) continue;
        final primitives = mesh['primitives'] as List?;
        if (primitives == null) continue;
        for (final prim in primitives) {
          if (prim is! Map) continue;
          final attrs = prim['attributes'] as Map?;
          if (attrs == null || !attrs.containsKey('COLOR_0')) continue;

          final colorAccIdx = attrs['COLOR_0'];
          if (colorAccIdx is! int ||
              colorAccIdx < 0 ||
              colorAccIdx >= accessors.length) {
            continue;
          }
          final acc = accessors[colorAccIdx] as Map?;
          if (acc == null) continue;

          if (_isDummyBlackVertexColor(acc, bufferViews, bvDataList)) {
            attrs.remove('COLOR_0');
            modified = true;
            GlbParserService._logger.log(
              'Stripped dummy/black COLOR_0 vertex color attribute from mesh primitive.',
              level: 'info',
              source: 'GlbParserService',
            );
          }
        }
      }
    }

    // 4. Inspect and sanitize skinning weights (downsample >4 bone influences to 4-bone normalized FLOAT and cap skin joints to 256)
    final skinModified = _sanitizeSkinningWeights(json, bufferViews, bvDataList);
    if (skinModified) {
      modified = true;
      GlbParserService._logger.log(
        'Sanitized skeletal mesh skinning weights: downsampled to 4 normalized float influences per vertex and capped skin joints to 256 (Filament limit).',
        level: 'info',
        source: 'GlbParserService',
      );
    }

    // 5. Inspect and strip unsupported custom vertex attributes (starting with '_', e.g. '_METALLIC_ROUGHNESS')
    // Filament gltfio AssetLoader rejects any unrecognized attribute semantics with
    // "Unrecognized vertex semantic in <name>" and fails the entire asset load.
    if (meshes != null) {
      for (final mesh in meshes) {
        if (mesh is! Map) continue;
        final primitives = mesh['primitives'] as List?;
        if (primitives == null) continue;
        for (final prim in primitives) {
          if (prim is! Map) continue;
          final attrs = prim['attributes'] as Map?;
          if (attrs == null) continue;
          final customKeys = attrs.keys.where((k) => k is String && k.startsWith('_')).toList();
          for (final key in customKeys) {
            attrs.remove(key);
            modified = true;
            GlbParserService._logger.log(
              'Stripped unsupported custom vertex attribute "$key" from mesh primitive for Filament compatibility.',
              level: 'info',
              source: 'GlbParserService',
            );
          }
        }
      }
    }

    if (!modified) return glbBytes;

    Uint8List newBinBytes;
    if (imagesModified || skinModified) {
      // Rebuild binary chunk with 4-byte aligned bufferViews
      final BytesBuilder newBinBuilder = BytesBuilder();
      int currentOffset = 0;
      for (int i = 0; i < bufferViews.length; i++) {
        final bv = bufferViews[i] as Map;
        final data = bvDataList[i];

        final padding = (4 - (currentOffset % 4)) % 4;
        for (int p = 0; p < padding; p++) {
          newBinBuilder.addByte(0);
        }
        currentOffset += padding;

        bv['buffer'] = 0;
        bv['byteOffset'] = currentOffset;
        bv['byteLength'] = data.length;

        newBinBuilder.add(data);
        currentOffset += data.length;
      }

      final finalPadding = (4 - (currentOffset % 4)) % 4;
      for (int p = 0; p < finalPadding; p++) {
        newBinBuilder.addByte(0);
      }
      currentOffset += finalPadding;

      final buffers = json['buffers'] as List?;
      if (buffers != null && buffers.isNotEmpty) {
        (buffers[0] as Map)['byteLength'] = currentOffset;
      } else {
        json['buffers'] = [
          {'byteLength': currentOffset},
        ];
      }

      newBinBytes = newBinBuilder.toBytes();
    } else {
      newBinBytes = originalBinBytes;
    }

    // Encode new JSON chunk with 4-byte space padding
    var newJsonString = jsonEncode(json);
    var newJsonBytes = utf8.encode(newJsonString);
    final jsonPad = (4 - (newJsonBytes.length % 4)) % 4;
    if (jsonPad > 0) {
      newJsonString += ' ' * jsonPad;
      newJsonBytes = utf8.encode(newJsonString);
    }

    final totalGlbLength =
        12 + 8 + newJsonBytes.length + 8 + newBinBytes.length;
    final BytesBuilder glbBuilder = BytesBuilder();

    // GLB Header (12 bytes)
    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little) // 'glTF'
      ..setUint32(4, 2, Endian.little) // Version 2
      ..setUint32(8, totalGlbLength, Endian.little);
    glbBuilder.add(header.buffer.asUint8List());

    // JSON Chunk Header (8 bytes)
    final jsonHeader = ByteData(8)
      ..setUint32(0, newJsonBytes.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little); // 'JSON'
    glbBuilder.add(jsonHeader.buffer.asUint8List());
    glbBuilder.add(newJsonBytes);

    // BIN Chunk Header (8 bytes)
    final binHeader = ByteData(8)
      ..setUint32(0, newBinBytes.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little); // 'BIN\0'
    glbBuilder.add(binHeader.buffer.asUint8List());
    glbBuilder.add(newBinBytes);

    GlbParserService._logger.log(
      'Sanitized GLB textures: converted and embedded all images directly into GLB binary buffer.',
      level: 'success',
      source: 'GlbParserService',
    );
    return glbBuilder.toBytes();
  } catch (e) {
    GlbParserService._logger.log(
      'GLB TGA to PNG conversion warning: $e',
      level: 'warning',
      source: 'GlbParserService',
    );
    return glbBytes;
  }
}
