import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Smoke — the edit-mode level viewport is lit by the
/// level's own lights, and a light's Details edits are visible. The Third Person level in Lumina Studio: lit by its
/// DirectionalLight_Sun and SkyAtmosphere_Env; deleting both leaves it dark;
/// undo lights it again; rotating the Directional Light moves the shadows.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Level Viewport Lights Smoke: the level is lit only by its own lights';

  testWidgets(testName, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_level_lights_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'level_lights_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/level_lights_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(60);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));
    Future<Uint8List> capture() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));

    /// Mean luminance (0–255) of the level viewport's pixels.
    double brightness(Uint8List png) {
      final image = img.decodePng(png)!;
      final r = tester.getRect(find.byType(ViewportWidget));
      var sum = 0.0;
      var n = 0;
      for (var y = r.top.toInt() + 40; y < r.bottom.toInt() - 40; y += 3) {
        for (var x = r.left.toInt() + 40; x < r.right.toInt() - 40; x += 3) {
          final p = image.getPixel(x, y);
          sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
          n++;
        }
      }
      return sum / n;
    }

    // --- The template level, lit by its sun and sky ------------------------
    EditorActorNode actorNamed(String name) => vm.actors.firstWhere((a) => a.name == name);
    expect(viewport().editorLightEntitiesForTest, hasLength(1), reason: 'DirectionalLight_Sun is the only light');
    final lit = await capture();
    final litBrightness = brightness(lit);
    SmokeArtifacts.saveScreenshot('level_viewport_lights_lit_by_the_level', lit);

    // --- Delete the sun and the sky: the level goes dark ---------------------
    for (final name in ['DirectionalLight_Sun', 'SkyAtmosphere_Env']) {
      vm.selectActor(actorNamed(name));
      vm.deleteSelectedActor();
      await rec.hold(const Duration(milliseconds: 1200));
    }
    await rec.hold(const Duration(seconds: 2));
    expect(viewport().editorLightEntitiesForTest, isEmpty);
    expect(viewport().editorEnvironmentAttachedForTest, isFalse);
    final dark = await capture();
    final darkBrightness = brightness(dark);
    SmokeArtifacts.saveScreenshot('level_viewport_lights_dark_without_lights', dark);
    expect(darkBrightness, lessThan(litBrightness * 0.5),
        reason: 'without lights the viewport is dark ($litBrightness → $darkBrightness)');

    // --- Undo both: lit again -------------------------------------------------
    vm.transactions.undo();
    await rec.hold(const Duration(milliseconds: 1200));
    vm.transactions.undo();
    await rec.hold(const Duration(seconds: 2));
    expect(viewport().editorLightEntitiesForTest, hasLength(1));
    final relit = await capture();
    expect(brightness(relit), greaterThan(litBrightness * 0.8), reason: 'undo brings the sun and sky back');

    // --- Rotate the sun: the shadows move ------------------------------------
    final sun = actorNamed('DirectionalLight_Sun');
    vm.selectActor(sun);
    final start = [...sun.rotation];
    for (var step = 1; step <= 60; step++) {
      vm.updateActorRotation([start[0], start[1], start[2] + step * 2.0], isCommit: step == 60);
      await rec.hold(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(seconds: 1));
    final turned = await capture();
    SmokeArtifacts.saveScreenshot('level_viewport_lights_sun_turned', turned);
    final a = img.decodePng(relit)!;
    final b = img.decodePng(turned)!;
    final r = tester.getRect(find.byType(ViewportWidget));
    var changed = 0;
    var total = 0;
    for (var y = r.top.toInt() + 40; y < r.bottom.toInt() - 40; y += 3) {
      for (var x = r.left.toInt() + 40; x < r.right.toInt() - 40; x += 3) {
        final p = a.getPixel(x, y), q = b.getPixel(x, y);
        if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() > 30) changed++;
        total++;
      }
    }
    expect(changed / total, greaterThan(0.05), reason: 'turning the sun moves light and shadows ($changed of $total)');
    expect(viewport().lightWiresForTest.keys, contains(sun.id), reason: 'the sun shows its direction arrow');

    // --- a Point Light's Details edits change the picture ------------------
    vm.spawnNewActor('PointLight');
    final lamp = vm.actors.last;
    vm.selectActorById(lamp.id);
    // Between the pillars, 2 m up, where the walls catch its light.
    vm.updateActorLocation([0.0, 300.0, 200.0]);
    await rec.hold(const Duration(seconds: 1));
    final lampComponent = LightActorProperties.componentOf(lamp)!;
    expect(viewport().lightWiresForTest.keys, contains(lamp.id), reason: 'the selected point light shows its radius sphere');
    final lampBefore = await capture();
    double diff(Uint8List x, Uint8List y) {
      final a = img.decodePng(x)!, b = img.decodePng(y)!;
      var n = 0, t = 0;
      for (var yy = r.top.toInt() + 40; yy < r.bottom.toInt() - 40; yy += 3) {
        for (var xx = r.left.toInt() + 40; xx < r.right.toInt() - 40; xx += 3) {
          final p = a.getPixel(xx, yy), q = b.getPixel(xx, yy);
          if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() > 30) n++;
          t++;
        }
      }
      return n / t;
    }

    // Intensity scrubbed up on camera (the Details field's scrub path).
    for (var step = 1; step <= 20; step++) {
      vm.updateComponentPropertyWithTransaction(lamp.id, lampComponent.id, 'intensity', 40000.0 + step * 4000.0, isCommit: step == 20);
      await rec.hold(const Duration(milliseconds: 120));
    }
    await rec.hold(const Duration(milliseconds: 800));
    final brighter = await capture();
    expect(diff(lampBefore, brighter), greaterThan(0.01), reason: 'a brighter point light changes the picture');
    // Colour to orange, radius down to 4 m: the sphere wire shrinks too.
    vm.updateComponentPropertyWithTransaction(lamp.id, lampComponent.id, 'colorHex', '#FF7A00');
    await rec.hold(const Duration(milliseconds: 800));
    for (var step = 1; step <= 15; step++) {
      vm.updateComponentPropertyWithTransaction(lamp.id, lampComponent.id, 'attenuationRadius', 1000.0 - step * 40.0, isCommit: step == 15);
      await rec.hold(const Duration(milliseconds: 120));
    }
    await rec.hold(const Duration(milliseconds: 800));
    final tinted = await capture();
    SmokeArtifacts.saveScreenshot('level_viewport_lights_point_light_edited', tinted);
    expect(diff(brighter, tinted), greaterThan(0.01), reason: 'colour and radius edits change the picture');

    expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
    rec.save(testName);
  });
}
