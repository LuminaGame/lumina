import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  group('EditorViewModel Real Data Tests', () {
    late EditorViewModel viewModel;
    late Directory projectsDir;

    setUp(() async {
      // Real disk I/O, real .lmproject/.lmas files — but in this test's own
      // directory. Defaulting to ~/Lumina Projects made every file in the suite
      // share one project, so a whole-suite run depended on what the others did
      // first, and it wrote into the developer's actual work.
      projectsDir = Directory.systemTemp.createTempSync('editor_vm_test_');

      // The folder tree a real project has. `AssetRepository.createAsset` opens
      // files without creating parents, so the view model's default-level
      // scaffolding needs these to exist — which is the only reason this test
      // ever worked against the real ~/Lumina Projects.
      const projectName = 'MyFirstLuminaGame';
      final projectDir = Directory('${projectsDir.path}/$projectName');
      for (final folder in const [
        'contents/meshes/static',
        'contents/meshes/skeletal',
        'contents/materials',
        'contents/textures',
        'contents/animations',
        'contents/audio',
        'contents/particles',
        'contents/levels',
        'contents/blueprints',
        'contents/ui',
      ]) {
        Directory('${projectDir.path}/$folder').createSync(recursive: true);
      }
      File('${projectDir.path}/$projectName.lmproject').writeAsStringSync(
        jsonEncode(const LuminaProject(
          projectName: projectName,
          engineVersion: '0.0.1',
          activeLevel: 'contents/levels/L_OpenWorld_Main.lmas',
        ).toMap()),
      );

      viewModel = EditorViewModel(projectLocation: projectsDir.path);
      await viewModel.ensureDefaultLevelAssets();
      viewModel.refreshAssets();
    });

    tearDown(() {
      viewModel.dispose();
      if (projectsDir.existsSync()) {
        projectsDir.deleteSync(recursive: true);
      }
    });

    test('works inside its own directory, never the real projects folder', () {
      expect(
        viewModel.projectDirPath,
        startsWith(projectsDir.path),
        reason: 'a test that writes into ~/Lumina Projects mutates real work and '
            'makes parallel runs depend on each other',
      );
    });

    test('Should initialize with Lumina Engine 0.0.1 default state', () {
      expect(viewModel.engineVersion, equals('0.0.1'));
      expect(viewModel.activeLevelName, equals('L_OpenWorld_Main'));
      expect(viewModel.isPlaying, isFalse);
      expect(viewModel.actors.isNotEmpty, isTrue);
    });

    test('Should toggle play/pause/stop simulation state', () {
      viewModel.startSimulation();
      expect(viewModel.isPlaying, isTrue);
      expect(viewModel.isPaused, isFalse);

      viewModel.togglePauseSimulation();
      expect(viewModel.isPaused, isTrue);

      viewModel.stopSimulation();
      expect(viewModel.isPlaying, isFalse);
    });

    test('Should update quality preset and VSync settings', () {
      viewModel.updateQualityPreset('high');
      expect(viewModel.qualityPreset, equals('high'));

      final initialVsync = viewModel.vsyncEnabled;
      viewModel.toggleVSync();
      expect(viewModel.vsyncEnabled, equals(!initialVsync));
    });

    test('Should select actor and update transform values', () {
      final firstActor = viewModel.actors.first;
      viewModel.selectActor(firstActor);

      expect(viewModel.selectedActor, equals(firstActor));

      viewModel.updateActorLocation([10.0, 20.0, 30.0]);
      expect(viewModel.selectedActor!.location, equals([10.0, 20.0, 30.0]));
      expect(viewModel.project.isDirty, isTrue);

      viewModel.updateActorMobility('Stationary');
      expect(viewModel.selectedActor!.mobility, equals('Stationary'));

      viewModel.updateActorLightIntensity(8000.0);
      expect(viewModel.selectedActor!.lightIntensity, equals(8000.0));

      viewModel.updateActorCastShadows(false);
      expect(viewModel.selectedActor!.castShadows, isFalse);
    });

    test('Should toggle the real render features and the resolution scale', () {
      // These used to be "Ray Tracing" and "Lumen", which Filament
      // does not have. They are now passes it really runs.
      viewModel.toggleSsao();
      expect(viewModel.ssaoEnabled, isFalse);

      viewModel.toggleBloom();
      expect(viewModel.bloomEnabled, isFalse);

      viewModel.toggleScreenSpaceReflections();
      expect(viewModel.screenSpaceReflectionsEnabled, isFalse);

      viewModel.updateResolutionScale(125.0);
      expect(viewModel.resolutionScale, equals(125.0));
      expect(viewModel.quality.profile.dynamicResolution.maxScaleX, closeTo(1.25, 1e-9));
    });

    test('Should clear logs from logger stream', () {
      viewModel.clearLogs();
      expect(viewModel.logs.isEmpty, isTrue);
    });

    test('Should execute processImportPipeline on real test file and manage isImporting state', () async {
      final testFile = File('${Directory.systemTemp.path}/test_cube.glb');
      testFile.writeAsStringSync('dummy glb content');

      expect(viewModel.isImporting, isFalse);

      final future = viewModel.processImportPipeline(sourceFilePath: testFile.path);
      expect(viewModel.isImporting, isTrue);
      expect(viewModel.importStatusMessage.isNotEmpty, isTrue);

      await future;

      expect(viewModel.isImporting, isFalse);
      expect(viewModel.importStatusMessage.isEmpty, isTrue);
      expect(viewModel.realAssets.isNotEmpty, isTrue);

      if (testFile.existsSync()) {
        testFile.deleteSync();
      }
    });

    test('Should create Blueprint with parent class', () async {
      await viewModel.createBlueprintWithParent(name: 'BP_HeroPawn', parentClass: 'LuminaPawn');
      expect(viewModel.realAssets.any((a) => a.fileName.contains('BP_HeroPawn')), isTrue);
    });

    test('Should support RMB Free-Look camera rotation with pitch clamping', () {
      final initialYaw = viewModel.cameraYaw;
      final initialPitch = viewModel.cameraPitch;

      viewModel.rotateCamera(20.0, 10.0);
      expect(viewModel.cameraYaw, equals(initialYaw + 20.0 * 0.25));
      expect(viewModel.cameraPitch, equals(initialPitch - 10.0 * 0.25));

      // Test extreme pitch clamping (-89° to +89°)
      viewModel.rotateCamera(0.0, 1000.0);
      expect(viewModel.cameraPitch, equals(-89.0));

      viewModel.rotateCamera(0.0, -2000.0);
      expect(viewModel.cameraPitch, equals(89.0));
    });

    test('Should support LMB Walk & Turn navigation', () {
      final initialPanX = viewModel.cameraPanX;
      final initialPanY = viewModel.cameraPanY;
      final initialYaw = viewModel.cameraYaw;

      viewModel.walkMove(10.0, -20.0);
      expect(viewModel.cameraYaw, equals(initialYaw + 10.0 * 0.25));
      // Should have moved along ground forward
      expect(viewModel.cameraPanX != initialPanX || viewModel.cameraPanY != initialPanY, isTrue);
    });

    test('Should support MMB Screen-Space Pan & Track', () {
      final initialPanX = viewModel.cameraPanX;
      final initialPanY = viewModel.cameraPanY;

      viewModel.panCamera(15.0, -10.0);
      expect(viewModel.cameraPanX != initialPanX || viewModel.cameraPanY != initialPanY, isTrue);
    });

    test('Should support Alt + LMB Orbit and Alt + RMB Dolly', () {
      final initialYaw = viewModel.cameraYaw;
      final initialPitch = viewModel.cameraPitch;
      final initialDist = viewModel.cameraDistance;

      viewModel.orbitCamera(15.0, 10.0);
      expect(viewModel.cameraYaw, equals(initialYaw + 15.0 * 0.3));
      expect(viewModel.cameraPitch, equals(initialPitch + 10.0 * 0.3));

      viewModel.dollyCamera(-50.0);
      expect(viewModel.cameraDistance, lessThan(initialDist));

      viewModel.dollyCamera(100.0);
      expect(viewModel.cameraDistance, greaterThan(initialDist - 50.0));
    });

    test('Should support continuous 3D flycam with Shift boost and Ctrl slow', () {
      viewModel.resetCamera();
      final startX = viewModel.cameraPanX;
      final startY = viewModel.cameraPanY;

      // Normal flight forward
      viewModel.flyWASD(
        forward: true,
        backward: false,
        left: false,
        right: false,
        up: false,
        down: false,
        dt: 0.016,
      );
      final normalMoveDist = (viewModel.cameraPanX - startX).abs() + (viewModel.cameraPanY - startY).abs();
      expect(normalMoveDist, greaterThan(0.0));

      // Flight with Shift Boost (2.5x speed)
      viewModel.resetCamera();
      viewModel.flyWASD(
        forward: true,
        backward: false,
        left: false,
        right: false,
        up: false,
        down: false,
        dt: 0.016,
        boost: true,
      );
      final boostMoveDist = (viewModel.cameraPanX - startX).abs() + (viewModel.cameraPanY - startY).abs();
      expect(boostMoveDist, greaterThan(normalMoveDist * 2.0));

      // Flight with Ctrl Slow (0.3x speed)
      viewModel.resetCamera();
      viewModel.flyWASD(
        forward: true,
        backward: false,
        left: false,
        right: false,
        up: false,
        down: false,
        dt: 0.016,
        slow: true,
      );
      final slowMoveDist = (viewModel.cameraPanX - startX).abs() + (viewModel.cameraPanY - startY).abs();
      expect(slowMoveDist, lessThan(normalMoveDist));
    });

    test('Should adjust camera speed scalar (Levels 1 to 8)', () {
      expect(viewModel.cameraSpeedScalar, equals(4));
      expect(viewModel.cameraSpeedMultiplier, equals(1.0));

      viewModel.adjustCameraSpeed(1);
      expect(viewModel.cameraSpeedScalar, equals(5));
      expect(viewModel.cameraSpeedMultiplier, equals(2.0));

      viewModel.setCameraSpeed(8);
      expect(viewModel.cameraSpeedScalar, equals(8));
      expect(viewModel.cameraSpeedMultiplier, equals(16.0));

      // Clamping test
      viewModel.adjustCameraSpeed(5);
      expect(viewModel.cameraSpeedScalar, equals(8));

      viewModel.setCameraSpeed(1);
      expect(viewModel.cameraSpeedScalar, equals(1));
      expect(viewModel.cameraSpeedMultiplier, equals(0.1));
    });

    test('Should frame and focus camera on selected actor (F key shortcut)', () {
      final targetActor = viewModel.actors.first;
      targetActor.location = [120.0, -80.0, 45.0];

      viewModel.focusCameraOnActor(targetActor);

      expect(viewModel.selectedActor, equals(targetActor));
      expect(viewModel.cameraPanX, equals(120.0));
      expect(viewModel.cameraPanY, equals(-80.0));
      expect(viewModel.cameraPanZ, equals(45.0));
      expect(viewModel.cameraDistance, greaterThanOrEqualTo(80.0));
    });
  });
}
