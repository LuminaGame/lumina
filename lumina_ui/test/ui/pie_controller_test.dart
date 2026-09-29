import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

void main() {
  // PIE takes the keyboard through HardwareKeyboard while a session runs,
  // which needs a binding even in these pure-Dart tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorPieGame.mapEditorActor', () {
    test('maps every editor actor type to a real runtime object', () {
      final pawn = EditorPieGame.mapEditorActor(EditorActorNode(id: 'p', name: 'P', type: 'Pawn', location: [1, 2, 3]));
      expect(pawn, isA<LuminaPawn>());
      expect((pawn as LuminaPawn).actorLocation.x, 1.0);

      final sun = EditorPieGame.mapEditorActor(EditorActorNode(
          id: 's', name: 'Sun', type: 'DirectionalLight', location: [0, 0, 0], lightIntensity: 4200.0, lightColorHex: '#FF8000', castShadows: true));
      expect(sun, isA<LuminaActor>());
      final sunRoot = (sun as LuminaActor).rootComponent;
      expect(sunRoot, isA<LuminaDirectionalLightComponent>());
      expect((sunRoot as LuminaDirectionalLightComponent).intensity, 4200.0);
      expect(sunRoot.color.x, closeTo(1.0, 1e-6));
      // #FF8000 is sRGB; Filament lights take linear RGB.
      expect(sunRoot.color.y, closeTo(luminaSrgbToLinear(0x80 / 255.0), 1e-6));
      expect(sunRoot.color.z, closeTo(0.0, 1e-6));

      expect((EditorPieGame.mapEditorActor(EditorActorNode(id: 'l', name: 'L', type: 'Light', location: [0, 0, 0])) as LuminaActor).rootComponent,
          isA<LuminaDirectionalLightComponent>());
      expect((EditorPieGame.mapEditorActor(EditorActorNode(id: 'pl', name: 'PL', type: 'PointLight', location: [0, 0, 0])) as LuminaActor).rootComponent,
          isA<LuminaPointLightComponent>());
      expect((EditorPieGame.mapEditorActor(EditorActorNode(id: 'sl', name: 'SL', type: 'SpotLight', location: [0, 0, 0])) as LuminaActor).rootComponent,
          isA<LuminaSpotLightComponent>());

      final mesh = EditorPieGame.mapEditorActor(EditorActorNode(
          id: 'm', name: 'Rock', type: 'StaticMesh', location: [5, 0, 0], scale: [2, 2, 2], meshAssetPath: '/tmp/rock.glb')) as LuminaActor;
      expect(mesh.rootComponent, isA<LuminaStaticMeshComponent>());
      expect((mesh.rootComponent as LuminaStaticMeshComponent).meshAssetPath, '/tmp/rock.glb');
      expect(mesh.actorScale.x, 2.0);

      final meshNoGeometry = EditorPieGame.mapEditorActor(EditorActorNode(id: 'm2', name: 'Ghost', type: 'Mesh', location: [0, 0, 0])) as LuminaActor;
      expect(meshNoGeometry.rootComponent, isA<LuminaSceneComponent>());
      expect(meshNoGeometry.rootComponent, isNot(isA<LuminaStaticMeshComponent>()));

      expect(EditorPieGame.mapEditorActor(EditorActorNode(id: 'f', name: 'Folder', type: 'Folder', location: [0, 0, 0])), isNull);
      expect(EditorPieGame.mapEditorActor(EditorActorNode(id: 'e', name: 'Sky', type: 'Environment', location: [0, 0, 0])), isA<LuminaActor>());
    });

    test('euler degrees convert to a unit quaternion', () {
      final q = EditorPieGame.eulerDegreesToQuaternion([30, 90, -45]);
      expect(q.length, closeTo(1.0, 1e-9));
      // Must match the Z*Y*X matrix composition the viewport uses.
      final m = vm64.Matrix4.rotationZ(-45 * math.pi / 180) *
          vm64.Matrix4.rotationY(90 * math.pi / 180) *
          vm64.Matrix4.rotationX(30 * math.pi / 180);
      final expected = m.transform3(vm64.Vector3(1, 0, 0));
      // vector_math's Quaternion.rotate uses the opposite handedness from its
      // own asRotationMatrix; the runtime composes transforms via matrices.
      final v = q.asRotationMatrix().transform(vm64.Vector3(1, 0, 0));
      expect(v.x, closeTo(expected.x, 1e-9));
      expect(v.y, closeTo(expected.y, 1e-9));
      expect(v.z, closeTo(expected.z, 1e-9));
    });

    test('game build produces one runtime child per non-folder actor', () {
      final actors = [
        EditorActorNode(id: '1', name: 'A', type: 'Pawn', location: [0, 0, 0]),
        EditorActorNode(id: '2', name: 'B', type: 'Folder', location: [0, 0, 0]),
        EditorActorNode(id: '3', name: 'C', type: 'PointLight', location: [0, 0, 0]),
      ];
      final children = actors.map(EditorPieGame.mapEditorActor).whereType<LuminaObject>().toList();
      expect(children.length, 2);
    });
  });

  // These two ran on a hand-written `MockFilamentEngine`, which threw
  // as soon as PIE mounted the starter level's sun. They now mount the real
  // starter level of a real temp project on a real headless (noop) engine.
  group('a PIE session on a real engine', () {
    late Directory tempDir;
    late EditorViewModel vm;
    late FilamentEngine engine;
    late FilamentScene scene;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('lumina_pie_controller_');
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'PieProject'),
        projectLocation: tempDir.path,
        enableTimers: false,
      );
      // The constructor starts the starter-level load; seed nothing before it lands.
      await vm.ensureDefaultLevelAssets();
    });

    tearDown(() {
      vm.dispose();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// A real Filament engine on the noop backend (no GPU needed).
    bool createEngine() {
      final created = FilamentEngine.create(backend: FilamentBackend.noop);
      if (created == null) return false;
      engine = created;
      scene = engine.createScene();
      addTearDown(engine.dispose);
      return true;
    }

    test('startPie mounts LuminaWorld and restores on stop', () {
      if (!createEngine()) return markTestSkipped('flutter_filament native library unavailable');
      expect(vm.actors.any((a) => a.type.contains('Light')), isTrue,
          reason: 'the starter level carries the sun that the mock engine could not create');

      vm.addActorNodeForTest(EditorActorNode(id: '1', name: 'Actor1', type: 'StaticMesh', location: [0, 0, 0]));
      vm.addActorNodeForTest(EditorActorNode(id: '2', name: 'Actor2', type: 'StaticMesh', location: [1, 1, 1]));
      vm.setCameraMode('Perspective');
      final actorsBefore = vm.actors.map((a) => a.id).toList();
      final yawBefore = vm.cameraYaw;
      final entitiesBefore = scene.entityCount;
      final pie = PieController(vm);

      pie.startPie(engine, scene);

      expect(pie.lastError, isNull);
      expect(pie.isPlaying, isTrue);
      expect(pie.game?.gameInstance.world, isNotNull, reason: 'a LuminaWorld must be mounted');
      expect(scene.entityCount, greaterThan(entitiesBefore), reason: 'the level\'s native objects reach the scene');

      // Edits made while playing are thrown away on stop.
      vm.setCameraMode('Top');
      expect(vm.cameraYaw, isNot(yawBefore));
      vm.addActorNodeForTest(EditorActorNode(id: 'pie', name: 'SpawnedDuringPie', type: 'StaticMesh', location: [0, 0, 0]));

      pie.stopPie(engine, scene);

      expect(pie.isPlaying, false);
      expect(pie.lastError, isNull);
      expect(vm.cameraYaw, yawBefore);
      expect(vm.cameraYaw, -35.0); // restored!
      expect(vm.actors.map((a) => a.id).toList(), actorsBefore);
    });

    test('Undo stack frozen during PIE', () {
      if (!createEngine()) return markTestSkipped('flutter_filament native library unavailable');
      final pie = PieController(vm);

      pie.startPie(engine, scene);
      expect(pie.isPlaying, isTrue, reason: pie.lastError ?? '');
      expect(vm.transactions.isFrozen, true);

      pie.stopPie(engine, scene);
      expect(vm.transactions.isFrozen, false);
    });
  });
}
