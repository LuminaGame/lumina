import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:image/image.dart' as imglib;

import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

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
/// content and engine, and destroyed when the last material that binds it is
/// released: a texture saved again is uploaded anew for the materials loaded
/// after the save. A texture that cannot be loaded logs one warning and its
/// sampler is left unbound.
class LuminaMaterialTextures {
  LuminaMaterialTextures._(this._engine, this.bound, this.missing, this._held);

  /// Nothing to bind.
  LuminaMaterialTextures.none()
      : _engine = null,
        bound = const {},
        missing = const {},
        _held = const [];

  final FilamentEngine? _engine;

  /// The texture bound to each sampler, by sampler name.
  final Map<String, LuminaBoundTexture> bound;

  /// Why a sampler's texture was not bound, by sampler name.
  final Map<String, String> missing;

  /// The shared uploads this holds, with their registry keys.
  final List<(String, _SharedTexture)> _held;
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
    final wanted = texturePaths(material, references, assetProvider: assetProvider);
    if (wanted.isEmpty) return LuminaMaterialTextures.none();

    final read = LuminaAssets.resolve(assetProvider);
    final registry = _registry[engine] ??= {};
    final bound = <String, LuminaBoundTexture>{};
    final missing = <String, String>{};
    final held = <(String, _SharedTexture)>[];
    await Future.wait([
      for (final e in wanted.entries)
        () async {
          final colour = isColorSampler(e.key);
          _SharedTexture? shared;
          String? key;
          try {
            // Shared by content, not by path alone: a texture saved again
            // (new image, new settings) is uploaded anew while the materials
            // still drawing the old one keep it until they are released.
            final bytes = await read(e.value);
            key = '${colour ? 'srgb' : 'linear'}|${e.value}|${_fingerprint(bytes)}';
            shared = registry[key] ??= _SharedTexture(_upload(engine, e.value, bytes, colour));
            shared.refs++;
            final t = shared.value = await shared.future;
            held.add((key, shared));
            bound[e.key] = LuminaBoundTexture._(e.value, t.texture, t.sampler, t.srgb);
          } catch (error) {
            // Read again by the next material that names it.
            if (shared != null) {
              shared.refs--;
              if (identical(registry[key], shared)) registry.remove(key);
            }
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
    return LuminaMaterialTextures._(engine, bound, missing, held);
  }

  /// The texture each sampler [material] declares draws, by sampler name: the
  /// path of the reference whose slot name is the sampler, as [load] reads it
  /// through [assetProvider] (else [LuminaAssets]).
  static Map<String, String> texturePaths(
    FilamentMaterial material,
    List<AssetReference> references, {
    LuminaAssetProvider? assetProvider,
  }) {
    final wanted = <String, String>{};
    if (references.isEmpty) return wanted;
    for (final p in material.parameters) {
      if (!p.isSampler) continue;
      for (final r in references) {
        if (r.slotName == p.name && r.assetPath.isNotEmpty) {
          wanted[p.name] = _readablePath(r.assetPath, assetProvider);
          break;
        }
      }
    }
    return wanted;
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
    for (final (key, shared) in _held) {
      if (--shared.refs > 0) continue;
      if (registry != null && identical(registry[key], shared)) registry.remove(key);
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

  /// A content hash of [bytes] (FNV-1a over every byte, with the length):
  /// two reads of an unchanged file share one upload.
  static String _fingerprint(Uint8List bytes) {
    var h = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i++) {
      h ^= bytes[i];
      // h * 16777619 (2^24 + 403) mod 2^32, exact on the web too.
      h = ((h << 24) + h * 403) & 0xffffffff;
    }
    return '${bytes.length}:${h.toRadixString(16)}';
  }

  static Future<_Uploaded> _upload(FilamentEngine engine, String path, Uint8List bytes, bool colourSampler) async {
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
