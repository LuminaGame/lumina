import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Editor Preferences → Level Editor → Viewports →
/// "Flight Camera Control Type": WASD flies with the right button held (the
/// default), always, or never. Per user, in a temp `LuminaConfigDir` here.
void main() {
  group('EditorPreferences on disk', () {
    late Directory config;
    setUp(() => config = Directory.systemTemp.createTempSync('lumina_editor_prefs_'));
    tearDown(() => config.deleteSync(recursive: true));

    test('defaults to right-button flight, and a choice survives a reload', () {
      final prefs = EditorPreferences.load(configDir: config);
      expect(prefs.flightCameraControl, FlightCameraControlType.rmbHeld);
      expect(FlightCameraControlType.rmbHeld.label, 'Use WASD Only When Right Mouse Button Is Held');
      expect(FlightCameraControlType.always.label, 'Use WASD For Camera Controls Always');
      expect(FlightCameraControlType.never.label, 'Never Use WASD For Camera Controls');

      var notified = 0;
      prefs.addListener(() => notified++);
      prefs.setFlightCameraControl(FlightCameraControlType.always);
      expect(notified, 1);
      final file = File('${config.path}/editor_preferences.json');
      expect(file.existsSync(), isTrue);
      expect((jsonDecode(file.readAsStringSync()) as Map)['flightCameraControl'], 'always');
      expect(EditorPreferences.load(configDir: config).flightCameraControl, FlightCameraControlType.always);
    });

    // Project Editor Builds › Open every project in its own editor.
    test('perProjectEditors defaults to on; off is saved and survives a reload', () {
      final prefs = EditorPreferences.load(configDir: config);
      expect(prefs.perProjectEditors, isTrue);
      var notified = 0;
      prefs.addListener(() => notified++);
      prefs.setPerProjectEditors(false);
      prefs.setPerProjectEditors(false);
      expect(notified, 1, reason: 'no change, no notification');
      expect((jsonDecode(File('${config.path}/editor_preferences.json').readAsStringSync()) as Map)['perProjectEditors'], isFalse);
      expect(EditorPreferences.load(configDir: config).perProjectEditors, isFalse);
    });

    test('an unreadable file falls back to the defaults', () {
      File('${config.path}/editor_preferences.json').writeAsStringSync('{ not json');
      expect(EditorPreferences.load(configDir: config).flightCameraControl, FlightCameraControlType.rmbHeld);
    });
  });

  group('in the editor', () {
    Future<void> frames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
      final dir = Directory.systemTemp.createTempSync('lumina_editor_prefs_editor_');
      addTearDown(() => dir.deleteSync(recursive: true));
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
      final vm = EditorViewModel(
        initialProject: LuminaProject(projectName: 'PrefsGame', template: kThirdPersonTemplateId, input: template.input),
        projectLocation: dir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());
      addTearDown(vm.dispose);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      final size = tester.getSize(find.byType(ViewportWidget));
      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      for (var i = 0; i < 60 && viewport().nativeProjectForTest(0.0, 0.0, 0.0, size) == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await frames(tester, 5);
      return vm;
    }

    List<double> pan(EditorViewModel vm) => [vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ];
    double moved(List<double> a, List<double> b) =>
        [for (var i = 0; i < 3; i++) (a[i] - b[i]).abs()].reduce((x, y) => x + y);

    Future<void> hold(WidgetTester tester, LogicalKeyboardKey key, {int holdFrames = 30}) async {
      await tester.sendKeyDownEvent(key);
      await frames(tester, holdFrames);
      await tester.sendKeyUpEvent(key);
      await frames(tester, 2);
    }

    Future<void> clickViewport(WidgetTester tester) async {
      await tester.tapAt(tester.getCenter(find.byType(ViewportWidget)) + const Offset(0, 200), kind: PointerDeviceKind.mouse);
      await frames(tester, 3);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 2);
    }

    testWidgets('Edit → Editor Preferences... opens the tab, and its Select persists the flight mode', (tester) async {
      final vm = await pumpEditor(tester);
      expect(vm.editorPreferences.flightCameraControl, FlightCameraControlType.rmbHeld);
      expect(vm.commands.byId('edit.editorPreferences')?.label, 'Editor Preferences...');

      vm.commands.execute('edit.editorPreferences');
      await frames(tester, 6);
      expect(vm.openTabs.any((t) => t.title == 'Editor Preferences'), isTrue);
      expect(find.text('Flight Camera Control Type'), findsOneWidget);
      expect(find.text('Level Editor › Viewports'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('editor_prefs_flight_camera_control')));
      // The popup slides in: after 6 frames its items are still below the
      // window, so wait for it to settle before picking one.
      await frames(tester, 20);
      await tester.tap(find.text(FlightCameraControlType.always.label).last);
      await frames(tester, 6);
      expect(vm.editorPreferences.flightCameraControl, FlightCameraControlType.always);
      final saved = jsonDecode(LuminaConfigDir.file('editor_preferences.json').readAsStringSync()) as Map;
      expect(saved['flightCameraControl'], 'always', reason: 'saved at once');
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.rmbHeld);
      await unmount(tester);
    });

    testWidgets('right button held (default): W alone switches the tool, W with the button flies', (tester) async {
      final vm = await pumpEditor(tester);
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.rmbHeld);
      await clickViewport(tester);
      final before = pan(vm);
      await hold(tester, LogicalKeyboardKey.keyW);
      expect(moved(before, pan(vm)), lessThan(1e-6), reason: 'W alone does not fly by default');
      expect(vm.activeTool, 'translate', reason: 'W alone is the Move tool');
      final state = tester.state(find.byType(ViewportWidget)) as dynamic;
      expect(state.flightHintForTest as String, 'RMB + WASD/QE to fly · Arrow keys to move');
      await unmount(tester);
    });

    testWidgets('always: W/A/S/D/Q/E fly with no button held, and Space cycles the transform tools', (tester) async {
      final vm = await pumpEditor(tester);
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.always);
      await frames(tester, 2);
      await clickViewport(tester);
      vm.setActiveTool('select');
      for (final key in [
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.keyE,
        LogicalKeyboardKey.keyQ,
      ]) {
        final before = pan(vm);
        await hold(tester, key);
        expect(moved(before, pan(vm)), greaterThan(20.0), reason: '${key.keyLabel} flies in "Always" mode');
      }
      expect(vm.activeTool, 'select', reason: 'the fly keys are not the tool shortcuts in "Always" mode');
      final state = tester.state(find.byType(ViewportWidget)) as dynamic;
      expect(state.flightHintForTest as String, 'WASD/QE to fly · Arrow keys to move');

      final cycle = <String>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await frames(tester, 2);
        cycle.add(vm.activeTool);
      }
      expect(cycle, ['translate', 'rotate', 'scale', 'translate'], reason: 'Space cycles Move → Rotate → Scale');
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.rmbHeld);
      await unmount(tester);
    });

    testWidgets('never: the right button held + W does not fly, and mouse look still turns', (tester) async {
      final vm = await pumpEditor(tester);
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.never);
      await frames(tester, 2);
      final state = tester.state(find.byType(ViewportWidget)) as dynamic;
      expect(state.flightHintForTest as String, 'RMB to look · Arrow keys to move');
      final centre = tester.getCenter(find.byType(ViewportWidget));
      final rmb = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await frames(tester, 2);
      final before = pan(vm);
      await hold(tester, LogicalKeyboardKey.keyW);
      expect(moved(before, pan(vm)), lessThan(1e-6), reason: '"Never" keeps WASD off the camera');
      final yaw = vm.cameraYaw;
      await rmb.moveBy(const Offset(80, 0));
      await frames(tester, 2);
      expect(vm.cameraYaw, isNot(closeTo(yaw, 1e-6)), reason: 'RMB drag still looks around');
      await rmb.up();
      await frames(tester, 2);
      vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.rmbHeld);
      await unmount(tester);
    });
  });
}
