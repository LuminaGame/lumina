import 'dart:convert';
import 'dart:io';

import '../models/lumina_asset.dart';
import 'thumbnail_service.dart';

/// What [ThumbnailSidecarMigration.run] did to one project.
class ThumbnailSidecarMigrationReport {
  /// `.thumbnails/` directories deleted.
  final int removedDirectories;

  /// Sidecar PNGs deleted.
  final int removedSidecars;

  /// `.lmas` files that had no embedded thumbnail and got the sidecar's.
  final int reembedded;

  /// `.lmas` whose current thumbnail was re-stamped for the new staleness
  /// rule (its modification time set back to the thumbnail stamp).
  final int restamped;

  /// Whether `contents/.thumbnails/cover.png` moved to `.lumina/cover.png`.
  final bool coverMoved;

  /// Rules appended to the project's `.gitignore`.
  final List<String> gitignoreRules;

  final Duration elapsed;

  const ThumbnailSidecarMigrationReport({
    this.removedDirectories = 0,
    this.removedSidecars = 0,
    this.reembedded = 0,
    this.restamped = 0,
    this.coverMoved = false,
    this.gitignoreRules = const [],
    this.elapsed = Duration.zero,
  });

  bool get didAnything => removedDirectories > 0 || coverMoved || gitignoreRules.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'dirs': removedDirectories,
        'sidecars': removedSidecars,
        'reembedded': reembedded,
        'restamped': restamped,
        'cover': coverMoved,
        'gitignore': gitignoreRules,
        'ms': elapsed.inMilliseconds,
      };

  factory ThumbnailSidecarMigrationReport.fromJson(Map<String, dynamic> json) => ThumbnailSidecarMigrationReport(
        removedDirectories: json['dirs'] as int? ?? 0,
        removedSidecars: json['sidecars'] as int? ?? 0,
        reembedded: json['reembedded'] as int? ?? 0,
        restamped: json['restamped'] as int? ?? 0,
        coverMoved: json['cover'] == true,
        gitignoreRules: [for (final r in (json['gitignore'] as List? ?? const [])) r.toString()],
        elapsed: Duration(milliseconds: json['ms'] as int? ?? 0),
      );

  @override
  String toString() =>
      'removed $removedSidecars sidecar(s) in $removedDirectories .thumbnails/ folder(s), re-embedded $reembedded, '
      're-stamped $restamped${coverMoved ? ', moved the cover to .lumina/cover.png' : ''}'
      '${gitignoreRules.isEmpty ? '' : ', .gitignore += ${gitignoreRules.join(' ')}'}';
}

/// The one-time move away from `.thumbnails/` sidecar files.
///
/// Every `contents/**/.thumbnails/<name>.png` is checked against its
/// `<name>.lmas`: an asset with no embedded thumbnail gets the sidecar's
/// (re-embedded), an asset whose thumbnail was current under the old rule
/// (sidecar not older than the `.lmas` nor its `.entity.glb`) is re-stamped
/// so it stays current under the new one ([ThumbnailService.staleFor]), and
/// then the sidecars and their folders are deleted.
/// `contents/.thumbnails/cover.png` moves to `.lumina/cover.png`. An existing
/// `.gitignore` gains `.lumina/` and `**/.thumbnails/` when it lacks them.
/// Idempotent: a migrated project has nothing left to do.
class ThumbnailSidecarMigration {
  static const String sidecarDirectoryName = '.thumbnails';
  static const String legacyCoverPath = 'contents/.thumbnails/cover.png';
  static const String coverPath = '.lumina/cover.png';
  static const List<String> gitignoreRules = ['.lumina/', '**/.thumbnails/'];

  /// Every `.thumbnails/` folder under `<projectDir>/contents`.
  static List<Directory> sidecarDirectories(String projectDir) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return const [];
    return [
      for (final e in contents.listSync(recursive: true, followLinks: false))
        // A Windows listing joins with `\`.
        if (e is Directory && e.path.replaceAll(r'\', '/').endsWith('/$sidecarDirectoryName')) e,
    ]..sort((a, b) => b.path.length.compareTo(a.path.length));
  }

  static ThumbnailSidecarMigrationReport run(String projectDir) {
    final sw = Stopwatch()..start();
    var removedDirs = 0;
    var removedSidecars = 0;
    var reembedded = 0;
    var restamped = 0;
    var coverMoved = false;

    final legacyCover = File('$projectDir/$legacyCoverPath');
    if (legacyCover.existsSync()) {
      final dest = File('$projectDir/$coverPath');
      dest.parent.createSync(recursive: true);
      if (!dest.existsSync()) {
        legacyCover.copySync(dest.path);
      }
      legacyCover.deleteSync();
      coverMoved = true;
    }

    for (final dir in sidecarDirectories(projectDir)) {
      for (final sidecar in dir.listSync(followLinks: false).whereType<File>()) {
        final name = sidecar.uri.pathSegments.last;
        if (name.endsWith('.png')) {
          final lmas = File('${dir.parent.path}/${name.substring(0, name.length - 4)}.lmas');
          if (lmas.existsSync()) {
            final outcome = _carryOver(lmas, sidecar);
            if (outcome == _Outcome.reembedded) reembedded++;
            if (outcome == _Outcome.restamped) restamped++;
          }
        }
        removedSidecars++;
      }
      dir.deleteSync(recursive: true);
      removedDirs++;
    }

    final rules = ensureGitignoreRules(projectDir);
    return ThumbnailSidecarMigrationReport(
      removedDirectories: removedDirs,
      removedSidecars: removedSidecars,
      reembedded: reembedded,
      restamped: restamped,
      coverMoved: coverMoved,
      gitignoreRules: rules,
      elapsed: sw.elapsed,
    );
  }

  static _Outcome _carryOver(File lmas, File sidecar) {
    try {
      final summary = LuminaAsset.readSummary(lmas);
      final sidecarMs = sidecar.lastModifiedSync().millisecondsSinceEpoch;
      final lmasMs = lmas.lastModifiedSync().millisecondsSinceEpoch;
      final companion = File(lmas.path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
      final companionMs = companion.existsSync() ? companion.lastModifiedSync().millisecondsSinceEpoch : null;
      final source = summary.thumbnailSource;
      // Current under the rule the sidecar stood for.
      final wasCurrent = source != null &&
          const {ThumbnailService.sourceFilament, ThumbnailService.sourceImage, ThumbnailService.sourceBadge}.contains(source) &&
          sidecarMs >= lmasMs &&
          (companionMs == null || companionMs <= sidecarMs);
      final embedded = summary.hasThumbnailBytes ||
          (summary.hasThumbnail && summary.thumbnailRange == null && summary.payloadRange == null && _embeddedByDecode(lmas));
      if (!embedded) {
        final png = sidecar.readAsBytesSync();
        if (png.isEmpty) return _Outcome.none;
        ThumbnailService.embedThumbnail(lmas.path, png, source: wasCurrent ? source : null);
        return _Outcome.reembedded;
      }
      if (!wasCurrent) return _Outcome.none;
      final stamp = DateTime.tryParse(summary.metadata[ThumbnailService.assetModifiedKey] ?? '');
      if (stamp == null) return _Outcome.none;
      final stampMs = stamp.millisecondsSinceEpoch;
      // The thumbnail was made from the file as it was at the stamp; the
      // write that embedded it moved the mtime on. Put it back (never past a
      // newer companion: that one needs a new render).
      if (companionMs != null && companionMs > stampMs) return _Outcome.none;
      if (lmasMs <= stampMs) return _Outcome.none;
      lmas.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(stampMs));
      return _Outcome.restamped;
    } catch (_) {
      return _Outcome.none;
    }
  }

  static bool _embeddedByDecode(File lmas) {
    try {
      return LuminaAsset.fromBytes(lmas.readAsBytesSync()).thumbnailPng?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Appends the [gitignoreRules] an existing `.gitignore` of [projectDir]
  /// lacks; returns what it appended.
  static List<String> ensureGitignoreRules(String projectDir) {
    final file = File('$projectDir/.gitignore');
    if (!file.existsSync()) return const [];
    final existing = file.readAsStringSync();
    final lines = LineSplitter.split(existing).map((l) => l.trim()).toSet();
    const equivalents = {
      '.lumina/': {'.lumina/', '.lumina', '/.lumina/', '/.lumina'},
      '**/.thumbnails/': {'**/.thumbnails/', '**/.thumbnails', '.thumbnails/', '.thumbnails'},
    };
    final missing = [
      for (final rule in gitignoreRules)
        if (!(equivalents[rule] ?? {rule}).any(lines.contains)) rule,
    ];
    if (missing.isEmpty) return const [];
    final out = StringBuffer(existing);
    if (existing.isNotEmpty && !existing.endsWith('\n')) out.writeln();
    out.writeln('# Lumina editor state and the asset index; thumbnails live in the .lmas');
    for (final rule in missing) {
      out.writeln(rule);
    }
    file.writeAsStringSync(out.toString());
    return missing;
  }
}

enum _Outcome { none, reembedded, restamped }
