import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

final String _assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
final File _manny = File('$_assets/mannequin/SKM_Manny_Simple.glb');

void main() {
  test('generates a physics asset for a project skeletal mesh, and keeps an edited one', () async {
    final project = await Directory.systemTemp.createTemp('phys_gen');
    addTearDown(() => project.delete(recursive: true));
    const mesh = 'contents/meshes/skeletal/SKM_Manny.lmas';
    await Directory('${project.path}/contents/meshes/skeletal').create(recursive: true);
    await _manny.copy('${project.path}/contents/meshes/skeletal/SKM_Manny.entity.glb');
    await File('${project.path}/$mesh').writeAsBytes(
        const LuminaAsset(assetId: 'SKM_Manny', name: 'SKM_Manny', type: AssetType.filameshSk).toProtoBufferBytes());

    final path = await PhysicsAssetGeneration.generateForSkeletalMesh(project.path, mesh);
    expect(path, 'contents/physics/PHYS_SKM_Manny.lmas');
    final asset = LuminaAsset.fromBytes(await File('${project.path}/$path').readAsBytes());
    expect(asset.type, AssetType.physicsAsset);
    expect(asset.references.single.slotName, 'skeletal_mesh');
    expect(asset.references.single.assetPath, mesh);
    final data = LuminaPhysicsAssetData.fromJson(jsonDecode(asset.metadata['physics_asset']!) as Map<String, dynamic>);
    expect(data.bodies.length, inInclusiveRange(15, 19));
    expect(asset.metadata['body_count'], '${data.bodies.length}');

    // An edited asset survives a second run; overwrite regenerates it.
    data.bodies.removeLast();
    await File('${project.path}/$path').writeAsBytes(PhysicsAssetGeneration.assetBytes(data, path, mesh));
    await PhysicsAssetGeneration.generateForSkeletalMesh(project.path, mesh);
    LuminaPhysicsAssetData read() => LuminaPhysicsAssetData.fromJson(
        jsonDecode(LuminaAsset.fromBytes(File('${project.path}/$path').readAsBytesSync()).metadata['physics_asset']!)
            as Map<String, dynamic>);
    expect(read().bodies.length, data.bodies.length);
    await PhysicsAssetGeneration.generateForSkeletalMesh(project.path, mesh, overwrite: true);
    expect(read().bodies.length, data.bodies.length + 1);
  }, skip: _manny.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing');
}
