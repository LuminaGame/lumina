import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:image/image.dart' as imglib;

import '../../data/models/lumina_asset.dart';
import '../utility/lumina_assets.dart';

/// One texture bound to a material's sampler.
class LuminaBoundTexture {
  /// The texture asset (or image file) the material names, as it was read.
  final String path;

  /// The uploaded texture, shared by every material that binds [path] the
  /// same way.
  final FilamentTexture texture;

  /// Filtering and wrapping from the texture's settings.
  final TextureSampler sampler;

  /// Whether the texels are sRGB colour (decoded to linear by the GPU) rather
  /// than linear data (normals, roughness, masks).
  final bool srgb;

  const LuminaBoundTexture._(this.path, this.texture, this.sampler, this.srgb);
}

/// The textures a material asset's samplers name, loaded and uploaded.
///
/// A material asset records which texture goes to which sampler in its
/// references: `slot_name` is the sampler parameter, `asset_path` the texture
/// asset (`.lmas`, its payload the image) or an image file. The glTF import
/// writes them for `baseColorMap`, `normalMap`, `metallicRoughnessMap`,
/// `occlusionMap` and `emissiveMap`; the Material Editor for every
/// `sampler2d` a texture was assigned to.
///
/// Textures are read through [LuminaAssets] (the open project's files in the
/// editor and Play, the asset bundle in a built game) and uploaded with the
/// texture asset's settings (`texture_settings`: sRGB, mipmaps, filtering,
/// wrap); without settings, colour samplers (`…Color…`, albedo, diffuse,
/// emissive) are sRGB and the rest linear. One upload is shared per texture
/// and engine, and destroyed when the last material that binds it is
/// released. A texture that cannot be loaded logs one warning and its
/// sampler is left unbound.
class LuminaMaterialTextures {
  LuminaMaterialTextures._(this._engine, this.bound, this.missing, this._keys);

  /// Nothing to bind.
  LuminaMaterialTextures.none()
      : _engine = null,
        bound = const {},
        missing = const {},
        _keys = const [];

  final FilamentEngine? _engine;

  /// The texture bound to each sampler, by sampler name.
  final Map<String, LuminaBoundTexture> bound;

  /// Why a sampler's texture was not bound, by sampler name.
  final Map<String, String> missing;

  final List<String> _keys;
  bool _released = false;

  /// Loads the textures [references] name for the samplers [material]
  /// declares. [materialPath] names the material in warnings.
  static Future<LuminaMaterialTextures> load(
    FilamentEngine engine,
    FilamentMaterial material,
    List<AssetReference> references, {
    required String materialPath,
    LuminaAssetProvider? assetProvider,
  }) async {
    if (references.isEmpty) return LuminaMaterialTextures.none();
    final samplers = [for (final p in material.parameters) if (p.isSampler) p.name];
    final wanted = <String, String>{};
    for (final name in samplers) {
      for (final r in references) {
        if (r.slotName == name && r.assetPath.isNotEmpty) {
          wanted[name] = _readablePath(r.assetPath, assetProvider);
          break;
        }
      }
    }
    if (wanted.isEmpty) return LuminaMaterialTextures.none();

    final read = LuminaAssets.resolve(assetProvider);
    final registry = _registry[engine] ??= {};
    final bound = <String, LuminaBoundTexture>{};
    final missing = <String, String>{};
    final keys = <String>[];
    await Future.wait([
      for (final e in wanted.entries)
        () async {
          final colour = isColorSampler(e.key);
          final key = '${colour ? 'srgb' : 'linear'}|${e.value}';
          final shared = registry[key] ??= _SharedTexture(_upload(engine, e.value, colour, read));
          shared.refs++;
          try {
            final t = shared.value = await shared.future;
            keys.add(key);
            bound[e.key] = LuminaBoundTexture._(e.value, t.texture, t.sampler, t.srgb);
          } catch (error) {
            // Read again by the next material that names it.
            if (identical(registry[key], shared)) registry.remove(key);
            missing[e.key] = '$error';
            developer.log(
              "Material $materialPath: texture '${e.value}' for sampler '${e.key}' could not be loaded, the sampler "
              'is left unbound: $error',
              name: 'Material',
              level: 900,
            );
          }
        }(),
    ]);
    return LuminaMaterialTextures._(engine, bound, missing, keys);
  }

  /// Binds every loaded texture on [instance]. Bound on a material's default
  /// instance, every instance created from it afterwards starts with them.
  void bindTo(FilamentMaterialInstance instance) {
    bound.forEach((name, t) => instance.setTexture(name, t.texture, sampler: t.sampler));
  }

  /// Lets go of the textures; each is destroyed once no material binds it.
  /// Call after the material (and its instances) is destroyed.
  void release() {
    if (_released) return;
    _released = true;
    final engine = _engine;
    if (engine == null) return;
    final registry = _registry[engine];
    if (registry == null) return;
    for (final key in _keys) {
      final shared = registry[key];
      if (shared == null) continue;
      if (--shared.refs > 0) continue;
      registry.remove(key);
      final uploaded = shared.value;
      if (uploaded != null) {
        uploaded.texture.dispose();
      } else {
        shared.future.then((t) => t.texture.dispose(), onError: (_) {});
      }
    }
  }

  /// Whether sampler [name] holds colour (an sRGB image) rather than data,
  /// decided by name as the importer's slot names and the Material Editor
  /// preview do.
  static bool isColorSampler(String name) {
    final lower = name.toLowerCase();
    return lower.contains('color') || lower.contains('albedo') || lower.contains('diffuse') || lower.contains('emissive');
  }

  static final Expando<Map<String, _SharedTexture>> _registry = Expando();

  /// [stored] as [LuminaAssets] reads it: `/`-separated, and a project
  /// file's absolute path cut to `contents/…` when a provider (a built
  /// game's bundle) serves the assets.
  static String _readablePath(String stored, LuminaAssetProvider? explicit) {
    final p = stored.replaceAll(r'\', '/');
    if ((explicit ?? LuminaAssets.defaultProvider) == null) return p;
    if (p.startsWith('contents/')) return p;
    final i = p.indexOf('/contents/');
    return i < 0 ? p : p.substring(i + 1);
  }

  static Future<_Uploaded> _upload(FilamentEngine engine, String path, bool colourSampler, LuminaAssetProvider read) async {
    final bytes = await read(path);
    Uint8List image = bytes;
    Map<String, Object?> settings = const {};
    if (path.toLowerCase().endsWith('.lmas')) {
      final asset = LuminaAsset.fromBytes(bytes);
      final payload = asset.rawPayload;
      if (payload == null || payload.isEmpty) throw StateError('$path carries no image');
      image = payload;
      try {
        final decoded = jsonDecode(asset.metadata['texture_settings'] ?? '');
        if (decoded is Map) settings = {for (final e in decoded.entries) e.key.toString(): e.value};
      } catch (_) {}
    }
    final pixels = await _decode(image);
    if (pixels == null) throw StateError('$path is not an image this runtime decodes');

    final srgb = settings['srgb'] is bool ? settings['srgb'] as bool : colourSampler;
    final format = srgb ? TextureFormat.srgb8A8 : TextureFormat.rgba8;
    final mipGen = settings['mip_gen'] as String? ?? 'FromTextureGroup';
    final wantsMips = mipGen != 'NoMipmaps' && !(mipGen == 'FromTextureGroup' && settings['group'] == 'UI');
    final mips = wantsMips && FilamentTexture.isFormatMipmappable(engine, format);
    final levels = mips ? (math.log(math.max(pixels.width, pixels.height)) / math.ln2).floor() + 1 : 1;

    final texture = FilamentTexture.create2D(
      engine: engine,
      width: pixels.width,
      height: pixels.height,
      format: format,
      levels: levels,
      usage: TextureUsage.defaultUsage | (levels > 1 ? TextureUsage.genMipmappable : 0),
    );
    texture.setImage(pixelData: pixels.rgba, width: pixels.width, height: pixels.height);
    if (levels > 1) texture.generateMipmaps(engine);
    return _Uploaded(texture, _sampler(settings, mips: levels > 1), srgb);
  }

  /// The Texture editor's filtering and address modes (`Bilinear`,
  /// `Trilinear`, `Anisotropic 16x`; `Wrap`, `Clamp`, `Mirror`).
  static TextureSampler _sampler(Map<String, Object?> settings, {required bool mips}) {
    SamplerWrapMode wrap(Object? mode) => switch (mode) {
          'Clamp' => SamplerWrapMode.clampToEdge,
          'Mirror' => SamplerWrapMode.mirroredRepeat,
          _ => SamplerWrapMode.repeat,
        };
    final filter = settings['filter'] as String? ?? 'Bilinear';
    final bilinear = filter == 'Bilinear';
    return TextureSampler(
      filterMin: !mips
          ? SamplerMinFilter.linear
          : bilinear
              ? SamplerMinFilter.linearMipmapNearest
              : SamplerMinFilter.linearMipmapLinear,
      filterMag: SamplerMagFilter.linear,
      wrapS: wrap(settings['address_x']),
      wrapT: wrap(settings['address_y']),
      anisotropy: filter.startsWith('Anisotropic') && mips ? 16.0 : 1.0,
    );
  }

  /// Straight (not premultiplied) RGBA8 texels of an encoded image: the
  /// platform codec where there is one (PNG, JPEG, WebP, GIF, BMP), else
  /// `package:image` (TGA and the rest it knows).
  static Future<({Uint8List rgba, int width, int height})?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
          if (data != null) {
            return (rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), width: image.width, height: image.height);
          }
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Not a format the platform codec reads; try package:image.
    }
    final decoded = imglib.decodeImage(bytes);
    if (decoded == null) return null;
    final rgba = decoded.convert(format: imglib.Format.uint8, numChannels: 4);
    return (rgba: Uint8List.fromList(rgba.getBytes(order: imglib.ChannelOrder.rgba)), width: rgba.width, height: rgba.height);
  }
}

class _Uploaded {
  final FilamentTexture texture;
  final TextureSampler sampler;
  final bool srgb;
  const _Uploaded(this.texture, this.sampler, this.srgb);
}

class _SharedTexture {
  _SharedTexture(this.future);
  final Future<_Uploaded> future;
  _Uploaded? value;
  int refs = 0;
}
