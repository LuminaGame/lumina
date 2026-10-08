import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';

/// Loading pose search databases from a project: the `.posedb` cache, and
/// one parse of the mesh shared by every database of it.
void main() {
  late Directory project;
  String? previousDir;
  const mesh = 'contents/meshes/Rig.glb';

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_psd_runtime_');
    previousDir = LuminaAssets.projectDir;
    LuminaAssets.projectDir = project.path;
    LuminaPoseSearchDatabaseRuntime.clearShared();
  });

  tearDown(() {
    LuminaAssets.projectDir = previousDir;
    LuminaPoseSearchDatabaseRuntime.clearShared();
    project.deleteSync(recursive: true);
  });

  Future<String> writeDatabase(String name, LuminaPoseSearchDatabaseDocument doc, Uint8List glb, {bool cache = true}) async {
    final path = 'contents/animations/$name.lmas';
    File('${project.path}/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: name,
        name: name,
        type: AssetType.poseSearchDatabase,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson()))),
      ).toProtoBufferBytes());
    if (cache) {
      final built = await LuminaPoseSearchBuilder.buildInBackground(glb, doc);
      File('${project.path}/${LuminaPoseSearchDatabaseRuntime.cachePathOf(path)}').writeAsBytesSync(built.cache);
    }
    return path;
  }

  test('databases of one mesh share its clips; a current cache is used, a missing one is rebuilt', () async {
    final glb = LuminaSyntheticLocomotionRig.build([
      LuminaSyntheticLocomotionRig.idle('Idle'),
      LuminaSyntheticLocomotionRig.walk('WalkF', 0, 1),
    ]);
    File('${project.path}/$mesh')
      ..createSync(recursive: true)
      ..writeAsBytesSync(glb);
    final stand = await writeDatabase('PSD_Stand',
        const LuminaPoseSearchDatabaseDocument(targetMesh: mesh, clips: [LuminaPoseSearchClip('Idle', loop: true)]), glb);
    final walk = await writeDatabase('PSD_Walk',
        const LuminaPoseSearchDatabaseDocument(targetMesh: mesh, clips: [LuminaPoseSearchClip('WalkF', loop: true)]), glb);
    final fresh = await writeDatabase('PSD_Fresh',
        const LuminaPoseSearchDatabaseDocument(targetMesh: mesh, clips: [LuminaPoseSearchClip('Idle', loop: true)]), glb,
        cache: false);

    final a = await LuminaPoseSearchDatabaseRuntime.load(stand);
    final b = await LuminaPoseSearchDatabaseRuntime.load(walk);
    expect(a.built, isFalse, reason: 'the .posedb is current');
    expect(b.built, isFalse);
    expect(identical(a.sampler, b.sampler), isTrue, reason: 'one parse of the mesh');
    expect(a.matchedClipName(0), 'Idle');
    expect(b.matchedClipName(0), 'WalkF');
    final c = await LuminaPoseSearchDatabaseRuntime.load(fresh);
    expect(c.built, isTrue, reason: 'no cache: rebuilt');
    expect(c.index.rowCount, a.index.rowCount, reason: 'the same clip gives the same rows');
    expect(File('${project.path}/contents/animations/PSD_Fresh.posedb').existsSync(), isTrue, reason: 'written back');
  });
}

extension on LuminaPoseSearchDatabaseRuntime {
  String matchedClipName(int clip) => document.clips[clip].clip;
}
