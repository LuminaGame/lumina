import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Blueprint Components panel is built like the World Outliner and
/// attaches components by drag and drop, as in the character Blueprint of
/// the report: Body onto the Capsule, the Camera onto the Spring Arm.
void main() {
  late BlueprintEditorViewModel vm;
  late Map<String, String> ids;

  setUp(() {
    vm = BlueprintEditorViewModel(
      assetPath: 'contents/blueprints/BP_MH_1.lmas',
      initialAsset: LuminaAsset(assetId: 'BP_MH_1', name: 'BP_MH_1', type: AssetType.actor),
    );
    final root = vm.addComponent('LuminaSceneComponent')!;
    final body = vm.addComponent('LuminaSkeletalMeshComponent', parentId: root.id)!;
    final capsule = vm.addComponent('LuminaCapsuleComponent', parentId: root.id)!;
    final arm = vm.addComponent('LuminaSpringArmComponent', parentId: root.id)!;
    final camera = vm.addComponent('LuminaCameraComponent', parentId: root.id)!;
    final movement = vm.addComponent('LuminaCharacterMovementComponent')!;
    ids = {'root': root.id, 'body': body.id, 'capsule': capsule.id, 'arm': arm.id, 'camera': camera.id, 'movement': movement.id};
  });

  Future<void> pumpTree(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 420, height: 700, child: BlueprintComponentTree(viewModel: vm))),
    ));
    await tester.pump();
  }

  Finder row(String key) => find.byKey(ValueKey('component_row_${ids[key]}'));

  Future<void> dragOnto(WidgetTester tester, String from, Finder to) async {
    final gesture = await tester.startGesture(tester.getCenter(row(from)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 6));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging Body onto the Capsule and the Camera onto the Spring Arm attaches them', (tester) async {
    await pumpTree(tester);
    await dragOnto(tester, 'body', row('capsule'));
    expect(vm.getComponent(ids['body']!)!.parentId, ids['capsule']);
    await dragOnto(tester, 'camera', row('arm'));
    expect(vm.getComponent(ids['camera']!)!.parentId, ids['arm']);
    // One undo step each.
    vm.undo();
    expect(vm.getComponent(ids['camera']!)!.parentId, ids['root']);
    vm.redo();
    await tester.pumpAndSettle();
    // The rows are indented under their new parents.
    expect(tester.getTopLeft(find.descendant(of: row('camera'), matching: find.text('CameraComponent'))).dx,
        greaterThan(tester.getTopLeft(find.descendant(of: row('arm'), matching: find.text('SpringArmComponent'))).dx));
  });

  testWidgets('a drop on the empty area attaches to the root; the root, a cycle and actor components are refused',
      (tester) async {
    await pumpTree(tester);
    await dragOnto(tester, 'camera', row('arm'));
    await dragOnto(tester, 'camera', find.byKey(const ValueKey('components_empty_area')));
    expect(vm.getComponent(ids['camera']!)!.parentId, ids['root']);

    await dragOnto(tester, 'arm', row('camera'));
    expect(vm.getComponent(ids['arm']!)!.parentId, ids['camera']);
    // The camera now holds the arm: it cannot go under the arm.
    await dragOnto(tester, 'camera', row('arm'));
    expect(vm.getComponent(ids['camera']!)!.parentId, ids['root']);
    // The root and the movement component do not drag.
    await dragOnto(tester, 'root', row('capsule'));
    expect(vm.getComponent(ids['root']!)!.parentId, isNull);
    await dragOnto(tester, 'movement', row('capsule'));
    expect(vm.getComponent(ids['movement']!)!.parentId, isNull);
    // The view model refuses a second root.
    expect(vm.reparent(ids['body']!, null), isTrue);
    expect(vm.getComponent(ids['body']!)!.parentId, ids['root']);
    expect(vm.canReparent(ids['root']!, null), isFalse);
  });

  testWidgets('search filters rows and double-click renames inline', (tester) async {
    await pumpTree(tester);
    await tester.enterText(find.byKey(const ValueKey('components_search')), 'cam');
    await tester.pump();
    expect(row('camera'), findsOneWidget);
    expect(row('capsule'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('components_search')), '');
    await tester.pump();

    final name = find.descendant(of: row('capsule'), matching: find.text('CapsuleComponent'));
    await tester.tap(name);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(name);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('component_rename_field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Collision');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(vm.getComponent(ids['capsule']!)!.name, 'Collision');
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('the header and rows use the World Outliner\'s measurements', (tester) async {
    await pumpTree(tester);
    final heading = tester.widget<Text>(find.text('COMPONENTS'));
    expect(heading.style, EditorIslandHeader.titleStyle);
    final header = find.ancestor(of: find.text('COMPONENTS'), matching: find.byType(EditorIslandHeader));
    expect(tester.getSize(header).height, EditorIslandStyle.headerHeight);
    expect(tester.getSize(row('body')).height, EditorDensity.rowHeight);
    expect(find.byKey(const ValueKey('add_component_button')), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
