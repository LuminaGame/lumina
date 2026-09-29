import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  test('setCameraMode(Top) stores pose and toggles ortho', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    vm.setCameraMode('Perspective');
    // Pose snapshot that must survive the ortho round-trip exactly.
    final perspPitch = vm.cameraPitch;
    final perspYaw = vm.cameraYaw;
    final perspDistance = vm.cameraDistance;
    vm.setCameraMode('Top');

    vm.setCameraMode('Top');
    expect(vm.cameraMode, 'Top');
    expect(vm.cameraPitch, -90.0);
    expect(vm.cameraYaw, 0.0);
    expect(vm.cameraDistance, 500); // ortho extent, independent of the orbit distance

    vm.setCameraMode('Perspective');
    expect(vm.cameraMode, 'Perspective');
    expect(vm.cameraPitch, perspPitch);
    expect(vm.cameraYaw, perspYaw);
    expect(vm.cameraDistance, perspDistance);
  });

  test('toggleShowFlag toggles the flag', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    expect(vm.showFlags['Grid'], true);
    
    vm.toggleShowFlag('Grid');
    expect(vm.showFlags['Grid'], false);
  });
}
