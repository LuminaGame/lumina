import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_core/lumina_core.dart';


import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {

  test('reparentActor transform preservation', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final parent = EditorActorNode(id: 'p1', name: 'Parent', type: 'StaticMesh', location: [40.0, 0.0, 0.0]);
    final child = EditorActorNode(id: 'c1', name: 'Child', type: 'StaticMesh', location: [100.0, 0.0, 50.0]);
    vm.addActorNodeForTest(parent);
    vm.addActorNodeForTest(child);
    
    vm.reparentActor(child.id, parent.id);
    expect(child.parentId, parent.id);
    expect(child.location, [60.0, 0.0, 50.0]); // Local location: World(100) - World(40) = Local(60)
  });

  test('cycle rejection', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'A', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'B', type: 'StaticMesh', location: [0,0,0], parentId: 'a');
    final c = EditorActorNode(id: 'c', name: 'C', type: 'StaticMesh', location: [0,0,0], parentId: 'b');
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    vm.addActorNodeForTest(c);
    
    expect(vm.canReparent('a', 'c'), false);
    
    // Reparent should ignore or throw, but not corrupt
    vm.reparentActor('a', 'c');
    expect(a.parentId, null); // Not reparented
  });

  test('renameActor rejects empty and duplicate names', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'MeshA', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'MeshB', type: 'StaticMesh', location: [0,0,0]);
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    
    vm.renameActor('a', '');
    expect(a.name, 'MeshA'); // ignored

    vm.renameActor('a', 'MeshB');
    expect(a.name, 'MeshA'); // rejected sibling duplicate
    
    vm.renameActor('a', 'MeshC');
    expect(a.name, 'MeshC');
  });

  test('duplicateActorSubtree duplicates deeply', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'Root', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'Child1', type: 'StaticMesh', location: [0,0,0], parentId: 'a');
    final c = EditorActorNode(id: 'c', name: 'Child2', type: 'StaticMesh', location: [0,0,0], parentId: 'a');
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    vm.addActorNodeForTest(c);
    
    vm.duplicateActorSubtree('a');
    // Default actors might be present, just check the duplicates exist
    expect(vm.actors.length > 3, true);
    final duplicatedRoot = vm.actors.firstWhere((x) => x.name == 'Root_Copy');
    final duplicatedChildren = vm.childrenOf(duplicatedRoot.id);
    expect(duplicatedChildren.length, 2);
    expect(duplicatedChildren.any((x) => x.name == 'Child1_Copy'), true);
    expect(duplicatedChildren.any((x) => x.name == 'Child2_Copy'), true);
  });

  test('deleteActorSubtree deletes deeply', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'Root', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'Child', type: 'StaticMesh', location: [0,0,0], parentId: 'a');
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    
    vm.deleteActorSubtree('a');
    expect(vm.actors.any((a) => a.id == 'a' || a.id == 'b'), false);
  });

  testWidgets('Widget test in ShadcnApp: double-click a row', (WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'Root', type: 'StaticMesh', location: [0,0,0]);
    vm.addActorNodeForTest(a);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        title: 'Test',
        home: Scaffold(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => OutlinerWidget(viewModel: vm),
          ),
        ),
      ),
    );

    expect(find.text('Root'), findsOneWidget);

    await tester.tap(find.text('Root'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Root'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'NewRoot');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('NewRoot'), findsOneWidget);
    expect(vm.actors.firstWhere((x) => x.id == 'a').name, 'NewRoot');
    vm.dispose();
  });

  testWidgets('Selection sync widget test: expands ancestors', (WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'Root', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'Child', type: 'StaticMesh', location: [0,0,0], parentId: 'a');
    final c = EditorActorNode(id: 'c', name: 'Deep', type: 'StaticMesh', location: [0,0,0], parentId: 'b');
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    vm.addActorNodeForTest(c);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        title: 'Test',
        home: Scaffold(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => OutlinerWidget(viewModel: vm),
          ),
        ),
      ),
    );

    // Initially collapsed, Deep is not visible
    expect(find.text('Deep'), findsNothing);

    vm.selectActorById('c');
    await tester.pumpAndSettle();

    // Ancestors expanded, Deep is visible
    expect(find.text('Deep'), findsOneWidget);
    
    // Tap Root
    await tester.tap(find.text('Root'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(vm.selectedActorId, 'a');
    vm.dispose();
  });

  testWidgets('Context menu targets the clicked node', (WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 'a', name: 'RootA', type: 'StaticMesh', location: [0,0,0]);
    final b = EditorActorNode(id: 'b', name: 'RootB', type: 'StaticMesh', location: [0,0,0]);
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        title: 'Test',
        home: Scaffold(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => OutlinerWidget(viewModel: vm),
          ),
        ),
      ),
    );

    vm.selectActorById('a');
    await tester.pumpAndSettle();

    // Right click b
    await tester.tap(find.text('RootB'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    
    // Check context menu is open
    expect(find.text('Delete Actor'), findsWidgets);
    
    // Tap Delete Actor
    await tester.tap(find.text('Delete Actor').last); // 'last' to pick from the overlay
    await tester.pumpAndSettle();

    // B is removed
    expect(vm.actors.any((x) => x.id == 'b'), false);
    // A is still selected and present
    expect(vm.selectedActorId, 'a');
    expect(vm.actors.any((x) => x.id == 'a'), true);
    vm.dispose();
  });

  testWidgets('Shift-click selects range of actors in outliner', (WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final a = EditorActorNode(id: 's1', name: 'Stair_01', type: 'StaticMesh', location: [0, 0, 0]);
    final b = EditorActorNode(id: 's2', name: 'Stair_02', type: 'StaticMesh', location: [0, 0, 0]);
    final c = EditorActorNode(id: 's3', name: 'Stair_03', type: 'StaticMesh', location: [0, 0, 0]);
    final d = EditorActorNode(id: 's4', name: 'Stair_04', type: 'StaticMesh', location: [0, 0, 0]);
    final e = EditorActorNode(id: 's5', name: 'Stair_05', type: 'StaticMesh', location: [0, 0, 0]);
    vm.addActorNodeForTest(a);
    vm.addActorNodeForTest(b);
    vm.addActorNodeForTest(c);
    vm.addActorNodeForTest(d);
    vm.addActorNodeForTest(e);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        title: 'Test',
        home: Scaffold(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => OutlinerWidget(viewModel: vm),
          ),
        ),
      ),
    );

    // 1. Normal click on Stair_02
    await tester.tap(find.text('Stair_02'));
    await tester.pumpAndSettle();
    expect(vm.selectedActorIds, equals({'s2'}));
    expect(vm.selectedActorId, 's2');

    // 2. Shift-click on Stair_04 -> selects Stair_02, Stair_03, Stair_04
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Stair_04'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(vm.selectedActorIds, equals({'s2', 's3', 's4'}));
    expect(vm.selectedActorId, 's4');

    // 3. Subsequent Shift-click on Stair_01 -> adjusts range from anchor Stair_02 backwards to Stair_01
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Stair_01'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(vm.selectedActorIds, equals({'s1', 's2'}));
    expect(vm.selectedActorId, 's1');

    // 4. Shift+Ctrl click adds range
    // First, click empty area to clear selection
    await tester.tap(find.byKey(const ValueKey('outliner_empty_area')));
    await tester.pumpAndSettle();
    expect(vm.selectedActorIds, isEmpty);

    // Click Stair_01
    await tester.tap(find.text('Stair_01'));
    await tester.pumpAndSettle();
    expect(vm.selectedActorIds, equals({'s1'}));

    // Ctrl-click Stair_03 to add it and make it anchor
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Stair_03'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(vm.selectedActorIds, equals({'s1', 's3'}));

    // Shift+Ctrl click Stair_05 -> adds range Stair_03..Stair_05 to existing selection (s1, s3, s4, s5)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Stair_05'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(vm.selectedActorIds, equals({'s1', 's3', 's4', 's5'}));

    vm.dispose();
  });

  test('importLevelDataFromJson deduplicates duplicate actor IDs preserving folders and hierarchy', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    final levelData = {
      'metadata': {
        'actors': [
          {'id': 'act_35', 'name': 'GroundF', 'type': 'Folder', 'parentId': null},
          {'id': 'c1', 'name': 'Child1', 'type': 'StaticMesh', 'parentId': 'act_35'},
          {'id': 'c2', 'name': 'Child2', 'type': 'StaticMesh', 'parentId': 'act_35'},
          {'id': 'act_35', 'name': 'BP_LightTower_35', 'type': 'Blueprint', 'parentId': null},
        ]
      }
    };

    vm.importLevelDataFromJson(levelData);

    expect(vm.actors.length, 4);
    final folder = vm.actors.firstWhere((a) => a.name == 'GroundF');
    final bp = vm.actors.firstWhere((a) => a.name == 'BP_LightTower_35');
    final c1 = vm.actors.firstWhere((a) => a.name == 'Child1');
    final c2 = vm.actors.firstWhere((a) => a.name == 'Child2');

    // Folder keeps act_35
    expect(folder.id, 'act_35');
    expect(c1.parentId, 'act_35');
    expect(c2.parentId, 'act_35');

    // BP receives a unique ID, distinct from act_35
    expect(bp.id, isNot('act_35'));

    // Children of GroundF are c1 and c2
    final folderChildren = vm.outlinerChildrenOf(folder.id);
    expect(folderChildren.map((a) => a.id), containsAll(['c1', 'c2']));

    // BP has no children in outliner
    final bpChildren = vm.outlinerChildrenOf(bp.id);
    expect(bpChildren, isEmpty);

    // Selecting BP does NOT select GroundF
    vm.selectActor(bp);
    expect(vm.selectedActorIds, equals({bp.id}));
    expect(vm.selectedActorIds.contains(folder.id), isFalse);

    vm.dispose();
  });
}

