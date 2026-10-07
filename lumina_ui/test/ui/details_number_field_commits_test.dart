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

/// The editor is a Linux desktop app; the text field's gestures differ on the
/// widget-test default (Android).
final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// A click on a Details number field committed the field's stale
/// scrub value (0 at first), and a typed value was committed twice (Enter,
/// then the focus loss it causes), leaving spurious undo steps.
void main() {
  late Directory project;
  late EditorViewModel vm;
  late EditorActorNode actor;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_details_number_commits_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'NumberCommits', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: project.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    actor = EditorActorNode(id: 'crate', name: 'Crate', type: 'LuminaStaticMesh', location: [10, 20, 30]);
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

  Finder locationAxis(int axis) =>
      find.descendant(of: find.byType(VectorRow).first, matching: find.byType(ScrubNumericField)).at(axis);

  Future<void> click(WidgetTester tester, Finder field) async {
    await tester.tap(field, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('clicking a field to type into it writes nothing', (tester) async {
    await pumpDetails(tester);
    await click(tester, locationAxis(0));
    expect(actor.location, [10, 20, 30], reason: 'a click does not move the actor');
    expect(vm.transactions.canUndo, isFalse, reason: 'a click records no undo step');
  }, variant: _linux);

  testWidgets('typing a value and pressing Enter is exactly one undo step', (tester) async {
    await pumpDetails(tester);
    await click(tester, locationAxis(0));
    await tester.enterText(find.descendant(of: locationAxis(0), matching: find.byType(EditableText)), '75');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 50));
    expect(actor.location, [75, 20, 30]);

    vm.transactions.undo();
    expect(actor.location, [10, 20, 30], reason: 'the first Undo reverts the typed value');
    expect(vm.transactions.canUndo, isFalse, reason: 'the edit was one undo step');
  }, variant: _linux);

  testWidgets('focusing a field and leaving it without typing writes nothing', (tester) async {
    await pumpDetails(tester);
    await click(tester, locationAxis(1));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    expect(actor.location, [10, 20, 30]);
    expect(vm.transactions.canUndo, isFalse);
    expect(tester.widget<EditableText>(find.descendant(of: locationAxis(1), matching: find.byType(EditableText))).controller.text, '20.00');
  }, variant: _linux);
}
