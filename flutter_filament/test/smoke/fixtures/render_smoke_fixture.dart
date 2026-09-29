// A real render the report runner tests drive through `tool/smoke_report.dart`
// (test/smoke_report_test.dart): Suzanne under a sun on the backend
// FILAMENT_SMOKE_BACKEND names, published as one PNG. Inside test/smoke/, so
// the runner runs it on both backends; not named `*_test.dart`, so a suite
// run never picks it up on its own.
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import '../smoke_helper.dart';

void main() {
  test('render smoke: suzanne frame to PNG', () {
    final rig = SmokeRig.create();
    addTearDown(rig.dispose);
    rig.addSun();
    rig.scene.createSuzanneSample(rig.view);
    // Before the engine goes (tear-downs run last-registered first): the
    // sample owns its entity, materials and textures.
    addTearDown(rig.scene.destroySuzanneSample);
    final pixels = rig.screenshot('render smoke: suzanne frame to PNG');
    expect(countForegroundPixels(pixels, rig.width), greaterThan(100), reason: 'Suzanne is on screen');
    expect(SmokeArtifacts.dir.path, endsWith(smokeBackendName), reason: 'the runner writes each backend into its folder');
  });
}
