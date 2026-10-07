import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart' show GameTemplateKind;
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sequencer_viewport_camera.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A placed Camera's Details show its camera settings (field of view,
/// projection, clip planes, exposure); a committed field of view is one undo
/// step, is saved in the level and its generated Dart, and is what Play, the
/// Sequencer camera lock and the player's view use. A real temp project.
void main() {
  late Directory root;
  late EditorViewModel vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_camera_details_');
    final pDir = Directory('${root.path}/CameraGame')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'CameraGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/CameraGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pumpDetails(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, height: 1600, child: DetailsWidget(viewModel: vm)))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a placed Camera shows its Camera section; a field of view commit is one undo step', (tester) async {
    vm.spawnNewActor('Camera');
    final actor = vm.actors.last;
    vm.selectActorById(actor.id);
    await pumpDetails(tester);

    expect(find.text('CAMERA'), findsOneWidget);
    final fov = tester.widget<ScrubNumericField>(find.byKey(const ValueKey('details_camera_fieldOfView')));
    expect(fov.value, 60.0, reason: 'the runtime camera\'s default vertical field of view');
    expect(fov.unit, '°');
    expect(tester.widget<ScrubNumericField>(find.byKey(const ValueKey('details_camera_nearClipPlane'))).unit, 'cm');
    expect(find.byKey(const ValueKey('details_camera_farClipPlane')), findsOneWidget);
    expect(tester.widget<EnumField>(find.byKey(const ValueKey('details_camera_projectionMode'))).value, 'Perspective');
    expect(find.byKey(const ValueKey('details_camera_autoExposure')), findsOneWidget);
    expect(find.byKey(const ValueKey('details_camera_autoActivateForPlayer')), findsOneWidget);

    fov.onCommit(30.0);
    await tester.pumpAndSettle();
    final props = actor.components.firstWhere((c) => c.type == 'LuminaCameraComponent').properties;
    expect(props['fieldOfView'], 30.0);
    expect(tester.widget<ScrubNumericField>(find.byKey(const ValueKey('details_camera_fieldOfView'))).value, 30.0);
    expect(SequencerViewportCamera.cameraFovDegrees(actor), 30.0, reason: 'the Sequencer camera lock looks through it');

    vm.transactions.undo();
    expect(props['fieldOfView'], 60.0, reason: 'one undo step');
    vm.transactions.redo();
    expect(props['fieldOfView'], 30.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Camera from an older level gets its camera component when selected', (tester) async {
    vm.spawnNewActor('Camera');
    final actor = vm.actors.last..components.clear();
    vm.selectActorById(actor.id);
    await pumpDetails(tester);
    await tester.pumpAndSettle();
    expect(actor.components.where((c) => c.type == 'LuminaCameraComponent'), hasLength(1));
    expect(find.text('CAMERA'), findsOneWidget);
  });

  test('the field of view is saved in the level and its generated Dart, and Play builds a camera with it', () async {
    vm.spawnNewActor('Camera');
    final actor = vm.actors.last;
    final component = actor.components.firstWhere((c) => c.type == 'LuminaCameraComponent');
    vm.selectActorById(actor.id);
    vm.updateComponentPropertyWithTransaction(actor.id, component.id, 'fieldOfView', 30.0);
    await vm.saveLevelAndGenerateCode();

    final level = jsonDecode(File('${vm.projectDirPath}/contents/levels/L_Main.lmas').readAsStringSync()) as Map<String, dynamic>;
    final saved = ((level['metadata'] as Map)['actors'] as List).cast<Map>().firstWhere((a) => a['id'] == actor.id);
    final savedCamera = (saved['components'] as List).cast<Map>().firstWhere((c) => c['type'] == 'LuminaCameraComponent');
    expect((savedCamera['properties'] as Map)['fieldOfView'], 30.0);

    final generated = File('${vm.projectDirPath}/lib/levels/l_main.dart').readAsStringSync();
    expect(generated, contains("LuminaCameraActor(key: const ValueKey('${actor.id}')"));
    expect(generated, contains("'fieldOfView': 30.0"));

    final played = EditorPieGame.mapEditorActor(actor);
    expect(played, isA<LuminaCameraActor>());
    expect((played as LuminaCameraActor).cameraComponent.fieldOfViewInDegrees, 30.0);
  });

  test('Play looks through a camera set to Auto Activate for Player, with its field of view', () {
    vm.spawnNewActor('PlayerStart');
    vm.spawnNewActor('Camera');
    final camera = vm.actors.last;
    final component = camera.components.firstWhere((c) => c.type == 'LuminaCameraComponent');
    vm.selectActorById(camera.id);
    vm.updateComponentPropertyWithTransaction(camera.id, component.id, 'fieldOfView', 30.0);
    vm.updateComponentPropertyWithTransaction(camera.id, component.id, 'autoActivateForPlayer', true);

    final game = EditorPieGame(vm.actors.toList(), templateKind: GameTemplateKind.firstPerson);
    game.mountIntoWorldForTest(LuminaWorld());
    game.step(1 / 60);
    final view = game.viewCamera;
    expect(view, isNotNull);
    expect(view!.fieldOfViewInDegrees, 30.0);
    expect(view, isNot(same(game.playerCamera)), reason: 'the camera actor, not the pawn\'s camera');
  });
}
