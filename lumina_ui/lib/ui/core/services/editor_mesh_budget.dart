import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

/// The editor's texture budget on every mesh the shared
/// engine loads by path — Blueprint previews, PIE, preview worlds — not only
/// on the level viewport's and sub-editors' payloads.
///
/// It routes lumina's `LuminaMeshAssetCache.sourceFilter` through
/// `AssetRepository.sanitizedGlbFor`, the same memo and derived-data cache
/// `AssetRepository.loadMeshFromDisk` uses, with the same memo tag. So an
/// 8K-textured `.entity.glb` left by an import from an older build is drawn
/// budgeted everywhere, and a preview world's path-based load gets the very
/// bytes the level viewport holds: one GPU upload for both.
abstract final class EditorMeshBudget {
  /// Installs the filter (idempotent). Called by the editor's viewports
  /// before they load anything.
  static void ensureInstalled() {
    if (!identical(LuminaMeshAssetCache.sourceFilter, _budgeted)) {
      LuminaMeshAssetCache.sourceFilter = _budgeted;
    }
  }

  /// Whether the editor's filter is the one installed.
  static bool get isInstalled => identical(LuminaMeshAssetCache.sourceFilter, _budgeted);

  static Future<Uint8List> _budgeted(String sourcePath, Uint8List bytes) {
    final file = File(sourcePath);
    if (!file.existsSync()) return Future.value(bytes);
    final lower = sourcePath.toLowerCase();
    // The tags `loadMeshFromDisk` memoizes under, so both paths share one
    // conversion: a companion GLB, an `.lmas` payload, a plain GLB.
    final tag = lower.endsWith('.entity.glb')
        ? 'companion'
        : lower.endsWith('.lmas')
            ? 'lmas-payload'
            : 'direct';
    final parent = file.parent.path;
    return AssetRepository.sanitizedGlbFor(
      file,
      bytes,
      tag: tag,
      searchDirs: [parent, '$parent/../../textures'],
    );
  }
}
