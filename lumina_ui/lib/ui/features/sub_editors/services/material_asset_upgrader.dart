/// Brings a project's material assets to the linked Filament release: a
/// `.lmas` whose compiled package was built for another material version (the
/// engine refuses it, so the material draws nothing) or whose `.mat` source
/// uses what this release deprecated or removed (`MatMigration`) is
/// rewritten to the current source and compiled again, and written back. A
/// material that does not compile is left untouched and reported.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_migration.dart';
import 'package:path/path.dart' as p;

/// What upgrading one material asset did.
class MaterialAssetUpgrade {
  final String path;

  /// The rewrites of its `.mat` source.
  final List<MatMigrationChange> changes;

  /// The material version its stored package was compiled for, when that is
  /// not the engine's; null when the package was current (or absent).
  final int? staleVersion;

  /// Why it was left untouched; null when it was upgraded.
  final String? error;

  const MaterialAssetUpgrade(this.path, {this.changes = const [], this.staleVersion, this.error});

  bool get upgraded => error == null;

  /// One line for the Output Log.
  String describe() {
    final name = p.basename(path);
    final why = [
      if (staleVersion != null) 'compiled for material version $staleVersion',
      if (changes.isNotEmpty) '${changes.length} deprecated construct${changes.length == 1 ? '' : 's'} in its source',
    ].join(' and ');
    if (error != null) return 'Material $name ($why) could not be upgraded: $error';
    return 'Upgraded material $name ($why): ${changes.isEmpty ? 'recompiled' : changes.join('; ')}';
  }
}

/// Compiles a whole `.mat` source; injectable so tests choose the compiler.
typedef MatSourceCompiler = MatcResult Function(String name, String source, String? includeDirectory);

class MaterialAssetUpgrader {
  /// The material version the engine reads ([filamentExpectedMaterialVersion]).
  final int expectedVersion;
  final MatSourceCompiler _compile;

  MaterialAssetUpgrader({int? expectedVersion, MatSourceCompiler? compile})
      : expectedVersion = expectedVersion ?? filamentExpectedMaterialVersion,
        _compile = compile ?? _matc;

  static MatcResult _matc(String name, String source, String? includeDirectory) =>
      FilamentMatc.compile(source, fileName: '$name.mat', defaultName: name, includeDirectory: includeDirectory);

  /// Upgrades the material asset at [lmasPath]; null when it is not a
  /// material or is already current. Reads and writes asynchronously; parsing
  /// and compiling run on a background isolate.
  Future<MaterialAssetUpgrade?> upgrade(String lmasPath) async {
    final file = File(lmasPath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    final compile = _compile;
    final job = (bytes: bytes, expected: expectedVersion, include: file.parent.path, path: lmasPath);
    final result = await Isolate.run(() => _upgradeBytes(job, compile));
    if (result == null) return null;
    if (result.bytes != null) await file.writeAsBytes(result.bytes!, flush: true);
    return result.outcome;
  }

  /// Upgrades every one of [lmasPaths], one at a time; the outcomes of those
  /// that needed it.
  Future<List<MaterialAssetUpgrade>> upgradeAll(Iterable<String> lmasPaths) async {
    final out = <MaterialAssetUpgrade>[];
    for (final path in lmasPaths) {
      try {
        final r = await upgrade(path);
        if (r != null) out.add(r);
      } catch (e) {
        out.add(MaterialAssetUpgrade(path, error: '$e'));
      }
    }
    return out;
  }

  /// The version byte of a compiled package (a `MAT_VERS` chunk of size 4);
  /// null for anything else.
  static int? packageVersion(Uint8List? bytes) {
    const magic = [0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D];
    if (bytes == null || bytes.length < 16) return null;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return null;
    }
    if (ByteData.view(bytes.buffer, bytes.offsetInBytes + 8, 4).getUint32(0, Endian.little) != 4) return null;
    return filamentMaterialPackageVersion(bytes);
  }

  static ({MaterialAssetUpgrade outcome, Uint8List? bytes})? _upgradeBytes(
    ({Uint8List bytes, int expected, String include, String path}) job,
    MatSourceCompiler compile,
  ) {
    final LuminaAsset asset;
    try {
      asset = LuminaAsset.fromBytes(job.bytes);
    } catch (_) {
      return null; // not an asset this can read: nothing to upgrade
    }
    if (asset.type != AssetType.filamat) return null;
    final version = packageVersion(asset.rawPayload);
    final stale = version != null && version != job.expected ? version : null;
    final migration = MatMigration.of(asset.rawMatSource);
    if (stale == null && !migration.changed) return null;
    if (migration.source.trim().isEmpty) {
      return (
        outcome: MaterialAssetUpgrade(job.path, staleVersion: stale, error: 'it has no .mat source to compile again'),
        bytes: null,
      );
    }
    final result = compile(asset.name.isEmpty ? 'Material' : asset.name, migration.source, job.include);
    final package = result.package;
    if (package == null) {
      return (
        outcome: MaterialAssetUpgrade(job.path, changes: migration.changes, staleVersion: stale, error: result.errorText),
        bytes: null,
      );
    }
    final upgraded = LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: asset.type,
      hasThumbnail: asset.hasThumbnail,
      thumbnailPng: asset.thumbnailPng,
      rawPayload: package,
      rawMatSource: migration.source,
      references: asset.references,
      metadata: {...asset.metadata, 'compiled_size': '${package.length}'},
    );
    return (
      outcome: MaterialAssetUpgrade(job.path, changes: migration.changes, staleVersion: stale),
      bytes: upgraded.toProtoBufferBytes(),
    );
  }
}
