import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina/data/services/filament_thumbnail_renderer.dart';

/// A generated thumbnail and what produced it.
class ThumbnailResult {
  final Uint8List png;

  /// [ThumbnailService.sourceFilament], [ThumbnailService.sourceImage] or
  /// [ThumbnailService.sourceBadge].
  final String source;

  const ThumbnailResult(this.png, this.source);
}

/// Content Browser thumbnails: routes each asset to the
/// thumbnail that shows what it is, caches it, and knows when it is stale.
///
/// | asset | thumbnail |
/// | --- | --- |
/// | static / skeletal mesh | Filament render of the mesh ([FilamentThumbnailRenderer.renderMesh]) |
/// | Blueprint | Filament render of its mesh components; the badge when it has none |
/// | material | its preview sphere ([FilamentThumbnailRenderer.renderMaterial]) |
/// | texture | the image itself, downscaled |
/// | level | Filament render of its actors ([FilamentThumbnailRenderer.renderLevel]) |
/// | animation sequence | its skeletal mesh posed at the middle of the clip; the badge without a mesh |
/// | Animation Blueprint | its target skeletal mesh; the badge without one |
/// | Blend Space | its target skeletal mesh, posed by the sample nearest the axes' centre |
/// | everything else | the type badge |
///
/// A thumbnail lives only inside the `.lmas` (`thumbnail_png`
/// — no `.thumbnails/` sidecar), keeping the file's own format — a level
/// stays the editor's JSON document. It is stamped with
/// `metadata.thumbnail_asset_modified`, and the file's modification time is
/// set to that stamp when the thumbnail is written, so an asset saved after
/// its thumbnail (its `.lmas`, or a mesh's `.entity.glb`, newer than the
/// stamp) is stale and is rendered again.
class ThumbnailService {
  ThumbnailService({this._renderer, AssetRepository? assetRepository})
      : _assetRepo = assetRepository ?? AssetRepository();

  /// Thumbnail edge length.
  static const int size = 256;

  /// `.lmas` metadata keys.
  static const String sourceKey = 'thumbnail_source';
  static const String renderedAtKey = 'thumbnail_rendered_at';
  static const String assetModifiedKey = 'thumbnail_asset_modified';

  /// [sourceKey] values.
  static const String sourceFilament = 'filament';
  static const String sourceImage = 'image';
  static const String sourceBadge = 'badge';

  static const Set<String> _currentSources = {sourceFilament, sourceImage, sourceBadge};

  /// Types that have something to render (or show); the rest keep a badge.
  static const Set<AssetType> renderedTypes = {
    AssetType.filamesh,
    AssetType.filameshSk,
    AssetType.filamat,
    AssetType.texture,
    AssetType.level,
    AssetType.actor,
    AssetType.animation,
    AssetType.animBlueprint,
    AssetType.blendSpace,
  };

  final FilamentThumbnailRenderer? _renderer;
  final AssetRepository _assetRepo;
  final EngineLoggerService _logger = EngineLoggerService();

  /// The renderer in use: the injected one, else the process-wide one.
  FilamentThumbnailRenderer get renderer => _renderer ?? FilamentThumbnailRenderer.shared;

  final Uint8List _fallbackPngBytes = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 1, 0, 0, 0, 1, 0, 8, 2, 0,
    0, 0, 107, 240, 136, 115, 0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 96, 96, 96, 0, 0, 0, 4,
    0, 1, 39, 52, 39, 10, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  // ---------------------------------------------------------------------------
  // Staleness
  // ---------------------------------------------------------------------------

  /// Whether [lmasPath] needs a (new) thumbnail. Reads the asset's summary
  /// (no payload decode); the editor uses [isStaleInfo] with what it scanned.
  bool isStale(String lmasPath) {
    final file = File(lmasPath);
    if (!file.existsSync()) return false;
    try {
      final summary = LuminaAsset.readSummary(file);
      return staleFor(
        lmasPath,
        summary.type,
        summary.thumbnailSource,
        hasThumbnail: summary.hasThumbnailBytes || (summary.hasThumbnail && summary.thumbnailRange == null && summary.payloadRange == null),
        assetModified: summary.metadata[assetModifiedKey],
      );
    } catch (_) {
      return false;
    }
  }

  /// [isStale] for a scanned asset (the asset index's summary; no re-read of
  /// the `.lmas` unless the scan did not carry the thumbnail stamp).
  static bool isStaleInfo(RealAssetInfo info) {
    final path = info.lmasPath;
    if (path == null) return false;
    var stamp = info.thumbnailAssetModified;
    var source = info.thumbnailSource;
    if (stamp == null) {
      try {
        final summary = LuminaAsset.readSummary(File(path));
        stamp = summary.metadata[assetModifiedKey];
        source = summary.thumbnailSource ?? source;
      } catch (_) {}
    }
    return staleFor(path, info.type, source, hasThumbnail: info.thumbnailBytes?.isNotEmpty ?? false, assetModified: stamp);
  }

  /// The staleness rule. A renderable asset is current when its thumbnail was
  /// made by this service and neither its `.lmas` nor a mesh's `.entity.glb`
  /// was modified after the thumbnail's [assetModifiedKey] stamp. Other types
  /// only need a thumbnail.
  static bool staleFor(String lmasPath, AssetType type, String? source, {required bool hasThumbnail, String? assetModified}) {
    final lmas = File(lmasPath);
    if (!lmas.existsSync()) return false;
    if (!renderedTypes.contains(type)) return !hasThumbnail;
    if (!hasThumbnail) return true;
    if (source == null || !_currentSources.contains(source)) return true;
    final stamp = assetModified == null ? null : DateTime.tryParse(assetModified);
    if (stamp == null) return true;
    final stampMs = stamp.millisecondsSinceEpoch;
    if (lmas.lastModifiedSync().millisecondsSinceEpoch > stampMs) return true;
    final companion = File(lmasPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    if (companion.existsSync() && companion.lastModifiedSync().millisecondsSinceEpoch > stampMs) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  /// Renders [lmasPath]'s thumbnail and writes it to the `.lmas` and the
  /// cache. Without [force] a current thumbnail is left alone (null). Null
  /// too when nothing could be produced (no GPU): the asset stays stale and
  /// is tried again later. An asset saved while it was rendering is rendered
  /// again, so the thumbnail never lags the file.
  Future<ThumbnailResult?> generate(String lmasPath, {bool force = false}) async {
    final file = File(lmasPath);
    if (!file.existsSync()) return null;
    if (!force && !isStale(lmasPath)) return null;
    for (var attempt = 0; attempt < 3; attempt++) {
      final before = file.lastModifiedSync();
      // The stamp: when this render started. A companion (`.entity.glb`)
      // saved while it renders is newer, so the thumbnail reads as stale.
      // (Never older than the files it was made from, whatever their clock.)
      final companion = File(lmasPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
      final started = DateTime.fromMillisecondsSinceEpoch([
        DateTime.now().millisecondsSinceEpoch,
        before.millisecondsSinceEpoch,
        if (companion.existsSync()) companion.lastModifiedSync().millisecondsSinceEpoch,
      ].reduce(math.max));
      final bytes = file.readAsBytesSync();
      final result = await _renderFile(lmasPath, bytes);
      if (result == null) return null;
      if (!file.existsSync()) return null;
      if (file.lastModifiedSync() != before) continue;
      embedThumbnail(lmasPath, result.png, source: result.source, stamp: started);
      _logger.log(
        'Thumbnail (${result.source}) written for ${file.uri.pathSegments.last}',
        level: 'info',
        source: 'ThumbnailService',
      );
      return result;
    }
    return null;
  }

  Future<ThumbnailResult?> _renderFile(String lmasPath, Uint8List bytes) async {
    final asset = _decode(bytes);
    if (asset == null) return null;
    final root = projectRootOf(lmasPath);
    switch (asset.type) {
      case AssetType.filamesh:
      case AssetType.filameshSk:
        final glb = await FilamentThumbnailRenderer.loadMeshGlb(lmasPath);
        if (glb == null) return _badge(asset.type);
        return _filament(await renderer.renderMesh(glb));
      case AssetType.filamat:
        return _filament(await renderer.renderMaterial(asset, projectRoot: root));
      case AssetType.texture:
        return await _texture(asset.rawPayload) ?? await _badge(asset.type);
      case AssetType.level:
        final actors = _levelActors(bytes);
        final parts = await FilamentThumbnailRenderer.levelParts(actors, projectRoot: root);
        if (parts.isEmpty) return _badge(asset.type);
        return _filament(await renderer.renderMeshParts(parts, pitchDegrees: 35));
      case AssetType.actor:
        final parts = await blueprintParts(asset, projectRoot: root);
        if (parts.isEmpty) return _badge(asset.type);
        return _filament(await renderer.renderMeshParts(parts));
      case AssetType.animation:
      case AssetType.animBlueprint:
      case AssetType.blendSpace:
        final part = await animationPart(asset, projectRoot: root);
        if (part == null) return _badge(asset.type);
        return _filament(await renderer.renderMeshParts([part]));
      default:
        return _badge(asset.type);
    }
  }

  /// What an animation asset's thumbnail draws: an
  /// animation sequence is its skeletal mesh (`source_mesh`, the clip lives in
  /// that mesh's GLB) posed at the middle of the clip; an Animation Blueprint
  /// is its target mesh (`target_mesh`) in its rest pose; a Blend Space is its
  /// target mesh posed by the sample nearest the centre of its axes. An
  /// unbound clip that carries its own GLB draws that when it has a mesh.
  /// Null when there is no mesh to draw.
  static Future<ThumbnailMeshPart?> animationPart(LuminaAsset asset, {String? projectRoot}) async {
    final document = _jsonPayload(asset.rawPayload);
    String? meshPath;
    ThumbnailPose? pose;
    switch (asset.type) {
      case AssetType.animation:
        meshPath = asset.metadata['source_mesh'] ?? _previewMeshOf(asset) ?? _referencedMesh(asset);
        pose = ThumbnailPose(
          clip: asset.metadata['clip_name'] ?? asset.name,
          clipIndex: int.tryParse(asset.metadata['clip_index'] ?? ''),
        );
      case AssetType.animBlueprint:
        meshPath = asset.metadata['target_mesh'] ?? document?['targetMesh'] as String? ?? _referencedMesh(asset);
      case AssetType.blendSpace:
        meshPath = asset.metadata['target_mesh'] ?? _referencedMesh(asset);
        if (document != null) {
          final space = LuminaBlendSpaceDocument.fromJson(document);
          double centre(int axis) => space.axes.length > axis ? (space.axes[axis].min + space.axes[axis].max) / 2 : 0.0;
          final sample = space.nearest(centre(0), centre(1));
          if (sample != null && sample.clip.isNotEmpty) pose = ThumbnailPose(clip: sample.clip);
        }
      default:
        return null;
    }

    Uint8List? glb;
    if (meshPath != null && meshPath.isNotEmpty) {
      final path = FilamentThumbnailRenderer.resolveProjectPath(meshPath, projectRoot) ??
          (projectRoot == null ? null : _findAssetByName(projectRoot, meshPath.split('/').last));
      if (path != null) glb = await FilamentThumbnailRenderer.loadMeshGlb(path);
    } else if (asset.type == AssetType.animation && _glbHasMesh(asset.rawPayload)) {
      // An unbound import keeps its clip GLB; a skeleton-only clip has
      // nothing to draw.
      glb = asset.rawPayload;
    }
    if (glb == null) return null;
    return ThumbnailMeshPart(glb, pose: pose);
  }

  /// The mesh an animation's editor previews on (`anim_properties`).
  static String? _previewMeshOf(LuminaAsset asset) {
    try {
      final props = jsonDecode(asset.metadata['anim_properties'] ?? '');
      final path = props is Map ? props['preview_mesh_path'] : null;
      return path is String && path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// The skeletal mesh an animation asset references (`skeletal_mesh` slot).
  static String? _referencedMesh(LuminaAsset asset) {
    for (final r in asset.references) {
      if (r.slotName == 'skeletal_mesh' && r.assetPath.isNotEmpty) return r.assetPath;
    }
    return null;
  }

  static Map<String, dynamic>? _jsonPayload(Uint8List? payload) {
    if (payload == null || payload.isEmpty || payload[0] != 0x7B) return null;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether a GLB's JSON chunk declares any mesh.
  static bool _glbHasMesh(Uint8List? glb) {
    if (glb == null || glb.length < 20 || glb[0] != 0x67 || glb[1] != 0x6C || glb[2] != 0x54 || glb[3] != 0x46) {
      return false;
    }
    try {
      final data = ByteData.sublistView(glb);
      final length = data.getUint32(12, Endian.little);
      if (20 + length > glb.length) return false;
      final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + length)));
      return json is Map && json['meshes'] is List && (json['meshes'] as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  ThumbnailResult? _filament(Uint8List? png) => png == null ? null : ThumbnailResult(png, sourceFilament);

  Future<ThumbnailResult> _badge(AssetType type) async =>
      ThumbnailResult(await renderTypeIconThumbnail(type), sourceBadge);

  Future<ThumbnailResult?> _texture(Uint8List? payload) async {
    if (payload == null || payload.isEmpty) return null;
    final png = await Isolate.run(() => _downscaledImage(payload, size));
    return png == null ? null : ThumbnailResult(png, sourceImage);
  }

  /// The image, box-filtered so its longer edge is at most [edge], as PNG.
  static Uint8List? _downscaledImage(Uint8List encoded, int edge) {
    final image = img.decodeImage(encoded);
    if (image == null) return null;
    var out = image;
    final longest = math.max(image.width, image.height);
    if (longest > edge) {
      final scale = edge / longest;
      out = img.copyResize(
        image,
        width: math.max(1, (image.width * scale).round()),
        height: math.max(1, (image.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }
    return img.encodePng(out);
  }

  /// A Blueprint's mesh components (`staticMeshAsset` / `skeletalMeshAsset`),
  /// each at its own stored transform — what the Blueprint Editor previews.
  static Future<List<ThumbnailMeshPart>> blueprintParts(LuminaAsset blueprint, {String? projectRoot}) async {
    final payload = blueprint.rawPayload;
    if (payload == null || payload.isEmpty) return const [];
    Map<String, dynamic> document;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map) return const [];
      document = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const [];
    }
    final parts = <ThumbnailMeshPart>[];
    for (final c in (document['components'] as List? ?? const [])) {
      if (c is! Map) continue;
      final props = c['properties'] is Map ? Map<String, dynamic>.from(c['properties'] as Map) : const <String, dynamic>{};
      final mesh = props['staticMeshAsset'] ?? props['skeletalMeshAsset'] ?? props['meshAsset'];
      if (mesh is! String || mesh.isEmpty) continue;
      if (props['isVisible'] == false || props['visible'] == false) continue;
      final path = FilamentThumbnailRenderer.resolveProjectPath(mesh, projectRoot) ??
          (projectRoot == null ? null : _findAssetByName(projectRoot, mesh));
      final glb = path == null ? null : await FilamentThumbnailRenderer.loadMeshGlb(path);
      if (glb == null) continue;
      parts.add(ThumbnailMeshPart(
        glb,
        transform: FilamentThumbnailRenderer.authoringTransform(props['location'], props['rotation'], props['scale']),
      ));
    }
    return parts;
  }

  /// A mesh referenced by name (`SM_Rock` / `SM_Rock.lmas`) under `contents/`.
  static String? _findAssetByName(String projectRoot, String name) {
    final wanted = name.endsWith('.lmas') ? name : '$name.lmas';
    final contents = Directory('$projectRoot/contents');
    if (!contents.existsSync()) return null;
    for (final e in contents.listSync(recursive: true, followLinks: false)) {
      if (e is File && e.uri.pathSegments.last == wanted) return e.path;
    }
    return null;
  }

  /// The project directory holding [lmasPath]: the nearest ancestor with a
  /// `contents/` folder.
  static String? projectRootOf(String lmasPath) {
    var dir = File(lmasPath).parent;
    for (var i = 0; i < 16; i++) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static List<Map<String, dynamic>> _levelActors(Uint8List bytes) {
    final map = _rawMap(bytes);
    final metadata = map?['metadata'];
    if (metadata is! Map) return const [];
    final actors = metadata['actors'];
    if (actors is! List) return const [];
    return [for (final a in actors) if (a is Map) Map<String, dynamic>.from(a)];
  }

  static bool _hasLmasHeader(Uint8List b) => b.length >= 4 && b[0] == 0x4C && b[1] == 0x4D && b[2] == 0x41 && b[3] == 0x53;

  /// The `.lmas` document as JSON, whichever container it is in.
  static Map<String, dynamic>? _rawMap(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(_hasLmasHeader(bytes) ? bytes.sublist(4) : bytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static LuminaAsset? _decode(Uint8List bytes) {
    try {
      return LuminaAsset.fromBytes(bytes);
    } catch (_) {
      final map = _rawMap(bytes);
      return map == null ? null : LuminaAsset.fromMap(map);
    }
  }

  /// Patches [png] into the `.lmas` at [lmasPath] without touching anything
  /// else in it (a level's actor list, keys this model does not know), in the
  /// same container format, with the base64 fields moved last
  /// ([LuminaAsset.withTrailingPayload]). The thumbnail is stamped
  /// ([sourceKey] = [source], [renderedAtKey], [assetModifiedKey] = [stamp])
  /// and the file's modification time is set to [stamp] (default: now), so
  /// it reads as current until the asset is saved again. Without [source]
  /// the existing stamps are kept and the file is simply written (a stale
  /// thumbnail stays stale).
  static void embedThumbnail(String lmasPath, Uint8List png, {String? source, DateTime? stamp}) {
    final file = File(lmasPath);
    final bytes = file.readAsBytesSync();
    final map = _rawMap(bytes);
    if (map == null) return;
    final metadata = map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : <String, dynamic>{};
    final at = DateTime.fromMillisecondsSinceEpoch((stamp ?? DateTime.now()).millisecondsSinceEpoch);
    if (source != null) {
      metadata[sourceKey] = source;
      metadata[renderedAtKey] = DateTime.now().toUtc().toIso8601String();
      metadata[assetModifiedKey] = at.toUtc().toIso8601String();
    }
    map
      ..['has_thumbnail'] = true
      ..['thumbnail_png'] = base64Encode(png)
      ..['metadata'] = metadata;
    final json = utf8.encode(jsonEncode(LuminaAsset.withTrailingPayload(map)));
    file.writeAsBytesSync(
      _hasLmasHeader(bytes) ? (BytesBuilder()..add(const [0x4C, 0x4D, 0x41, 0x53])..add(json)).toBytes() : json,
      flush: true,
    );
    if (source != null) file.setLastModifiedSync(at);
  }

  // ---------------------------------------------------------------------------
  // In-memory renders (Build Manager's Regenerate Thumbnails step)
  // ---------------------------------------------------------------------------

  /// The thumbnail for an in-memory [asset] (no file to resolve companions
  /// or references against): meshes from their embedded GLB and materials
  /// through Filament, textures from their image; the badge otherwise or
  /// when nothing could be rendered.
  Future<Uint8List> renderAssetThumbnail(LuminaAsset asset, {int size = size}) async {
    Uint8List? png;
    try {
      switch (asset.type) {
        case AssetType.filamesh:
        case AssetType.filameshSk:
          final payload = asset.rawPayload;
          if (payload != null && payload.length > 20 && payload[0] == 0x67) {
            png = await renderer.renderMesh(payload);
          }
        case AssetType.filamat:
          png = await renderer.renderMaterial(asset);
        case AssetType.texture:
          png = (await _texture(asset.rawPayload))?.png;
        default:
          break;
      }
    } catch (e) {
      _logger.log('Thumbnail render for ${asset.name} failed: $e', level: 'warning', source: 'ThumbnailService');
    }
    return png ?? await renderTypeIconThumbnail(asset.type, size: size);
  }

  /// The type badge (a card with the type's glyph), the thumbnail of types
  /// with nothing to render.
  Future<Uint8List> renderTypeIconThumbnail(AssetType type, {int size = size}) async {
    final thumb = await _assetRepo.generateThumbnailBytes(type);
    return thumb ?? _fallbackPngBytes;
  }
}
