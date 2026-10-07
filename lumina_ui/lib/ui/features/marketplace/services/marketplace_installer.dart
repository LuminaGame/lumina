import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:lumina_editor_data/lumina_editor.dart'
    show ImportConflictPolicy, ImportFolderOptions, ImportFolderPlan, ImportFolderScanner, ImportProgress, ImportRequest, ImportStage;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/core/services/folder_install.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';

/// Runs import requests on the editor's background import queue
/// and completes with each file's final state.
typedef MarketplaceImportRunner = Future<List<ImportProgress>> Function(List<ImportRequest> requests);

/// Opens a manifest URL as a streamed response (`MarketplaceClient.openDownload`).
typedef MarketplaceDownloadOpener = Future<http.StreamedResponse> Function(String url);

/// Why an install stopped. Nothing is left in the destination when one is
/// thrown: the download lives in a staging directory until it is verified,
/// and a failed import removes what it wrote (restoring a previous install).
class MarketplaceInstallException implements Exception {
  const MarketplaceInstallException(this.code, this.message);

  /// `cancelled`, `unsafe_manifest`, `checksum_mismatch`, `invalid_archive`,
  /// `import_failed`, `not_a_plugin`, `invalid_theme`, `no_project`.
  final String code;
  final String message;

  bool get cancelled => code == 'cancelled';

  @override
  String toString() => 'MarketplaceInstallException($code): $message';
}

/// Cancels a running install (the download stops at the next chunk).
class MarketplaceCancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void _onCancel(void Function() listener) => _listeners.add(listener);
  void _off(void Function() listener) => _listeners.remove(listener);
}

enum MarketplaceInstallPhase { downloading, verifying, importing, installing, done }

class MarketplaceInstallProgress {
  const MarketplaceInstallProgress(this.phase, {this.received = 0, this.total = 0, this.message = ''});

  final MarketplaceInstallPhase phase;
  final int received;
  final int total;
  final String message;

  /// 0–1 over the whole install: the download is the first 80 %.
  double get fraction => switch (phase) {
        MarketplaceInstallPhase.downloading => total <= 0 ? 0 : 0.8 * (received / total).clamp(0.0, 1.0),
        MarketplaceInstallPhase.verifying => 0.82,
        MarketplaceInstallPhase.importing => 0.85,
        MarketplaceInstallPhase.installing => 0.95,
        MarketplaceInstallPhase.done => 1,
      };
}

/// Installs Marketplace listing versions, per category:
///
/// * assets (`project_contents`) into the open project under
///   `contents/Marketplace/<Publisher>/<Listing>/` (or a Content Browser
///   folder the user dropped the listing on) — raw model, texture and audio
///   files through the background import queue, `.lmas` and other files
///   copied as they are;
/// * plugins into the user plugin directory (`<package>/`), where the Plugin
///   Manager lists them;
/// * themes into the editor themes directory (`<name>.json`);
/// * game templates into the editor templates directory (`<Listing>/`).
///
/// Every install is transactional: the archive is downloaded into a staging
/// directory, its sha256 and every file's sha256 checked against the
/// manifest, every target checked with [isSafeRelativePath] and against the
/// category's root, and only then moved into place. Each install writes a
/// `LICENSE-<listing>.txt` notice next to what it installed and an entry in
/// the matching `licenses.json`.
class MarketplaceInstaller {
  MarketplaceInstaller({
    required this.dirs,
    required this.openDownload,
    required this.serverUrl,
    this.importRunner,
    Directory? stagingRoot,
  }) : stagingRoot = stagingRoot ?? Directory.systemTemp;

  final MarketplaceInstallDirs dirs;
  final MarketplaceDownloadOpener openDownload;
  final MarketplaceImportRunner? importRunner;

  /// The server root, for the `source` of license records.
  final Uri serverUrl;

  /// Where downloads are staged (a `lumina_marketplace_*` directory per
  /// install, removed afterwards).
  final Directory stagingRoot;

  static const Set<String> _neverImported = {'lmas', 'md', 'txt', 'json', 'yaml', 'yml', 'csv'};

  /// The listing's page on the server, recorded as the license source.
  String sourceFor(InstallManifest m) => serverUrl.resolve('listings/${m.slug}').toString();

  /// The records of everything installed into the open project and into the
  /// editor (plugins, themes, templates). A project's `licenses.json` also
  /// keeps the notice of the game template it was created from; that entry is attribution, not an install of this
  /// project, so only its asset entries count here.
  List<MarketplaceInstallRecord> installed() => [
        if (dirs.projectRoot != null)
          ...MarketplaceLicenseRecords(File(dirs.projectLicensesFile!))
              .read()
              .where((r) => r.installKind == InstallKind.projectContents),
        ...MarketplaceLicenseRecords(File(dirs.editorLicensesFile)).read(),
      ];

  MarketplaceInstallRecord? installedRecord(String listingId) {
    for (final r in installed()) {
      if (r.listingId == listingId) return r;
    }
    return null;
  }

  /// Checks [m] before anything is downloaded: a known format, a safe
  /// folder name, and every target a safe relative path under the root its
  /// install kind allows. Throws `unsafe_manifest` otherwise.
  static void validateManifest(InstallManifest m) {
    void refuse(String why) => throw MarketplaceInstallException('unsafe_manifest', 'Refused ${m.title}: $why');
    if (m.formatVersion != 1) refuse('unknown manifest format ${m.formatVersion}');
    if (m.folderName.isEmpty || installFolderName(m.folderName) != m.folderName) {
      refuse('"${m.folderName}" is not a safe folder name');
    }
    final root = m.targetRoot;
    if (!root.endsWith('/') || !isSafeRelativePath(root.substring(0, root.length - 1))) {
      refuse('the target root "$root" is not a safe relative path');
    }
    final expected = MarketplaceInstallDirs.manifestRootPrefix(m.installKind);
    if (!root.startsWith(expected)) refuse('a ${m.installKind.wire} listing must install under $expected, not $root');
    if (m.files.isEmpty) refuse('it has no files');
    final seen = <String>{};
    for (final f in m.files) {
      if (!isSafeRelativePath(f.path)) refuse('the archive path "${f.path}" is not safe');
      if (!isSafeRelativePath(f.target)) refuse('the target "${f.target}" escapes its folder');
      if (!f.target.startsWith(root) || f.target.length == root.length) refuse('the target "${f.target}" is outside $root');
      if (!seen.add(f.target.toLowerCase())) refuse('two files target "${f.target}"');
    }
    if (m.installKind == InstallKind.theme && m.files.length != 1) refuse('a theme is one .json file');
  }

  /// Downloads, verifies and installs [m]. [projectFolder] (a Content
  /// Browser folder, `contents/...`) replaces the default
  /// `contents/Marketplace/<Publisher>/` parent of an asset listing: the
  /// listing lands in `<projectFolder>/<Listing>/`.
  Future<MarketplaceInstallRecord> install(
    InstallManifest m, {
    String? projectFolder,
    void Function(MarketplaceInstallProgress progress)? onProgress,
    MarketplaceCancelToken? cancel,
  }) async {
    validateManifest(m);
    if (m.installKind == InstallKind.projectContents && dirs.projectRoot == null) {
      throw const MarketplaceInstallException('no_project', 'Open a project to add assets to it.');
    }
    String? folder;
    if (projectFolder != null) {
      folder = ImportFolderPlan.normalizeFolder(projectFolder);
      if (m.installKind != InstallKind.projectContents) {
        throw MarketplaceInstallException('unsafe_manifest', '${m.title} is a ${m.category.label}, not project content.');
      }
      if (!isSafeRelativePath(folder) || (folder != 'contents' && !folder.startsWith('contents/'))) {
        throw MarketplaceInstallException('unsafe_manifest', '"$projectFolder" is not a Content Browser folder.');
      }
    }
    final staging = stagingRoot.createTempSync('lumina_marketplace_');
    try {
      final archive = await _download(m, staging, onProgress, cancel);
      _checkCancelled(cancel);
      onProgress?.call(const MarketplaceInstallProgress(MarketplaceInstallPhase.verifying, message: 'Verifying files'));
      final files = Directory('${staging.path}/files')..createSync();
      _extract(m, archive, files);
      _checkCancelled(cancel);
      final record = switch (m.installKind) {
        InstallKind.projectContents => await _installProjectContents(m, files, folder, onProgress),
        InstallKind.plugin => _installPlugin(m, files, onProgress),
        InstallKind.theme => _installTheme(m, files, onProgress),
        InstallKind.gameTemplate => _installTemplate(m, files, onProgress),
      };
      onProgress?.call(const MarketplaceInstallProgress(MarketplaceInstallPhase.done, message: 'Installed'));
      return record;
    } finally {
      try {
        staging.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Removes what [record] installed and its license entry.
  bool uninstall(MarketplaceInstallRecord record) => removeInstall(record)?.removed ?? false;

  /// [uninstall] with the details: a folder goes through
  /// [FolderInstall.remove] (set aside, then deleted; a link is removed as a
  /// link), a theme file is deleted with its notice. The license entry is
  /// removed once the install is gone; a removal that stopped keeps it.
  /// Null when [record] is project content and no project is open.
  FolderRemoval? removeInstall(MarketplaceInstallRecord record) {
    final project = record.installKind == InstallKind.projectContents;
    if (project && dirs.projectRoot == null) return null;
    final target = project ? '${dirs.projectRoot}/${record.installedTo}' : record.installedTo;
    final FolderRemoval removal;
    final type = FileSystemEntity.typeSync(target, followLinks: false);
    if (type == FileSystemEntityType.directory || type == FileSystemEntityType.link) {
      removal = FolderInstall.remove(Directory(target), tag: 'marketplace-removing');
    } else {
      try {
        if (type == FileSystemEntityType.file) File(target).deleteSync();
        if (record.installKind == InstallKind.theme) {
          final notice = File(record.licenseFile);
          if (notice.existsSync()) notice.deleteSync();
        }
        removal = FolderRemoval(path: target, removed: true);
      } on FileSystemException catch (e) {
        return FolderRemoval(path: target, removed: false, error: FolderInstall.describe(e));
      }
    }
    if (!removal.removed) return removal;
    MarketplaceLicenseRecords(File(project ? dirs.projectLicensesFile! : dirs.editorLicensesFile)).remove(record.listingId);
    return removal;
  }

  // --- Download and verification -------------------------------------------------

  static void _checkCancelled(MarketplaceCancelToken? cancel) {
    if (cancel?.isCancelled ?? false) throw const MarketplaceInstallException('cancelled', 'The download was cancelled.');
  }

  Future<File> _download(
    InstallManifest m,
    Directory staging,
    void Function(MarketplaceInstallProgress)? onProgress,
    MarketplaceCancelToken? cancel,
  ) async {
    _checkCancelled(cancel);
    final response = await openDownload(m.archiveUrl);
    final total = response.contentLength ?? m.archiveSize;
    final headerSha = response.headers['x-content-sha256'];
    final out = File('${staging.path}/archive.${m.installKind == InstallKind.theme ? 'json' : 'zip'}');
    final sink = out.openSync(mode: FileMode.write);
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var received = 0;
    final done = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    void onCancel() {
      if (done.isCompleted) return;
      unawaited(sub.cancel());
      done.completeError(const MarketplaceInstallException('cancelled', 'The download was cancelled.'));
    }

    sub = response.stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        sink.writeFromSync(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(MarketplaceInstallProgress(MarketplaceInstallPhase.downloading,
            received: received, total: total, message: 'Downloading ${m.title}'));
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    cancel?._onCancel(onCancel);
    try {
      await done.future;
    } finally {
      cancel?._off(onCancel);
      sink.closeSync();
    }
    hasher.close();
    final actual = digest.value.toString();
    if (actual != m.archiveSha256 || (headerSha != null && headerSha != actual) || received != m.archiveSize) {
      throw MarketplaceInstallException('checksum_mismatch',
          'The download of ${m.title} does not match its manifest (sha256 $actual, $received bytes).');
    }
    return out;
  }

  /// Unpacks [archive] into [into], each manifest file at its target relative
  /// to the manifest's target root, after checking that the archive holds
  /// exactly the manifest's files with their sha256.
  void _extract(InstallManifest m, File archive, Directory into) {
    final byPath = {for (final f in m.files) f.path: f};
    void place(String path, List<int> bytes) {
      final f = byPath.remove(path);
      if (f == null) throw MarketplaceInstallException('invalid_archive', '"$path" is not in the manifest.');
      if (sha256.convert(bytes).toString() != f.sha256 || bytes.length != f.size) {
        throw MarketplaceInstallException('checksum_mismatch', '"$path" does not match its manifest entry.');
      }
      final out = File('${into.path}/${f.target.substring(m.targetRoot.length)}');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes);
    }

    if (m.installKind == InstallKind.theme) {
      place(m.files.single.path, archive.readAsBytesSync());
    } else {
      final Archive zip;
      try {
        zip = ZipDecoder().decodeBytes(archive.readAsBytesSync(), verify: true);
      } catch (e) {
        throw MarketplaceInstallException('invalid_archive', 'The archive of ${m.title} is not a valid zip ($e).');
      }
      for (final entry in zip) {
        if (entry.isSymbolicLink) throw MarketplaceInstallException('invalid_archive', '"${entry.name}" is a symbolic link.');
        if (!entry.isFile) continue;
        if (!isSafeRelativePath(entry.name)) {
          throw MarketplaceInstallException('unsafe_manifest', 'The archive path "${entry.name}" is not safe.');
        }
        final bytes = entry.readBytes();
        if (bytes == null) throw MarketplaceInstallException('invalid_archive', '"${entry.name}" is unreadable.');
        place(entry.name, bytes);
      }
    }
    if (byPath.isNotEmpty) {
      throw MarketplaceInstallException('invalid_archive', 'The archive is missing ${byPath.keys.first}.');
    }
  }

  // --- Per category --------------------------------------------------------------

  Future<MarketplaceInstallRecord> _installProjectContents(
    InstallManifest m,
    Directory files,
    String? folder,
    void Function(MarketplaceInstallProgress)? onProgress,
  ) async {
    final project = dirs.projectRoot!;
    final destRel = folder == null ? m.targetRoot.substring(0, m.targetRoot.length - 1) : '$folder/${m.folderName}';
    final dest = Directory('$project/$destRel');
    final backup = FolderInstall.moveAside(dest, tag: 'marketplace-previous');
    try {
      dest.createSync(recursive: true);
      _markFolders(project, destRel);
      final scan = ImportFolderScanner.scan(files.path);
      final imported = <String>{
        for (final f in scan.files)
          if (!_neverImported.contains(f.fileName.split('.').last.toLowerCase())) ...[f.path, ...f.companions],
      };
      final plan = ImportFolderPlan.build(
        scan,
        projectPath: project,
        options: ImportFolderOptions(targetFolder: destRel, conflictPolicy: ImportConflictPolicy.overwrite),
      );
      final requests = [
        for (final i in plan.imports)
          if (imported.contains(i.file.path)) i.request,
      ];
      // `.lmas` assets and everything the pipeline does not take (read-mes,
      // license texts) are copied as they are.
      for (final f in files.listSync(recursive: true).whereType<File>()) {
        if (imported.contains(f.path)) continue;
        final rel = f.path.substring(files.path.length + 1);
        final out = File('${dest.path}/$rel');
        out.parent.createSync(recursive: true);
        f.copySync(out.path);
      }
      final landed = <String>[];
      if (requests.isNotEmpty) {
        final runner = importRunner;
        if (runner == null) throw const MarketplaceInstallException('no_project', 'No import queue is available.');
        onProgress?.call(MarketplaceInstallProgress(MarketplaceInstallPhase.importing,
            message: 'Importing ${requests.length} file(s) into $destRel'));
        final results = await runner(requests);
        final failed = [for (final r in results) if (r.stage != ImportStage.done) '${r.request.fileName}: ${r.error ?? r.stage.name}'];
        if (failed.isNotEmpty) {
          throw MarketplaceInstallException('import_failed', 'Import failed for ${failed.join('; ')}');
        }
        for (final r in results) {
          for (final a in r.assets) {
            landed.add(a.relativePath);
          }
        }
      }
      onProgress?.call(const MarketplaceInstallProgress(MarketplaceInstallPhase.installing, message: 'Writing the license notice'));
      final notice = '$destRel/LICENSE-${m.folderName}.txt';
      File('$project/$notice').writeAsStringSync(marketplaceLicenseNotice(m, source: sourceFor(m)));
      final copied = [
        for (final f in dest.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.lmas')) f.path.substring(project.length + 1),
      ];
      final record = _record(m, installedTo: destRel, licenseFile: notice, files: {...landed, ...copied}.toList()..sort());
      MarketplaceLicenseRecords(File(dirs.projectLicensesFile!)).upsert(record);
      FolderInstall.dropAside(backup);
      return record;
    } catch (_) {
      FolderInstall.restore(dest, backup);
      rethrow;
    }
  }

  MarketplaceInstallRecord _installPlugin(InstallManifest m, Directory files, void Function(MarketplaceInstallProgress)? onProgress) {
    final package = m.targetRoot.substring('plugins/'.length, m.targetRoot.length - 1);
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(package) || package.contains('/')) {
      throw MarketplaceInstallException('not_a_plugin', '"$package" is not a Dart package name.');
    }
    if (!File('${files.path}/$package.lmplugin').existsSync()) {
      throw MarketplaceInstallException('not_a_plugin', '${m.title} has no $package.lmplugin manifest at its top level.');
    }
    onProgress?.call(MarketplaceInstallProgress(MarketplaceInstallPhase.installing, message: 'Installing the $package plugin'));
    final dest = Directory('${dirs.pluginDir}/$package');
    return _placeFolder(m, files, dest);
  }

  MarketplaceInstallRecord _installTemplate(InstallManifest m, Directory files, void Function(MarketplaceInstallProgress)? onProgress) {
    final name = m.targetRoot.substring('templates/'.length, m.targetRoot.length - 1);
    onProgress?.call(MarketplaceInstallProgress(MarketplaceInstallPhase.installing, message: 'Installing the $name template'));
    return _placeFolder(m, files, Directory('${dirs.templatesDir}/$name'));
  }

  MarketplaceInstallRecord _placeFolder(InstallManifest m, Directory files, Directory dest) {
    final backup = FolderInstall.moveAside(dest, tag: 'marketplace-previous');
    try {
      FolderInstall.copyTree(files, dest);
      final notice = '${dest.path}/LICENSE-${m.folderName}.txt';
      File(notice).writeAsStringSync(marketplaceLicenseNotice(m, source: sourceFor(m)));
      final record = _record(m, installedTo: dest.path, licenseFile: notice, files: [
        for (final f in m.files) '${dest.path}/${f.target.substring(m.targetRoot.length)}',
      ]);
      MarketplaceLicenseRecords(File(dirs.editorLicensesFile)).upsert(record);
      FolderInstall.dropAside(backup);
      return record;
    } catch (_) {
      FolderInstall.restore(dest, backup);
      rethrow;
    }
  }

  MarketplaceInstallRecord _installTheme(InstallManifest m, Directory files, void Function(MarketplaceInstallProgress)? onProgress) {
    final rel = m.files.single.target.substring(m.targetRoot.length);
    final staged = File('${files.path}/$rel');
    try {
      final j = jsonDecode(staged.readAsStringSync());
      if (j is! Map || j['name'] is! String || j['colors'] is! Map) throw const FormatException('name and colors');
    } catch (e) {
      throw MarketplaceInstallException('invalid_theme', '${m.title} is not an editor theme ({name, colors, …}): $e');
    }
    onProgress?.call(MarketplaceInstallProgress(MarketplaceInstallPhase.installing, message: 'Installing the ${m.title} theme'));
    final dir = Directory(dirs.themesDir)..createSync(recursive: true);
    final dest = File('${dir.path}/$rel');
    final tmp = File('${dest.path}.tmp');
    staged.copySync(tmp.path);
    tmp.renameSync(dest.path);
    final notice = '${dir.path}/LICENSE-${m.folderName}.txt';
    File(notice).writeAsStringSync(marketplaceLicenseNotice(m, source: sourceFor(m)));
    final record = _record(m, installedTo: dest.path, licenseFile: notice, files: [dest.path]);
    MarketplaceLicenseRecords(File(dirs.editorLicensesFile)).upsert(record);
    return record;
  }

  // --- Helpers -----------------------------------------------------------------------

  MarketplaceInstallRecord _record(InstallManifest m,
          {required String installedTo, required String licenseFile, required List<String> files}) =>
      MarketplaceInstallRecord(
        listingId: m.listingId,
        slug: m.slug,
        title: m.title,
        version: m.version,
        category: m.category,
        installKind: m.installKind,
        publisherUsername: m.publisher.username,
        publisherDisplayName: m.publisher.displayName,
        installedTo: installedTo,
        licenseFile: licenseFile,
        licenses: m.licenses,
        installedAt: DateTime.now().toUtc(),
        source: sourceFor(m),
        files: files,
      );

  /// Every folder from `contents/` down to [rel] gets a Content Browser
  /// folder marker, so the empty tree shows before the imports land.
  static void _markFolders(String project, String rel) {
    var path = '';
    for (final segment in rel.split('/')) {
      path = path.isEmpty ? segment : '$path/$segment';
      if (path == 'contents') continue;
      final dir = Directory('$project/$path');
      if (dir.existsSync()) ContentFolders.writeMarker(dir.path);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
