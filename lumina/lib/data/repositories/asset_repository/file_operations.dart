part of '../asset_repository.dart';

/// Rename, move and duplicate assets with their companion files, size info
/// and healing the assets that reference a moved one.
mixin _AssetFileOperations on _AssetRepositoryState {

  void renameAsset(String projectPath, String lmasPath, String newName, AssetReferenceGraph graph) {
    final file = File(lmasPath);
    if (!file.existsSync()) return;

    final dir = file.parent.path;
    final newLmasPath = '$dir/$newName.lmas';

    if (File(newLmasPath).existsSync()) {
      throw Exception('Asset already exists at $newLmasPath');
    }

    final bytes = file.readAsBytesSync();
    final asset = LuminaAsset.fromBytes(bytes);

    final newAsset = LuminaAsset(
      assetId: asset.assetId,
      name: newName,
      type: asset.type,
      hasThumbnail: asset.hasThumbnail,
      thumbnailPng: asset.thumbnailPng,
      rawPayload: asset.rawPayload,
      rawMatSource: asset.rawMatSource,
      references: asset.references,
      metadata: asset.metadata,
    );

    File(newLmasPath).writeAsBytesSync(newAsset.toProtoBufferBytes());
    _renameCompanions(lmasPath, newLmasPath);
    file.deleteSync();

    _healReferencers(projectPath, asset.assetId, newLmasPath, graph);
  }

  void moveAsset(String projectPath, String lmasPath, String targetFolder, AssetReferenceGraph graph) {
    final file = File(lmasPath);
    if (!file.existsSync()) return;

    final basename = file.uri.pathSegments.last;
    final newLmasPath = '$targetFolder/$basename';

    if (File(newLmasPath).existsSync()) {
      throw Exception('Asset already exists at $newLmasPath');
    }
    
    Directory(targetFolder).createSync(recursive: true);
    final bytes = file.readAsBytesSync();
    File(newLmasPath).writeAsBytesSync(bytes);
    
    _renameCompanions(lmasPath, newLmasPath);
    file.deleteSync();
    
    final asset = LuminaAsset.fromBytes(bytes);
    _healReferencers(projectPath, asset.assetId, newLmasPath, graph);
  }

  void duplicateAsset(String lmasPath) {
    final file = File(lmasPath);
    if (!file.existsSync()) return;
    
    final bytes = file.readAsBytesSync();
    final asset = LuminaAsset.fromBytes(bytes);
    
    final dir = file.parent.path;
    final basename = file.uri.pathSegments.last;
    final nameWithoutExt = basename.replaceAll(RegExp(r'\.lmas$'), '');
    
    String newName = '${nameWithoutExt}_1';
    String newPath = '$dir/$newName.lmas';
    int counter = 2;
    while (File(newPath).existsSync()) {
      newName = '${nameWithoutExt}_$counter';
      newPath = '$dir/$newName.lmas';
      counter++;
    }

    final newAsset = LuminaAsset(
      assetId: AssetRepository._generateUuidV4(),
      name: newName,
      type: asset.type,
      hasThumbnail: asset.hasThumbnail,
      thumbnailPng: asset.thumbnailPng,
      rawPayload: asset.rawPayload,
      rawMatSource: asset.rawMatSource,
      references: asset.references,
      metadata: asset.metadata,
    );

    File(newPath).writeAsBytesSync(newAsset.toProtoBufferBytes());
    _copyCompanions(lmasPath, newPath);
  }
  
  Map<String, int> sizeInfo(String projectPath, String lmasPath, AssetReferenceGraph graph) {
    final file = File(lmasPath);
    if (!file.existsSync()) return {'file': 0, 'payload': 0, 'thumbnail': 0, 'closure': 0};
    
    final bytes = file.readAsBytesSync();
    final asset = LuminaAsset.fromBytes(bytes);
    
    int fileSize = bytes.length;
    int payloadSize = asset.rawPayload?.length ?? 0;
    int thumbnailSize = asset.thumbnailPng?.length ?? 0;
    
    final closureIds = graph.dependencyClosure(asset.assetId);
    int closureSize = 0;
    for (final id in closureIds) {
      final dep = graph.getAsset(id);
      if (dep != null) {
        final f = File('$projectPath/${dep.relativePath}');
        if (f.existsSync()) {
          closureSize += f.lengthSync();
        }
      }
    }
    
    return {
      'file': fileSize,
      'payload': payloadSize,
      'thumbnail': thumbnailSize,
      'closure': closureSize,
    };
  }

  /// The files Migrate would copy: [lmasPath]'s dependency closure (every
  /// transitively referenced `.lmas`) and their `.entity.glb` companions,
  /// `contents/`-relative, each marked when it already exists in
  /// [targetProjectPath]. Throws [ArgumentError] when the target is not a
  /// project folder (no `.lmproject`) or is the source project.
  List<AssetMigrateEntry> migratePreview(
      String projectPath, String lmasPath, String targetProjectPath, AssetReferenceGraph graph) {
    _checkMigrateTarget(projectPath, targetProjectPath);
    final asset = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    final relatives = <String>{};
    for (final id in graph.dependencyClosure(asset.assetId)) {
      final dep = graph.getAsset(id);
      if (dep == null) continue;
      final rel = dep.relativePath.replaceAll(r'\', '/');
      relatives.add(rel);
      final companion = '${rel.substring(0, rel.length - '.lmas'.length)}.entity.glb';
      if (rel.endsWith('.lmas') && File('$projectPath/$companion').existsSync()) relatives.add(companion);
    }
    return [
      for (final rel in relatives.toList()..sort())
        if (File('$projectPath/$rel').existsSync())
          AssetMigrateEntry(
            relativePath: rel,
            bytes: File('$projectPath/$rel').lengthSync(),
            conflict: File('$targetProjectPath/$rel').existsSync(),
          ),
    ];
  }

  /// Copies [migratePreview]'s files into [targetProjectPath], keeping their
  /// relative paths (so asset ids and reference paths stay valid). A file that
  /// already exists there is skipped and reported as a conflict — Migrate
  /// never overwrites.
  List<AssetMigrateEntry> migrateAsset(
      String projectPath, String lmasPath, String targetProjectPath, AssetReferenceGraph graph) {
    return [
      for (final e in migratePreview(projectPath, lmasPath, targetProjectPath, graph))
        if (e.conflict)
          e
        else
          () {
            final dest = File('$targetProjectPath/${e.relativePath}');
            dest.parent.createSync(recursive: true);
            File('$projectPath/${e.relativePath}').copySync(dest.path);
            return AssetMigrateEntry(relativePath: e.relativePath, bytes: e.bytes, conflict: false, copied: true);
          }(),
    ];
  }

  void _checkMigrateTarget(String projectPath, String targetProjectPath) {
    final target = Directory(targetProjectPath);
    if (!target.existsSync() || !target.listSync().any((f) => f is File && f.path.endsWith('.lmproject'))) {
      throw ArgumentError('$targetProjectPath is not a Lumina project (no .lmproject file).');
    }
    String norm(String p) => Directory(p).absolute.path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '').toLowerCase();
    if (norm(projectPath) == norm(targetProjectPath)) {
      throw ArgumentError('The target is the same project as the source.');
    }
  }

  void _renameCompanions(String oldPath, String newPath) {
    final oldDir = File(oldPath).parent.path;
    final newDir = File(newPath).parent.path;
    final oldBase = File(oldPath).uri.pathSegments.last.replaceAll(RegExp(r'\.lmas$'), '');
    final newBase = File(newPath).uri.pathSegments.last.replaceAll(RegExp(r'\.lmas$'), '');

    final entityFile = File('$oldDir/$oldBase.entity.glb');
    if (entityFile.existsSync()) entityFile.renameSync('$newDir/$newBase.entity.glb');
    // Thumbnails live inside the `.lmas`: nothing else moves.
  }

  void _copyCompanions(String oldPath, String newPath) {
    final oldDir = File(oldPath).parent.path;
    final newDir = File(newPath).parent.path;
    final oldBase = File(oldPath).uri.pathSegments.last.replaceAll(RegExp(r'\.lmas$'), '');
    final newBase = File(newPath).uri.pathSegments.last.replaceAll(RegExp(r'\.lmas$'), '');

    final entityFile = File('$oldDir/$oldBase.entity.glb');
    if (entityFile.existsSync()) entityFile.copySync('$newDir/$newBase.entity.glb');
  }

  void _healReferencers(String projectPath, String targetAssetId, String newLmasPath, AssetReferenceGraph graph) {
    final referencers = graph.referencersOf(targetAssetId);
    // Relative path of the new target
    String relativeTarget = newLmasPath;
    if (relativeTarget.startsWith(projectPath)) {
      relativeTarget = relativeTarget.substring(projectPath.length);
      if (relativeTarget.startsWith('/')) relativeTarget = relativeTarget.substring(1);
    }

    for (final ref in referencers) {
      final referencerPath = ref.relativePath;
      final f = File('$projectPath/$referencerPath');
        if (f.existsSync()) {
          final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
          
          final newRefs = asset.references.map((r) {
            if (r.assetId == targetAssetId) {
              return AssetReference(slotName: r.slotName, assetId: r.assetId, assetPath: relativeTarget);
            }
            return r;
          }).toList();
          
          final healedAsset = LuminaAsset(
            assetId: asset.assetId,
            name: asset.name,
            type: asset.type,
            hasThumbnail: asset.hasThumbnail,
            thumbnailPng: asset.thumbnailPng,
            rawPayload: asset.rawPayload,
            rawMatSource: asset.rawMatSource,
            references: newRefs,
            metadata: asset.metadata,
          );
          
          f.writeAsBytesSync(healedAsset.toProtoBufferBytes());
        }
    }
  }
}

/// One file of a Migrate: its
/// `contents/`-relative path, size, whether the target already has it, and
/// whether this run copied it.
class AssetMigrateEntry {
  final String relativePath;
  final int bytes;
  final bool conflict;
  final bool copied;

  const AssetMigrateEntry({required this.relativePath, required this.bytes, required this.conflict, this.copied = false});

  @override
  String toString() => 'AssetMigrateEntry($relativePath, $bytes B${conflict ? ', conflict' : ''}${copied ? ', copied' : ''})';
}
