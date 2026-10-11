import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';

/// The shared 3D test models (`LUMINA_TEST_ASSETS` overrides).
Directory get viewportTestAssets =>
    Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A temporary Lumina project laid out as the importer writes one: a
/// skeletal mesh `.lmas` with its `.entity.glb` companion and its clips
/// listed, an animation `.lmas` that names its clip on that mesh, and
/// static mesh `.lmas` props, all from the models in `test-assets/`.
class ViewportTestProject {
  ViewportTestProject._(this.dir, this.idleClip);

  final Directory dir;

  /// The clip the idle animation asset names.
  final String idleClip;

  static const String mannequin = 'contents/meshes/skeletal/SKM_Mannequin.lmas';
  static const String idle = 'contents/animations/Idle/Idle.lmas';
  static const String hatA = 'contents/meshes/static/SM_Hat_A.lmas';
  static const String hatB = 'contents/meshes/static/SM_Hat_B.lmas';
  static const String barrel = 'contents/meshes/static/SM_Barrel.lmas';
  static const String acUnit = 'contents/meshes/static/SM_AcUnit.lmas';

  /// The source models, by project path.
  static Map<String, String> get sources => {
        mannequin: 'mannequin/MM_Idle.glb',
        hatA: 'Props/Access_cards/access_card_red.glb',
        hatB: 'Props/Access_cards/access_card_blue.glb',
        barrel: 'Props/Barrels/fuel_barrel_red.glb',
        acUnit: 'Props/AC_units/ac_unit_a_300x300.glb',
      };

  /// Whether every source model is present.
  static bool get available => sources.values.every((s) => File('${viewportTestAssets.path}/$s').existsSync());

  /// Builds the project under a new temp folder; the idle animation names
  /// the mannequin's first clip.
  static ViewportTestProject create() {
    final dir = Directory.systemTemp.createTempSync('lumina_vp_');
    final names = GlbAnimationMerger.animationNames(File('${viewportTestAssets.path}/${sources[mannequin]}').readAsBytesSync());
    final idleClip = names.isEmpty ? '' : names.first;
    for (final e in sources.entries) {
      final glb = File('${viewportTestAssets.path}/${e.value}').readAsBytesSync();
      final skeletal = e.key == mannequin;
      _write(dir, e.key, glb, skeletal ? AssetType.filameshSk : AssetType.filamesh,
          skeletal ? {'payload_format': 'glb', 'animation_clips': idleClip} : {'payload_format': 'glb'});
    }
    final anim = LuminaAsset(
      assetId: 'idle',
      name: 'Idle',
      type: AssetType.animation,
      references: const [AssetReference(slotName: 'skeletal_mesh', assetId: 'mannequin', assetPath: mannequin)],
      metadata: {'source_mesh': mannequin, 'clip_name': idleClip, 'clip_index': '0'},
    );
    final animFile = File('${dir.path}/$idle')..parent.createSync(recursive: true);
    animFile.writeAsBytesSync(anim.toProtoBufferBytes());
    return ViewportTestProject._(dir, idleClip);
  }

  static void _write(Directory dir, String path, Uint8List glb, AssetType type, Map<String, String> metadata) {
    final file = File('${dir.path}/$path')..parent.createSync(recursive: true);
    final name = path.split('/').last.replaceAll('.lmas', '');
    file.writeAsBytesSync(LuminaAsset(assetId: name, name: name, type: type, rawPayload: glb, metadata: metadata).toProtoBufferBytes());
    File('${dir.path}/${path.replaceAll('.lmas', '.entity.glb')}').writeAsBytesSync(glb);
  }

  void delete() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
