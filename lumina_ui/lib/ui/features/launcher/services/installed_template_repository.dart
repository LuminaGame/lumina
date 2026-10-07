import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart'
    show GameTemplateCheck, InstallKind, checkGameTemplate, kGameTemplatePubspecOverrides, kGameTemplateThumbnailNames;

import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_installer.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';

/// The `id` prefix of a folder template in the Create Project dialog; the
/// built-in templates use their bare catalog ids (`blank_3d`, …).
const String kInstalledTemplateIdPrefix = 'marketplace:';

/// A game template installed into `<config>/templates/<Folder>/`, usually from
/// the Lumina Marketplace.
///
/// The folder is a Lumina project tree in the game template archive format:
/// `template.json` and/or the source project's `.lmproject`, `contents/`,
/// optionally `lib/`, `pubspec.yaml` and a `thumbnail.png`, plus the
/// `LICENSE-<Listing>.txt` notice the installer wrote beside them.
class InstalledGameTemplate {
  const InstalledGameTemplate({
    required this.folderName,
    required this.dir,
    required this.title,
    required this.description,
    required this.engineVersion,
    this.thumbnailPath,
    this.lmprojectPath,
    this.record,
    this.declaredPublisher = '',
    this.declaredVersion = '',
  });

  /// The folder under `<config>/templates/`.
  final String folderName;

  /// The absolute template folder.
  final String dir;
  final String title;
  final String description;

  /// The engine version the template was made with (`template.json`
  /// `engine_version`, else the `.lmproject`'s), or ''.
  final String engineVersion;

  /// The screenshot shown on the template's card, or null.
  final String? thumbnailPath;

  /// The source project's manifest, or null for a template that ships only
  /// `template.json` and `contents/`.
  final String? lmprojectPath;

  /// The Marketplace install record (`<config>/marketplace/licenses.json`),
  /// or null for a folder that was copied in by hand.
  final MarketplaceInstallRecord? record;

  /// `template.json` `publisher` / `version`, for hand-copied templates.
  final String declaredPublisher;
  final String declaredVersion;

  /// What the Create Project dialog selects (`marketplace:<Folder>`).
  String get id => '$kInstalledTemplateIdPrefix$folderName';

  String get publisher => record?.publisherDisplayName.isNotEmpty ?? false ? record!.publisherDisplayName : declaredPublisher;
  String get version => record?.version.isNotEmpty ?? false ? record!.version : declaredVersion;

  /// The listing's licenses as SPDX ids (`CC-BY-4.0 + MIT`), or ''.
  String get licenseLabel => record == null ? '' : record!.licenses.map((l) => l.id).join(' + ');

  /// The `LICENSE-<Listing>.txt` notice the installer wrote, when it exists.
  File? get licenseNotice {
    final path = record?.licenseFile;
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }

  /// Only Marketplace installs are removed from the launcher (through
  /// [MarketplaceInstaller.uninstall]); a hand-copied folder is the user's.
  bool get canUninstall => record != null;
}

/// A template folder that was skipped, and why.
class InvalidTemplateFolder {
  const InvalidTemplateFolder(this.path, this.reason);
  final String path;
  final String reason;
}

/// Lists the game templates installed under `<config>/templates/`.
///
/// A folder is a template when it passes the shared game template check
/// (`checkGameTemplate` in lumina_marketplace_shared), the same
/// rules the Marketplace server applies to an upload: files under
/// `contents/`, a `template.json` with a title or exactly one `.lmproject`
/// that parses, an existing thumbnail when one is named, no platform or
/// build folders, and a pubspec whose path dependencies stay inside the
/// template. Anything else is left out of the list and reported once in the
/// Output Log with the check's reasons.
class InstalledTemplateRepository {
  InstalledTemplateRepository({required this.dirs, EngineLoggerService? logger}) : _logger = logger ?? EngineLoggerService();

  /// [MarketplaceInstallDirs.resolve] for [configDir] (null: the editor's
  /// config directory).
  factory InstalledTemplateRepository.forConfigDir(Directory? configDir) =>
      InstalledTemplateRepository(dirs: MarketplaceInstallDirs.resolve(configDir: configDir));

  final MarketplaceInstallDirs dirs;
  final EngineLoggerService _logger;
  final Set<String> _reported = {};

  static const List<String> thumbnailNames = kGameTemplateThumbnailNames;

  List<InvalidTemplateFolder> _invalid = const [];

  /// The folders the last [scan] skipped.
  List<InvalidTemplateFolder> get invalid => _invalid;

  /// The valid templates, sorted by title.
  List<InstalledGameTemplate> scan() {
    final root = Directory(dirs.templatesDir);
    if (!root.existsSync()) {
      _invalid = const [];
      return const [];
    }
    final records = {
      for (final r in MarketplaceLicenseRecords(File(dirs.editorLicensesFile)).read())
        if (r.installKind == InstallKind.gameTemplate) _normalize(r.installedTo): r,
    };
    final found = <InstalledGameTemplate>[];
    final invalid = <InvalidTemplateFolder>[];
    final folders = root.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final listed in folders) {
      // The last path segment: a Windows listing joins it with '\' to a
      // '/'-separated root, which `Directory.uri` does not split. The folder
      // is then addressed as `<root>/<name>`, so every path derived from it
      // (the template dir, its thumbnail, the skipped list) is '/'-joined.
      final name = listed.path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
      final folder = Directory('${root.path}/$name');
      // `.X.marketplace-previous` is a reinstall's backup, not a template.
      if (name.startsWith('.')) continue;
      final result = _read(folder, name, records[_normalize(folder.path)]);
      switch (result) {
        case InstalledGameTemplate t:
          found.add(t);
        case String reason:
          invalid.add(InvalidTemplateFolder(folder.path, reason));
          if (_reported.add('${folder.path}|$reason')) {
            _logger.log('Skipped the game template folder ${folder.path}: $reason', level: 'warning', source: 'Templates');
          }
      }
    }
    _invalid = invalid;
    found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return found;
  }

  InstalledGameTemplate? byId(String id) {
    for (final t in scan()) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Removes a Marketplace-installed [template] and its licenses.json entry.
  bool uninstall(InstalledGameTemplate template) {
    final record = template.record;
    if (record == null) return false;
    final installer = MarketplaceInstaller(
      dirs: dirs,
      openDownload: (_) => throw StateError('uninstalling downloads nothing'),
      serverUrl: Uri.tryParse(record.source) ?? Uri(),
    );
    final ok = installer.uninstall(record);
    _logger.log(
      ok ? 'Uninstalled the game template ${template.title} (${template.dir})' : 'Could not remove the game template ${template.title}',
      level: ok ? 'info' : 'error',
      source: 'Templates',
    );
    return ok;
  }

  /// [path] '/'-separated (a Windows listing uses '\', a licenses.json record
  /// '/') and without a trailing separator, so the two compare equal.
  static String _normalize(String path) {
    final slashed = path.replaceAll(r'\', '/');
    return slashed.endsWith('/') ? slashed.substring(0, slashed.length - 1) : slashed;
  }

  /// The template in [folder], or why it is not one.
  ///
  /// The folder is checked as an archive whose single top folder is [name],
  /// so its own root is always the template root.
  Object _read(Directory folder, String name, MarketplaceInstallRecord? record) {
    final root = folder.path;
    String? fileOf(String archivePath) =>
        archivePath.startsWith('$name/') ? '$root/${archivePath.substring(name.length + 1)}' : null;
    final GameTemplateCheck checked;
    try {
      // A local folder may carry its author's pubspec_overrides.yaml (the
      // Marketplace refuses one); the project creator never copies it, so it
      // does not make the template invalid here.
      final paths = [
        for (final e in folder.listSync(recursive: true, followLinks: false))
          if (e is File && e.uri.pathSegments.last != kGameTemplatePubspecOverrides)
            '$name/${e.path.substring(root.length + 1).replaceAll(Platform.pathSeparator, '/')}',
      ];
      checked = checkGameTemplate(paths, read: (p) {
        final path = fileOf(p);
        final f = path == null ? null : File(path);
        return f != null && f.existsSync() ? f.readAsBytesSync() : null;
      });
    } on FileSystemException catch (e) {
      return 'it could not be read (${e.message}${e.path == null ? '' : ': ${e.path}'})';
    }
    if (!checked.isValid) return checked.problems.map((p) => p.message).join('; ');

    final manifest = checked.manifest;
    final lmproject = checked.projectPath == null ? null : fileOf(checked.projectPath!);
    Map<String, Object?> project = const {};
    if (lmproject != null) {
      // The check parsed it already; read the fields the card shows.
      project = (jsonDecode(File(lmproject).readAsStringSync()) as Map).cast<String, Object?>();
    }
    final declared = manifest?.thumbnail;
    final thumbnail = declared != null
        ? '$root/$declared'
        : thumbnailNames.map((n) => '$root/$n').where((p) => File(p).existsSync()).firstOrNull;
    return InstalledGameTemplate(
      folderName: name,
      dir: root,
      title: manifest?.title ?? record?.title ?? project['project_name'] as String,
      description: manifest != null && manifest.description.isNotEmpty
          ? manifest.description
          : (project['description'] as String? ?? ''),
      engineVersion: manifest != null && manifest.engineVersion.isNotEmpty
          ? manifest.engineVersion
          : (project['engine_version'] as String? ?? ''),
      thumbnailPath: thumbnail,
      lmprojectPath: lmproject,
      record: record,
      declaredPublisher: manifest?.publisher ?? '',
      declaredVersion: manifest?.version ?? '',
    );
  }
}
