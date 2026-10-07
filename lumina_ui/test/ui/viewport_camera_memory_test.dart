import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_camera_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The viewport camera when a project opens: the geometry is framed on the
/// first open (markers far away do not count), and the camera a project was
/// last edited with comes back on the next open.
void main() {
  late Directory tempDir;
  late Directory projectsDir;
  late Directory configDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_camera_');
    projectsDir = Directory('${tempDir.path}/projects')..createSync();
    configDir = Directory('${tempDir.path}/config');
    addTearDown(() => tempDir.deleteSync(recursive: true));
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'CameraGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: projectsDir.path,
        enableTimers: false,
        autoInitAssets: false,
        cameraStore: EditorCameraStore(configDir: configDir),
      );

  /// A glTF cube is in metres (drawn ×100), so [half] is half a metre by default.
  GlbMeshData cube(double half) => GlbMeshData(
        positions: [-half, -half, -half, half, half, half],
        indices: const [0, 1, 0],
        minBounds: [-half, -half, -half],
        maxBounds: [half, half, half],
      );

  EditorActorNode mesh(String id, List<double> location, double half) => EditorActorNode(
        id: id,
        name: id,
        type: 'StaticMesh',
        location: location,
        meshAssetPath: '/abs/SM_$id.lmas',
        meshData: cube(half),
      );

  test('framing the level ignores actors without mesh bounds, so a far light does not zoom the camera out', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.restoreSnapshot([
      mesh('barrel', [0.0, 0.0, 0.0], 0.5),
      mesh('crate', [300.0, 100.0, 0.0], 0.5),
      EditorActorNode(id: 'sun', name: 'DirectionalLight_Sun', type: 'DirectionalLight', location: [0.0, 0.0, 500000.0]),
      EditorActorNode(id: 'sky', name: 'SkyAtmosphere_Env', type: 'SkyAtmosphere', location: [-800000.0, 0.0, 0.0]),
    ]);
    vm.frameLevelBounds();
    final cam = vm.cameraState;
    expect(cam.distance, lessThan(1500), reason: 'two barrels 3 m apart, not the sun 5 km up');
    expect(cam.panX, closeTo(150, 1e-6));
    expect(cam.panZ, closeTo(0, 1e-6), reason: 'the pivot sits on the geometry');
  });

  test('a level of nothing but markers still frames them', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.restoreSnapshot([
      EditorActorNode(id: 'start', name: 'PlayerStart', type: 'PlayerStart', location: [100.0, 0.0, 0.0]),
      EditorActorNode(id: 'sun', name: 'Sun', type: 'DirectionalLight', location: [-100.0, 0.0, 0.0]),
    ]);
    vm.frameLevelBounds();
    expect(vm.cameraState.panX, closeTo(0, 1e-6));
    expect(vm.cameraState.distance, greaterThan(0));
  });

  test('the camera is remembered per project and comes back on the next open instead of framing', () async {
    final first = makeEditor();
    expect(await first.restoreSavedCamera(), isFalse, reason: 'never opened here: nothing to restore');
    first.orbitCamera(80, -20);
    first.dollyCamera(-300);
    first.panCamera(40, 10);
    await first.flushCameraState();
    final moved = first.cameraState;
    expect(moved.yaw, isNot(-35.0));
    first.dispose();

    final again = makeEditor();
    addTearDown(again.dispose);
    expect(again.cameraState, isNot(moved));
    expect(await again.restoreSavedCamera(), isTrue);
    expect(again.cameraState, moved);

    // Another project on the same machine keeps its own camera.
    final other = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'OtherGame', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: projectsDir.path,
      enableTimers: false,
      autoInitAssets: false,
      cameraStore: EditorCameraStore(configDir: configDir),
    );
    addTearDown(other.dispose);
    expect(await other.restoreSavedCamera(), isFalse);
  });

  test('a camera file with a broken entry is ignored, not trusted', () async {
    final store = EditorCameraStore(configDir: configDir);
    configDir.createSync(recursive: true);
    store.file.writeAsStringSync('{"${Directory(projectsDir.path).path}/CameraGame": {"yaw": "no", "distance": -5}}');
    final vm = makeEditor();
    addTearDown(vm.dispose);
    expect(await vm.restoreSavedCamera(), isFalse);
    expect(EditorCameraState.fromMap(const {'yaw': 1, 'pitch': 2, 'distance': 0, 'pan': [0, 0, 0]}), isNull);
    final ok = EditorCameraState.fromMap(const {'yaw': 1, 'pitch': 95, 'distance': 10, 'pan': [1, 2, 3], 'mode': 'Top'});
    expect(ok, isNotNull);
    expect(ok!.pitch, 89.0, reason: 'clamped like the camera itself');
    expect(ok.mode, 'Top');
  });
}
