import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';

import '../helpers/scaffold_game_project.dart';

/// An animation's metadata blend space can be
/// extracted to a Blend Space asset an Animation Blueprint plays; nothing is
/// converted automatically.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Extract to Blend Space asset writes a BLEND_SPACE .lmas for the preview mesh', () async {
    final root = Directory.systemTemp.createTempSync('lumina_bs_extract_');
    addTearDown(() => root.deleteSync(recursive: true));
    final dir = await scaffoldGameProject(root, name: 'bs_extract', widgetLibrary: 'flutter');
    final idle = '$dir/${LuminaThirdPersonContent.projectAnimationDir}/Idle_Loop.lmas';
    final vm = AnimationEditorViewModel(assetPath: idle);
    await vm.load();
    expect(vm.previewMeshPath, LuminaThirdPersonContent.projectMeshAssetPath);
    expect(vm.extractBlendSpaceAsset(), isNull, reason: 'nothing to extract without samples');

    vm.setBlendSpace2D(true);
    vm.addBlendSample('', 'Idle_Loop', 0, 0);
    vm.addBlendSample('', 'Walk_Fwd_Loop', 0, 250);
    final path = vm.extractBlendSpaceAsset()!;
    expect(path, 'contents/animations/SKM_Superhero_Female/BS_Idle_Loop.lmas');

    final asset = LuminaAsset.fromBytes(File('$dir/$path').readAsBytesSync());
    expect(asset.type, AssetType.blendSpace);
    final doc = AnimGraphAssetService.readBlendSpace(dir, path)!;
    expect(doc.axes.map((a) => a.name), ['Direction', 'Speed']);
    expect(doc.samples.map((s) => (s.clip, s.x, s.y)), [('Idle_Loop', 0.0, 0.0), ('Walk_Fwd_Loop', 0.0, 250.0)]);
    expect(AnimGraphAssetService.blendSpacesFor(dir, LuminaThirdPersonContent.projectMeshAssetPath), contains(path));
    expect(vm.blendSpace.samples, hasLength(2), reason: 'the animation keeps its own copy');
  });
}
