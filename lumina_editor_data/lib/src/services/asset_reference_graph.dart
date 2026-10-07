import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/asset_repository.dart';

class ResolvedReference {
  final RealAssetInfo? asset;
  final String? resolvedPath;
  final bool broken;

  ResolvedReference({this.asset, this.resolvedPath, this.broken = false});
}

class AssetReferenceGraph {
  final Map<String, RealAssetInfo> _assetsById = {};
  final Map<String, RealAssetInfo> _assetsByPath = {};

  // Maps Asset ID to a List of Asset IDs that reference it
  final Map<String, List<String>> _referencers = {};

  void build(List<RealAssetInfo> assets) {
    _assetsById.clear();
    _assetsByPath.clear();
    _referencers.clear();

    for (final asset in assets) {
      if (asset.assetId != null && asset.assetId!.isNotEmpty) {
        _assetsById[asset.assetId!] = asset;
      }
      _assetsByPath[asset.relativePath] = asset;
    }

    for (final asset in assets) {
      if (asset.assetId == null || asset.assetId!.isEmpty) continue;
      _referencers[asset.assetId!] ??= [];

      for (final ref in asset.references) {
        _referencers[ref.assetId] ??= [];
        if (!_referencers[ref.assetId]!.contains(asset.assetId!)) {
          _referencers[ref.assetId]!.add(asset.assetId!);
        }
      }
    }
  }

  RealAssetInfo? getAsset(String assetId) => _assetsById[assetId];

  List<RealAssetInfo> dependenciesOf(String assetId) {
    final asset = _assetsById[assetId];
    if (asset == null) return [];

    final deps = <RealAssetInfo>[];
    for (final ref in asset.references) {
      final dep = _assetsById[ref.assetId];
      if (dep != null) deps.add(dep);
    }
    return deps;
  }

  List<RealAssetInfo> referencersOf(String assetId) {
    final referencerIds = _referencers[assetId] ?? [];
    return referencerIds
        .map((id) => _assetsById[id])
        .whereType<RealAssetInfo>()
        .toList();
  }

  Set<String> dependencyClosure(String assetId) {
    final visited = <String>{};
    final queue = <String>[assetId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      if (visited.contains(currentId)) continue;

      visited.add(currentId);
      final asset = _assetsById[currentId];
      if (asset != null) {
        for (final ref in asset.references) {
          queue.add(ref.assetId);
        }
      }
    }
    return visited;
  }

  ResolvedReference resolve(AssetReference ref) {
    // 1. Try by exact path
    final assetByPath = _assetsByPath[ref.assetPath];
    if (assetByPath != null && assetByPath.assetId == ref.assetId) {
      return ResolvedReference(asset: assetByPath, resolvedPath: ref.assetPath);
    }

    // 2. Try by exact ID
    final assetById = _assetsById[ref.assetId];
    if (assetById != null) {
      final correctPath = _assetsByPath.entries
          .where((e) => e.value.assetId == assetById.assetId)
          .firstOrNull
          ?.key;
      return ResolvedReference(asset: assetById, resolvedPath: correctPath);
    }

    // 3. Try by exact path (ID might be wrong)
    if (assetByPath != null) {
      return ResolvedReference(asset: assetByPath, resolvedPath: ref.assetPath);
    }

    return ResolvedReference(broken: true);
  }
}
