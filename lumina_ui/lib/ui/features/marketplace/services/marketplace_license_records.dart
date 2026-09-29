import 'dart:convert';
import 'dart:io';

import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

/// One installed Marketplace listing version, as `licenses.json` records it:
/// what was installed, where, and under which licenses (so attribution
/// licences such as CC-BY are honoured and an uninstall knows what to remove).
class MarketplaceInstallRecord {
  const MarketplaceInstallRecord({
    required this.listingId,
    required this.slug,
    required this.title,
    required this.version,
    required this.category,
    required this.installKind,
    required this.publisherUsername,
    required this.publisherDisplayName,
    required this.installedTo,
    required this.licenseFile,
    required this.licenses,
    required this.installedAt,
    required this.source,
    this.files = const [],
  });

  final String listingId;
  final String slug;
  final String title;
  final String version;
  final ListingCategory category;
  final InstallKind installKind;
  final String publisherUsername;
  final String publisherDisplayName;

  /// The install folder (or theme file): project-relative for
  /// [InstallKind.projectContents] (`contents/Marketplace/lumina/Barrel`),
  /// absolute for the editor-wide kinds (plugins, themes, templates).
  final String installedTo;

  /// The `LICENSE-<listing>.txt` notice, in the same form as [installedTo].
  final String licenseFile;
  final List<LicenseInfo> licenses;
  final DateTime installedAt;

  /// The listing page on the server it came from.
  final String source;

  /// The installed files, in the same form as [installedTo] (a theme's one
  /// file; the `.lmas` assets an import wrote are listed as they land).
  final List<String> files;

  bool get attributionRequired => licenses.any((l) => l.attributionRequired);

  Map<String, Object?> toJson() => {
        'listingId': listingId,
        'slug': slug,
        'title': title,
        'version': version,
        'category': category.wire,
        'installKind': installKind.wire,
        'publisher': {'username': publisherUsername, 'displayName': publisherDisplayName},
        'installedTo': installedTo,
        'licenseFile': licenseFile,
        'licenses': [for (final l in licenses) l.toJson()],
        'attributionRequired': attributionRequired,
        'installedAt': installedAt.toUtc().toIso8601String(),
        'source': source,
        'files': files,
      };

  factory MarketplaceInstallRecord.fromJson(Map<String, Object?> j) {
    final publisher = (j['publisher'] as Map?)?.cast<String, Object?>() ?? const {};
    return MarketplaceInstallRecord(
      listingId: j['listingId'] as String,
      slug: j['slug'] as String? ?? '',
      title: j['title'] as String? ?? '',
      version: j['version'] as String? ?? '',
      category: ListingCategory.tryParse(j['category'] as String?) ?? ListingCategory.model,
      installKind: InstallKind.tryParse(j['installKind'] as String?) ?? InstallKind.projectContents,
      publisherUsername: publisher['username'] as String? ?? '',
      publisherDisplayName: publisher['displayName'] as String? ?? '',
      installedTo: j['installedTo'] as String,
      licenseFile: j['licenseFile'] as String? ?? '',
      licenses: [
        for (final l in (j['licenses'] as List?) ?? const [])
          LicenseInfo.fromJson((l as Map).cast<String, Object?>()),
      ],
      installedAt: DateTime.tryParse(j['installedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: j['source'] as String? ?? '',
      files: [for (final f in (j['files'] as List?) ?? const []) f as String],
    );
  }
}

/// A `licenses.json` file: the project's `contents/Marketplace/licenses.json`
/// for assets, the editor config's `marketplace/licenses.json` for plugins,
/// themes and game templates. One entry per listing (a reinstall replaces
/// it).
class MarketplaceLicenseRecords {
  MarketplaceLicenseRecords(this.file);

  final File file;

  static const int formatVersion = 1;

  List<MarketplaceInstallRecord> read() {
    if (!file.existsSync()) return const [];
    try {
      final j = jsonDecode(file.readAsStringSync());
      if (j is! Map) return const [];
      return [
        for (final e in (j['entries'] as List?) ?? const [])
          if (e is Map) MarketplaceInstallRecord.fromJson(e.cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  MarketplaceInstallRecord? byListing(String listingId) {
    for (final r in read()) {
      if (r.listingId == listingId) return r;
    }
    return null;
  }

  void upsert(MarketplaceInstallRecord record) =>
      _write([for (final r in read()) if (r.listingId != record.listingId) r, record]);

  void remove(String listingId) => _write([for (final r in read()) if (r.listingId != listingId) r]);

  void _write(List<MarketplaceInstallRecord> entries) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'formatVersion': formatVersion,
      'note': 'Written by Lumina Studio: every Marketplace install and the licenses it came with.',
      'entries': [for (final e in entries) e.toJson()],
    }));
    tmp.renameSync(file.path);
  }
}

/// The text of `LICENSE-<listing>.txt`: what the listing is, who published
/// it, where it came from, and each license with its canonical text URL and
/// what it asks of the user.
String marketplaceLicenseNotice(InstallManifest manifest, {required String source, DateTime? installedAt}) {
  final b = StringBuffer()
    ..writeln('${manifest.title} ${manifest.version}')
    ..writeln('Publisher: ${manifest.publisher.displayName} (@${manifest.publisher.username})')
    ..writeln('Source: $source')
    ..writeln('Installed by Lumina Studio from the Lumina Marketplace on '
        '${(installedAt ?? DateTime.now()).toUtc().toIso8601String().split('T').first}.')
    ..writeln();
  for (final l in manifest.licenses) {
    b
      ..writeln('${l.kind.label} license: ${l.name} (${l.id})')
      ..writeln('  Text: ${l.url}')
      ..writeln('  SPDX: ${l.spdxUrl}')
      ..writeln('  ${l.summary}');
    if (l.attributionRequired) {
      b.writeln('  Attribution required: credit "${manifest.publisher.displayName}" and link the source above '
          'wherever you use or redistribute this work.');
    }
    if (l.shareAlike) b.writeln('  Share-alike: adaptations must be released under the same license.');
    b.writeln();
  }
  return b.toString();
}
