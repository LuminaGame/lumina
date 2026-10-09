import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2, Vector3;

import '../../test/helpers/blueprint_test_project.dart';
import '../../test/helpers/pie_pointer_fixture.dart';

/// The game's mouse in Play-In-Editor on the real editor and GPU: a First
/// Person level with real props (fuel barrels, an AC unit), a placed
/// `BP_Clicker` that prints Get Mouse Position / Get Viewport Size every tick
/// and, on a left click, deprojects the cursor and line-traces into the level
/// with Draw Debug on. The cursor (drawn by the smoke: the OS cursor is not in
/// a screenshot) sweeps the view, then clicks the props and the floor; every
/// hit lands under the cursor with Location = Impact Point.
const _testName = 'PIE Mouse Smoke: Get Mouse Position follows the cursor and a click traces into the level under it';
const _barrel = 'Props/Barrels/fuel_barrel_red.glb';
const _acUnit = 'Props/AC_units/ac_unit_b_600x600.glb';
const _barrelMesh = 'contents/meshes/static/SM_FuelBarrel.glb';
const _acUnitMesh = 'contents/meshes/static/SM_AcUnit.glb';

/// A prop Blueprint: [mesh] with a BlockAll box of [extent] (authoring
/// half extents, Z up) around it, standing on its origin.
LuminaBlueprintDocument _prop(String mesh, List<double> extent) => LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(
          id: 'mesh', name: 'Mesh', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {'staticMeshAsset': mesh}),
      LuminaBlueprintComponent(id: 'box', name: 'Blocker', type: 'LuminaBoxComponent', parentId: 'root', properties: {
        'boxExtent': extent,
        'preset': 'BlockAll',
        'location': [0.0, 0.0, extent[2]],
      }),
    ]);

Map<String, dynamic> _placed(String id, String cls, List<double> at) => {
      'id': id,
      'name': id,
      'type': 'Blueprint',
      'blueprintClass': 'contents/blueprints/$cls.lmas',
      'location': at,
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final rel in [_barrel, _acUnit]) {
      if (!File('$assets/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final project = PiePointerProject.create(name: 'PieMouseSmoke', drawDebug: true, extraActors: [
      // Ahead of the player (it starts at (0, -600) looking along +Y).
      _placed('BarrelLeft', 'BP_Barrel', [-180.0, -250.0, 0.0]),
      _placed('BarrelRight', 'BP_Barrel', [160.0, -150.0, 0.0]),
      _placed('AcUnit', 'BP_AcUnit', [0.0, 700.0, 0.0]),
    ]);
    addTearDown(project.dispose);
    for (final (from, to) in [(_barrel, _barrelMesh), (_acUnit, _acUnitMesh)]) {
      File('${project.dir}/$to')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File('$assets/$from').readAsBytesSync());
    }
    writeBlueprint(project.dir, 'BP_Barrel', _prop(_barrelMesh, [38.0, 38.0, 57.0]));
    writeBlueprint(project.dir, 'BP_AcUnit', _prop(_acUnitMesh, [300.0, 300.0, 53.0]));

    // The recording backend: nothing grabs the real pointer.
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
    addTearDown(() => LuminaMouseCapture.backend = RecordingMouseCaptureBackend());
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final vm = EditorViewModel(initialProject: project.manifest(), projectLocation: project.root.path, enableTimers: false);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();

    // The smoke draws the cursor: a screenshot has no OS pointer in it.
    final cursor = ValueNotifier<Offset?>(null);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: Stack(textDirection: TextDirection.ltr, children: [
        ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CursorPainter(cursor)))),
      ]),
    ));
    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // --- Play ----------------------------------------------------------------
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    await settle(60);
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    final world = pie.game!.world!;
    final clicker =
        world.persistentLevel.actors.whereType<LuminaBlueprintInstance>().firstWhere((a) => a.blueprintClass.name == 'BP_Clicker');
    final trace = <LuminaBlueprintTraceEvent>[];
    (clicker as LuminaBlueprintRuntime).trace = trace.add;
    // A visible cursor, as a click-to-act game shows it.
    pie.game!.playerController!.setShowMouseCursor(true);
    await settle(6);

    final viewRect = tester.getRect(find.byType(FilamentWidget));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await mouse.addPointer(location: viewRect.center);
    addTearDown(mouse.removePointer);
    Future<void> moveTo(Offset local, {int frames = 2}) async {
      cursor.value = viewRect.topLeft + local;
      await mouse.moveTo(viewRect.topLeft + local);
      await settle(frames);
      await rec.capture();
    }

    Vector2 v2(Object? v) => v as Vector2;
    Vector3 v3(Object? v) => v as Vector3;
    Object? last(String node) => trace.lastWhere((t) => t.nodeId == node).values['return_value'];

    // --- Hover: the position follows the cursor in view pixels ---------------
    final size = v2(last('size'));
    expect(size.x, closeTo(viewRect.width.roundToDouble(), 0.5), reason: 'Get Viewport Size is the PIE view ($size vs ${viewRect.size})');
    expect(size.y, closeTo(viewRect.height.roundToDouble(), 0.5));
    for (var i = 0; i <= 120; i++) {
      final t = i / 120;
      await moveTo(Offset(viewRect.width * (0.1 + 0.8 * t), viewRect.height * (0.55 + 0.2 * math.sin(4 * math.pi * t))));
    }
    final probe = Offset((viewRect.width * 0.3).roundToDouble(), (viewRect.height * 0.7).roundToDouble());
    await moveTo(probe, frames: 4);
    final m = v2(last('mouse'));
    expect(m.x, closeTo(probe.dx, 0.6), reason: 'Get Mouse Position $m under the cursor $probe');
    expect(m.y, closeTo(probe.dy, 0.6));
    await rec.hold(const Duration(milliseconds: 800));
    await shot('pie_mouse_position_follows_cursor');

    // --- Clicks: on each prop on screen, and on the floor ---------------------
    final targets = <(String, Offset)>[];
    for (final (name, at) in [
      ('BarrelLeft', Vector3(-180, -250, 70)),
      ('BarrelRight', Vector3(160, -150, 70)),
      ('AcUnit', Vector3(0, 480, 100)),
    ]) {
      final s = LuminaBlueprintFunctionLibrary.projectWorldToScreen(clicker, at);
      if (s.returnValue && s.screenPosition.x > 20 && s.screenPosition.y > 20 && s.screenPosition.x < size.x - 20 && s.screenPosition.y < size.y - 20) {
        targets.add((name, Offset(s.screenPosition.x.roundToDouble(), s.screenPosition.y.roundToDouble())));
      }
    }
    final centreRay = LuminaBlueprintFunctionLibrary.deprojectScreenToWorld(clicker, Vector2(size.x / 2, size.y / 2));
    debugPrint('[pie_mouse_smoke] view centre ray ${centreRay.worldLocation} -> ${centreRay.worldDirection}');
    debugPrint('[pie_mouse_smoke] props on screen: ${targets.map((t) => '${t.$1}@${t.$2}').join(', ')}');
    expect(targets, isNotEmpty, reason: 'the props stand in front of the player');
    targets.add(('floor', Offset((viewRect.width * 0.75).roundToDouble(), (viewRect.height * 0.85).roundToDouble())));

    final hitNames = <String>[];
    for (final (name, local) in targets) {
      // Glide to the target, then click.
      final from = v2(last('mouse'));
      for (var i = 1; i <= 24; i++) {
        await moveTo(Offset.lerp(Offset(from.x, from.y), local, i / 24)!);
      }
      trace.removeWhere((t) => t.nodeId == 'trace' || t.nodeId == 'hit');
      await mouse.down(viewRect.topLeft + local);
      await settle(4);
      await mouse.up();
      await settle(4);
      expect(trace.where((t) => t.nodeId == 'trace'), isNotEmpty, reason: 'the click on $name reached the game');
      final hit = trace.lastWhere((t) => t.nodeId == 'hit').values;
      expect(hit['blocking_hit'], isTrue, reason: '$name: something is under the cursor');
      expect(hit['hit_actor'], isNot(same(pie.possessedPawn)), reason: '$name: the trace ignores the player');
      final impact = v3(hit['impact_point']);
      expect((v3(hit['location']) - impact).length, lessThan(1e-3), reason: '$name: a line trace stops at its impact point');
      final back = LuminaBlueprintFunctionLibrary.projectWorldToScreen(clicker, impact);
      expect((back.screenPosition - Vector2(local.dx, local.dy)).length, lessThan(2.0),
          reason: '$name: the hit ${back.screenPosition} lies under the cursor $local');
      final actor = hit['hit_actor'];
      hitNames.add(actor is LuminaBlueprintInstance ? actor.blueprintClass.name : '${actor?.runtimeType}');
      debugPrint('[pie_mouse_smoke] $name click at $local hit ${hitNames.last} at $impact');
      for (var i = 0; i < 30; i++) {
        await settle(1);
        await rec.capture();
      }
      await shot('pie_mouse_click_${name.toLowerCase()}');
    }
    expect(vm.selectedActorId, isNull, reason: 'clicks in the playing viewport never select editor actors');
    await rec.hold(const Duration(milliseconds: 1200));

    vm.stopSimulation();
    await settle(20);
    final video = rec.save(_testName);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    await tester.pumpWidget(const SizedBox());
    await settle(30);
  });
}

/// The smoke's stand-in for the OS cursor: an arrow at the pointer.
class _CursorPainter extends CustomPainter {
  _CursorPainter(this.at) : super(repaint: at);

  final ValueNotifier<Offset?> at;

  @override
  void paint(Canvas canvas, Size size) {
    final p = at.value;
    if (p == null) return;
    final arrow = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx, p.dy + 20)
      ..lineTo(p.dx + 5, p.dy + 15)
      ..lineTo(p.dx + 9, p.dy + 23)
      ..lineTo(p.dx + 12, p.dy + 21)
      ..lineTo(p.dx + 8, p.dy + 14)
      ..lineTo(p.dx + 14, p.dy + 14)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(
        arrow,
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => true;
}
