import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The World Outliner's folder authoring, driven through the
/// real widget: header New Folder + inline rename, folder chevrons and icons,
/// mouse drag-and-drop (single and multi), drop rejection, Move to Folder.
void main() {
  late Directory tempDir;
  const project = LuminaProject(projectName: 'TreeGame');

  Future<EditorViewModel> openEditor(WidgetTester tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async {
      vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
      await vm.ensureDefaultLevelAssets();
    });
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pumpOutliner(WidgetTester tester, EditorViewModel vm) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ListenableBuilder(listenable: vm, builder: (context, _) => OutlinerWidget(viewModel: vm)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  String addCrate(EditorViewModel vm, String name) {
    vm.spawnNewActor('Primitive');
    final crate = vm.actors.last;
    vm.renameActorWithTransaction(crate.id, name);
    return crate.id;
  }

  Finder row(String id) => find.byKey(ValueKey('outliner_row_$id'));

  /// A real mouse drag (no long press) from one row onto another.
  Future<void> mouseDrag(WidgetTester tester, Finder from, Finder to) async {
    final start = tester.getCenter(from);
    final end = tester.getCenter(to);
    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await tester.pump();
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_outliner_tree_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('the header New Folder button creates a folder straight into inline rename', (tester) async {
    final vm = await openEditor(tester);
    vm.clearSelection();
    await pumpOutliner(tester, vm);

    await tester.tap(find.byKey(const ValueKey('outliner_new_folder')));
    await tester.pump(const Duration(milliseconds: 100));

    final folder = vm.actors.last;
    expect(folder.type, 'Folder');
    final field = find.byKey(const ValueKey('outliner_rename_field'));
    expect(field, findsOneWidget);

    await tester.enterText(find.descendant(of: field, matching: find.byType(EditableText)), 'Lighting');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 100));

    expect(vm.actors.firstWhere((a) => a.id == folder.id).name, 'Lighting');
    expect(find.byKey(const ValueKey('outliner_rename_field')), findsNothing);
    expect(find.text('Lighting'), findsOneWidget);
  });

  testWidgets('folders open and close: chevron on an empty folder, open/closed icon, double-click', (tester) async {
    final vm = await openEditor(tester);
    final props = vm.createFolder(name: 'Props');
    vm.endOutlinerRename();
    vm.collapseAllInOutliner();
    await pumpOutliner(tester, vm);

    final chevron = find.byKey(ValueKey('outliner_chevron_$props'));
    expect(chevron, findsOneWidget, reason: 'an empty folder can still be opened');
    expect(find.descendant(of: row(props), matching: find.byIcon(LucideIcons.folder)), findsOneWidget);

    await tester.tap(chevron);
    await tester.pump();
    expect(vm.isOutlinerExpanded(props), isTrue);
    expect(find.descendant(of: row(props), matching: find.byIcon(LucideIcons.folderOpen)), findsOneWidget);

    final crate = addCrate(vm, 'Crate_01');
    vm.moveToFolder([crate], props);
    vm.clearSelection();
    await tester.pump();
    expect(row(crate), findsOneWidget);

    await tester.tap(chevron);
    await tester.pump();
    expect(row(crate), findsNothing);

    // Double-clicking a folder row toggles it as well.
    await tester.tap(find.byKey(ValueKey('row_gesture_$props')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(ValueKey('row_gesture_$props')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(vm.isOutlinerExpanded(props), isTrue);
    expect(row(crate), findsOneWidget);
  });

  testWidgets('a plain mouse drag moves an actor into a folder, and a selected row carries the selection', (tester) async {
    final vm = await openEditor(tester);
    final props = vm.createFolder(name: 'Props');
    vm.endOutlinerRename();
    vm.collapseAllInOutliner();
    final a = addCrate(vm, 'Crate_01');
    final b = addCrate(vm, 'Crate_02');
    final c = addCrate(vm, 'Crate_03');
    vm.clearSelection();
    await pumpOutliner(tester, vm);

    await mouseDrag(tester, row(a), row(props));
    expect(vm.actors.firstWhere((x) => x.id == a).parentId, props);
    expect(vm.isOutlinerExpanded(props), isTrue, reason: 'the receiving folder opens');

    vm.selectActorById(b);
    vm.toggleActorSelection(c);
    await tester.pump();
    await mouseDrag(tester, row(b), row(props));
    expect(vm.actors.firstWhere((x) => x.id == b).parentId, props);
    expect(vm.actors.firstWhere((x) => x.id == c).parentId, props, reason: 'the whole selection moves');
  });

  testWidgets('a folder dropped on an actor is rejected; dropping on the empty area moves to the root', (tester) async {
    final vm = await openEditor(tester);
    final outer = vm.createFolder(name: 'Outer');
    final props = vm.createFolder(name: 'Props', parentFolderId: outer);
    vm.endOutlinerRename();
    final crate = addCrate(vm, 'Crate_03');
    final inner = addCrate(vm, 'Inner');
    vm.moveToFolder([inner], props);
    vm.clearSelection();
    await pumpOutliner(tester, vm);

    await mouseDrag(tester, row(props), row(crate));
    expect(vm.actors.firstWhere((x) => x.id == props).parentId, outer,
        reason: 'the drop is rejected: the folder stays where it was, not under the actor or at the root');

    await mouseDrag(tester, row(inner), find.byKey(const ValueKey('outliner_empty_area')));
    expect(vm.actors.firstWhere((x) => x.id == inner).parentId, isNull);
  });

  testWidgets('Move to Folder moves into a nested folder and back to the root; folders say Delete Folder', (tester) async {
    final vm = await openEditor(tester);
    final props = vm.createFolder(name: 'Props');
    final crates = vm.createFolder(name: 'Crates', parentFolderId: props);
    vm.endOutlinerRename();
    final barrel = addCrate(vm, 'Barrel_01');
    vm.clearSelection();
    await pumpOutliner(tester, vm);

    await tester.tap(find.byKey(ValueKey('row_gesture_$barrel')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Props / Crates'));
    await tester.pumpAndSettle();
    expect(vm.actors.firstWhere((x) => x.id == barrel).parentId, crates);

    await tester.tap(find.byKey(ValueKey('row_gesture_$barrel')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('(Root)'));
    await tester.pumpAndSettle();
    expect(vm.actors.firstWhere((x) => x.id == barrel).parentId, isNull);

    await tester.tap(find.byKey(ValueKey('row_gesture_$props')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete Folder'), findsOneWidget);
    expect(find.text('Delete Actor'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('Expand All and Collapse All in the header', (tester) async {
    final vm = await openEditor(tester);
    final props = vm.createFolder(name: 'Props');
    final crates = vm.createFolder(name: 'Crates', parentFolderId: props);
    vm.endOutlinerRename();
    await pumpOutliner(tester, vm);

    await tester.tap(find.byKey(const ValueKey('outliner_collapse_all')));
    await tester.pump();
    expect(vm.outlinerExpandedIds, isEmpty);
    expect(row(crates), findsNothing);

    await tester.tap(find.byKey(const ValueKey('outliner_expand_all')));
    await tester.pump();
    expect(vm.isOutlinerExpanded(props), isTrue);
    expect(row(crates), findsOneWidget);
  });

  testWidgets('a folder created while the list is scrolled down scrolls into view in rename', (tester) async {
    final vm = await openEditor(tester);
    for (var i = 0; i < 60; i++) {
      addCrate(vm, 'Crate_${i.toString().padLeft(2, '0')}');
    }
    final last = vm.actors.last.id;
    vm.clearSelection();
    await pumpOutliner(tester, vm);

    final list = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    tester.state<ScrollableState>(list).position.jumpTo(tester.state<ScrollableState>(list).position.maxScrollExtent);
    await tester.pump();
    expect(row(last), findsOneWidget);

    vm.selectActorById(last);
    await tester.tap(find.byKey(const ValueKey('outliner_new_folder')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('outliner_rename_field')), findsOneWidget,
        reason: 'the new folder sorts to the top; the list must follow it');
  });
}
