import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// A level authored in metres and a level authored in centimetres both have to
/// be visible when they open. The editor frames what is actually there instead
/// of assuming one scale.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_frame_test_');
    Directory('${tempDir.path}/FrameGame').createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'FrameGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  test('framing centres on the level and pulls back far enough to hold it', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.replaceActorsForTest([
      EditorActorNode(id: 'a', name: 'Floor', type: 'Primitive', location: [-10.0, 0.0, -10.0]),
      EditorActorNode(id: 'b', name: 'Pillar', type: 'Primitive', location: [10.0, 4.0, 10.0]),
    ]);

    vm.frameLevelBounds();
    expect(vm.cameraPanX, closeTo(0.0, 1e-6));
    expect(vm.cameraPanY, closeTo(2.0, 1e-6));
    expect(vm.cameraPanZ, closeTo(0.0, 1e-6));
    // The diagonal is ~28 units, so the camera must sit beyond it, not at the
    // 250-unit default tuned for centimetre-scale props.
    expect(vm.cameraDistance, greaterThan(20.0));
    expect(vm.cameraDistance, lessThan(120.0));
  });

  test('a centimetre-scale level is framed just as well', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.replaceActorsForTest([
      EditorActorNode(id: 'a', name: 'Slab', type: 'Primitive', location: [-1000.0, 0.0, -1000.0]),
      EditorActorNode(id: 'b', name: 'Crate', type: 'Primitive', location: [1000.0, 200.0, 1000.0]),
    ]);

    vm.frameLevelBounds();
    expect(vm.cameraPanX, closeTo(0.0, 1e-6));
    expect(vm.cameraDistance, greaterThan(2000.0));
  });

  test('an empty level leaves the camera where it is', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.replaceActorsForTest([]);
    final before = vm.cameraDistance;
    vm.frameLevelBounds();
    expect(vm.cameraDistance, before);
  });
}
