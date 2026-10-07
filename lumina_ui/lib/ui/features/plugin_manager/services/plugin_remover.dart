import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart' show InstallKind;
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/services/folder_install.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_installer.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';

/// Whose saved data a [PluginDataFolder] is.
enum PluginDataKind {
  /// `<data>/plugin_data/<name>/` ([PluginDataDir]), for every project.
  user,

  /// `<project>/.lumina/plugins/<name>/`, the open project's.
  project,
}

/// A plugin's saved-data folder that exists, with what it holds.
class PluginDataFolder {
  const PluginDataFolder({required this.kind, required this.dir, required this.fileCount, required this.bytes});

  final PluginDataKind kind;
  final Directory dir;
  final int fileCount;
  final int bytes;

  Map<String, Object?> toJson() => {'kind': kind.name, 'path': dir.path, 'file_count': fileCount, 'bytes': bytes};
}

/// Everything removing one plugin deletes or changes, worked out before
/// anything is deleted (the confirmation dialog and `remove_plugin`'s
/// `dry_run` list it).
class PluginRemovalPlan {
  const PluginRemovalPlan({
    required this.name,
    required this.displayName,
    required this.origin,
    required this.pluginDir,
    required this.linkTarget,
    required this.fileCount,
    required this.bytes,
    required this.enabled,
    required this.contentOnly,
    required this.dependents,
    required this.loaded,
    required this.marketplaceRecord,
    required this.revealedOrigin,
    required this.revealedDir,
    required this.data,
    required this.projectDir,
  });

  final String name;
  final String displayName;

  /// [PluginOrigin.user] (removed for every project on this machine) or
  /// [PluginOrigin.project] (this project's `plugins/`).
  final PluginOrigin origin;

  /// The plugin's folder in its scan root (the link itself for a linked
  /// install).
  final Directory pluginDir;

  /// Where a linked install (a symbolic link or a Windows junction) points;
  /// only the link is removed. Null for a real folder.
  final String? linkTarget;

  /// The files and bytes deleted with the folder (none for a link).
  final int fileCount;
  final int bytes;

  /// Enabled in the open project: removing disables it there.
  final bool enabled;
  final bool contentOnly;

  /// The enabled plugins that depend on it; they are disabled too.
  final List<String> dependents;

  /// Registered in this editor session: it stays active until a restart.
  final bool loaded;

  /// The Marketplace install record when the Marketplace installed it.
  final MarketplaceInstallRecord? marketplaceRecord;

  /// A plugin of the same name in a lower-priority root (a built-in, or a
  /// user plugin under a project one) that takes its place again.
  final PluginOrigin? revealedOrigin;
  final Directory? revealedDir;

  /// The saved-data folders that exist (deleted only on request).
  final List<PluginDataFolder> data;

  /// The open project.
  final String? projectDir;

  bool get linked => linkTarget != null;

  Map<String, Object?> toJson() => {
        'name': name,
        'friendly_name': displayName,
        'origin': origin.name,
        'plugin_dir': PluginRemover._trimmed(pluginDir.path),
        'linked_from': linkTarget,
        'file_count': fileCount,
        'bytes': bytes,
        'every_project': origin == PluginOrigin.user,
        'enabled': enabled,
        'also_disabled': dependents,
        'restart_required': enabled && !contentOnly,
        'loaded_until_restart': loaded,
        'marketplace': marketplaceRecord == null
            ? null
            : {
                'listing_id': marketplaceRecord!.listingId,
                'title': marketplaceRecord!.title,
                'version': marketplaceRecord!.version,
              },
        'comes_back': revealedDir == null ? null : {'origin': revealedOrigin!.name, 'plugin_dir': revealedDir!.path},
        'data': [for (final d in data) d.toJson()],
      };
}

/// What [PluginRemover.remove] did.
class PluginRemovalResult {
  const PluginRemovalResult({
    required this.removed,
    this.removedPaths = const [],
    this.notRemoved = const [],
    this.disabled = const [],
    this.restartRequired = false,
  });

  /// The plugin folder (or link) is gone from its scan root.
  final bool removed;

  /// What was deleted.
  final List<String> removedPaths;

  /// What was not deleted, each as `<path>: <reason>`.
  final List<String> notRemoved;

  /// The plugins disabled in the open project.
  final List<String> disabled;

  /// A code plugin was disabled: the project editor is rebuilt on restart.
  final bool restartRequired;

  PluginRemovalResult withProject({required List<String> disabled, required bool restartRequired}) => PluginRemovalResult(
        removed: removed,
        removedPaths: removedPaths,
        notRemoved: notRemoved,
        disabled: disabled,
        restartRequired: restartRequired,
      );

  Map<String, Object?> toJson() => {
        'removed': removed,
        'removed_paths': removedPaths,
        'not_removed': notRemoved,
        'disabled': disabled,
        'restart_required': restartRequired,
      };
}

/// Removes a user or project plugin from disk: [plan] lists what removing
/// it deletes, [remove] deletes it. A built-in is never removed.
///
/// The plugin folder goes through [FolderInstall.remove] (set aside, then
/// deleted; a link is removed as a link, never followed); a Marketplace
/// install goes through [MarketplaceInstaller.removeInstall], so its
/// `licenses.json` entry goes with it. Saved data is deleted only on
/// request, and only once the plugin itself is gone.
class PluginRemover {
  PluginRemover({Directory? pluginDataDir, this.marketplaceDirs}) : pluginDataDir = pluginDataDir ?? PluginDataDir.resolve();

  /// `<data>/plugin_data`, where each plugin keeps its per-user data.
  final Directory pluginDataDir;

  /// Where the Marketplace records its installs; null resolves the
  /// editor's ([MarketplaceInstallDirs.resolve]).
  final MarketplaceInstallDirs? marketplaceDirs;

  MarketplaceInstallDirs get _dirs => marketplaceDirs ?? MarketplaceInstallDirs.resolve();

  /// What removing [entry] deletes. [entries] are the registry's (for the
  /// dependents), [roots] its scan roots (for a plugin of the same name that
  /// comes back), [projectDir] the open project, [loaded] whether this editor
  /// session registered it. Throws [ArgumentError] for a built-in.
  PluginRemovalPlan plan(
    PluginEntry entry, {
    required List<PluginEntry> entries,
    required List<PluginScanRoot> roots,
    String? projectDir,
    bool loaded = false,
  }) {
    final d = entry.descriptor;
    if (d.origin == PluginOrigin.engine) {
      throw ArgumentError('${d.name} is a built-in plugin; it ships with the engine and cannot be removed.');
    }
    final dir = d.pluginDir;
    final linked = FileSystemEntity.isLinkSync(_trimmed(dir.path));
    String? target;
    if (linked) {
      try {
        target = Link(_trimmed(dir.path)).targetSync();
      } on FileSystemException {
        target = '(unreadable link)';
      }
    }
    final (files, bytes) = linked ? (0, 0) : _measure(dir);

    final revealed = _revealed(d, roots);
    return PluginRemovalPlan(
      name: d.name,
      displayName: d.friendlyName ?? d.name,
      origin: d.origin,
      pluginDir: dir,
      linkTarget: target,
      fileCount: files,
      bytes: bytes,
      enabled: entry.enabled,
      contentOnly: d.isContentOnly,
      dependents: [
        for (final e in entries)
          if (e.enabled && e.descriptor.name != d.name && e.descriptor.dependencies.any((dep) => dep.name == d.name)) e.descriptor.name,
      ]..sort(),
      loaded: loaded,
      marketplaceRecord: d.origin == PluginOrigin.user ? _marketplaceRecordFor(dir) : null,
      revealedOrigin: revealed?.$1,
      revealedDir: revealed?.$2,
      data: [
        ?_dataFolder(PluginDataKind.user, Directory(p.join(pluginDataDir.path, d.name))),
        if (projectDir != null) ?_dataFolder(PluginDataKind.project, Directory(p.join(projectDir, '.lumina', 'plugins', d.name))),
      ],
      projectDir: projectDir,
    );
  }

  /// Deletes what [plan] lists: the plugin folder (or link), then, with
  /// [deleteData], its saved-data folders. Changes nothing in the project
  /// (the view model disables it there).
  PluginRemovalResult remove(PluginRemovalPlan plan, {bool deleteData = false}) {
    final removedPaths = <String>[];
    final notRemoved = <String>[];
    final record = plan.marketplaceRecord;
    final FolderRemoval removal;
    if (record != null) {
      final installer = MarketplaceInstaller(
        dirs: _dirs,
        openDownload: (_) => throw StateError('removing a plugin downloads nothing'),
        serverUrl: Uri.tryParse(record.source) ?? Uri(),
      );
      removal = installer.removeInstall(record) ?? FolderRemoval(path: plan.pluginDir.path, removed: false, error: 'No project is open.');
    } else {
      removal = FolderInstall.remove(Directory(_trimmed(plan.pluginDir.path)));
    }
    if (!removal.removed) {
      notRemoved.add('${plan.pluginDir.path}: ${removal.error ?? 'not removed'}');
      return PluginRemovalResult(removed: false, notRemoved: notRemoved);
    }
    removedPaths.add(removal.link ? '${plan.pluginDir.path} (link)' : plan.pluginDir.path);
    for (final left in removal.leftovers) {
      notRemoved.add('$left: ${removal.error ?? 'could not be deleted'}');
    }
    if (deleteData) {
      for (final folder in plan.data) {
        final r = FolderInstall.remove(folder.dir);
        if (r.removed) removedPaths.add(folder.dir.path);
        if (!r.removed) notRemoved.add('${folder.dir.path}: ${r.error ?? 'not removed'}');
        for (final left in r.leftovers) {
          notRemoved.add('$left: ${r.error ?? 'could not be deleted'}');
        }
      }
    }
    return PluginRemovalResult(removed: true, removedPaths: removedPaths, notRemoved: notRemoved);
  }

  MarketplaceInstallRecord? _marketplaceRecordFor(Directory dir) {
    final MarketplaceInstallDirs dirs;
    try {
      dirs = _dirs;
    } catch (_) {
      return null;
    }
    final want = _key(dir.absolute.path);
    for (final r in MarketplaceLicenseRecords(File(dirs.editorLicensesFile)).read()) {
      if (r.installKind == InstallKind.plugin && _key(r.installedTo) == want) return r;
    }
    return null;
  }

  /// The plugin of the same name a lower-priority root holds.
  static (PluginOrigin, Directory)? _revealed(LuminaPluginDescriptor d, List<PluginScanRoot> roots) {
    final lower = switch (d.origin) {
      PluginOrigin.project => const [PluginOrigin.user, PluginOrigin.engine],
      PluginOrigin.user => const [PluginOrigin.engine],
      PluginOrigin.engine => const <PluginOrigin>[],
    };
    final self = _key(d.pluginDir.absolute.path);
    for (final origin in lower) {
      for (final root in roots.where((r) => r.origin == origin)) {
        for (final candidate in root.candidates()) {
          if (_key(candidate.absolute.path) == self) continue;
          if (File(p.join(candidate.path, '${d.name}.lmplugin')).existsSync()) return (origin, candidate);
        }
      }
    }
    return null;
  }

  static PluginDataFolder? _dataFolder(PluginDataKind kind, Directory dir) {
    if (FileSystemEntity.typeSync(dir.path, followLinks: false) == FileSystemEntityType.notFound) return null;
    final linked = FileSystemEntity.isLinkSync(dir.path);
    final (files, bytes) = linked ? (0, 0) : _measure(dir);
    return PluginDataFolder(kind: kind, dir: dir, fileCount: files, bytes: bytes);
  }

  /// The files under [dir] and their total size, links not followed.
  static (int, int) _measure(Directory dir) {
    var files = 0;
    var bytes = 0;
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          files++;
          try {
            bytes += e.lengthSync();
          } on FileSystemException catch (_) {}
        }
      }
    } on FileSystemException catch (_) {}
    return (files, bytes);
  }

  static String _trimmed(String path) =>
      path.length > 1 && (path.endsWith('/') || path.endsWith(r'\')) ? path.substring(0, path.length - 1) : path;

  /// [path] compared across `\` / `/`, a trailing separator and, on
  /// Windows, case.
  static String _key(String path) {
    final slashed = _trimmed(p.normalize(path).replaceAll(r'\', '/'));
    return Platform.isWindows ? slashed.toLowerCase() : slashed;
  }
}
