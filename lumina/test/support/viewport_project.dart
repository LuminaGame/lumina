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
  ViewportTestProject._(this.dir, this.idleClip, this.mannequinPath, this.idlePath);

  final Directory dir;

  /// The clip the idle animation asset names.
  final String idleClip;

  /// Where this project keeps the mannequin and its idle animation.
  final String mannequinPath;
  final String idlePath;

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
  /// the mannequin's first clip. [mannequinAt] and [idleAt] move the
  /// mannequin and its animation, [extra] adds props (project path →
  /// `test-assets/` model).
  static ViewportTestProject create({String mannequinAt = mannequin, String idleAt = idle, Map<String, String> extra = const {}}) {
    final dir = Directory.systemTemp.createTempSync('lumina_vp_');
    final names = GlbAnimationMerger.animationNames(File('${viewportTestAssets.path}/${sources[mannequin]}').readAsBytesSync());
    final idleClip = names.isEmpty ? '' : names.first;
    final all = {for (final e in sources.entries) e.key == mannequin ? mannequinAt : e.key: e.value, ...extra};
    for (final e in all.entries) {
      final glb = File('${viewportTestAssets.path}/${e.value}').readAsBytesSync();
      final skeletal = e.key == mannequinAt;
      _write(dir, e.key, glb, skeletal ? AssetType.filameshSk : AssetType.filamesh,
          skeletal ? {'payload_format': 'glb', 'animation_clips': idleClip} : {'payload_format': 'glb'});
    }
    final anim = LuminaAsset(
      assetId: 'idle',
      name: 'Idle',
      type: AssetType.animation,
      references: [AssetReference(slotName: 'skeletal_mesh', assetId: 'mannequin', assetPath: mannequinAt)],
      metadata: {'source_mesh': mannequinAt, 'clip_name': idleClip, 'clip_index': '0'},
    );
    final animFile = File('${dir.path}/$idleAt')..parent.createSync(recursive: true);
    animFile.writeAsBytesSync(anim.toProtoBufferBytes());
    return ViewportTestProject._(dir, idleClip, mannequinAt, idleAt);
  }

  /// Writes the mannequin at [path] as a multi-skin mesh the way a MetaHuman
  /// export lays one out: a first skin of the head and neck joints only,
  /// then the full body skin. Returns the written GLB.
  Uint8List writeMultiSkinMannequin(String path) {
    final doc = GlbDocument.parse(File('${viewportTestAssets.path}/${sources[mannequin]}').readAsBytesSync());
    final nodes = (doc.json['nodes'] as List).cast<Map<String, dynamic>>();
    final head = <int>[];
    void collect(int i) {
      head.add(i);
      for (final c in (nodes[i]['children'] as List? ?? const [])) {
        collect(c as int);
      }
    }

    collect(nodes.indexWhere((n) => n['name'] == 'neck_01'));
    final skins = (doc.json['skins'] as List).cast<Map<String, dynamic>>();
    doc.json['skins'] = [
      {'name': 'head_skin', 'joints': head..sort()},
      ...skins,
    ];
    for (final n in nodes) {
      if (n['skin'] is int) n['skin'] = (n['skin'] as int) + 1;
    }
    final glb = doc.encode();
    _write(dir, path, glb, AssetType.filameshSk, {'payload_format': 'glb', 'animation_clips': idleClip});
    return glb;
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
