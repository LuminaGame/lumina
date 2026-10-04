import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A Point or Spot Light placed in a level without a sun or sky
/// light lights it: the viewport's Filament light carries the Details
/// values (cm position, linear colour, lumens → cm-world power, radius,
/// cones), every Details edit reaches it, mobility does not matter, and the
/// viewport camera is exposed for the lamp instead of for a 100 000 lux sun.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_point_light_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  double log2(double v) => math.log(v) / math.ln2;
  final sunny = log2(16 * 16 * 125);

  /// A sunless, skyless level: a Player Start and a floor.
  EditorViewModel sunlessLevel() {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'PointLight'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot([
      EditorActorNode(id: 'start', name: 'PlayerStart', type: 'PlayerStart', location: [0, 0, 0]),
    ]);
    return vm;
  }

  Future<dynamic> mount(WidgetTester tester, EditorViewModel vm) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    for (var i = 0; i < 60 && viewport().nativeSceneForTest == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(viewport().nativeSceneForTest, isNotNull, reason: 'the viewport needs its Filament scene for this test');
    await tester.pump(const Duration(milliseconds: 16));
    return viewport();
  }

  Future<void> unmount(WidgetTester tester, EditorViewModel vm) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    vm.dispose();
  }

  /// The EV100 the viewport's Filament camera renders at, read from the
  /// camera itself.
  double cameraEv(dynamic viewport) {
    final FilamentCamera camera = (viewport.nativeViewForTest as FilamentView).camera!;
    return log2(camera.aperture * camera.aperture / camera.shutterSpeed * 100 / camera.sensitivity);
  }

  void expectVector(List<double> actual, List<double> expected, {double tol = 1e-3, String? reason}) {
    for (var i = 0; i < 3; i++) {
      expect(actual[i], closeTo(expected[i], tol), reason: '${reason ?? ''} $actual vs $expected');
    }
  }

  testWidgets('the user\'s red Point Light in a sunless level: Filament light, Details edits, mobility, exposure',
      (tester) async {
    final vm = sunlessLevel();
    final viewport = await mount(tester, vm);
    final FilamentScene scene = viewport.nativeSceneForTest;
    final lm = FilamentLightManager(viewport.nativeEngineForTest as FilamentEngine);
    expect(scene.lightCount, 0);
    expect(cameraEv(viewport), closeTo(sunny, 1e-3), reason: 'nothing to meter: sunny 16');

    // Place Actors ▸ Lights ▸ Point Light, then the user's Details values.
    vm.spawnNewActor('PointLight');
    final lamp = vm.actors.last;
    vm.selectActorById(lamp.id);
    final c = LightActorProperties.componentOf(lamp)!;
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'intensity', 55695.0);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'colorHex', '#D22121');
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'attenuationRadius', 2000.0);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'castShadows', true);
    vm.updateActorLocation([300.0, -200.0, 120.0]);
    await tester.pump(const Duration(milliseconds: 16));

    final entity = (viewport.editorLightEntitiesForTest as List).single as int;
    expect(scene.hasEntity(entity), isTrue);
    expect(lm.isPoint(entity), isTrue);
    // cm, Z-up authoring → the runtime's Y-up cm world.
    final expectedPosition = LuminaAxes.location([300.0, -200.0, 120.0]);
    expectVector(lm.getPosition(entity), [expectedPosition.x, expectedPosition.y, expectedPosition.z], reason: 'position');
    // #D22121 is sRGB: Filament gets linear RGB.
    final linear = luminaLightColorFromHex('#D22121');
    expectVector(lm.getColor(entity), [linear.x, linear.y, linear.z], tol: 1e-4, reason: 'linear colour');
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(55695) / (4 * math.pi), 1.0), reason: 'lm → cd, cm world');
    expect(lm.getFalloff(entity), closeTo(2000, 1e-3));
    expect(lm.isShadowCaster(entity), isTrue);

    // The camera is exposed for the lamp (1 108 lux at 2 m), not the sun.
    final lampEv = log2(55695 / (4 * math.pi) / 4 / 2.5);
    expect(cameraEv(viewport), closeTo(lampEv, 1e-3), reason: 'metered for the lamp, not sunny 16');

    // A scrubbed intensity (not committed, then committed) follows live, and
    // so does the exposure.
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'intensity', 20000.0, isCommit: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(20000) / (4 * math.pi), 1.0));
    expect(cameraEv(viewport), closeTo(log2(20000 / (4 * math.pi) / 4 / 2.5), 1e-3));
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'intensity', 55695.0);
    // Colour, radius and shadows.
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'colorHex', '#2140D2');
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'attenuationRadius', 800.0);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'castShadows', false);
    await tester.pump(const Duration(milliseconds: 16));
    expect((viewport.editorLightEntitiesForTest as List).single, entity, reason: 'updated in place');
    final blue = luminaLightColorFromHex('#2140D2');
    expectVector(lm.getColor(entity), [blue.x, blue.y, blue.z], tol: 1e-4);
    expect(lm.getFalloff(entity), closeTo(800, 1e-3));
    expect(lm.isShadowCaster(entity), isFalse);

    // Moved (the gizmo's drag path): the light moves with the actor.
    vm.updateActorLocation([-150.0, 400.0, 60.0], isCommit: false);
    await tester.pump(const Duration(milliseconds: 16));
    final moved = LuminaAxes.location([-150.0, 400.0, 60.0]);
    expectVector(lm.getPosition(entity), [moved.x, moved.y, moved.z], reason: 'moved');

    // Static, Stationary and Movable all light the level the same way (no
    // lightmaps exist to bake a static light into).
    for (final mobility in ['Static', 'Stationary', 'Movable']) {
      vm.updateActorMobility(mobility);
      await tester.pump(const Duration(milliseconds: 16));
      final e = (viewport.editorLightEntitiesForTest as List).single as int;
      expect(scene.hasEntity(e), isTrue, reason: '$mobility light is in the scene');
      expect(lm.getIntensity(e), closeTo(LuminaUnits.lightPower(55695) / (4 * math.pi), 1.0), reason: mobility);
      expect(cameraEv(viewport), closeTo(lampEv, 1e-3), reason: mobility);
    }

    // Play builds the same light and meters the same exposure.
    final pie = EditorPieGame.mapEditorActor(vm.actors.last) as LuminaActor;
    final pieLight = pie.rootComponent as LuminaPointLightComponent;
    expectVector([pieLight.color.x, pieLight.color.y, pieLight.color.z], [blue.x, blue.y, blue.z], tol: 1e-6);
    expect(LuminaAutoExposure.ev100For([pieLight]), closeTo(cameraEv(viewport), 1e-3));

    // A sun brings back the daylight exposure; deleting it returns to the lamp.
    vm.spawnNewActor('DirectionalLight');
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.lightCount, 2);
    expect(cameraEv(viewport), closeTo(sunny, 1e-3), reason: 'a 100 000 lux sun: sunny 16');
    vm.selectActorById(vm.actors.last.id);
    vm.deleteSelectedActor();
    await tester.pump(const Duration(milliseconds: 16));
    expect(cameraEv(viewport), closeTo(lampEv, 1e-3));

    await unmount(tester, vm);
  });

  testWidgets('the user\'s Spot Light: pointing down, cones in radians, metered exposure', (tester) async {
    final vm = sunlessLevel();
    final viewport = await mount(tester, vm);
    final lm = FilamentLightManager(viewport.nativeEngineForTest as FilamentEngine);

    vm.spawnNewActor('SpotLight');
    final spot = vm.actors.last;
    vm.selectActorById(spot.id);
    final c = LightActorProperties.componentOf(spot)!;
    vm.updateComponentPropertyWithTransaction(spot.id, c.id, 'intensity', 50000.0);
    vm.updateComponentPropertyWithTransaction(spot.id, c.id, 'colorHex', '#FFFFFF');
    vm.updateComponentPropertyWithTransaction(spot.id, c.id, 'attenuationRadius', 2000.0);
    vm.updateActorLocation([100.0, 50.0, 300.0]);
    await tester.pump(const Duration(milliseconds: 16));

    final entity = (viewport.editorLightEntitiesForTest as List).single as int;
    expect(lm.isSpot(entity), isTrue);
    final dir = lm.getDirection(entity);
    expect(dir[1], lessThan(-0.99), reason: 'the placed spot light points down: $dir');
    final pie = (EditorPieGame.mapEditorActor(spot) as LuminaActor).rootComponent as LuminaSpotLightComponent;
    expectVector(dir, [pie.lightDirection.x, pie.lightDirection.y, pie.lightDirection.z], tol: 1e-4, reason: 'as Play builds it');
    // The stored cone angles are half-angles in degrees; Filament's in radians.
    expect(lm.getSpotLightInnerCone(entity), closeTo(30 * math.pi / 180, 5e-3), reason: 'Filament stores the cone as cosines (float precision)');
    expect(lm.getSpotLightOuterCone(entity), closeTo(45 * math.pi / 180, 5e-3), reason: 'Filament stores the cone as cosines (float precision)');
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(50000) / math.pi, 1.0), reason: 'spot: lm / π');
    vm.updateComponentPropertyWithTransaction(spot.id, c.id, 'outerConeAngle', 60.0);
    vm.updateComponentPropertyWithTransaction(spot.id, c.id, 'innerConeAngle', 20.0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(lm.getSpotLightInnerCone(entity), closeTo(20 * math.pi / 180, 5e-3), reason: 'Filament stores the cone as cosines (float precision)');
    expect(lm.getSpotLightOuterCone(entity), closeTo(60 * math.pi / 180, 5e-3), reason: 'Filament stores the cone as cosines (float precision)');

    expect(cameraEv(viewport), closeTo(log2(50000 / math.pi / 4 / 2.5), 1e-3), reason: 'metered for the spot light');
    await unmount(tester, vm);
  });

  testWidgets('a Spot Light\'s Details panel has the Mobility row, like every actor\'s', (tester) async {
    final vm = sunlessLevel();
    addTearDown(vm.dispose);
    vm.spawnNewActor('SpotLight');
    vm.selectActorById(vm.actors.last.id);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: vm))));
    await tester.pump(const Duration(milliseconds: 50));
    for (final label in ['MOBILITY', 'Static', 'Stationary', 'Movable', 'Inner Cone Angle', 'Outer Cone Angle']) {
      expect(find.text(label, skipOffstage: false), findsWidgets, reason: label);
    }
    await tester.tap(find.text('Static'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.actors.last.mobility, 'Static');
  });

  testWidgets('a placed Blueprint actor containing a light component lights the level viewport', (tester) async {
    final vm = sunlessLevel();
    // Register an open Blueprint document with a spot light
    final bpDoc = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'root',
          'name': 'DefaultSceneRoot',
          'type': 'LuminaSceneComponent',
        },
        {
          'id': 'lamp',
          'name': 'SpotLight',
          'type': 'SpotLightComponent',
          'parentId': 'root',
          'properties': {
            'intensity': 45000.0,
            'attenuationRadius': 1500.0,
          },
        },
      ],
    });
    vm.registerInMemoryBlueprintDocument('BP_LightTower', bpDoc);

    final viewport = await mount(tester, vm);
    final FilamentScene scene = viewport.nativeSceneForTest;
    final lm = FilamentLightManager(viewport.nativeEngineForTest as FilamentEngine);

    // Place an instance of BP_LightTower in the level
    vm.restoreSnapshot([
      EditorActorNode(
        id: 'start',
        name: 'PlayerStart',
        type: 'PlayerStart',
        location: [0, 0, 0],
      ),
      EditorActorNode(
        id: 'tower_1',
        name: 'BP_LightTower_1',
        type: 'Actor',
        blueprintClass: 'BP_LightTower',
        location: [200.0, 100.0, 300.0],
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 16));

    final cls = vm.pieController.registry.classFor('BP_LightTower');
    expect(cls, isNotNull);
    expect(cls!.hasErrors, isFalse, reason: 'diagnostics: ${cls.diagnostics.map((d) => d.message).toList()}');
    final built = EditorPieGame.mapEditorActor(vm.actors.last, registry: vm.pieController.registry);
    expect(built, isA<LuminaActor>());
    final comps = (built as LuminaActor).components.whereType<LuminaLightComponent>().toList();
    expect(comps.length, 1);

    final entities = viewport.editorLightEntitiesForTest as List<int>;
    expect(entities.length, 1, reason: 'the light inside BP_LightTower is realised in the scene');
    final entity = entities.first;
    expect(scene.hasEntity(entity), isTrue);
    expect(lm.isSpot(entity), isTrue);
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(45000) / math.pi, 50.0));

    await unmount(tester, vm);
  });
}
