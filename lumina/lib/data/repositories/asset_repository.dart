import 'dart:async';
import 'dart:convert';
import '../services/asset_reference_graph.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/lumina_asset.dart';
import '../models/lumina_theme_document.dart';
import '../services/animation_import_binder.dart';
import '../services/asset_index.dart';
import '../services/assimp_import_service.dart';
import '../services/derived_data_cache.dart';
import '../services/encoded_image_format.dart';
import '../services/engine_logger_service.dart';
import '../services/fbx_import_service.dart';
import '../services/fbx_material_mapper.dart';
import '../services/glb_animation_merger.dart';
import '../services/glb_parser_service.dart';
import '../services/gltf_packer.dart';
import '../services/import_formats.dart';
import '../services/import_image_conversion.dart';
import '../services/imported_asset_names.dart';
import '../services/obj_import_service.dart';
import '../services/obj_parser_service.dart';
import '../services/workspace_paths.dart';
import 'package:flutter_assimp/flutter_assimp.dart';

part 'asset_repository/state.dart';
part 'asset_repository/file_operations.dart';
part 'asset_repository/scanning.dart';
part 'asset_repository/import_staging.dart';
part 'asset_repository/imported_material.dart';
part 'asset_repository/staged_conversion.dart';
part 'asset_repository/asset_family.dart';
part 'asset_repository/import_pipeline.dart';
part 'asset_repository/thumbnails.dart';
part 'asset_repository/mesh_thumbnail_geometry.dart';

class RealAssetInfo {
  final String fileName;
  final String relativePath;
  final AssetType type;
  final int bytes;
  final Uint8List? thumbnailBytes;

  /// `metadata.thumbnail_source` of the `.lmas` (`filament`, `image`, `badge`;
  /// null for a thumbnail made before thumbnail sources were recorded, or none at all).
  final String? thumbnailSource;

  /// `metadata.thumbnail_asset_modified`: when the embedded thumbnail was
  /// made (the `.lmas` is current while it is not newer).
  final String? thumbnailAssetModified;
  final String? lmasPath;
  final String? assetId;
  final List<AssetReference> references;
  final DateTime? lastModified;

  const RealAssetInfo({
    required this.fileName,
    required this.relativePath,
    required this.type,
    required this.bytes,
    this.thumbnailBytes,
    this.thumbnailSource,
    this.thumbnailAssetModified,
    this.lmasPath,
    this.assetId,
    this.references = const [],
    this.lastModified,
  });

  String get formattedSize {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealAssetInfo &&
          runtimeType == other.runtimeType &&
          relativePath == other.relativePath;

  @override
  int get hashCode => relativePath.hashCode;
}

class AssetRepository extends _AssetRepositoryState
    with
        _AssetFileOperations,
        _AssetScanning,
        _AssetImportStaging,
        _AssetStagedConversion,
        _AssetFamilyEmission,
        _AssetImportPipeline,
        _AssetThumbnails {
  static final StreamController<void> _assetsChangedController =
      StreamController<void>.broadcast();

  /// Broadcast stream fired whenever assets are modified, saved, or retargeted on disk.
  static Stream<void> get onAssetsChanged => _assetsChangedController.stream;

  /// Notifies all listeners (such as the editor's Content Browser / EditorViewModel)
  /// that asset files on disk have changed and need to be re-scanned.
  static void notifyAssetsChanged() {
    if (!_assetsChangedController.isClosed) {
      _assetsChangedController.add(null);
    }
  }

  /// Sanitized-GLB memo, keyed by source file identity (path + mtime + length).
  ///
  /// `GlbParserService.convertGlbTgaToPng` enforces a texture budget, which means
  /// decoding and resizing every oversized source image — ~37 s for an asset carrying
  /// fourteen 8192x8192 PNGs. The editor loads the same mesh once per viewport (the
  /// main viewport and each open sub-editor each drive their own Filament engine), so
  /// without this memo that cost is paid again per viewport.
  ///
  /// Assets re-imported after this change are stored already-downscaled, so the
  /// sanitizer's cheap header peek short-circuits and the memo only matters for
  /// projects holding pre-existing oversized art.
  ///
  /// Behind the memo sits the project's persistent `DerivedDataCache/`:
  /// a memo miss for such art loads the budgeted GLB a
  /// previous session stored there instead of downscaling again.
  static final Map<String, Uint8List> _sanitizedGlbCache = <String, Uint8List>{};
  static int _sanitizedGlbCacheBytes = 0;
  static const int _sanitizedGlbCacheMaxBytes = 256 * 1024 * 1024;

  /// Sanitizations in progress, by memo key: two viewports loading the same
  /// mesh at once share one conversion instead of each paying for it.
  static final Map<String, Future<Uint8List>> _sanitizedGlbInFlight = <String, Future<Uint8List>>{};

  /// Clears the sanitized-GLB memo. Call after re-importing or editing assets on disk
  /// if the mtime is not expected to change. The persistent derived-data cache is
  /// content-addressed and needs no such call (`DerivedDataCache.clear` empties it).
  static void clearSanitizedGlbCache() {
    _sanitizedGlbCache.clear();
    _sanitizedGlbCacheBytes = 0;
  }

  /// The texture-budgeted, sanitized form of [payload], which was read from
  /// [source]: from the session memo, else the project's derived-data cache,
  /// else built by `GlbParserService.convertGlbTgaToPngAsync` (and stored).
  static Future<Uint8List> sanitizedGlbFor(
    File source,
    Uint8List payload, {
    List<String>? searchDirs,
    String tag = 'direct',
  }) =>
      _sanitizedGlbFor(source, tag, payload, searchDirs: searchDirs);

  static Future<Uint8List> _sanitizedGlbFor(
    File source,
    String tag,
    Uint8List payload, {
    List<String>? searchDirs,
  }) async {
    String? key;
    try {
      final stat = source.statSync();
      key = '${source.path}|$tag|${stat.modified.microsecondsSinceEpoch}|${stat.size}';
      final cached = _sanitizedGlbCache[key];
      if (cached != null) {
        // Refresh LRU position.
        _sanitizedGlbCache.remove(key);
        _sanitizedGlbCache[key] = cached;
        return cached;
      }
    } catch (_) {
      key = null; // Unstattable source: sanitize without memoizing.
    }
    final pending = key == null ? null : _sanitizedGlbInFlight[key];
    if (pending != null) return pending;

    final future = DerivedDataCache.sanitizeGlbForAsset(
      source.path,
      payload,
      searchDirs: searchDirs,
    );
    if (key != null) _sanitizedGlbInFlight[key] = future;
    final Uint8List sanitized;
    try {
      sanitized = await future;
    } finally {
      if (key != null) _sanitizedGlbInFlight.remove(key);
    }

    if (key != null && sanitized.length <= _sanitizedGlbCacheMaxBytes) {
      _sanitizedGlbCache[key] = sanitized;
      _sanitizedGlbCacheBytes += sanitized.length;
      while (_sanitizedGlbCacheBytes > _sanitizedGlbCacheMaxBytes &&
          _sanitizedGlbCache.isNotEmpty) {
        final oldest = _sanitizedGlbCache.keys.first;
        _sanitizedGlbCacheBytes -= _sanitizedGlbCache.remove(oldest)!.length;
      }
    }
    return sanitized;
  }

  static final Uint8List _fallbackPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAAAXNSR0IArs4c6QAAAARnQU1BAACx'
    'jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGQSURBVHhe7dKxDQAwDMSw3X/npg4BvYkCGchd'
    'n/OZ5wE8ePDgAYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMH'
    'Dx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48'
    'ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDg'
    'wYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMH'
    'Dx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48'
    'ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDg'
    'wYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDgwYMHDx48ePDg+bPvAwHwGg9iA8cAAAAASUVORK5C'
    'YII='
  );

  /// Centralized Universal 3D Mesh Loader:
  /// Reads any .lmas asset container, companion .entity.glb file, direct .glb/.gltf, or .obj file
  /// and returns a fully parsed [GlbMeshData] with geometry, bounds, subPrimitives, and material slots.
  static Future<GlbMeshData?> loadMeshFromDisk(String targetPath) async {
    try {
      final file = File(targetPath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      GlbMeshData? mesh;
      final parentDir = file.parent.path;
      final searchDirs = [
        parentDir,
        '$parentDir/../../textures',
        '$parentDir/../../textures/${file.uri.pathSegments.last.split(".").first}',
      ];

      // 1. Try parsing direct GLB / GLTF file
      if (targetPath.endsWith('.glb') || targetPath.endsWith('.gltf')) {
        final sanitized = await _sanitizedGlbFor(file, 'direct', bytes, searchDirs: searchDirs);
        mesh = await GlbParserService.parseGlb(sanitized);
        if (mesh != null) return mesh;
      }

      // 2. Check companion .entity.glb file if target is .lmas
      if (targetPath.endsWith('.lmas')) {
        final companionGlb = File(targetPath.replaceAll('.lmas', '.entity.glb'));
        if (companionGlb.existsSync()) {
          final sanitized = await _sanitizedGlbFor(
            companionGlb,
            'companion',
            companionGlb.readAsBytesSync(),
            searchDirs: searchDirs,
          );
          mesh = await GlbParserService.parseGlb(sanitized);
          if (mesh != null) return mesh;
        }
      }

      // 3. Try parsing LuminaAsset (.lmas) container bytes to extract embedded GLB rawPayload
      try {
        LuminaAsset? limAsset;
        try {
          limAsset = LuminaAsset.fromBytes(bytes);
        } catch (_) {
          final content = utf8.decode(bytes);
          final map = jsonDecode(content);
          if (map is Map) {
            limAsset = LuminaAsset.fromMap(Map<String, dynamic>.from(map));
          }
        }
        if (limAsset?.rawPayload != null && limAsset!.rawPayload!.isNotEmpty) {
          final type = limAsset.type;
          if (type != AssetType.filamesh &&
              type != AssetType.filameshSk &&
              type != AssetType.unknown) {
            return null;
          }
          final payload = limAsset.rawPayload!;
          final isGlb = payload.length >= 4 &&
              payload[0] == 0x67 &&
              payload[1] == 0x6C &&
              payload[2] == 0x54 &&
              payload[3] == 0x46;
          final isJsonGltf = payload.isNotEmpty && payload[0] == 0x7B;
          if (isGlb || isJsonGltf) {
            final sanitized =
                await _sanitizedGlbFor(file, 'lmas-payload', payload, searchDirs: searchDirs);
            mesh = await GlbParserService.parseGlb(sanitized);
            if (mesh != null) return mesh;
          }
          try {
            mesh = ObjParserService.parseObj(utf8.decode(payload));
            if (mesh != null) return mesh;
          } catch (_) {}
        }
        if (targetPath.endsWith('.lmas')) {
          return null; // .lmas container did not contain valid mesh payload; do not parse container as raw model
        }
      } catch (_) {}

      // 4. Fallback direct OBJ/GLB parse only for model extensions or glTF magic
      if (targetPath.endsWith('.glb') || targetPath.endsWith('.gltf') || (bytes.length >= 4 && bytes[0] == 0x67 && bytes[1] == 0x6C && bytes[2] == 0x54 && bytes[3] == 0x46)) {
        mesh = await GlbParserService.parseGlb(bytes);
        if (mesh != null) return mesh;
      }

      if (targetPath.endsWith('.obj')) {
        try {
          mesh = ObjParserService.parseObj(utf8.decode(bytes));
          if (mesh != null) return mesh;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// Throws a [FormatException] naming [file] when its GLB header promises
  /// more bytes than the file has, or a chunk runs past its end — a
  /// truncated download or copy. Without this such a file imported "fine"
  /// as an asset with a broken payload. Reads 20 bytes.
  static void checkGlbContainer(File file) {
    final name = file.uri.pathSegments.last;
    final length = file.lengthSync();
    if (length < 12) return; // not a container at all; later steps say so
    final raf = file.openSync();
    final Uint8List head;
    try {
      head = raf.readSync(length >= 20 ? 20 : 12);
    } finally {
      raf.closeSync();
    }
    final data = ByteData.sublistView(head);
    if (data.getUint32(0, Endian.little) != 0x46546C67) return; // no "glTF" magic: not ours to judge
    final declared = data.getUint32(8, Endian.little);
    if (declared > length) {
      throw FormatException('$name is truncated: its GLB header declares $declared bytes but the file has $length');
    }
    if (head.length >= 20) {
      final jsonLength = data.getUint32(12, Endian.little);
      if (20 + jsonLength > length) {
        throw FormatException('$name is truncated: its JSON chunk needs ${20 + jsonLength} bytes but the file has $length');
      }
    }
  }

  static String _generateUuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join('')}-${hex.sublist(4, 6).join('')}-${hex.sublist(6, 8).join('')}-${hex.sublist(8, 10).join('')}-${hex.sublist(10, 16).join('')}';
  }

  /// The detected kind [stageImport] reports, as an asset type.
  static AssetType assetTypeForDetectedKind(String detectedKind) => switch (detectedKind) {
        'static mesh' => AssetType.filamesh,
        'skeletal mesh' => AssetType.filameshSk,
        'animation' => AssetType.animation,
        'texture' => AssetType.texture,
        'audio' => AssetType.audio,
        'material' => AssetType.filamat,
        _ => AssetType.filamesh,
      };

  static void _deleteStaged(String stagedPath) {
    if (stagedPath.isEmpty) return;
    try {
      File(stagedPath).deleteSync();
    } catch (_) {}
    // The private staging folder [stageImport] made for a same-named file.
    final parent = File(stagedPath).parent;
    if (parent.uri.pathSegments.where((s) => s.isNotEmpty).last.startsWith('stage_')) {
      try {
        parent.deleteSync();
      } catch (_) {}
    }
  }

  static GlbMeshData? _cachedMaterialSphereMesh;
}

/// A thumbnail [AssetRepository.convertStagedAsset] left for the UI isolate
/// to draw (`renderThumbnails: false`): [type]'s thumbnail, drawn from the
/// converted payload when [fromPayload], with the payload's mesh already in
/// [geometry].
class PendingImportThumbnail {
  const PendingImportThumbnail({required this.type, required this.fromPayload, this.geometry});

  final AssetType type;
  final bool fromPayload;
  final MeshThumbnailGeometry? geometry;
}

/// An import staged, converted and routed ([AssetRepository.prepareImport])
/// but not yet written. Plain Dart data, so it crosses isolates.
class PreparedImport {
  const PreparedImport({
    required this.sourcePath,
    required this.stagedPath,
    required this.type,
    required this.baseName,
    required this.converted,
    required this.targetPaths,
  });

  final String sourcePath;
  final String stagedPath;
  final AssetType type;
  final String baseName;

  /// [AssetRepository.convertStagedAsset]'s result.
  final Map<String, dynamic> converted;

  /// Family key (`primary`, `M_…`, `T_…`, `A_…`) → project-relative `.lmas`.
  final Map<String, String> targetPaths;
}

/// The thumbnails of a [PreparedImport] still to draw
/// ([AssetRepository.thumbnailJobFor]).
class ImportThumbnailJob {
  const ImportThumbnailJob({this.primary, this.primaryImage, this.textureImages = const []});

  /// The primary asset's thumbnail, when pending.
  final PendingImportThumbnail? primary;

  /// The primary's image, when it is a texture (drawn scaled into the card).
  final Uint8List? primaryImage;

  /// Each extracted texture's image, in family order.
  final List<Uint8List> textureImages;
}

/// Thumbnails drawn for an [ImportThumbnailJob], in its order.
class ImportThumbnails {
  const ImportThumbnails({required this.hasPrimary, this.primary, this.textures = const []});

  final bool hasPrimary;
  final Uint8List? primary;
  final List<Uint8List?> textures;
}

/// What [AssetRepository.writeImport] wrote.
class ImportWriteResult {
  const ImportWriteResult({required this.info, required this.writtenPaths});

  /// The primary asset.
  final RealAssetInfo info;

  /// Every project-relative `.lmas` written, the primary included.
  final List<String> writtenPaths;
}

class _ThumbTri {
  final ui.Offset p0;
  final ui.Offset p1;
  final ui.Offset p2;
  final double depth;
  final double shade;
  final int i0;
  final int i1;
  final int i2;

  const _ThumbTri(this.p0, this.p1, this.p2, this.depth, this.shade, this.i0, this.i1, this.i2);
}
