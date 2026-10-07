import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:image/image.dart' as imglib;
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart' show MaterialParamModel, MaterialParamType;
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart' show PreviewShape;
import 'package:lumina_ui/ui/features/sub_editors/services/preview_mesh_factory.dart';

/// Owns the Filament objects that show a compiled `.filamat` package on a
/// procedural preview primitive inside a sub-editor viewport.
///
/// Lifecycle: [mount] once the engine/scene exist, [applyParameters] whenever
/// the editor's parameter values change, [setShape] when the user picks another
/// primitive, [dispose] on teardown. Every native call is guarded: a material
/// that fails to load leaves [isMounted] false and the caller keeps its
/// software fallback.
class MaterialPreviewRenderer {
  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _instance;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;
  int _entity = 0;
  final Map<String, FilamentTexture> _samplerTextures = {};

  /// The path each sampler's texture was decoded from (null: the neutral
  /// fallback), so a parameter edit rebinds only what changed.
  final Map<String, String?> _samplerSources = {};
  final Map<String, TextureFormat> _samplerFormats = {};
  PreviewShape _shape = PreviewShape.sphere;
  String? _lastError;

  bool get isMounted => _entity != 0 && _instance != null;
  int get entity => _entity;
  PreviewShape get shape => _shape;
  String? get lastError => _lastError;
  FilamentMaterialInstance? get materialInstance => _instance;

  /// A compiled filamat package starts with a `MAT_VERS` chunk (stored
  /// little-endian, so the bytes read `SREV_TAM`) followed by its 4-byte size.
  static const List<int> _packageMagic = [0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D];

  /// Whether [bytes] look like a compiled `.filamat` package. Filament aborts
  /// the process (uncatchable panic) when handed arbitrary bytes, so callers
  /// must check this before [mount].
  static bool isFilamatPackage(Uint8List? bytes) {
    if (bytes == null || bytes.length < 16) return false;
    for (var i = 0; i < _packageMagic.length; i++) {
      if (bytes[i] != _packageMagic[i]) return false;
    }
    final chunkSize = ByteData.view(bytes.buffer, bytes.offsetInBytes + 8, 4).getUint32(0, Endian.little);
    return chunkSize == 4;
  }

  /// The MATERIAL_VERSION a package was compiled with, or null if not a package.
  static int? packageMaterialVersion(Uint8List? bytes) {
    if (!isFilamatPackage(bytes)) return null;
    return ByteData.view(bytes!.buffer, bytes.offsetInBytes + 12, 4).getUint32(0, Endian.little);
  }

  /// Creates the material from [filamatBytes], builds [shape] and adds the
  /// renderable to [scene]. Returns true on success.
  bool mount({
    required FilamentEngine engine,
    required FilamentScene scene,
    required Uint8List filamatBytes,
    required PreviewShape shape,
    List<MaterialParamModel> parameters = const [],
  }) {
    dispose();
    if (!isFilamatPackage(filamatBytes)) {
      _lastError = 'not a compiled filamat package (${filamatBytes.length} bytes)';
      debugPrint('[MaterialPreviewRenderer] refusing to load: $_lastError');
      return false;
    }
    _engine = engine;
    _scene = scene;
    _shape = shape;
    try {
      _material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: filamatBytes);
      _instance = _material!.createInstance('LuminaMaterialPreview');
      applyParameters(parameters);
      _buildGeometry(shape);
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MaterialPreviewRenderer] mount failed: $e');
      dispose();
      return false;
    }
  }

  /// Pushes the editor's parameter values into the material instance. Unknown
  /// or sampler parameters are skipped; each setter is guarded so one bad
  /// value never blocks the rest.
  void applyParameters(List<MaterialParamModel> parameters) {
    final mi = _instance;
    final mat = _material;
    if (mi == null || mat == null) return;
    _applySamplers(parameters);

    for (final p in parameters) {
      if (p.isSampler || p.type == MaterialParamType.sampler2dType) continue;
      if (!mat.hasParameter(p.name)) continue;
      try {
        final v = p.value;
        switch (p.type) {
          case MaterialParamType.floatType:
            if (v is num) mi.setFloat(p.name, v.toDouble());
            break;
          case MaterialParamType.boolType:
            if (v is bool) mi.setBool(p.name, v);
            break;
          case MaterialParamType.vec2Type:
            final l = _asDoubles(v, 2);
            if (l != null) mi.setFloat2(p.name, l[0], l[1]);
            break;
          case MaterialParamType.vec3Type:
            final l = _asDoubles(v, 3);
            if (l != null) mi.setFloat3(p.name, l[0], l[1], l[2]);
            break;
          case MaterialParamType.colorType:
          case MaterialParamType.vec4Type:
            final l4 = _asDoubles(v, 4);
            if (l4 != null) {
              mi.setFloat4(p.name, l4[0], l4[1], l4[2], l4[3]);
            } else {
              final l3 = _asDoubles(v, 3);
              if (l3 != null) mi.setFloat3(p.name, l3[0], l3[1], l3[2]);
            }
            break;
          case MaterialParamType.sampler2dType:
            break;
        }
      } catch (e) {
        debugPrint('[MaterialPreviewRenderer] parameter ${p.name}: $e');
      }
    }
  }

  /// Rebuilds the geometry for [shape] keeping the same material instance.
  void setShape(PreviewShape shape) {
    if (_engine == null || _instance == null) return;
    if (shape == _shape && _entity != 0) return;
    _shape = shape;
    try {
      _destroyGeometry();
      _buildGeometry(shape);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[MaterialPreviewRenderer] setShape failed: $e');
    }
  }

  /// Interleaved vertex layout: position float3 | tangents snorm16x4 | uv0 float2.
  static const int _strideBytes = 12 + 8 + 8;

  /// Packs [mesh] into the interleaved layout Filament expects. Exposed for
  /// tests (no engine required).
  static Uint8List packVertices(PreviewMeshData mesh) {
    final count = mesh.vertexCount;
    final bytes = Uint8List(count * _strideBytes);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < count; i++) {
      final base = i * _strideBytes;
      data.setFloat32(base, mesh.positions[i * 3], Endian.host);
      data.setFloat32(base + 4, mesh.positions[i * 3 + 1], Endian.host);
      data.setFloat32(base + 8, mesh.positions[i * 3 + 2], Endian.host);
      final q = tangentFrameFromNormal(
        mesh.normals[i * 3],
        mesh.normals[i * 3 + 1],
        mesh.normals[i * 3 + 2],
      );
      final packed = packTangentFrame(q);
      for (var c = 0; c < 4; c++) {
        data.setInt16(base + 12 + c * 2, packed[c], Endian.host);
      }
      data.setFloat32(base + 20, mesh.uv0[i * 2], Endian.host);
      data.setFloat32(base + 24, mesh.uv0[i * 2 + 1], Endian.host);
    }
    return bytes;
  }

  /// Builds a unit quaternion whose rotation maps +Z to the given normal, with
  /// a stable tangent chosen perpendicular to it (Filament's TBN frame where
  /// column 2 is the normal).
  static vm.Quaternion tangentFrameFromNormal(double nx, double ny, double nz) {
    final n = vm.Vector3(nx, ny, nz)..normalize();
    final helper = n.y.abs() < 0.99 ? vm.Vector3(0, 1, 0) : vm.Vector3(1, 0, 0);
    final t = helper.cross(n)..normalize();
    final b = n.cross(t)..normalize();
    final m = vm.Matrix3.columns(t, b, n);
    final q = vm.Quaternion.fromRotation(m)..normalize();
    // Filament requires w >= 0 for the packed frame (sign encodes handedness).
    if (q.w < 0) q.scale(-1.0);
    return q;
  }

  void _buildGeometry(PreviewShape shape) {
    final engine = _engine!;
    final scene = _scene!;
    final mesh = PreviewMeshFactory.build(shape);
    final attributes = <VertexAttributeDesc>[
      const VertexAttributeDesc(
        attribute: VertexAttribute.position,
        type: AttributeType.float3,
        byteOffset: 0,
        byteStride: _strideBytes,
      ),
      const VertexAttributeDesc(
        attribute: VertexAttribute.tangents,
        type: AttributeType.short4,
        byteOffset: 12,
        byteStride: _strideBytes,
        normalized: true,
      ),
      const VertexAttributeDesc(
        attribute: VertexAttribute.uv0,
        type: AttributeType.float2,
        byteOffset: 20,
        byteStride: _strideBytes,
      ),
    ];
    _vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: mesh.vertexCount,
      bufferCount: 1,
      attributes: attributes,
    );
    _vb!.setBufferAt(engine, 0, NativeBuffer.copy(packVertices(mesh)));
    _ib = FilamentIndexBuffer.create(engine: engine, indexCount: mesh.indices.length, type: IndexType.uint);
    _ib!.setIndicesU32(mesh.indices);

    _entity = engine.createEntity();
    final builder = RenderableBuilder(1);
    builder.geometry(0, PrimitiveType.triangles, _vb!, ib: _ib);
    builder.boundingBox(
      mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2],
      mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2],
    );
    builder.material(0, _instance!);
    builder.culling(false);
    builder.castShadows(true);
    builder.receiveShadows(true);
    builder.build(engine, _entity);
    scene.addEntity(_entity);
  }

  void _destroyGeometry() {
    final engine = _engine;
    if (engine == null) return;
    try {
      if (_entity != 0) {
        try {
          _scene?.removeEntity(_entity);
        } catch (_) {}
        engine.flushAndWait();
        engine.destroyEntityComponents(_entity);
        engine.destroyEntity(_entity);
        _entity = 0;
      }
      _ib?.dispose();
      _ib = null;
      _vb?.dispose();
      _vb = null;
    } catch (e) {
      debugPrint('[MaterialPreviewRenderer] geometry teardown: $e');
    }
  }

  /// How many texture files have been decoded, for tests of the rebind cache.
  @visibleForTesting
  static int decodeCount = 0;

  /// The format [name]'s texture was uploaded in, or null when unbound.
  @visibleForTesting
  TextureFormat? boundFormat(String name) => _samplerFormats[name];

  /// Whether sampler [name] holds colour (an sRGB image) rather than data
  /// (normals, roughness, masks). Decided by name, as lumina's thumbnail
  /// renderer and the importer's slot names do.
  static bool isColorSampler(String name) {
    final lower = name.toLowerCase();
    return lower.contains('color') || lower.contains('albedo') || lower.contains('diffuse') || lower.contains('emissive');
  }

  /// Filtered and repeating, as the thumbnail renderer samples: tiled UVs
  /// wrap instead of smearing the edge texels.
  static const TextureSampler textureSampler = TextureSampler(
    filterMin: SamplerMinFilter.linear,
    filterMag: SamplerMagFilter.linear,
    wrapS: SamplerWrapMode.repeat,
    wrapT: SamplerWrapMode.repeat,
  );

  /// Raw pixels of a decoded texture asset, ready for [FilamentTexture.setImage].
  static ({Uint8List rgba, int width, int height})? decodeTextureAsset(String path) {
    decodeCount++;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      var bytes = Uint8List.fromList(file.readAsBytesSync());

      // A texture `.lmas` wraps the image; a loose `.png` is already the image.
      if (path.toLowerCase().endsWith('.lmas')) {
        final payload = LuminaAsset.fromBytes(bytes).rawPayload;
        if (payload == null || payload.isEmpty) return null;
        bytes = payload;
      }

      final decoded = imglib.decodeImage(bytes);
      if (decoded == null) return null;
      return (
        rgba: Uint8List.fromList(decoded.getBytes(order: imglib.ChannelOrder.rgba)),
        width: decoded.width,
        height: decoded.height,
      );
    } catch (_) {
      return null;
    }
  }

  /// The 1×1 pixel to bind to a declared sampler that has nothing assigned.
  ///
  /// Filament treats an unset sampler as an error condition, and a material is
  /// routinely opened before every slot is filled. White is neutral for a
  /// colour multiply; a normal map needs flat (0.5, 0.5, 1.0) or every surface
  /// tilts.
  static List<int> fallbackPixelFor(String parameterName) {
    final lower = parameterName.toLowerCase();
    if (lower.contains('normal')) return const [128, 128, 255, 255];
    return const [255, 255, 255, 255];
  }

  /// Uploads [rgba] and binds it to [name] on the instance, replacing whatever
  /// that sampler held before.
  void _bindSampler(String name, Uint8List rgba, int width, int height) {
    final engine = _engine;
    final instance = _instance;
    if (engine == null || instance == null) return;

    final format = isColorSampler(name) ? TextureFormat.srgb8A8 : TextureFormat.rgba8;
    final texture = FilamentTexture.create2D(
      engine: engine,
      width: width,
      height: height,
      format: format,
    );
    texture.setImage(pixelData: rgba, width: width, height: height);
    instance.setTexture(name, texture, sampler: textureSampler);
    _samplerFormats[name] = format;

    final previous = _samplerTextures.remove(name);
    if (previous != null) {
      try {
        previous.dispose();
      } catch (_) {}
    }
    _samplerTextures[name] = texture;
  }

  /// Binds every sampler the material declares: the assigned texture where the
  /// editor has one, a neutral 1×1 otherwise.
  void _applySamplers(List<MaterialParamModel> parameters) {
    final mat = _material;
    if (mat == null || _instance == null) return;

    for (final p in parameters) {
      if (!p.isSampler && p.type != MaterialParamType.sampler2dType) continue;
      if (!mat.hasParameter(p.name)) continue;

      try {
        // The resolved path is the one that can actually be opened; the
        // reference itself stays project-relative for portability.
        final assignedPath = p.resolvedTexturePath ?? p.textureRef?.assetPath;
        if (_samplerTextures.containsKey(p.name) &&
            _samplerSources.containsKey(p.name) &&
            _samplerSources[p.name] == assignedPath) {
          continue; // Already bound to this file.
        }
        _samplerSources[p.name] = assignedPath;
        final decoded =
            assignedPath == null ? null : decodeTextureAsset(assignedPath);
        if (decoded != null) {
          _bindSampler(p.name, decoded.rgba, decoded.width, decoded.height);
          continue;
        }
        if (assignedPath != null) {
          debugPrint(
            '[MaterialPreviewRenderer] could not decode "$assignedPath" for '
            'sampler ${p.name}; using the neutral fallback',
          );
        }
        _bindSampler(
          p.name,
          Uint8List.fromList(fallbackPixelFor(p.name)),
          1,
          1,
        );
      } catch (e) {
        debugPrint('[MaterialPreviewRenderer] sampler ${p.name} failed: $e');
      }
    }
  }

  void dispose() {
    _destroyGeometry();
    try {
      _instance?.dispose();
    } catch (_) {}
    _instance = null;
    for (final texture in _samplerTextures.values) {
      try {
        texture.dispose();
      } catch (_) {}
    }
    _samplerTextures.clear();
    _samplerSources.clear();
    _samplerFormats.clear();
    try {
      _material?.dispose();
    } catch (_) {}
    _material = null;
    _engine = null;
    _scene = null;
  }

  static List<double>? _asDoubles(dynamic v, int n) {
    if (v is List && v.length >= n) {
      final out = <double>[];
      for (var i = 0; i < n; i++) {
        final e = v[i];
        if (e is! num) return null;
        out.add(e.toDouble());
      }
      return out;
    }
    return null;
  }
}
