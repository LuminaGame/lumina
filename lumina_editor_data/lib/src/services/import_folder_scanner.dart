import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/repositories/asset_repository.dart';
import 'package:lumina_editor_data/src/services/import_queue.dart';

/// One primary file a folder import brings in, with the files that travel
/// with it.
class ImportFolderFile {
  const ImportFolderFile({
    required this.path,
    required this.relativePath,
    required this.kind,
    required this.bytes,
    this.companions = const [],
  });

  /// Absolute path.
  final String path;

  /// Path under the scanned folder, `/`-separated (`Props/Barrels/x.glb`).
  final String relativePath;
  final ImportFormatKind kind;

  /// Its size plus its companions'.
  final int bytes;

  /// A `.gltf`'s buffers and images, an OBJ's `.mtl` and its textures
  /// (absolute paths): grouped here, never imported on their own.
  final List<String> companions;

  /// The folder under the scanned root, '' at the root (`Props/Barrels`).
  String get relativeDir {
    final i = relativePath.lastIndexOf('/');
    return i < 0 ? '' : relativePath.substring(0, i);
  }

  String get fileName => relativePath.substring(relativePath.lastIndexOf('/') + 1);

  /// The file name without its extension: the imported asset's name.
  String get baseName {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }

  @override
  String toString() => 'ImportFolderFile($relativePath, ${kind.name}, companions: ${companions.length})';
}

/// A file a folder import leaves out, and why.
class SkippedImportFile {
  const SkippedImportFile({required this.path, required this.relativePath, required this.reason});
  final String path;
  final String relativePath;
  final String reason;

  @override
  String toString() => 'SkippedImportFile($relativePath: $reason)';
}

/// What [ImportFolderScanner.scan] found under [root].
class ImportFolderScan {
  const ImportFolderScan({
    required this.root,
    required this.files,
    required this.skipped,
    required this.ignored,
    required this.totalBytes,
  });

  final String root;

  /// Primary files, sorted by [ImportFolderFile.relativePath].
  final List<ImportFolderFile> files;

  /// Files that are not imported (unsupported, orphaned companions, links,
  /// a glTF missing a buffer), sorted by path.
  final List<SkippedImportFile> skipped;

  /// Hidden files and folders and OS junk (`.DS_Store`, `Thumbs.db`, …),
  /// left out silently.
  final int ignored;

  /// Bytes of every file that imports, companions included (each once).
  final int totalBytes;

  int get companionCount => files.fold(0, (n, f) => n + f.companions.length);

  /// How many primary files import as each kind.
  Map<ImportFormatKind, int> get countsByKind {
    final counts = <ImportFormatKind, int>{};
    for (final f in files) {
      counts[f.kind] = (counts[f.kind] ?? 0) + 1;
    }
    return counts;
  }

  /// The distinct folders (relative) the primary files sit in.
  Set<String> get folders => {for (final f in files) f.relativeDir};
}

/// Walks a folder for File → Import Asset Folder…:
/// every file the import pipeline takes ([ImportFormats]), recursively.
///
/// Hidden folders and files and OS junk are ignored; symbolic links are
/// not followed unless asked (and then each real folder is visited once);
/// a `.gltf`'s `.bin` and images and an OBJ's `.mtl` and textures are
/// grouped with it, so they import once, as part of it.
class ImportFolderScanner {
  const ImportFolderScanner._();

  /// File names (lower case) the walk ignores.
  static const Set<String> junkFileNames = {'.ds_store', 'thumbs.db', 'desktop.ini', 'ehthumbs.db', 'icon\r'};

  /// OBJ material-library statements whose last token is a texture file.
  static const Set<String> _mtlMapStatements = {
    'map_ka', 'map_kd', 'map_ks', 'map_ke', 'map_ns', 'map_d', 'map_bump', 'bump', 'disp', 'decal', 'norm', 'map_pr', 'map_pm',
  };

  /// [scan] in a background isolate, for a big tree.
  static Future<ImportFolderScan> scanInBackground(String root, {bool followLinks = false}) =>
      Isolate.run(() => scan(root, followLinks: followLinks));

  static ImportFolderScan scan(String root, {bool followLinks = false}) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) throw FileSystemException('The folder does not exist', root);
    final rootPath = p.normalize(rootDir.absolute.path);
    final found = <String>[];
    final skipped = <SkippedImportFile>[];
    var ignored = 0;
    final visited = <String>{};

    String rel(String path) => p.relative(path, from: rootPath).replaceAll(r'\', '/');

    void walk(Directory dir) {
      try {
        visited.add(dir.resolveSymbolicLinksSync());
      } catch (_) {}
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false)..sort((a, b) => a.path.compareTo(b.path));
      } on FileSystemException catch (e) {
        skipped.add(SkippedImportFile(path: dir.path, relativePath: rel(dir.path), reason: 'folder not readable: ${e.message}'));
        return;
      }
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name.startsWith('.') || junkFileNames.contains(name.toLowerCase())) {
          ignored++;
          continue;
        }
        if (entry is Link) {
          if (!followLinks) {
            skipped.add(SkippedImportFile(path: entry.path, relativePath: rel(entry.path), reason: 'symbolic link (not followed)'));
            continue;
          }
          final String target;
          try {
            target = entry.resolveSymbolicLinksSync();
          } catch (_) {
            skipped.add(SkippedImportFile(path: entry.path, relativePath: rel(entry.path), reason: 'broken symbolic link'));
            continue;
          }
          if (FileSystemEntity.isDirectorySync(target)) {
            if (!visited.contains(target)) walk(Directory(entry.path));
          } else {
            found.add(p.normalize(entry.path));
          }
        } else if (entry is Directory) {
          walk(entry);
        } else if (entry is File) {
          found.add(p.normalize(entry.path));
        }
      }
    }

    walk(Directory(rootPath));

    final present = found.toSet();
    // Companions: what each .gltf / .obj references, resolved beside it.
    final companionsOf = <String, List<String>>{};
    final missingOf = <String, String>{};
    for (final path in found) {
      final ext = ImportFormats.extensionOf(path);
      if (ext == 'gltf') {
        try {
          final refs = [for (final r in GltfPacker.referencedFiles(path)) p.normalize(r)];
          final missing = refs.where((r) => !File(r).existsSync()).toList();
          if (missing.isNotEmpty) {
            missingOf[path] = 'references ${p.basename(missing.first)}, which is missing';
          }
          companionsOf[path] = [for (final r in refs) if (present.contains(r)) r];
        } catch (e) {
          missingOf[path] = 'not a readable glTF document';
        }
      } else if (ext == 'obj') {
        companionsOf[path] = _objCompanions(path).where(present.contains).toList();
      }
    }
    final companionSet = {for (final list in companionsOf.values) ...list};

    final files = <ImportFolderFile>[];
    final counted = <String>{};
    var totalBytes = 0;
    int sizeOf(String path) {
      try {
        return File(path).lengthSync();
      } catch (_) {
        return 0;
      }
    }

    for (final path in found) {
      final relative = rel(path);
      final missing = missingOf[path];
      if (missing != null) {
        skipped.add(SkippedImportFile(path: path, relativePath: relative, reason: missing));
        continue;
      }
      final kind = ImportFormats.kindOf(path);
      final isCompanion = companionSet.contains(path);
      // A texture a glTF / material library uses imports with it, not alone.
      if (isCompanion && (kind == null || kind == ImportFormatKind.texture)) continue;
      if (kind == null) {
        final ext = ImportFormats.extensionOf(path);
        final reason = ext == 'bin'
            ? 'glTF buffer that no .gltf in this folder references'
            : ext == 'mtl'
                ? 'material library that no .obj in this folder references'
                : ImportFormats.unsupportedReason(path)!;
        skipped.add(SkippedImportFile(path: path, relativePath: relative, reason: reason));
        continue;
      }
      final companions = companionsOf[path] ?? const <String>[];
      var bytes = sizeOf(path);
      for (final c in companions) {
        bytes += sizeOf(c);
      }
      for (final f in [path, ...companions]) {
        if (counted.add(f)) totalBytes += sizeOf(f);
      }
      files.add(ImportFolderFile(path: path, relativePath: relative, kind: kind, bytes: bytes, companions: companions));
    }
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    skipped.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return ImportFolderScan(root: rootPath, files: files, skipped: skipped, ignored: ignored, totalBytes: totalBytes);
  }

  /// The `.mtl` files an OBJ names and the textures those name.
  static List<String> _objCompanions(String objPath) {
    final out = <String>[];
    final dir = p.dirname(objPath);
    List<String> lines(String path) {
      try {
        return File(path).readAsLinesSync();
      } catch (_) {
        return const [];
      }
    }

    for (final line in lines(objPath)) {
      final t = line.trim();
      if (!t.toLowerCase().startsWith('mtllib ')) continue;
      final mtl = p.normalize(p.join(dir, t.substring(7).trim().replaceAll(r'\', '/')));
      out.add(mtl);
      final mtlDir = p.dirname(mtl);
      for (final mline in lines(mtl)) {
        final parts = mline.trim().split(RegExp(r'\s+'));
        if (parts.length < 2 || !_mtlMapStatements.contains(parts.first.toLowerCase())) continue;
        out.add(p.normalize(p.join(mtlDir, parts.last.replaceAll(r'\', '/'))));
      }
    }
    return out;
  }
}

/// What to do when an imported asset's target already exists.
enum ImportConflictPolicy {
  /// Leave the existing asset; the file is not imported.
  skip,

  /// Re-import over it (it keeps its asset id, so references hold).
  overwrite,

  /// Import beside it as `<name>_1` (`_2`, …).
  rename,
}

/// The Import Asset Folder summary dialog's options.
class ImportFolderOptions {
  const ImportFolderOptions({
    this.targetFolder = 'contents',
    this.mirrorFolderStructure = true,
    this.conflictPolicy = ImportConflictPolicy.skip,
    this.autoOrganize = false,
    this.generateLods = false,
  });

  /// The Content Browser folder the tree lands in (`contents/Imported`).
  final String targetFolder;

  /// `Props/Barrels/x.glb` → `<target>/Props/Barrels/` instead of `<target>/`.
  final bool mirrorFolderStructure;
  final ImportConflictPolicy conflictPolicy;

  /// Sort by type into `contents/meshes/static/`, `contents/textures/`, …
  /// instead (target folder and mirroring then do not apply).
  final bool autoOrganize;
  final bool generateLods;

  ImportFolderOptions copyWith({
    String? targetFolder,
    bool? mirrorFolderStructure,
    ImportConflictPolicy? conflictPolicy,
    bool? autoOrganize,
    bool? generateLods,
  }) =>
      ImportFolderOptions(
        targetFolder: targetFolder ?? this.targetFolder,
        mirrorFolderStructure: mirrorFolderStructure ?? this.mirrorFolderStructure,
        conflictPolicy: conflictPolicy ?? this.conflictPolicy,
        autoOrganize: autoOrganize ?? this.autoOrganize,
        generateLods: generateLods ?? this.generateLods,
      );
}

/// One file of an [ImportFolderPlan].
class PlannedFolderImport {
  const PlannedFolderImport({required this.file, required this.request, required this.targetPath, this.conflicted = false});
  final ImportFolderFile file;
  final ImportRequest request;

  /// Where its primary `.lmas` lands (project-relative); with Auto Organize
  /// the type decides, so this is the likeliest folder.
  final String targetPath;

  /// Its target already existed (or another file of the batch takes it):
  /// it overwrites, or was renamed.
  final bool conflicted;
}

/// A scan turned into import requests under [ImportFolderOptions]: target
/// folders (mirrored or not) and the conflict policy applied.
class ImportFolderPlan {
  const ImportFolderPlan({required this.imports, required this.skippedExisting});

  final List<PlannedFolderImport> imports;

  /// Files left out because their asset exists (policy skip).
  final List<ImportFolderFile> skippedExisting;

  List<ImportRequest> get requests => [for (final i in imports) i.request];

  /// Files whose target exists, whatever the policy did with them.
  int get conflicts => skippedExisting.length + imports.where((i) => i.conflicted).length;

  /// The folder [file] imports into.
  static String folderFor(ImportFolderFile file, ImportFolderOptions options) {
    final target = normalizeFolder(options.targetFolder);
    if (!options.mirrorFolderStructure || file.relativeDir.isEmpty) return target;
    return '$target/${file.relativeDir}';
  }

  /// `contents/Imported/` → `contents/Imported` (and `\` → `/`).
  static String normalizeFolder(String folder) {
    var f = folder.trim().replaceAll(r'\', '/');
    while (f.endsWith('/')) {
      f = f.substring(0, f.length - 1);
    }
    return f.isEmpty ? 'contents' : f;
  }

  static ImportFolderPlan build(ImportFolderScan scan, {required String projectPath, required ImportFolderOptions options}) {
    final repo = AssetRepository();
    final claimed = <String>{};
    final imports = <PlannedFolderImport>[];
    final skippedExisting = <ImportFolderFile>[];

    for (final file in scan.files) {
      final folder = folderFor(file, options);
      final types = _candidateTypes(file);
      List<String> targets(String base) => {
            for (final t in types)
              repo
                  .resolveTargetPaths(
                    projectPath: projectPath,
                    baseName: base,
                    primaryType: t,
                    autoOrganize: options.autoOrganize,
                    browserSelectedFolder: folder,
                    extractedSubAssets: const [],
                  )['primary']!,
          }.toList();
      bool taken(String base) => targets(base).any((t) => claimed.contains(t) || File('$projectPath/$t').existsSync());

      var base = file.baseName;
      final conflicted = taken(base);
      if (conflicted) {
        switch (options.conflictPolicy) {
          case ImportConflictPolicy.skip:
            skippedExisting.add(file);
            continue;
          case ImportConflictPolicy.overwrite:
            break;
          case ImportConflictPolicy.rename:
            var n = 1;
            while (taken('${file.baseName}_$n')) {
              n++;
            }
            base = '${file.baseName}_$n';
        }
      }
      final paths = targets(base);
      claimed.addAll(paths);
      imports.add(PlannedFolderImport(
        file: file,
        targetPath: paths.first,
        conflicted: conflicted,
        request: ImportRequest(
          sourcePath: file.path,
          targetSubFolder: options.autoOrganize ? null : folder,
          autoOrganize: options.autoOrganize,
          generateLods: options.generateLods,
          targetBaseName: base == file.baseName ? null : base,
        ),
      ));
    }
    return ImportFolderPlan(imports: imports, skippedExisting: skippedExisting);
  }

  /// The asset types [file] may import as (a GLB is a static or skeletal
  /// mesh, or an animation, which only its contents tell).
  static List<AssetType> _candidateTypes(ImportFolderFile file) {
    switch (file.kind) {
      case ImportFormatKind.mesh:
        return const [AssetType.filamesh, AssetType.filameshSk, AssetType.animation];
      case ImportFormatKind.texture:
        return const [AssetType.texture];
      case ImportFormatKind.audio:
        return const [AssetType.audio];
      case ImportFormatKind.asset:
        try {
          return [LuminaAsset.readSummary(File(file.path)).type];
        } catch (_) {
          return const [AssetType.unknown];
        }
    }
  }
}
