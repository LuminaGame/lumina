import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina/data/services/engine_bootstrap.dart';

/// Which engine a Lumina Studio runs on, or which engine a project's copy of
/// the engine source was taken from: a release tag and its commit, or for a
/// source checkout the source version and its `HEAD`.
class EngineIdentity {
  /// The version without the tag's `v`: `0.0.1-dev.7`, or `0.0.1-dev` in a
  /// source checkout.
  final String version;

  /// The full commit SHA; empty when unknown (a source tree that is not a
  /// git checkout).
  final String commit;

  /// Whether this is a fetched release checkout (named by its tag alone).
  final bool release;

  const EngineIdentity({required this.version, this.commit = '', this.release = false});

  /// The engine at [engineRoot]: a fetched release checkout names its tag and
  /// commit (its bootstrap marker), so a project editor, which carries no
  /// release defines, reads the same identity as the Studio that fetched it.
  /// Any other tree is a source checkout: [LuminaRelease.displayVersion] and
  /// `git rev-parse HEAD` there.
  static Future<EngineIdentity> of(String engineRoot) async {
    final marker = EngineBootstrap.readMarker(engineRoot);
    if (marker != null) {
      return EngineIdentity(version: stripTag(marker.version), commit: marker.commit, release: true);
    }
    return EngineIdentity(version: LuminaRelease.displayVersion, commit: await _gitHead(engineRoot));
  }

  /// `HEAD` of the checkout at [dir] itself (its own `.git`; a folder inside
  /// another repository names none), without running git otherwise.
  static Future<String> _gitHead(String dir) async {
    if (FileSystemEntity.typeSync(p.join(dir, '.git')) == FileSystemEntityType.notFound) return '';
    try {
      final r = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: dir);
      return r.exitCode == 0 ? (r.stdout as String).trim() : '';
    } on ProcessException {
      return '';
    }
  }

  /// `v0.1.0` → `0.1.0`.
  static String stripTag(String version) => version.replaceFirst(RegExp('^v'), '');

  /// The first seven characters of [commit].
  String get shortCommit => commit.length > 7 ? commit.substring(0, 7) : commit;

  /// The name shown to the user: the release version, or the source version
  /// with its commit (`0.0.1-dev (08cb722)`).
  String get label => release || commit.isEmpty ? version : '$version ($shortCommit)';

  /// Equal for the same engine.
  String get key => '$version@$commit';

  Map<String, Object?> toJson() => {'version': version, 'commit': commit, 'release': release};

  /// Null when [json] names no version.
  static EngineIdentity? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    if (version is! String || version.isEmpty) return null;
    final commit = json['commit'];
    return EngineIdentity(version: version, commit: commit is String ? commit : '', release: json['release'] == true);
  }

  @override
  bool operator ==(Object other) => other is EngineIdentity && other.key == key && other.release == release;

  @override
  int get hashCode => Object.hash(key, release);

  @override
  String toString() => 'EngineIdentity($label)';
}
