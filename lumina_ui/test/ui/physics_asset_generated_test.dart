import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';

String _mannequinPath() {
  final env = Platform.environment['LUMINA_TEST_ASSETS'];
  final candidates = [
    if (env != null && env.isNotEmpty) '$env/mannequin/SKM_Manny_Simple.glb',
    '${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb',
  ];
  return candidates.firstWhere((p) => File(p).existsSync(), orElse: () => candidates.first);
}

/// A physics asset generated from a skeleton (project-relative mesh
/// reference, joint types and frames the editor does not show) opens in the
/// Physics Asset editor, and an edit saved there keeps what the runtime
/// needs.
void main() {
  final mannequin = _mannequinPath();

  test('a generated physics asset opens, edits and saves without losing its joints', () async {
    final project = Directory.systemTemp.createTempSync('phat_generated_');
    addTearDown(() => project.deleteSync(recursive: true));
    final repo = AssetRepository();
    await repo.importExternalFile(projectPath: project.path, sourceFilePath: mannequin);
    final mesh = repo
        .scanProjectContents(project.path)
        .firstWhere((a) => a.type == AssetType.filameshSk || a.type == AssetType.filamesh);
    final meshPath = mesh.relativePath.replaceAll(r'\', '/');
    final relative = await PhysicsAssetGeneration.generateForSkeletalMesh(project.path, meshPath);

    final vm = PhysicsAssetEditorViewModel(assetPath: '${project.path}/$relative');
    await vm.load();
    expect(vm.hasError, isFalse);
    expect(vm.linkError, isNull);
    expect(vm.hasSkeletalMesh, isTrue);
    expect(vm.document.bodies.length, inInclusiveRange(15, 19));
    expect(vm.validationErrors, isEmpty);

    vm.setBodyRadius('head', 12.5);
    expect(await vm.save(), isTrue);

    final saved = LuminaAsset.fromBytes(File('${project.path}/$relative').readAsBytesSync());
    expect(saved.references.single.assetPath, meshPath, reason: 'the reference stays project-relative');
    final data = LuminaPhysicsAssetData.fromJson(jsonDecode(saved.metadata['physics_asset']!) as Map<String, dynamic>);
    expect(data.bodyForBone('head')!.radius, 12.5);
    final knee = data.constraints.firstWhere((c) => c.bodyB == 'calf_l');
    expect(knee.type, LuminaPhysicsJointType.hinge);
    expect(knee.twistMaxDegrees, 140);
    expect(knee.frameRotationDegrees, isNotNull);
  }, skip: File(mannequin).existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing');
}
