import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/data/models/lumina_project.dart';


import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
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
}
