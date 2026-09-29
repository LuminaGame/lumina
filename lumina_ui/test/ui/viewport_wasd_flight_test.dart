import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Viewport flight in the level editor: hold the right mouse button
/// over the viewport and W/A/S/D/Q/E fly the camera, Shift faster, Ctrl
/// slower. Driven end to end with real pointer and key events through the
/// whole editor, on the Third Person template's level in a temp project, and
/// checked on both the view model's camera and the native Filament camera.
void main() {
  Future<void> frames(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_wasd_flight_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'FlightGame', template: kThirdPersonTemplateId, input: template.input),
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

  double distance(List<double> a, List<double> b) =>
      math.sqrt(List.generate(3, (i) => (a[i] - b[i]) * (a[i] - b[i])).reduce((x, y) => x + y));

  /// Where the native Filament camera draws a fixed point off the view axis:
  /// it moves on screen whenever the camera moves.
  Offset probe(WidgetTester tester, List<double> point) {
    final size = tester.getSize(find.byType(ViewportWidget));
    final state = tester.state(find.byType(ViewportWidget)) as dynamic;
    return state.nativeProjectForTest(point[0], point[1], point[2], size) as Offset;
  }

  /// Holds the right button over the viewport, holds [keys] (with
  /// [modifiers]) for [holdFrames] frames, and lets go.
  Future<void> fly(WidgetTester tester, List<LogicalKeyboardKey> keys,
      {List<LogicalKeyboardKey> modifiers = const [], int holdFrames = 30}) async {
    final rmb = await tester.startGesture(tester.getCenter(find.byType(ViewportWidget)),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await frames(tester, 2);
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    for (final k in keys) {
      await tester.sendKeyDownEvent(k);
    }
    await frames(tester, holdFrames);
    for (final k in keys) {
      await tester.sendKeyUpEvent(k);
    }
    for (final m in modifiers) {
      await tester.sendKeyUpEvent(m);
    }
    await frames(tester, 2);
    await rmb.up();
    await frames(tester, 2);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  }

  testWidgets('RMB held + W/S/A/D/E/Q fly the view-model and the native camera', (tester) async {
    final vm = await pumpEditor(tester);
    final offAxis = [vm.cameraPanX + 150.0, vm.cameraPanY + 150.0, vm.cameraPanZ + 50.0];

    for (final key in [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyQ,
    ]) {
      final before = pan(vm);
      final drawnBefore = probe(tester, offAxis);
      await fly(tester, [key]);
      final moved = distance(before, pan(vm));
      final drawnMoved = (probe(tester, offAxis) - drawnBefore).distance;
      expect(moved, greaterThan(20.0), reason: '${key.keyLabel} with RMB held must fly the camera ($moved cm)');
      expect(drawnMoved, greaterThan(1.0), reason: '${key.keyLabel}: the native Filament camera must move too');
    }
    expect(vm.activeTool, 'select', reason: 'W/E/Q while flying are not the transform-tool shortcuts');
    await unmount(tester);
  });

  testWidgets('Shift flies faster and Ctrl slower', (tester) async {
    final vm = await pumpEditor(tester);
    var before = pan(vm);
    await fly(tester, [LogicalKeyboardKey.keyW]);
    final normal = distance(before, pan(vm));
    before = pan(vm);
    await fly(tester, [LogicalKeyboardKey.keyW], modifiers: [LogicalKeyboardKey.shiftLeft]);
    final boosted = distance(before, pan(vm));
    before = pan(vm);
    await fly(tester, [LogicalKeyboardKey.keyW], modifiers: [LogicalKeyboardKey.controlLeft]);
    final slowed = distance(before, pan(vm));
    expect(boosted, greaterThan(normal * 1.5), reason: 'Shift boosts ($boosted vs $normal)');
    expect(slowed, lessThan(normal * 0.6), reason: 'Ctrl slows ($slowed vs $normal)');
    expect(slowed, greaterThan(0.0));
    await unmount(tester);
  });

  testWidgets('flight works right after focus was in the Content Browser, the Outliner or the Details panel',
      (tester) async {
    final vm = await pumpEditor(tester);
    final actor = vm.actors.firstWhere((a) => a.type == 'PlayerStart');

    Future<void> expectFlight(String after) async {
      final before = pan(vm);
      await fly(tester, [LogicalKeyboardKey.keyW]);
      expect(distance(before, pan(vm)), greaterThan(20.0), reason: 'RMB + W must fly after $after');
    }

    // Content Browser search field.
    final search = find.byWidgetPredicate((w) => w is TextField && (w.placeholder is Text) &&
        ((w.placeholder as Text).data ?? '').toLowerCase().contains('search'));
    expect(search, findsWidgets);
    await tester.tap(search.first);
    await frames(tester, 3);
    await expectFlight('typing in a search field');

    // An Outliner row.
    await tester.tap(find.byKey(ValueKey('row_gesture_${actor.id}')));
    await frames(tester, 3);
    expect(vm.selectedActorId, actor.id);
    await expectFlight('selecting an Outliner row');

    // A Details panel number field of the selected actor.
    // (Details sits under the Outliner.)
    final detailsField = find.descendant(of: find.byType(DetailsWidget), matching: find.byType(TextField)).evaluate().where((e) {
      final box = e.renderObject as RenderBox?;
      return box != null && box.hasSize;
    });
    expect(detailsField, isNotEmpty, reason: 'the Details panel shows the selected actor\'s fields');
    await tester.tap(find.byElementPredicate((e) => e == detailsField.first));
    await frames(tester, 3);
    await expectFlight('clicking into a Details field');
    await unmount(tester);
  });
}
