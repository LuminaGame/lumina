import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A placed rotation means one thing in the editor and in Play: a long red
/// pointer placed at `[pitch 30, roll 0, yaw 90]` (Details values) rises
/// toward +X — the green marker — in the level viewport and in the running
/// game, where Get Actor Rotation reads the same `[30, 0, 90]` back and Get
/// Actor Forward Vector points up and to +X. The blue marker is at −X.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'placed rotation: an actor placed at yaw 90 faces +X in the editor and in Play';

  testWidgets(scenario, (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_rot_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeRotation')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    final project = LuminaProject(
      projectName: 'SmokeRotation',
      activeLevel: 'contents/levels/L_DefaultLevel.lmas',
      template: kThirdPersonTemplateId,
      input: template.input,
    );
    File('${pDir.path}/SmokeRotation.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    Map<String, dynamic> primitive(String id, String shape, List<double> size, String color, List<double> location,
            [List<double> rotation = const [0.0, 0.0, 0.0]]) =>
        <String, dynamic>{
          'id': id,
          'name': id,
          'type': 'Primitive',
          'parentId': null,
          'location': location,
          'rotation': rotation,
          'scale': [1.0, 1.0, 1.0],
          'isVisible': true,
          'isLocked': false,
          'mobility': 'Static',
          'components': [
            {
              'id': '${id}_mesh',
              'type': 'LuminaProceduralMeshComponent',
              'name': 'Shape',
              'enabled': true,
              'properties': <String, dynamic>{
                'shape': shape,
                'sizeX': size[0],
                'sizeY': size[1],
                'sizeZ': size[2],
                'colorHex': color,
              },
            },
          ],
        };

    // The real level container on disk: the template's actors plus a pointer
    // and two markers, as the Details panel stores them. A Primitive's sizes
    // are Z up like its location, so sizeY runs along the forward axis (+Y)
    // and the pointer's front end is its high end.
    const pointerRotation = [30.0, 0.0, 90.0];
    File('${pDir.path}/contents/levels/L_DefaultLevel.lmas').writeAsStringSync(jsonEncode(<String, dynamic>{
      'assetId': 'level_L_DefaultLevel',
      'name': 'L_DefaultLevel',
      'type': 'level',
      'relativePath': 'contents/levels/L_DefaultLevel.lmas',
      'rawPayload': null,
      'metadata': <String, dynamic>{
        'actors': [
          ...template.levelActors,
          primitive('Pointer', 'box', [24.0, 360.0, 24.0], '#E03C31', [0.0, 200.0, 180.0], pointerRotation),
          primitive('Marker_PlusX', 'sphere', [60.0, 60.0, 60.0], '#3CB44B', [260.0, 200.0, 180.0]),
          primitive('Marker_MinusX', 'sphere', [60.0, 60.0, 60.0], '#2F6BE0', [-260.0, 200.0, 180.0]),
        ],
      },
    }));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final pointer = vm.actors.firstWhere((a) => a.name == 'Pointer');
      expect(pointer.rotation, pointerRotation);

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png);
      }

      final s30 = math.sin(30 * math.pi / 180);
      final c30 = math.cos(30 * math.pi / 180);
      void expectForward(Vector3 f, String reason) {
        expect(f.x, closeTo(c30, 1e-6), reason: '$reason: $f');
        expect(f.y, closeTo(0.0, 1e-6), reason: '$reason: $f');
        expect(f.z, closeTo(s30, 1e-6), reason: '$reason: $f');
      }

      // The editor draws the pointer rising toward +X.
      final editorMatrix = EditorTransforms.actorMatrix(pointer);
      expectForward(
          LuminaBlueprintFunctionLibrary.toAuthoring(editorMatrix.getRotation().transformed(Vector3(0, 0, -1))..normalize()),
          'the editor draws the pointer');
      vm.restoreCameraSnapshot([0.0, 15.0, 1100.0, 0.0, 200.0, 180.0]);
      await settle(30);
      await rec.hold(const Duration(seconds: 3));
      await shot('$scenario 01 editor');
      vm.restoreCameraSnapshot([35.0, 25.0, 1100.0, 0.0, 200.0, 180.0]);
      await settle(30);
      await rec.hold(const Duration(seconds: 2));
      await shot('$scenario 02 editor angled');

      // Play: the same transform, and Blueprint reads the Details values.
      await tester.tap(find.byKey(const ValueKey('toolbar_play')));
      await settle(40);
      final pie = vm.pieController;
      expect(pie.isPlaying, isTrue, reason: 'PIE error: ${pie.lastError}');
      final world = pie.game!.world!;
      final runtime = world.persistentLevel.actors.firstWhere((r) => r.key == LuminaObjectKey(pointer.id));
      final placed = runtime.rootComponent.worldTransform;
      for (var i = 0; i < 16; i++) {
        expect(placed.storage[i], closeTo(editorMatrix.storage[i], 1e-3), reason: 'Play places the pointer as the editor, element $i');
      }
      expectForward(LuminaBlueprintFunctionLibrary.getActorForwardVector(runtime), 'Get Actor Forward Vector in Play');
      final read = LuminaBlueprintFunctionLibrary.getActorRotation(runtime);
      expect(read.pitch, closeTo(30.0, 1e-6), reason: 'Get Actor Rotation: $read');
      expect(read.roll, closeTo(0.0, 1e-6), reason: 'Get Actor Rotation: $read');
      expect(read.yaw, closeTo(90.0, 1e-6), reason: 'Get Actor Rotation: $read');
      await rec.hold(const Duration(seconds: 4));
      await shot('$scenario 03 play');
      await rec.hold(const Duration(seconds: 2));

      await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
      await settle(20);
      await rec.hold(const Duration(seconds: 1));
      rec.save(scenario);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
