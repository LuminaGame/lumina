import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The edit-mode level viewport is lit by the level's own light
/// actors, through the components PIE builds, and by nothing else: no
/// hidden preview sun, no fallback sky light for a level without an
/// Environment actor.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_level_viewport_lights_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  EditorViewModel vmWith(List<EditorActorNode> actors) {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'LevelLights'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot(actors);
    return vm;
  }

  EditorActorNode sun({List<double> rotation = const [0, -45, 30]}) => EditorActorNode(
        id: 'sun',
        name: 'DirectionalLight',
        type: 'DirectionalLight',
        location: [0, 0, 500],
        rotation: [...rotation],
        lightIntensity: 80000,
        lightColorHex: '#FFFFFF',
        castShadows: true,
      );

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

  /// The direction PIE's LuminaDirectionalLightComponent gives the actor.
  List<double> pieDirection(EditorActorNode node) {
    final actor = EditorPieGame.mapEditorActor(node) as LuminaActor;
    final light = actor.rootComponent as LuminaLightComponent;
    final d = light.lightDirection;
    return [d.x, d.y, d.z];
  }

  testWidgets('a level without light actors has no light and no sky light in the edit-mode scene', (tester) async {
    final vm = vmWith([EditorActorNode(id: 'start', name: 'PlayerStart', type: 'PlayerStart', location: [0, 0, 0])]);
    final viewport = await mount(tester, vm);
    final FilamentScene scene = viewport.nativeSceneForTest;
    expect(scene.lightCount, 0, reason: 'no hidden preview sun or fill light');
    expect(viewport.editorEnvironmentAttachedForTest, isFalse,
        reason: 'no Environment actor: no skybox and no image-based light');
    await unmount(tester, vm);
  });

  testWidgets('a Directional Light actor lights the scene as PIE builds it and follows Details edits, delete and undo',
      (tester) async {
    final node = sun();
    final vm = vmWith([node]);
    final viewport = await mount(tester, vm);
    final FilamentScene scene = viewport.nativeSceneForTest;
    final FilamentEngine engine = viewport.nativeEngineForTest;
    final lights = FilamentLightManager(engine);
    List<int> entities() => List<int>.from(viewport.editorLightEntitiesForTest as List);

    expect(scene.lightCount, 1, reason: 'exactly the level\'s one light');
    var light = entities().single;
    expect(lights.getIntensity(light), closeTo(80000, 1e-3));
    expect(lights.isShadowCaster(light), isTrue);
    final expected = pieDirection(node);
    final actual = lights.getDirection(light);
    for (var i = 0; i < 3; i++) {
      expect(actual[i], closeTo(expected[i], 1e-4), reason: 'direction as PIE builds it: $expected vs $actual');
    }

    // Details edits on the selected light.
    vm.selectActor(vm.actors.single);
    vm.updateActorLightIntensity(20000);
    vm.updateActorCastShadows(false);
    vm.updateActorLightColor('#FF0000');
    await tester.pump(const Duration(milliseconds: 16));
    light = entities().single;
    expect(lights.getIntensity(light), closeTo(20000, 1e-3));
    expect(lights.isShadowCaster(light), isFalse);
    final color = lights.getColor(light);
    expect(color[0], greaterThan(color[1] * 4), reason: 'red: $color');

    // Rotating it turns the sun.
    vm.updateActorRotation([0, -80, 120]);
    await tester.pump(const Duration(milliseconds: 16));
    final rotated = lights.getDirection(entities().single);
    final expectedRotated = pieDirection(vm.actors.single);
    for (var i = 0; i < 3; i++) {
      expect(rotated[i], closeTo(expectedRotated[i], 1e-4));
    }

    // Unlit and the Lighting show flag take it out; Lit brings it back.
    vm.setViewMode('Unlit');
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.lightCount, 0);
    vm.setViewMode('Lit');
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.lightCount, 1);

    // Deleting the light leaves the level dark; undo lights it again.
    vm.deleteSelectedActor();
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.lightCount, 0, reason: 'a level without lights is dark');
    vm.transactions.undo();
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.lightCount, 1, reason: 'undo restores the light');

    await unmount(tester, vm);
  });
}
