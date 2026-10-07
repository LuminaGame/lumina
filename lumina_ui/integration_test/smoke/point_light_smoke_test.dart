import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Smoke — a point and a spot light light a level without a sun.
///
/// The Third Person level with its sun and sky deleted (the user's setup) and
/// real props from `test-assets/` placed on the floor. A Point Light is added
/// from the World Outliner's Add menu with the user's values (55 695 lm,
/// #D22121, 2000 cm, shadows): its red pool must show on the floor. Then the
/// intensity and radius are scrubbed, the light is moved, the mobility is
/// switched in Details, and a Spot Light (50 000 lm, 30°/45°) is added
/// pointing down. Floor pixels around the lights are measured in the frame
/// and stored in the sidecars. Before the fix the whole frame stayed black:
/// the camera was exposed for a 100 000 lux sun.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Point Light Smoke: a sunless level is lit by a placed point light and spot light';

  // Props on the open floor south-east of the hurdle (editor space: cm, Z up).
  const props = {
    'Props/Barrels/fuel_barrel_red.glb': [380.0, -320.0, 0.0],
    'Props/AC_units/aircon_small.glb': [650.0, -300.0, 0.0],
    'Props/Banana Bunch/banana_bunch_long.glb': [520.0, -250.0, 0.0],
  };
  // Between the editor grid's 1 m lines.
  const lampAt = [530.0, -450.0, 150.0];

  testWidgets(testName, (tester) async {
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('lumina_smoke_point_light_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'point_light_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/point_light_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    // The user's level: no sun, no sky light.
    for (final name in ['DirectionalLight_Sun', 'SkyAtmosphere_Env']) {
      vm.selectActor(vm.actors.firstWhere((a) => a.name == name));
      vm.deleteSelectedActor();
    }
    expect(vm.actors.where((a) => a.type.contains('Light') || a.type == 'Environment'), isEmpty);
    // Real props through the real import pipeline.
    for (final entry in props.entries) {
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
      vm.refreshAssets();
      final stem = entry.key.split('/').last.replaceAll('.glb', '');
      final asset = vm.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: entry.value));
    }
    vm.clearSelection();
    // Looking down at the props from the south, 9 m away.
    vm.restoreCameraSnapshot([0.0, 50.0, 900.0, lampAt[0], lampAt[1] + 100, 0.0]);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await _settle(tester, 60);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    Future<Uint8List> capture() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    /// Median RGB of a 7×7 patch where the floor point [x], [y] (cm, z = 1)
    /// is drawn.
    List<double> floorRgb(Uint8List png, double x, double y) {
      final image = img.decodePng(png)!;
      final rect = tester.getRect(find.byType(ViewportWidget));
      final at = viewport().nativeProjectForTest(x, y, 1.0, rect.size) as Offset?;
      expect(at, isNotNull, reason: 'floor point ($x, $y) is in view');
      final cx = (rect.left + at!.dx).round(), cy = (rect.top + at.dy).round();
      // The median of each channel, so a grid line through the patch does not
      // count as light.
      final channels = [<num>[], <num>[], <num>[]];
      for (var j = -3; j <= 3; j++) {
        for (var i = -3; i <= 3; i++) {
          final p = image.getPixel(cx + i, cy + j);
          channels[0].add(p.r);
          channels[1].add(p.g);
          channels[2].add(p.b);
        }
      }
      return [for (final c in channels) (c..sort())[c.length ~/ 2].toDouble()];
    }

    String fmt(List<double> rgb) => '(${rgb.map((v) => v.round()).join(', ')})';
    double ev() => viewport().cameraEv100ForTest as double;
    final assets = props.keys.toList();

    // --- 1. The sunless level is black ---------------------------------------
    final dark = await capture();
    final darkUnder = floorRgb(dark, lampAt[0], lampAt[1]);
    SmokeArtifacts.saveScreenshot('point_light_smoke_01_sunless_level', dark,
        usedAssets: assets, metrics: {'ev100': ev(), 'floor_under_lamp_rgb': fmt(darkUnder)});
    expect(darkUnder.reduce(math.max), lessThan(12), reason: 'no light, no sky: black ${fmt(darkUnder)}');

    // --- 2. Outliner ▸ Add ▸ Point Light, with the user's values --------------
    await tester.tap(find.descendant(of: find.byType(OutlinerWidget), matching: find.text('Add')).first);
    await _settle(tester);
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('spawn_actor_PointLight')));
    await _settle(tester);
    final lamp = vm.actors.last;
    expect(lamp.type, 'PointLight');
    vm.selectActorById(lamp.id);
    final c = LightActorProperties.componentOf(lamp)!;
    vm.updateActorLocation([...lampAt]);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'intensity', 55695.0);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'colorHex', '#D22121');
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'attenuationRadius', 2000.0);
    vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'castShadows', true);
    await _settle(tester);
    await rec.hold(const Duration(seconds: 2));
    final lit = await capture();
    final under = floorRgb(lit, lampAt[0], lampAt[1]);
    final at3m = floorRgb(lit, lampAt[0] - 300, lampAt[1]);
    SmokeArtifacts.saveScreenshot('point_light_smoke_02_red_point_light', lit, usedAssets: assets, metrics: {
      'ev100': ev(),
      'floor_under_lamp_rgb': fmt(under),
      'floor_3m_from_lamp_rgb': fmt(at3m),
    });
    expect(ev(), lessThan(LuminaAutoExposure.daylightEv100 - 5), reason: 'exposed for the lamp');
    expect(under[0], greaterThan(60), reason: 'the red pool under the lamp: ${fmt(under)}');
    expect(under[0], greaterThan(under[1] * 2), reason: 'and it is red: ${fmt(under)}');
    expect(at3m[0], greaterThan(darkUnder[0] + 10), reason: 'lit 3 m away too: ${fmt(at3m)}');

    // --- 3. Scrub the intensity down and up ---------------------------------
    for (var step = 1; step <= 20; step++) {
      final v = step <= 10 ? 55695.0 - step * 4500.0 : 10695.0 + (step - 10) * 4500.0;
      vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'intensity', v, isCommit: step == 20);
      await rec.hold(const Duration(milliseconds: 120));
    }
    await rec.hold(const Duration(milliseconds: 600));

    // --- 4. Scrub the radius to 3 m: the floor 6 m away goes black ----------
    final beforeRadius = floorRgb(await capture(), lampAt[0] - 600, lampAt[1]);
    for (var step = 1; step <= 17; step++) {
      vm.updateComponentPropertyWithTransaction(lamp.id, c.id, 'attenuationRadius', 2000.0 - step * 100.0, isCommit: step == 17);
      await rec.hold(const Duration(milliseconds: 120));
    }
    await rec.hold(const Duration(milliseconds: 800));
    final radius = await capture();
    final inside = floorRgb(radius, lampAt[0], lampAt[1]);
    final outside = floorRgb(radius, lampAt[0] - 600, lampAt[1]);
    SmokeArtifacts.saveScreenshot('point_light_smoke_03_radius_3m', radius, usedAssets: assets, metrics: {
      'ev100': ev(),
      'floor_under_lamp_rgb': fmt(inside),
      'floor_6m_before_rgb': fmt(beforeRadius),
      'floor_6m_after_rgb': fmt(outside),
    });
    expect(inside[0], greaterThan(60), reason: 'still lit inside the radius: ${fmt(inside)}');
    expect(outside.reduce(math.max), lessThan(12), reason: 'black outside the 3 m radius: ${fmt(outside)}');

    // --- 5. Move the light (the gizmo's drag path): the pool follows --------
    for (var step = 1; step <= 20; step++) {
      vm.updateActorLocation([lampAt[0] - step * 15.0, lampAt[1], lampAt[2]], isCommit: step == 20);
      await rec.hold(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 800));
    final moved = await capture();
    final newUnder = floorRgb(moved, lampAt[0] - 300, lampAt[1]);
    final oldUnder = floorRgb(moved, lampAt[0] + 150, lampAt[1]);
    SmokeArtifacts.saveScreenshot('point_light_smoke_04_moved_3m_west', moved, usedAssets: assets, metrics: {
      'ev100': ev(),
      'floor_under_moved_lamp_rgb': fmt(newUnder),
      'floor_1_5m_east_of_old_spot_rgb': fmt(oldUnder),
    });
    expect(newUnder[0], greaterThan(60), reason: 'the pool moved with the light: ${fmt(newUnder)}');
    expect(newUnder[0], greaterThan(oldUnder[0] + 20), reason: 'brighter at the new spot than past the old one');

    // --- 6. Mobility in Details: Static, Stationary, Movable all light -----
    for (final mobility in ['Static', 'Stationary', 'Movable']) {
      await tester.tap(find.descendant(of: find.byType(DetailsWidget), matching: find.text(mobility)).first);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 900));
      expect(vm.actors.firstWhere((a) => a.id == lamp.id).mobility, mobility);
      final frame = await capture();
      final rgb = floorRgb(frame, lampAt[0] - 300, lampAt[1]);
      SmokeArtifacts.saveScreenshot('point_light_smoke_05_mobility_${mobility.toLowerCase()}', frame,
          usedAssets: assets, metrics: {'ev100': ev(), 'floor_under_lamp_rgb': fmt(rgb)});
      expect(rgb[0], greaterThan(60), reason: '$mobility light lights the floor: ${fmt(rgb)}');
    }

    // --- 7. A Spot Light pointing down lights its cone ----------------------
    vm.selectActorById(lamp.id);
    vm.deleteSelectedActor();
    vm.clearSelection();
    await tester.tap(find.descendant(of: find.byType(OutlinerWidget), matching: find.text('Add')).first);
    await _settle(tester);
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('spawn_actor_SpotLight')));
    await _settle(tester);
    final spot = vm.actors.last;
    expect(spot.type, 'SpotLight');
    vm.selectActorById(spot.id);
    final sc = LightActorProperties.componentOf(spot)!;
    vm.updateActorLocation([lampAt[0], lampAt[1], 300.0]);
    vm.updateComponentPropertyWithTransaction(spot.id, sc.id, 'intensity', 50000.0);
    vm.updateComponentPropertyWithTransaction(spot.id, sc.id, 'attenuationRadius', 2000.0);
    await _settle(tester);
    await rec.hold(const Duration(seconds: 2));
    final spotFrame = await capture();
    final cone = floorRgb(spotFrame, lampAt[0], lampAt[1]);
    final outsideCone = floorRgb(spotFrame, lampAt[0] - 500, lampAt[1]);
    SmokeArtifacts.saveScreenshot('point_light_smoke_06_spot_light_cone', spotFrame, usedAssets: assets, metrics: {
      'ev100': ev(),
      'floor_cone_centre_rgb': fmt(cone),
      'floor_5m_outside_cone_rgb': fmt(outsideCone),
    });
    expect(cone.reduce(math.min), greaterThan(25), reason: 'the cone lights the floor: ${fmt(cone)}');
    expect(outsideCone.reduce(math.max), lessThan(cone.reduce(math.min) / 3),
        reason: 'dark outside the 45° cone: ${fmt(outsideCone)} vs ${fmt(cone)}');
    // Widen the cone on camera.
    for (var step = 1; step <= 12; step++) {
      vm.updateComponentPropertyWithTransaction(spot.id, sc.id, 'outerConeAngle', 45.0 + step * 2.5, isCommit: step == 12);
      await rec.hold(const Duration(milliseconds: 120));
    }
    await rec.hold(const Duration(seconds: 1));

    expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
    rec.save(testName, usedAssets: assets);
  });
}
