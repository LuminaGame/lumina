import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';

/// A skeletal mesh as a preview component loads it: a GLB path and, for a
/// mesh whose GLB lives inside its `.lmas` payload, a provider handing those
/// bytes over.
typedef AnimPreviewMeshSource = ({String path, LuminaAssetProvider? provider});

/// Animation Blueprint and Blend Space assets on disk: lumina's anim graph
/// documents as JSON in the `.lmas`
/// `raw_payload`, next to the mesh's clips under
/// `contents/animations/<Mesh>/`, with the target mesh kept in the metadata
/// and as an asset reference.
abstract final class AnimGraphAssetService {
  static const String targetMeshKey = 'target_mesh';

  static String baseName(String path) => path.split('/').last.replaceAll('.lmas', '');

  /// The project's skeletal meshes.
  static List<RealAssetInfo> skeletalMeshes(String projectDir) => AssetRepository()
      .scanProjectContents(projectDir)
      .where((a) {
        final lower = a.relativePath.toLowerCase();
        final nameLower = a.fileName.toLowerCase();
        // Strictly reject materials, textures, animations, static meshes
        if (a.type == AssetType.filamat || a.type == AssetType.texture || a.type == AssetType.animation) return false;
        if (lower.contains('/materials/') || lower.contains('/textures/') || lower.contains('/animations/')) return false;
        if (nameLower.startsWith('m_') || nameLower.startsWith('mi_') || nameLower.startsWith('t_') || nameLower.startsWith('sm_')) return false;
        return a.type == AssetType.filameshSk ||
            nameLower.startsWith('skm_') ||
            lower.contains('/skeletal') ||
            lower.contains('/skm');
      })
      .toList()
    ..sort((a, b) => a.fileName.compareTo(b.fileName));

  /// Where [meshRelPath]'s GLB is: the `.entity.glb` companion (template
  /// content) or the `.lmas` payload (an import). Null when neither exists.
  static AnimPreviewMeshSource? meshSource(String projectDir, String meshRelPath) {
    if (meshRelPath.isEmpty) return null;
    final lmas = File('$projectDir/$meshRelPath');
    final companion = File('$projectDir/${meshRelPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
    if (companion.existsSync()) return (path: companion.path, provider: null);
    if (!lmas.existsSync()) return null;
    if (meshRelPath.endsWith('.glb')) return (path: lmas.path, provider: null);
    try {
      final payload = LuminaAsset.fromBytes(lmas.readAsBytesSync()).rawPayload;
      if (payload == null || payload.isEmpty) return null;
      return (path: lmas.path, provider: (_) async => payload);
    } catch (_) {
      return null;
    }
  }

  /// The animation clips stored in [meshRelPath]'s GLB, in gltfio order.
  static List<String> clipNames(String projectDir, String meshRelPath) {
    final lmas = File('$projectDir/$meshRelPath');
    if (lmas.existsSync() && meshRelPath.endsWith('.lmas')) {
      try {
        final clips = LuminaAsset.fromBytes(lmas.readAsBytesSync()).metadata['animation_clips'];
        if (clips != null && clips.isNotEmpty) return clips.split(',');
      } catch (_) {}
    }
    final source = meshSource(projectDir, meshRelPath);
    if (source == null) return const [];
    try {
      final bytes = source.provider == null
          ? File(source.path).readAsBytesSync()
          : LuminaAsset.fromBytes(File(source.path).readAsBytesSync()).rawPayload!;
      return GlbAnimationMerger.animationNames(bytes);
    } catch (_) {
      return const [];
    }
  }

  static String _folderFor(String meshRelPath) =>
      'contents/animations/${baseName(meshRelPath).isEmpty ? 'Shared' : baseName(meshRelPath)}';

  static String _uniquePath(String projectDir, String folder, String name) {
    var candidate = name;
    var n = 1;
    while (File('$projectDir/$folder/$candidate.lmas').existsSync()) {
      candidate = '${name}_${++n}';
    }
    return '$folder/$candidate.lmas';
  }

  static String withPrefix(String name, String prefix) {
    final clean = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (clean.isEmpty) return '${prefix}New';
    return clean.startsWith(prefix) ? clean : '$prefix$clean';
  }

  /// What a new Animation Blueprint for [meshRelPath] starts as: an
  /// EventGraph with Blueprint Update Animation, and an AnimGraph whose
  /// Output Pose is fed by the Locomotion state machine with one Idle state
  /// playing the mesh's first clip.
  static LuminaAnimBlueprintDocument newAnimBlueprint(String meshRelPath, List<String> clips) => LuminaAnimBlueprintDocument(
        targetMesh: meshRelPath,
        eventGraph: LuminaBlueprintGraph(nodes: [
          LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.updateAnimation, nodeId: 'update', x: 0, y: 0),
        ]),
        stateMachines: [
          LuminaAnimStateMachine(
            name: 'Locomotion',
            entryState: 'Idle',
            states: [
              LuminaAnimState('Idle', clips.isEmpty ? const LuminaAnimPose.hold() : LuminaAnimPose.clip(clips.first),
                  x: 120, y: 60),
            ],
            transitions: [],
          ),
        ],
      );

  /// A new 2D Blend Space: Direction (−180…180°) × Speed (0…500 cm/s).
  static LuminaBlendSpaceDocument newBlendSpace() => const LuminaBlendSpaceDocument(
        axes: [LuminaBlendSpaceAxis('Direction', -180, 180), LuminaBlendSpaceAxis('Speed', 0, 500)],
        samples: [],
      );

  /// Creates `ABP_<name>.lmas` for [meshRelPath] and returns its project
  /// relative path.
  static String createAnimBlueprint(String projectDir, {required String name, required String meshRelPath}) {
    final rel = _uniquePath(projectDir, _folderFor(meshRelPath), withPrefix(name, 'ABP_'));
    writeAnimBlueprint(projectDir, rel, newAnimBlueprint(meshRelPath, clipNames(projectDir, meshRelPath)));
    return rel;
  }

  /// Creates `BS_<name>.lmas` for [meshRelPath] and returns its path;
  /// [document] is its content (a new 2D space by default).
  static String createBlendSpace(String projectDir,
      {required String name, required String meshRelPath, LuminaBlendSpaceDocument? document}) {
    final rel = _uniquePath(projectDir, _folderFor(meshRelPath), withPrefix(name, 'BS_'));
    writeBlendSpace(projectDir, rel, document ?? newBlendSpace(), targetMesh: meshRelPath);
    return rel;
  }

  static Map<String, dynamic>? _payload(File file) {
    if (!file.existsSync()) return null;
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null) return null;
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static LuminaAnimBlueprintDocument? readAnimBlueprint(String projectDir, String relPath) {
    final map = _payload(File('$projectDir/$relPath'));
    return map == null ? null : LuminaAnimBlueprintDocument.fromJson(map);
  }

  static LuminaBlendSpaceDocument? readBlendSpace(String projectDir, String relPath) {
    final map = _payload(File('$projectDir/$relPath'));
    return map == null ? null : LuminaBlendSpaceDocument.fromJson(map);
  }

  /// The mesh a Blend Space was made for (its metadata), or null.
  static String? blendSpaceTarget(String projectDir, String relPath) {
    final file = File('$projectDir/$relPath');
    if (!file.existsSync()) return null;
    try {
      return LuminaAsset.fromBytes(file.readAsBytesSync()).metadata[targetMeshKey];
    } catch (_) {
      return null;
    }
  }

  static LuminaAsset? _existing(File file) {
    if (!file.existsSync()) return null;
    try {
      return LuminaAsset.fromBytes(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static List<AssetReference> _meshReference(String projectDir, String meshRelPath) {
    if (meshRelPath.isEmpty) return const [];
    final mesh = _existing(File('$projectDir/$meshRelPath'));
    return [AssetReference(slotName: 'skeletal_mesh', assetId: mesh?.assetId ?? '', assetPath: meshRelPath)];
  }

  static String _json(Map<String, dynamic> map) => const JsonEncoder.withIndent('  ').convert(map);

  static void _write(String projectDir, String relPath, AssetType type, Map<String, dynamic> json, String targetMesh) {
    final file = File('$projectDir/$relPath')..parent.createSync(recursive: true);
    final previous = _existing(file);
    final text = _json(json);
    final asset = LuminaAsset(
      assetId: previous?.assetId ?? '${type.name}_${DateTime.now().microsecondsSinceEpoch}',
      name: baseName(relPath),
      type: type,
      rawPayload: Uint8List.fromList(utf8.encode(text)),
      rawMatSource: text,
      thumbnailPng: previous?.thumbnailPng,
      hasThumbnail: previous?.hasThumbnail ?? false,
      references: _meshReference(projectDir, targetMesh),
      metadata: {
        ...?previous?.metadata,
        'payload_format': 'json',
        targetMeshKey: targetMesh,
        'last_modified': DateTime.now().toIso8601String(),
      },
    );
    file.writeAsBytesSync(asset.toProtoBufferBytes());
  }

  static void writeAnimBlueprint(String projectDir, String relPath, LuminaAnimBlueprintDocument doc) =>
      _write(projectDir, relPath, AssetType.animBlueprint, doc.toJson(), doc.targetMesh);

  static void writeBlendSpace(String projectDir, String relPath, LuminaBlendSpaceDocument doc, {required String targetMesh}) =>
      _write(projectDir, relPath, AssetType.blendSpace, doc.toJson(), targetMesh);

  /// Blend Spaces made for [meshRelPath]: named in their metadata, or (for a
  /// Blend Space written without one) whose samples all play clips the mesh
  /// has.
  static List<String> blendSpacesFor(String projectDir, String meshRelPath) {
    final clips = clipNames(projectDir, meshRelPath).toSet();
    final out = <String>[];
    for (final a in AssetRepository().scanProjectContents(projectDir)) {
      if (a.type != AssetType.blendSpace) continue;
      final target = blendSpaceTarget(projectDir, a.relativePath);
      if (target != null && target.isNotEmpty) {
        if (target == meshRelPath) out.add(a.relativePath);
        continue;
      }
      final doc = readBlendSpace(projectDir, a.relativePath);
      if (doc != null && doc.samples.isNotEmpty && doc.samples.every((s) => clips.contains(s.clip))) out.add(a.relativePath);
    }
    return out..sort();
  }

  /// Walks up from [path] to the project directory (the folder holding the
  /// `.lmproject`, or `contents/`).
  static String? projectDirOf(String path) {
    var dir = File(path).absolute.parent;
    while (dir.path != dir.parent.path) {
      if (Directory('${dir.path}/contents').existsSync() &&
          dir.listSync().any((e) => e is File && e.path.endsWith('.lmproject'))) {
        return dir.path;
      }
      dir = dir.parent;
    }
    dir = File(path).absolute.parent;
    while (dir.path != dir.parent.path) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      dir = dir.parent;
    }
    return null;
  }
}
