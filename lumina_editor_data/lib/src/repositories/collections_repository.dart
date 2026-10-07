import 'dart:convert';
import 'dart:io';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/asset_repository.dart';

class CollectionAsset {
  final String assetId;
  final String assetPath;

  CollectionAsset({required this.assetId, required this.assetPath});

  factory CollectionAsset.fromJson(Map<String, dynamic> json) {
    return CollectionAsset(
      assetId: json['asset_id'] as String,
      assetPath: json['asset_path'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset_id': assetId,
      'asset_path': assetPath,
    };
  }
}

class Collection {
  final String name;
  final List<CollectionAsset> assets;

  Collection({required this.name, required this.assets});

  factory Collection.fromJson(Map<String, dynamic> json) {
    final assetsList = (json['assets'] as List?)?.map((e) => CollectionAsset.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
    return Collection(
      name: json['name'] as String,
      assets: assetsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'assets': assets.map((a) => a.toJson()).toList(),
    };
  }
}

class CollectionsRepository {
  final EngineLoggerService _logger = EngineLoggerService();

  String _getCollectionsFilePath(String projectPath) {
    return '$projectPath/contents/.collections.json';
  }

  List<Collection> loadCollections(String projectPath) {
    final file = File(_getCollectionsFilePath(projectPath));
    if (!file.existsSync()) return [];

    try {
      final jsonStr = file.readAsStringSync();
      final map = jsonDecode(jsonStr);
      final collectionsList = (map['collections'] as List?)?.map((e) => Collection.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
      return collectionsList;
    } catch (e) {
      _logger.log('Error loading collections: $e', level: 'error', source: 'CollectionsRepository');
      return [];
    }
  }

  void saveCollections(String projectPath, List<Collection> collections) {
    final path = _getCollectionsFilePath(projectPath);
    final dir = Directory('$projectPath/contents');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    
    final tempPath = '$path.tmp';
    try {
      final data = {'collections': collections.map((c) => c.toJson()).toList()};
      File(tempPath).writeAsStringSync(jsonEncode(data));
      File(tempPath).renameSync(path);
    } catch (e) {
      _logger.log('Error saving collections: $e', level: 'error', source: 'CollectionsRepository');
    }
  }

  void healPaths(String projectPath, List<RealAssetInfo> currentAssets) {
    final collections = loadCollections(projectPath);
    bool changed = false;

    final idToPath = <String, String>{};
    for (final asset in currentAssets) {
      if (asset.assetId != null) {
        idToPath[asset.assetId!] = asset.relativePath;
      }
    }

    for (final col in collections) {
      for (int i = 0; i < col.assets.length; i++) {
        final a = col.assets[i];
        final currentPath = idToPath[a.assetId];
        if (currentPath != null && currentPath != a.assetPath) {
          col.assets[i] = CollectionAsset(assetId: a.assetId, assetPath: currentPath);
          changed = true;
        }
      }
    }

    if (changed) {
      saveCollections(projectPath, collections);
      _logger.log('Healed collection paths', level: 'info', source: 'CollectionsRepository');
    }
  }
}
