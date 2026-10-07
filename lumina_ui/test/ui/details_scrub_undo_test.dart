import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor is a Linux desktop app: its text fields select with a pan
/// recognizer there, which a scrub beats (widget tests default to Android,
/// whose horizontal text-drag recognizer wins the arena instead).
final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// A Details scrub opened a transform drag and its release never
/// ended it, so no undo transaction was recorded and Edit → Undo did nothing.
void main() {
  late Directory project;
  late EditorViewModel vm;
  late EditorActorNode actor;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_details_scrub_undo_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ScrubUndo', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: project.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    actor = EditorActorNode(id: 'crate', name: 'Crate', type: 'LuminaStaticMesh', location: [10, 20, 0]);
    vm.addActorNodeForTest(actor);
    vm.selectActor(actor);
  });

  tearDown(() {
    vm.dispose();
    project.deleteSync(recursive: true);
  });

  Future<void> pumpDetails(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: vm))));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Scrubs [field] to the right with a mouse: slow first pixels (a scrub has
  /// to win over the text field's drag-to-select), then [steps] moves.
  Future<void> scrub(WidgetTester tester, Finder field, {int steps = 30}) async {
    final g = await tester.startGesture(tester.getCenter(field) + const Offset(10, 0), kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 3; i++) {
      await g.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < steps; i++) {
      await g.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder locationAxis(int axis) =>
      find.descendant(of: find.byType(VectorRow).first, matching: find.byType(ScrubNumericField)).at(axis);

  testWidgets('a Location Z scrub is one undo transaction and Edit → Undo restores it', (tester) async {
    await pumpDetails(tester);
    await scrub(tester, locationAxis(2));
    expect(actor.location[2], greaterThan(20), reason: 'the scrub moved the actor up');

    final undo = vm.commands.byId('edit.undo')!;
    expect(undo.canExecute(), isTrue, reason: 'Edit → Undo is available after the scrub');
    undo.execute(tester.element(find.byType(DetailsWidget)));
    await tester.pump();
    expect(actor.location, [10, 20, 0], reason: 'Undo puts the actor back where the scrub started');
    expect(vm.transactions.canUndo, isFalse, reason: 'the scrub was exactly one transaction');

    vm.transactions.redo();
    expect(actor.location[2], greaterThan(20));
  }, variant: _linux);

  testWidgets('a typed edit after a scrub is its own undo step', (tester) async {
    await pumpDetails(tester);
    await scrub(tester, locationAxis(2));
    final scrubbedZ = actor.location[2];

    // Click X, type 75 and press Enter. (The drag the scrub left open used to
    // swallow this commit too.)
    await tester.tap(locationAxis(0), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.enterText(find.descendant(of: locationAxis(0), matching: find.byType(EditableText)), '75');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(actor.location[0], 75);

    // One Undo per edit (the click and the Enter no longer add their own
    // steps): the typed X first, then the scrub.
    vm.transactions.undo();
    expect(actor.location, [10, 20, scrubbedZ], reason: 'the first Undo reverts only the typed X');
    vm.transactions.undo();
    expect(actor.location, [10, 20, 0], reason: 'the second Undo reverts the scrub');
    expect(vm.transactions.canUndo, isFalse);
  }, variant: _linux);
}
