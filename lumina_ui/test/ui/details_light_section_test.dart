import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_lights.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A placed light's Details panel has a "Light" section
/// (Intensity, Light Color, Attenuation Radius, cone angles, Cast Shadows),
/// its edits reach the edit-mode Filament light live and undo, they persist
/// in the level, and Play builds the same light. A directional light shows
/// an arrow along the exact direction Filament lights from.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_details_light_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  EditorViewModel vm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'LightDetails'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  Future<void> pumpDetails(WidgetTester tester, EditorViewModel model) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: model))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a placed Point Light shows the Light section with its properties', (tester) async {
    final model = vm();
    addTearDown(model.dispose);
    model.spawnNewActor('PointLight');
    final point = model.actors.single;
    model.selectActorById(point.id);
    await pumpDetails(tester, model);

    for (final label in ['Light', 'Intensity', 'Light Color', 'Attenuation Radius', 'Cast Shadows']) {
      expect(find.text(label, skipOffstage: false), findsWidgets, reason: '$label is in the Details panel');
    }
    expect(find.text('Inner Cone Angle', skipOffstage: false), findsNothing, reason: 'cone angles are a spot light\'s');
    final props = LightActorProperties.read(point);
    expect(props.intensity, EditorActorCatalog.byId('PointLight')!.lightIntensity, reason: 'the catalog\'s point light intensity');
    expect(props.attenuationRadius, LightActorProperties.defaultAttenuationRadius);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a Spot Light adds the cone angles; a Directional Light the source angle in lux', (tester) async {
    final model = vm();
    addTearDown(model.dispose);
    model.spawnNewActor('SpotLight');
    model.selectActorById(model.actors.single.id);
    await pumpDetails(tester, model);
    expect(find.text('Inner Cone Angle', skipOffstage: false), findsWidgets);
    expect(find.text('Outer Cone Angle', skipOffstage: false), findsWidgets);

    model.spawnNewActor('DirectionalLight');
    model.selectActorById(model.actors.last.id);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Source Angle', skipOffstage: false), findsWidgets);
    expect(find.text('Attenuation Radius', skipOffstage: false), findsNothing);
    expect(find.textContaining('lux', skipOffstage: false), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a light from an older level (no component) gets its Light section, keeping its values', (tester) async {
    final model = vm();
    addTearDown(model.dispose);
    model.restoreSnapshot([
      EditorActorNode(id: 'old', name: 'OldLamp', type: 'PointLight', location: [0, 0, 100], lightIntensity: 1234.0, lightColorHex: '#FF8000', castShadows: true),
    ]);
    model.selectActorById('old');
    await pumpDetails(tester, model);
    expect(find.text('Attenuation Radius', skipOffstage: false), findsWidgets);
    final c = LightActorProperties.componentOf(model.actors.single)!;
    expect(c.properties['intensity'], 1234.0);
    expect(c.properties['colorHex'], '#FF8000');
    expect(c.properties['castShadows'], isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test('edits reach the edit-mode Filament light live, undo, and persist in the level', () async {
    final model = vm();
    addTearDown(model.dispose);
    model.spawnNewActor('PointLight');
    final point = model.actors.single;
    model.selectActorById(point.id);
    final component = LightActorProperties.componentOf(point)!;

    final lease = FilamentEngineHost.acquire(owner: 'details_light_section_test')!;
    addTearDown(lease.release);
    final scene = lease.engine.createScene();
    addTearDown(scene.dispose);
    final lights = EditorLevelLights()..attach(lease.engine, scene);
    addTearDown(lights.detach);
    final lm = FilamentLightManager(lease.engine);
    void sync() => lights.sync(model.actors, enabled: true);

    sync();
    final entity = lights.lightEntities.single;
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(50000.0) / (4 * math.pi), 1.0));
    expect(lm.getFalloff(entity), closeTo(LightActorProperties.defaultAttenuationRadius, 1e-3));

    // A scrub commits through the same transaction path the Details rows use.
    model.updateComponentPropertyWithTransaction(point.id, component.id, 'intensity', 2000.0);
    model.updateComponentPropertyWithTransaction(point.id, component.id, 'attenuationRadius', 350.0);
    model.updateComponentPropertyWithTransaction(point.id, component.id, 'colorHex', '#00FF00');
    sync();
    expect(lights.lightEntities.single, entity, reason: 'updated in place, not rebuilt');
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(2000.0) / (4 * math.pi), 1.0));
    expect(lm.getFalloff(entity), closeTo(350.0, 1e-3));
    final colour = lm.getColor(entity);
    expect(colour[1], greaterThan(colour[0] * 4));

    model.transactions.undo();
    sync();
    expect(lm.getColor(entity)[0], closeTo(lm.getColor(entity)[1], 1e-6), reason: 'white again');
    model.transactions.undo();
    model.transactions.undo();
    sync();
    expect(lm.getIntensity(entity), closeTo(LuminaUnits.lightPower(50000.0) / (4 * math.pi), 1.0));
    expect(lm.getFalloff(entity), closeTo(LightActorProperties.defaultAttenuationRadius, 1e-3));

    // Persistence: the component's properties are what the level file keeps.
    model.updateComponentPropertyWithTransaction(point.id, component.id, 'attenuationRadius', 777.0);
    final map = EditorActorNode.fromMap(point.toMap());
    expect(LightActorProperties.read(map).attenuationRadius, 777.0);
  });

  test('Play builds the same light: attenuation radius and cone angles reach the runtime components', () {
    final spot = EditorActorNode(id: 's', name: 'Torch', type: 'SpotLight', location: [0, 0, 200]);
    LightActorProperties.ensureComponent(spot)!.properties.addAll({
      'intensity': 7500.0,
      'colorHex': '#FF4000',
      'attenuationRadius': 850.0,
      'innerConeAngle': 20.0,
      'outerConeAngle': 35.0,
      'castShadows': true,
    });
    final built = EditorPieGame.mapEditorActor(spot) as LuminaActor;
    final root = built.rootComponent as LuminaSpotLightComponent;
    expect(root.intensity, 7500.0);
    expect(root.falloffRadius, 850.0);
    expect(root.innerConeAngleDegrees, 20.0);
    expect(root.outerConeAngleDegrees, 35.0);
    expect(root.castShadows, isTrue);
    expect(root.color.x, closeTo(1.0, 1e-6));
    // #FF4000 is sRGB; Filament lights take linear RGB.
    expect(root.color.y, closeTo(luminaSrgbToLinear(0x40 / 255.0), 1e-6));

    final point = EditorActorNode(id: 'p', name: 'Bulb', type: 'PointLight', location: [0, 0, 100]);
    LightActorProperties.ensureComponent(point)!.properties['attenuationRadius'] = 300.0;
    expect(((EditorPieGame.mapEditorActor(point) as LuminaActor).rootComponent as LuminaPointLightComponent).falloffRadius, 300.0);
  });

  testWidgets('a directional light\'s arrow points where Filament lights from, and follows a yaw of 90°', (tester) async {
    final model = vm();
    model.restoreSnapshot([
      EditorActorNode(id: 'sun', name: 'Sun', type: 'DirectionalLight', location: [0, 0, 500], rotation: [0, -45, 30], lightIntensity: 80000),
    ]);
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: model)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    for (var i = 0; i < 60 && viewport().nativeSceneForTest == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pump(const Duration(milliseconds: 16));
    final FilamentEngine engine = viewport().nativeEngineForTest;
    final lm = FilamentLightManager(engine);

    void expectArrowMatchesLight() {
      final arrow = viewport().lightArrowDirectionForTest('sun') as Vector3?;
      expect(arrow, isNotNull, reason: 'a directional light always shows its arrow');
      final light = lm.getDirection((viewport().editorLightEntitiesForTest as List<int>).single);
      for (var i = 0; i < 3; i++) {
        expect(arrow![i], closeTo(light[i], 1e-4), reason: 'arrow $arrow vs light $light');
      }
    }

    expectArrowMatchesLight();
    final before = viewport().lightArrowDirectionForTest('sun') as Vector3;

    model.selectActorById('sun');
    model.updateActorRotation([0, -45, 120]);
    await tester.pump(const Duration(milliseconds: 16));
    expectArrowMatchesLight();
    final after = viewport().lightArrowDirectionForTest('sun') as Vector3;
    // A 90° yaw turns the arrow's horizontal heading by 90°.
    final headingBefore = math.atan2(before.x, -before.z);
    final headingAfter = math.atan2(after.x, -after.z);
    var turned = (headingAfter - headingBefore) * 180 / math.pi;
    while (turned > 180) {
      turned -= 360;
    }
    while (turned < -180) {
      turned += 360;
    }
    expect(turned.abs(), closeTo(90.0, 0.5));

    // Selecting a point light shows its sphere; deselecting hides it.
    model.spawnNewActor('PointLight');
    model.selectActorById(model.actors.last.id);
    await tester.pump(const Duration(milliseconds: 16));
    expect(viewport().lightWiresForTest.keys, containsAll(['sun', model.actors.last.id]));
    model.selectActorById(null);
    await tester.pump(const Duration(milliseconds: 16));
    expect(viewport().lightWiresForTest.keys, ['sun'], reason: 'only the directional arrow stays');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    model.dispose();
  });
}
