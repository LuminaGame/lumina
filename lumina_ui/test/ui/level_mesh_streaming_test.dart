import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_camera_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';

/// A level's meshes stream in a few at a time, nearest to the camera first,
/// with progress the stat strip can show; nothing waits for the whole level.
void main() {
  late Directory tempDir;
  late Directory projectsDir;
  final glb = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_stream_');
    projectsDir = Directory('${tempDir.path}/projects')..createSync();
    // The derived-data cache may still be writing next to the project when
    // the test ends; give it a moment before the folder goes.
    addTearDown(() async {
      for (var i = 0; i < 40; i++) {
        try {
          tempDir.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      tempDir.deleteSync(recursive: true);
    });
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'StreamGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: projectsDir.path,
        enableTimers: false,
        autoInitAssets: false,
        cameraStore: EditorCameraStore(configDir: Directory('${tempDir.path}/config')),
      );

  test('meshes load four at a time, nearest to the camera first, with progress; the level is framed once they are in', () async {
    if (!glb.existsSync()) {
      markTestSkipped('needs test-assets/Props/Barrels/fuel_barrel_red.glb');
      return;
    }
    final vm = makeEditor();
    addTearDown(vm.dispose);
    // Twelve copies of a real prop, each its own file, spread along X; the
    // camera pivot sits at the far end so the order is the reverse of the ids.
    final meshDir = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    final actors = <EditorActorNode>[];
    for (var i = 0; i < 12; i++) {
      final copy = glb.copySync('${meshDir.path}/barrel_$i.glb');
      actors.add(EditorActorNode(
        id: 'barrel_$i',
        name: 'Barrel $i',
        type: 'StaticMesh',
        location: [i * 200.0, 0.0, 0.0],
        meshAssetPath: copy.path,
      ));
    }
    actors.add(EditorActorNode(id: 'sun', name: 'Sun', type: 'DirectionalLight', location: [0.0, 0.0, 1000.0]));
    vm.restoreSnapshot(actors);
    vm.restoreCameraSnapshot([-35, 25, 500, 11 * 200.0, 0, 0]);
    final cameraBefore = vm.cameraState;

    var notifications = 0;
    vm.addListener(() => notifications++);
    final run = vm.loadLevelMeshes(reframeWhenDone: true);
    expect(vm.meshesLoading, isTrue);
    expect(vm.meshesToLoad, 13, reason: 'every actor without mesh data counts, the light too');
    expect(vm.meshLoadOrder.take(4), ['barrel_11', 'barrel_10', 'barrel_9', 'barrel_8'],
        reason: 'the four workers start on the actors nearest the camera pivot');
    await run;
    expect(vm.meshesLoading, isFalse);
    expect(vm.meshesToLoad, 0);
    expect(vm.meshLoadOrder.where((id) => id.startsWith('barrel')).toList(),
        [for (var i = 11; i >= 0; i--) 'barrel_$i']);
    for (final a in vm.actors.where((a) => a.id.startsWith('barrel'))) {
      expect(a.meshData, isNotNull, reason: '${a.id} has mesh data');
      expect(a.meshData!.minBounds, hasLength(3));
    }
    expect(notifications, greaterThan(0));
    expect(notifications, lessThanOrEqualTo(2 * 13 + 2), reason: 'bounded by the arrivals, never per frame or per worker step');
    expect(vm.cameraState, isNot(cameraBefore), reason: 'framed from the mesh bounds once they were in');
    expect(vm.cameraState.panX, closeTo(11 * 200.0 / 2, 60), reason: 'the pivot moved to the row of barrels');
  });

  test('a camera the user moved during the stream is left alone', () async {
    if (!glb.existsSync()) {
      markTestSkipped('needs test-assets/Props/Barrels/fuel_barrel_red.glb');
      return;
    }
    final vm = makeEditor();
    addTearDown(vm.dispose);
    final copy = glb.copySync('${vm.projectDirPath}/barrel.glb');
    vm.restoreSnapshot([
      EditorActorNode(id: 'b', name: 'Barrel', type: 'StaticMesh', location: [0.0, 0.0, 0.0], meshAssetPath: copy.path),
    ]);
    final run = vm.loadLevelMeshes(reframeWhenDone: true);
    vm.orbitCamera(50, 0);
    final moved = vm.cameraState;
    await run;
    expect(vm.cameraState, moved);
  });

  test('the stat strip counts the meshes still streaming and nothing else otherwise', () {
    const stats = ToolbarFrameStats(fps: 60, frameMs: 16.6, cpuMs: 1.2, gpuMs: -1, fromWorld: false);
    expect(stats.label(1200), 'Tris: 1200  GPU: --ms  CPU: 1.2ms  60 FPS');
    expect(stats.label(1200, meshesLoaded: 12, meshesToLoad: 2000), startsWith('Meshes: 12/2000  Tris: 1200'));
    expect(stats.label(1200, meshesLoaded: 5, meshesToLoad: 5), startsWith('Tris:'));
  });
}
