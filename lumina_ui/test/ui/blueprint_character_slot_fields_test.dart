import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// A Blueprint character's slot fields in the Details panel: the Slot name
/// and the Pose From picker, which lists the other skeletal meshes of the
/// Blueprint but never the component itself or one already following it.
void main() {
  late BlueprintTestProject project;
  setUpAll(() => project = BlueprintTestProject.create(name: 'SlotFields'));
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

  test('Skeletal Mesh and Skinned Cloth carry Slot and Pose From', () {
    for (final type in ['LuminaSkeletalMeshComponent', 'LuminaSkinnedClothComponent']) {
      final schema = BlueprintComponentRegistry.getSchema(type);
      final slot = schema.firstWhere((p) => p.dartField == 'slot');
      expect(slot.type, ComponentPropertyType.string);
      final from = schema.firstWhere((p) => p.dartField == 'poseFrom');
      expect(from.type, ComponentPropertyType.componentReference);
      expect(from.referenceTypes, contains('LuminaSkeletalMeshComponent'));
    }
  });

  testWidgets('Pose From lists the other skeletal meshes; picking one stores its id; a follower cannot lead its leader', (tester) async {
    final vm = await open(tester, 'BP_Slots');
    addTearDown(vm.dispose);
    final body = vm.addComponent('LuminaSkeletalMeshComponent')!;
    final hair = vm.addComponent('LuminaSkeletalMeshComponent', parentId: body.id)!;
    vm.selectComponent(hair.id);
    await tester.pumpAndSettle();
    expect(find.text('CHARACTER'), findsOneWidget);
    expect(find.text('Slot'), findsOneWidget);
    expect(find.text('Pose From'), findsOneWidget);

    // Slot: a typed name.
    final slotField = find.descendant(of: find.byKey(ValueKey('bp_prop_${hair.id}_slot')), matching: find.byType(EditableText));
    await tester.enterText(slotField, 'Hair');
    await tester.pumpAndSettle();
    expect(vm.getComponent(hair.id)!.properties['slot'], 'Hair');

    // Pose From: None, then the body.
    await tester.tap(find.byKey(const ValueKey('bp_component_ref_poseFrom')));
    await tester.pumpAndSettle();
    expect(find.text('None'), findsWidgets);
    expect(find.text(hair.name), findsWidgets, reason: 'its own name is the tree row, not an option');
    await tester.tap(find.text(body.name).last);
    await tester.pumpAndSettle();
    expect(vm.getComponent(hair.id)!.properties['poseFrom'], body.id);

    // The body's picker leaves out the hair, which follows it.
    vm.selectComponent(body.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bp_component_ref_poseFrom')));
    await tester.pumpAndSettle();
    final options = find.descendant(of: find.byType(SelectItemButton<String>), matching: find.byType(Text));
    final labels = [for (final e in options.evaluate()) (e.widget as Text).data];
    expect(labels.first, 'None');
    expect(labels, isNot(contains(hair.name)), reason: 'the hair follows the body: no cycle offered');
    expect(labels, isNot(contains(body.name)), reason: 'not itself');
    await tester.pumpWidget(const SizedBox());
  });
}
