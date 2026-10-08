import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart';

import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_traversal.dart';

/// One animation sequence of the exported sample: its FBX file and what the
/// export's `metadata.json` records about it.
class GaspSequence {
  /// The clip name: the FBX base name (`M_Neutral_Walk_Loop_F`), which is
  /// also the glTF animation name an import gives it.
  final String name;

  /// The animation folder below `Animations/` (`Walk`, `Jump`,
  /// `Traversal/Mantle`, …); the first segment is its [category].
  final String folder;

  /// Absolute path of the FBX.
  final String fbxPath;

  /// Length in seconds (0 when the metadata has none).
  final double lengthSeconds;

  const GaspSequence({required this.name, required this.folder, required this.fbxPath, this.lengthSeconds = 0.0});

  /// The top animation folder: `Walk`, `Run`, `Sprint`, `Crouch`, `Idle`,
  /// `Jump`, `Traversal`, `Slide`, `Interactions`, …
  String get category => folder.split('/').first;
}

/// One clip entry of a pose search database of the sample.
class GaspDatabaseClip {
  final String clip;

  /// Seconds of the clip searched (`SamplingRange`); 0 = the whole clip.
  final double samplingStart;
  final double samplingEnd;
  final bool enabled;

  /// `MirrorOption`: null (unmirrored only), `MirroredOnly` or
  /// `UnmirroredAndMirrored`.
  final String? mirror;

  const GaspDatabaseClip(this.clip, {this.samplingStart = 0.0, this.samplingEnd = 0.0, this.enabled = true, this.mirror});
}

/// A pose search database of the sample: its clips, tags and cost biases.
class GaspDatabase {
  final String name;
  final String schema;
  final List<String> tags;
  final double baseCostBias;
  final double loopingCostBias;
  final double continuingPoseCostBias;
  final List<GaspDatabaseClip> clips;

  const GaspDatabase({
    required this.name,
    required this.schema,
    required this.tags,
    required this.baseCostBias,
    required this.loopingCostBias,
    required this.continuingPoseCostBias,
    required this.clips,
  });
}

/// The animation export of the sample: a folder holding
/// `Game/Characters/UEFN_Mannequin/Animations/<category>/…/*.fbx` and the
/// `metadata.json` written next to it (sequences, pose search databases
/// with their text exports).
///
/// Nothing of the sample is part of Lumina: this only reads a local export.
class GaspExport {
  /// Below the export root, the folder the sequences live in.
  static const String animationsFolder = 'Game/Characters/UEFN_Mannequin/Animations';

  final String root;
  final List<GaspSequence> sequences;
  final Map<String, GaspDatabase> databases;

  /// The traversal chooser's rows with their montages' warp windows
  /// ([GaspTraversal.rows]); empty when the metadata has none.
  final List<LuminaTraversalAnimation> traversal;

  GaspExport._(this.root, this.sequences, this.databases, [this.traversal = const []]);

  /// Reads [root]'s `metadata.json` (when present) and lists its FBX files.
  /// A sequence without an FBX (the export skipped it) is left out.
  static Future<GaspExport> open(String root) async {
    final animations = Directory('$root/$animationsFolder');
    if (!await animations.exists()) {
      throw FileSystemException('No sample animation export (expected $animationsFolder)', root);
    }
    final metadataFile = File('$root/metadata.json');
    final metadata = await metadataFile.exists()
        ? Map<String, dynamic>.from(jsonDecode(await metadataFile.readAsString()) as Map)
        : const <String, dynamic>{};
    return parse(root, metadata, await _fbxFiles(animations));
  }

  /// [metadata] (the export's `metadata.json`) and the FBX files found
  /// (absolute paths) as an export.
  static GaspExport parse(String root, Map<String, dynamic> metadata, List<String> fbxFiles) {
    final lengths = <String, double>{};
    for (final s in (metadata['anim_sequences'] as List?) ?? const []) {
      final m = s as Map;
      final name = '${m['path']}'.split('.').last;
      lengths[name] = (m['length_s'] as num?)?.toDouble() ?? 0.0;
    }
    final prefix = '${root.replaceAll(r'\', '/')}/$animationsFolder/';
    final sequences = <GaspSequence>[];
    final seen = <String>{};
    for (final path in fbxFiles) {
      final normal = path.replaceAll(r'\', '/');
      if (!normal.startsWith(prefix)) continue;
      final rel = normal.substring(prefix.length);
      final slash = rel.lastIndexOf('/');
      if (slash < 0) continue;
      final name = rel.substring(slash + 1).replaceAll(RegExp(r'\.fbx$', caseSensitive: false), '');
      // Clip names are glTF animation names in one mesh: the first wins.
      if (!seen.add(name)) continue;
      sequences.add(GaspSequence(name: name, folder: rel.substring(0, slash), fbxPath: path, lengthSeconds: lengths[name] ?? 0.0));
    }
    sequences.sort((a, b) => a.folder != b.folder ? a.folder.compareTo(b.folder) : a.name.compareTo(b.name));
    final databases = <String, GaspDatabase>{};
    final assets = (metadata['assets'] as Map?) ?? const {};
    for (final d in (assets['PoseSearchDatabase'] as List?) ?? const []) {
      final db = parseDatabase(Map<String, dynamic>.from(d as Map));
      databases.putIfAbsent(db.name, () => db);
    }
    return GaspExport._(root, sequences, databases, GaspTraversal.rows(metadata));
  }

  static final _assetLine = RegExp(r'^\s*DatabaseAnimationAssets\(\d+\)=\((.*)\)\s*$', multiLine: true);
  static final _animAsset = RegExp(r'''AnimAsset="[^']*'([^']+)'"''');
  static final _sampling = RegExp(r'SamplingRange=\(([^)]*)\)');
  static final _mirror = RegExp(r'MirrorOption=(\w+)');

  /// One `PoseSearchDatabase` entry of the metadata: its `t3d` text export
  /// lists the clips (`DatabaseAnimationAssets(i)=(AnimAsset=…, SamplingRange=(Min=…,Max=…), MirrorOption=…)`).
  static GaspDatabase parseDatabase(Map<String, dynamic> entry) {
    final name = '${entry['path']}'.split('/').last.split('.').first;
    final t3d = '${entry['t3d'] ?? ''}';
    final clips = <GaspDatabaseClip>[];
    for (final m in _assetLine.allMatches(t3d)) {
      final body = m.group(1)!;
      final asset = _animAsset.firstMatch(body);
      if (asset == null || !body.contains('AnimSequence')) continue;
      var start = 0.0, end = 0.0;
      final range = _sampling.firstMatch(body)?.group(1);
      if (range != null) {
        for (final part in range.split(',')) {
          final kv = part.split('=');
          if (kv.length != 2) continue;
          final v = double.tryParse(kv[1]) ?? 0.0;
          if (kv[0].trim() == 'Min') start = v;
          if (kv[0].trim() == 'Max') end = v;
        }
      }
      clips.add(GaspDatabaseClip(
        asset.group(1)!.split('.').last,
        samplingStart: start,
        samplingEnd: end,
        enabled: !body.contains('bEnabled=False'),
        mirror: _mirror.firstMatch(body)?.group(1),
      ));
    }
    double number(String key) => (entry[key] as num?)?.toDouble() ?? 0.0;
    return GaspDatabase(
      name: name,
      schema: '${entry['schema'] ?? ''}'.split('.').last,
      tags: [for (final t in (entry['tags'] as List?) ?? const []) '$t'],
      baseCostBias: number('base_cost_bias'),
      loopingCostBias: number('looping_cost_bias'),
      continuingPoseCostBias: number('continuing_pose_cost_bias'),
      clips: clips,
    );
  }

  static Future<List<String>> _fbxFiles(Directory dir) async => [
        await for (final e in dir.list(recursive: true, followLinks: false))
          if (e is File && e.path.toLowerCase().endsWith('.fbx')) e.path,
      ];

  /// The sequence named [name], or null.
  GaspSequence? sequence(String name) {
    for (final s in sequences) {
      if (s.name == name) return s;
    }
    return null;
  }
}
