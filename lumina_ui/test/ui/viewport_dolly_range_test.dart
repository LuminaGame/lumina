import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The orbit camera's dolly was capped at 5000 cm, so in a level
/// framed from further out (the Third Person template's 60 m yard is framed
/// from ~120 m) the first scroll jumped the camera in to 50 m. Now
/// the dolly range scales with the level's bounds.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_viewport_dolly_range_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  EditorViewModel vmWith(List<EditorActorNode> actors) {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DollyRange'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot(actors);
    return vm;
  }

  test('one scroll in a level framed from beyond 50 m moves one step, not to 50 m', () {
    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    final vm = vmWith(template.levelActors.map(EditorActorNode.fromMap).toList());
    addTearDown(vm.dispose);
    vm.frameLevelBounds();
    final framed = vm.cameraDistance;
    expect(framed, greaterThan(5000.0), reason: 'the 60 m yard is framed from further than 50 m');
    final step = 60.0 * 0.8 * vm.cameraSpeedMultiplier;

    vm.dollyCamera(-60.0);
    expect(vm.cameraDistance, closeTo(framed - step, 1e-6), reason: 'a scroll in is one step, not a jump to 5000 cm');
    vm.dollyCamera(60.0);
    vm.dollyCamera(60.0);
    expect(vm.cameraDistance, closeTo(framed + step, 1e-6), reason: 'and out again past the framing distance');

    // Dollying out stops at a range that scales with the level: twice the
    // distance that frames it.
    for (var i = 0; i < 20000; i++) {
      vm.dollyCamera(600.0);
    }
    expect(vm.cameraDistance, closeTo(framed * 2.0, 1e-6));
    expect(vm.maxCameraDistance, closeTo(framed * 2.0, 1e-6));
  });

  test('a small level keeps the 50 m floor; an empty one too', () {
    final vm = vmWith([
      EditorActorNode(id: 'a', name: 'Cube', type: 'StaticMesh', location: [0, 0, 0]),
      EditorActorNode(id: 'b', name: 'Cube2', type: 'StaticMesh', location: [300, 0, 0]),
    ]);
    addTearDown(vm.dispose);
    expect(vm.maxCameraDistance, 5000.0);
    for (var i = 0; i < 2000; i++) {
      vm.dollyCamera(600.0);
    }
    expect(vm.cameraDistance, 5000.0);

    final empty = vmWith(const []);
    addTearDown(empty.dispose);
    expect(empty.maxCameraDistance, 5000.0);
  });
}
