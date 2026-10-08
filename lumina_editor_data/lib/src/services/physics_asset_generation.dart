import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:path/path.dart' as p;

/// Writes a physics asset for a skeletal mesh of a project: bodies and
/// joints generated from the mesh's skeleton by [LuminaPhysicsAssetGenerator]
/// (main bones only), in a `physicsAsset` `.lmas` that the Physics Asset
/// editor opens and a ragdoll component loads.
abstract final class PhysicsAssetGeneration {
  /// Where the physics asset of [meshAssetPath] goes:
  /// `contents/physics/PHYS_<mesh>.lmas`.
  static String assetPathFor(String meshAssetPath) {
    final name = p.basenameWithoutExtension(meshAssetPath.replaceAll(r'\', '/'));
    return 'contents/physics/PHYS_$name.lmas';
  }

  /// Generates the physics asset of [meshAssetPath] (project-relative) in
  /// [projectDir] and returns its project-relative path. The skeleton is
  /// read and the bodies built on a background isolate. An existing asset
  /// is kept (its bodies may have been edited) unless [overwrite].
  static Future<String> generateForSkeletalMesh(String projectDir, String meshAssetPath,
      {double totalMassKg = 80.0, bool overwrite = false}) async {
    final relative = assetPathFor(meshAssetPath);
    final file = File(p.join(projectDir, relative));
    if (!overwrite && await file.exists()) return relative;
    final glb = await LuminaMeshAssetCache.meshBytes((path) => File(p.join(projectDir, path)).readAsBytes(), meshAssetPath);
    final data = await generate(glb, totalMassKg: totalMassKg);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(assetBytes(data, relative, meshAssetPath));
    return relative;
  }

  /// The physics asset for the skinned [glb], built on a background isolate.
  static Future<LuminaPhysicsAssetData> generate(Uint8List glb, {double totalMassKg = 80.0}) async {
    String work() => jsonEncode(
        LuminaPhysicsAssetGenerator.fromSampler(LuminaGlbAnimationSampler.fromGlb(glb), totalMassKg: totalMassKg).toJson());
    final json = await Isolate.run(work, debugName: 'physics asset generation');
    return LuminaPhysicsAssetData.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
  }

  /// [data] as the `.lmas` at [relativePath] bound to [meshAssetPath].
  static Uint8List assetBytes(LuminaPhysicsAssetData data, String relativePath, String meshAssetPath) {
    final name = p.basenameWithoutExtension(relativePath);
    return LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.physicsAsset,
      metadata: {
        LuminaPhysicsAssetData.metadataKey: jsonEncode(data.toJson()),
        'body_count': '${data.bodies.length}',
        'constraint_count': '${data.constraints.length}',
        'generated': 'skeleton',
      },
      references: [
        AssetReference(slotName: LuminaPhysicsAssetData.skeletalMeshSlot, assetId: '', assetPath: meshAssetPath),
      ],
    ).toProtoBufferBytes();
  }
}
