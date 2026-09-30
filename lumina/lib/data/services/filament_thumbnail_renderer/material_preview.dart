part of '../filament_thumbnail_renderer.dart';

/// Material thumbnails: compiling the .mat source, applying parameters,
/// binding samplers and the preview sphere.
mixin _ThumbnailMaterialPreview on _FilamentThumbnailRendererState {

  Future<Uint8List?> _renderMaterial(LuminaAsset material, {String? projectRoot}) async {
    if (!_ensureEngine()) return null;
    final engine = _engine!;
    final values = FilamentThumbnailRenderer.materialParameterValues(material);

    Uint8List? package = FilamentThumbnailRenderer.isFilamatPackage(material.rawPayload) ? material.rawPayload : null;
    var source = material.rawMatSource;
    if (package == null && source.trim().isNotEmpty) {
      package = await _compile(material.name.isEmpty ? 'Material' : material.name, source);
    }
    if (package == null) {
      // The Material Editor's fallback: a default lit surface in the
      // material's own base colour.
      source = FilamentThumbnailRenderer._fallbackSource;
      package = await _compile('LuminaThumbnailFallback', source);
      values['baseColor'] ??= _fallbackBaseColor(material);
      values['roughness'] ??= 0.45;
      values['metallic'] ??= 0.0;
    }
    if (package == null) return null;

    FilamentMaterial? mat;
    FilamentMaterialInstance? mi;
    final textures = <FilamentTexture>[];
    var entity = 0;
    try {
      mat = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: package);
      mi = mat.createInstance('LuminaThumbnailMaterial');
      _applyParameters(mat, mi, _headerParameters(source), values);
      await _bindSamplers(mat, mi, material, _headerParameters(source), projectRoot, textures);

      _ensureSphere();
      entity = engine.createEntity();
      final builder = RenderableBuilder(1);
      builder.geometry(0, PrimitiveType.triangles, _sphereVb!, ib: _sphereIb);
      builder.boundingBox(-FilamentThumbnailRenderer._sphereRadius, -FilamentThumbnailRenderer._sphereRadius, -FilamentThumbnailRenderer._sphereRadius, FilamentThumbnailRenderer._sphereRadius, FilamentThumbnailRenderer._sphereRadius, FilamentThumbnailRenderer._sphereRadius);
      builder.material(0, mi);
      builder.culling(false);
      builder.castShadows(true);
      builder.receiveShadows(true);
      builder.build(engine, entity);
      _scene!.addEntity(entity);

      _frame(
        Aabb3.minMax(Vector3.all(-FilamentThumbnailRenderer._sphereRadius), Vector3.all(FilamentThumbnailRenderer._sphereRadius)),
        pitchDegrees: 18,
      );
      return await _captureAndEncode();
    } finally {
      if (entity != 0) {
        _scene?.removeEntity(entity);
        engine.flushAndWait();
        engine.destroyEntityComponents(entity);
        engine.destroyEntity(entity);
      }
      for (final t in textures) {
        try {
          t.dispose();
        } catch (_) {}
      }
      try {
        mi?.dispose();
        mat?.dispose();
      } catch (_) {}
    }
  }

  /// Compiles the whole `.mat` [source] with the material compiler
  /// (Filament's own `.mat` parser, as the Material Editor uses it) for this
  /// engine's backend, off the calling isolate. Null when it is rejected; the
  /// compiler's message is logged.
  Future<Uint8List?> _compile(String name, String source) async {
    if (_compiled.containsKey(source)) return _compiled[source];
    final spec = _CompileSpec(
      name: name,
      source: source,
      targetApi: (_engine?.backend == FilamentBackend.opengl ? TargetApi.opengl : TargetApi.vulkan).value,
    );
    Uint8List? bytes;
    try {
      final (package, errors) = await Isolate.run(() => _compileSpec(spec));
      bytes = package;
      if (package == null) {
        _logger.log('Thumbnail material "$name" did not compile: $errors', level: 'warning', source: 'ThumbnailRenderer');
      }
    } catch (e) {
      _logger.log('Thumbnail material "$name" did not compile: $e', level: 'warning', source: 'ThumbnailRenderer');
    }
    if (!FilamentThumbnailRenderer.isFilamatPackage(bytes)) bytes = null;
    _compiled[source] = bytes;
    return bytes;
  }

  void _applyParameters(
    FilamentMaterial mat,
    FilamentMaterialInstance mi,
    List<_MatParam> declared,
    Map<String, Object?> values,
  ) {
    final types = {for (final p in declared) p.name: p.type};
    values.forEach((name, value) {
      if (value == null || !mat.hasParameter(name)) return;
      final type = types[name] ?? _inferType(value);
      final list = value is List ? value.whereType<num>().map((e) => e.toDouble()).toList() : null;
      final scalar = value is num ? value.toDouble() : null;
      try {
        switch (type) {
          case 'float':
            if (scalar != null) mi.setFloat(name, scalar);
          case 'float2':
            if (list != null && list.length >= 2) mi.setFloat2(name, list[0], list[1]);
          case 'float3':
            if (list != null && list.length >= 3) mi.setFloat3(name, list[0], list[1], list[2]);
          case 'float4':
            if (list != null && list.length >= 4) {
              mi.setFloat4(name, list[0], list[1], list[2], list[3]);
            } else if (list != null && list.length == 3) {
              mi.setFloat4(name, list[0], list[1], list[2], 1.0);
            }
          case 'bool':
            if (value is bool) mi.setBool(name, value);
          case 'int':
            if (value is num) mi.setInt(name, value.toInt());
        }
      } catch (e) {
        _logger.log('Thumbnail material parameter $name: $e', level: 'warning', source: 'ThumbnailRenderer');
      }
    });
  }

  /// Binds every declared sampler: the texture the material references in
  /// that slot, decoded and downscaled, else a neutral 1×1 (white, or flat
  /// for a normal map), since Filament treats an unset sampler as an error.
  Future<void> _bindSamplers(
    FilamentMaterial mat,
    FilamentMaterialInstance mi,
    LuminaAsset material,
    List<_MatParam> declared,
    String? projectRoot,
    List<FilamentTexture> keep,
  ) async {
    final engine = _engine!;
    const sampler = TextureSampler(
      filterMin: SamplerMinFilter.linear,
      filterMag: SamplerMagFilter.linear,
      wrapS: SamplerWrapMode.repeat,
      wrapT: SamplerWrapMode.repeat,
    );
    for (final p in declared) {
      if (!p.type.startsWith('sampler') || !mat.hasParameter(p.name)) continue;
      final lower = p.name.toLowerCase();
      final isColor = lower.contains('color') || lower.contains('albedo') || lower.contains('diffuse') || lower.contains('emissive');
      _DecodedImage? decoded;
      for (final ref in material.references) {
        if (ref.slotName != p.name) continue;
        final path = FilamentThumbnailRenderer.resolveProjectPath(ref.assetPath, projectRoot);
        final bytes = path == null ? null : _imageBytesOf(path);
        if (bytes != null) {
          decoded = await Isolate.run(() => _decodeForSampler(bytes, 512));
        }
        break;
      }
      decoded ??= _DecodedImage(
        Uint8List.fromList(lower.contains('normal') ? const [128, 128, 255, 255] : const [255, 255, 255, 255]),
        1,
        1,
      );
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: decoded.width,
        height: decoded.height,
        format: isColor ? TextureFormat.srgb8A8 : TextureFormat.rgba8,
      );
      texture.setImage(pixelData: decoded.rgba, width: decoded.width, height: decoded.height);
      mi.setTexture(p.name, texture, sampler: sampler);
      keep.add(texture);
    }
  } // position | tangent frame | uv0

  void _ensureSphere() {
    if (_sphereVb != null) return;
    final engine = _engine!;
    const rings = 48;
    const segments = 96;
    final count = (rings + 1) * (segments + 1);
    final bytes = Uint8List(count * FilamentThumbnailRenderer._stride);
    final data = ByteData.view(bytes.buffer);
    var v = 0;
    for (var ring = 0; ring <= rings; ring++) {
      final theta = ring / rings * math.pi;
      for (var seg = 0; seg <= segments; seg++) {
        final phi = seg / segments * 2 * math.pi;
        final n = Vector3(math.sin(theta) * math.sin(phi), math.cos(theta), math.sin(theta) * math.cos(phi));
        final base = v * FilamentThumbnailRenderer._stride;
        data.setFloat32(base, n.x * FilamentThumbnailRenderer._sphereRadius, Endian.little);
        data.setFloat32(base + 4, n.y * FilamentThumbnailRenderer._sphereRadius, Endian.little);
        data.setFloat32(base + 8, n.z * FilamentThumbnailRenderer._sphereRadius, Endian.little);
        final packed = packTangentFrame(_tangentFrame(n));
        for (var c = 0; c < 4; c++) {
          data.setInt16(base + 12 + c * 2, packed[c], Endian.little);
        }
        data.setFloat32(base + 20, seg / segments * 2.0, Endian.little);
        data.setFloat32(base + 24, ring / rings, Endian.little);
        v++;
      }
    }
    final indices = Uint32List(rings * segments * 6);
    var i = 0;
    for (var ring = 0; ring < rings; ring++) {
      for (var seg = 0; seg < segments; seg++) {
        final a = ring * (segments + 1) + seg;
        final b = a + segments + 1;
        indices[i++] = a;
        indices[i++] = b;
        indices[i++] = a + 1;
        indices[i++] = a + 1;
        indices[i++] = b;
        indices[i++] = b + 1;
      }
    }
    _sphereVb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: count,
      bufferCount: 1,
      attributes: const [
        VertexAttributeDesc(attribute: VertexAttribute.position, type: AttributeType.float3, byteOffset: 0, byteStride: FilamentThumbnailRenderer._stride),
        VertexAttributeDesc(
          attribute: VertexAttribute.tangents,
          type: AttributeType.short4,
          byteOffset: 12,
          byteStride: FilamentThumbnailRenderer._stride,
          normalized: true,
        ),
        VertexAttributeDesc(attribute: VertexAttribute.uv0, type: AttributeType.float2, byteOffset: 20, byteStride: FilamentThumbnailRenderer._stride),
      ],
    );
    _sphereVb!.setBufferAt(engine, 0, NativeBuffer.copy(bytes));
    _sphereIb = FilamentIndexBuffer.create(engine: engine, indexCount: indices.length, type: IndexType.uint);
    _sphereIb!.setIndicesU32(indices);
  }
}

(Uint8List?, String) _compileSpec(_CompileSpec s) {
  final result = FilamentMatc.compile(
    s.source,
    fileName: '${s.name}.mat',
    defaultName: s.name,
    platform: MaterialPlatform.desktop,
    targetApi: TargetApi.values.firstWhere((t) => t.value == s.targetApi),
    optimization: OptimizationLevel.none,
  );
  return (result.package, result.ok ? '' : result.errorText);
}

List<double> _fallbackBaseColor(LuminaAsset material) {
  final stored = material.metadata['baseColor'];
  if (stored != null) {
    final parts = stored.split(',').map((e) => double.tryParse(e.trim())).whereType<double>().toList();
    if (parts.length >= 3) return [parts[0], parts[1], parts[2], parts.length > 3 ? parts[3] : 1.0];
  }
  return const [0.55, 0.56, 0.6, 1.0];
}

String _inferType(Object value) {
  if (value is bool) return 'bool';
  if (value is num) return 'float';
  if (value is List) return 'float${value.length.clamp(2, 4)}';
  return '';
}

/// The encoded image a texture file holds: a `.lmas`'s payload, or the
/// file itself.
Uint8List? _imageBytesOf(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    if (path.endsWith('.lmas')) return LuminaAsset.fromBytes(bytes).rawPayload;
    return bytes;
  } catch (_) {
    return null;
  }
}

_DecodedImage? _decodeForSampler(Uint8List bytes, int maxEdge) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  if (image.width > maxEdge || image.height > maxEdge) {
    final scale = maxEdge / math.max(image.width, image.height);
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }
  final rgba = image.convert(numChannels: 4, format: img.Format.uint8);
  return _DecodedImage(Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)), rgba.width, rgba.height);
}

/// A unit quaternion mapping +Z onto [n], with a stable tangent (Filament's
/// TBN frame, normal in column 2; w ≥ 0 because its sign is handedness).
Quaternion _tangentFrame(Vector3 n) {
  final helper = n.y.abs() < 0.99 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
  final t = helper.cross(n)..normalize();
  final b = n.cross(t)..normalize();
  final q = Quaternion.fromRotation(Matrix3.columns(t, b, n))..normalize();
  if (q.w < 0) q.scale(-1.0);
  return q;
}

// --- .mat header parsing ------------------------------------------------------

/// `parameters : [ { type : float4, name : baseColor, default : [..] } ]`,
/// read with bracket depth so a `default` list does not end the block.
List<_MatParam> _headerParameters(String source) {
  final out = <_MatParam>[];
  final start = RegExp(r'parameters\s*:\s*\[').firstMatch(source);
  if (start == null) return out;
  var depth = 1;
  var i = start.end;
  for (; i < source.length && depth > 0; i++) {
    if (source[i] == '[') depth++;
    if (source[i] == ']') depth--;
  }
  final block = source.substring(start.end, math.max(start.end, i - 1));
  for (final m in RegExp(r'\{([^{}]*)\}').allMatches(block)) {
    final entry = m.group(1)!;
    final type = RegExp(r'type\s*:\s*([A-Za-z0-9_]+)').firstMatch(entry)?.group(1);
    final name = RegExp(r'name\s*:\s*"?([A-Za-z_][A-Za-z0-9_]*)"?').firstMatch(entry)?.group(1);
    if (type == null || name == null) continue;
    Object? def;
    final d = RegExp(r'default\s*:\s*(\[[^\]]*\]|true|false|[-+0-9.eE]+)').firstMatch(entry)?.group(1);
    if (d != null) {
      if (d == 'true' || d == 'false') {
        def = d == 'true';
      } else if (d.startsWith('[')) {
        def = d
            .substring(1, d.length - 1)
            .split(',')
            .map((e) => double.tryParse(e.trim()))
            .whereType<double>()
            .toList();
      } else {
        def = double.tryParse(d);
      }
    }
    out.add(_MatParam(type, name, def));
  }
  return out;
}

class _MatParam {
  final String type;
  final String name;
  final Object? defaultValue;
  const _MatParam(this.type, this.name, this.defaultValue);
}

class _DecodedImage {
  final Uint8List rgba;
  final int width;
  final int height;
  const _DecodedImage(this.rgba, this.width, this.height);
}

/// What the material compiler needs, as plain values so it can cross into the
/// compile isolate.
class _CompileSpec {
  final String name;
  final String source;
  final int targetApi;

  const _CompileSpec({required this.name, required this.source, required this.targetApi});
}
