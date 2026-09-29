import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/testing.dart';

import '../helpers/cc_body_asset.dart';

/// The Character Creator bodies are found portably, and a test
/// that cannot find one is told why instead of passing without running.
void main() {
  late Directory temp;
  late File glb;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('cc_body_asset_');
    glb = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A real GLB saved under the CC body's name in [dir].
  File place(String dir) {
    Directory(dir).createSync(recursive: true);
    return glb.copySync('$dir/${CcBodyAsset.male}');
  }

  test('LUMINA_CC_BODY_DIR comes first, then test-assets, then <home>/Documents/outfiles', () {
    if (!glb.existsSync()) return markTestSkipped('test-assets missing');
    final explicit = place('${temp.path}/explicit');
    final assets = place('${temp.path}/assets/Characters/CCMH');
    final home = place('${temp.path}/home/Documents/outfiles');

    CcBodyAsset resolve({bool withEnv = true, bool withAssets = true}) => CcBodyAsset.resolve(
          CcBodyAsset.male,
          environment: {
            if (withEnv) 'LUMINA_CC_BODY_DIR': '${temp.path}/explicit',
            'USERPROFILE': '${temp.path}/home',
          },
          testAssetsDir: withAssets ? Directory('${temp.path}/assets') : Directory('${temp.path}/none'),
        );

    expect(resolve().file!.path, explicit.path);
    expect(resolve(withEnv: false).file!.path, assets.path.replaceAll(r'\', '/'));
    expect(resolve(withEnv: false, withAssets: false).file!.path, home.path);
  });

  test('nothing found: no file and a skip reason naming every place looked in', () {
    final found = CcBodyAsset.resolve(
      CcBodyAsset.female,
      environment: {'LUMINA_CC_BODY_DIR': '${temp.path}/explicit', 'HOME': '${temp.path}/home'},
      testAssetsDir: Directory('${temp.path}/assets'),
    );
    expect(found.file, isNull);
    expect(found.skipReason, contains(CcBodyAsset.female));
    expect(found.skipReason, contains('LUMINA_CC_BODY_DIR'));
    expect(found.skipReason, contains('${temp.path}/assets'));
    expect(found.skipReason, contains('${temp.path}/home/Documents/outfiles'));
  });
}
