import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

/// The Game Animation Sample locomotion clips kept in the shared test assets
/// (`test-assets/FBX/GameAnimationSample/`): the UEFN mannequin skeletal
/// mesh and a set of idle / walk / run clips with root motion, exported from
/// Unreal Engine as FBX.
class LocomotionFbxFixture {
  static Directory get directory {
    final root = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
    return Directory('$root/FBX/GameAnimationSample');
  }

  static File get meshFbx => File('${directory.path}/SKM_UEFN_Mannequin.fbx');

  /// Whether the fixture is present (tests skip without it).
  static bool get available => meshFbx.existsSync();

  /// The clip FBX files, sorted by name.
  static List<File> get clipFiles => directory
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.fbx') && !f.path.contains('SKM_'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  static String clipName(File f) => f.uri.pathSegments.last.replaceAll(RegExp(r'\.fbx$', caseSensitive: false), '');

  static Uint8List? _merged;

  /// The mannequin GLB with every clip imported the way the editor imports
  /// an animation FBX: converted by [FbxImportService] and retargeted onto
  /// the mesh by [GlbAnimationRetargeter.retargetInto] (as
  /// `AnimationImportBinder.bind` does). Built once per test process.
  static Future<Uint8List> mergedGlb() async {
    final cached = _merged;
    if (cached != null) return cached;
    var glb = (await FbxImportService.convert(meshFbx.path)).glb;
    for (final f in clipFiles) {
      final clip = await FbxImportService.convert(f.path);
      glb = GlbAnimationRetargeter.retargetInto(target: glb, clip: clip.glb, clipName: clipName(f)).glb;
    }
    return _merged = glb;
  }

  /// A database over every fixture clip: loops loop, every clip mirrored.
  static LuminaPoseSearchDatabaseDocument document({String targetMesh = '', bool mirror = true}) =>
      LuminaPoseSearchDatabaseDocument(
        targetMesh: targetMesh,
        clips: [
          for (final f in clipFiles)
            LuminaPoseSearchClip(
              clipName(f),
              loop: LuminaPoseSearchClip.looksLooping(clipName(f)),
              mirror: mirror,
              tags: [if (clipName(f).contains('_Run_')) 'run' else 'walk'],
              // A start is searched for its first second; then a loop takes
              // over.
              samplingEnd: clipName(f).contains('_Start_') ? 1.0 : 0.0,
            ),
        ],
      );
}
