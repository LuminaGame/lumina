import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// Blueprint Details number rows: a slider over
/// the schema's range plus an editable number field that may go past it up
/// to the hard limits; a typed value and a whole slider drag are one undo
/// step each, and the 3D Viewport's preview follows.
void main() {
  late BlueprintTestProject project;
  setUpAll(() => project = BlueprintTestProject.create(name: 'NumberFields'));
  tearDownAll(() => project.dispose());

  Future<BlueprintEditorViewModel> open(WidgetTester tester, String name) async {
    final vm = BlueprintEditorViewModel(assetPath: project.createBlueprint(name));
    await tester.runAsync(vm.load);
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: name, assetPath: vm.assetPath, viewModel: vm, showPreviewViewport: false)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    return vm;
  }

  Finder field(String componentId, String prop) =>
      find.descendant(of: find.byKey(ValueKey('bp_prop_${componentId}_$prop')), matching: find.byType(EditableText));

  Future<void> type(WidgetTester tester, Finder f, String text) async {
    await tester.tap(f);
    await tester.pump();
    await tester.enterText(f, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  double previewArm(BlueprintEditorViewModel vm) => (vm.preview.componentFor('spring_arm') as LuminaSpringArmComponent).targetArmLength;

  testWidgets('typing 500 into Target Arm Length changes the document and the preview arm; undo restores', (tester) async {
    final vm = await open(tester, 'BP_ArmTyped');
    addTearDown(vm.dispose);
    vm.selectComponent('spring_arm');
    await tester.pumpAndSettle();
    expect(find.text('Target Arm Length'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_prop_spring_arm_targetArmLength')), matching: find.byType(Slider)),
        findsOneWidget, reason: 'the slider stays');
    expect(previewArm(vm), 400.0);

    await type(tester, field('spring_arm', 'targetArmLength'), '500');
    expect(vm.getComponent('spring_arm')!.properties['targetArmLength'], 500.0);
    expect(previewArm(vm), 500.0, reason: 'the 3D Viewport\'s arm follows');
    expect(vm.transactions.undoLabel, 'Undo Edit Target Arm Length');

    vm.undo();
    await tester.pumpAndSettle();
    expect(vm.getComponent('spring_arm')!.properties['targetArmLength'], 400.0);
    expect(previewArm(vm), 400.0);
    expect(vm.transactions.canUndo, isFalse, reason: 'the typed value was one undo step');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a typed value goes past the slider up to the hard limits; negatives clamp to 0', (tester) async {
    final vm = await open(tester, 'BP_ArmRange');
    addTearDown(vm.dispose);
    vm.selectComponent('spring_arm');
    await tester.pumpAndSettle();
    final schema = BlueprintComponentRegistry.getSchema('LuminaSpringArmComponent').firstWhere((p) => p.dartField == 'targetArmLength');
    expect(schema.max, 2000.0);

    await type(tester, field('spring_arm', 'targetArmLength'), '2500');
    expect(vm.getComponent('spring_arm')!.properties['targetArmLength'], 2500.0, reason: 'past the slider\'s 2000');
    expect(previewArm(vm), 2500.0);
    await type(tester, field('spring_arm', 'targetArmLength'), '-40');
    expect(vm.getComponent('spring_arm')!.properties['targetArmLength'], 0.0, reason: 'a length is never negative');

    // Field of View keeps a hard ceiling.
    final camera = vm.document.components.firstWhere((c) => c.type == 'LuminaCameraComponent');
    vm.selectComponent(camera.id);
    await tester.pumpAndSettle();
    await type(tester, field(camera.id, 'fieldOfView'), '400');
    expect(vm.getComponent(camera.id)!.properties['fieldOfView'], 170.0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a slider drag is one undo step, recorded on release', (tester) async {
    final vm = await open(tester, 'BP_ArmDrag');
    addTearDown(vm.dispose);
    vm.selectComponent('spring_arm');
    await tester.pumpAndSettle();
    final slider = find.descendant(of: find.byKey(const ValueKey('bp_prop_spring_arm_targetArmLength')), matching: find.byType(Slider));
    final rect = tester.getRect(slider);
    final gesture = await tester.startGesture(rect.centerLeft + Offset(rect.width * 0.2, 0));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveBy(Offset(rect.width * 0.05, 0));
      await tester.pump();
    }
    final live = vm.getComponent('spring_arm')!.properties['targetArmLength'] as double;
    expect(live, isNot(400.0), reason: 'the drag writes through live');
    expect(previewArm(vm), live);
    expect(vm.transactions.canUndo, isFalse, reason: 'no undo step until release');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(vm.transactions.canUndo, isTrue);
    vm.undo();
    await tester.pumpAndSettle();
    expect(vm.getComponent('spring_arm')!.properties['targetArmLength'], 400.0, reason: 'one undo reverts the whole drag');
    expect(vm.transactions.canUndo, isFalse);
    expect(previewArm(vm), 400.0);
    await tester.pumpWidget(const SizedBox());
  });
}
