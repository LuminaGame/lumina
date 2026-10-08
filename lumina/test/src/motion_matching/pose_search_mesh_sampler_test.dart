import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/blueprint/anim/anim_motion_matching_driver.dart';
import 'package:lumina_core/testing.dart';

/// The shared per-mesh clip parse: a mesh that cannot be read fails every
/// waiting caller, is forgotten (the next call retries), and a Motion
/// Matching load over it reports the error instead of throwing from its
/// handler.
void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('lumina_mesh_sampler_');
    LuminaPoseSearchDatabaseRuntime.clearShared();
  });
  tearDown(() {
    LuminaPoseSearchDatabaseRuntime.clearShared();
    dir.deleteSync(recursive: true);
  });

  test('a missing mesh fails, is forgotten, and loads once it exists', () async {
    final path = '${dir.path}/Rig.glb';
    await expectLater(LuminaPoseSearchDatabaseRuntime.meshSampler(path, provider: (p) => File(p).readAsBytes()),
        throwsA(isA<FileSystemException>()));
    File(path).writeAsBytesSync(LuminaSyntheticLocomotionRig.build([LuminaSyntheticLocomotionRig.idle('Idle')]));
    final sampler = await LuminaPoseSearchDatabaseRuntime.meshSampler(path, provider: (p) => File(p).readAsBytes());
    expect(sampler.clipIndex('Idle'), 0);
    // Shared: the same parse for the next caller.
    expect(identical(await LuminaPoseSearchDatabaseRuntime.meshSampler(path, provider: (p) => File(p).readAsBytes()), sampler),
        isTrue);
  });

  test('a Motion Matching database over a missing mesh reports the error without an unhandled one', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: '${dir.path}/Missing.glb');
      final driver = LuminaAnimMotionMatchingDriver(mesh, {
        '${dir.path}/PSD.lmas': LuminaPoseSearchDatabaseDocument(
            targetMesh: '${dir.path}/Missing.glb', clips: const [LuminaPoseSearchClip('Idle', loop: true)]),
      });
      await expectLater(driver.load('${dir.path}/PSD.lmas'), throwsA(anything));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(driver.lastError, isNotNull);
      expect(driver.isLoaded('${dir.path}/PSD.lmas'), isFalse);
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty, reason: 'the load error is handled where it is reported');
  });
}
