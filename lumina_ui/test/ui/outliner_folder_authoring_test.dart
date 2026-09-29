import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Ray, Vector3;

/// Folder authoring on the view model, against a real temp
/// project: create folders (optionally around the
/// selection), move nodes into and out of them, and the outliner's tree
/// expansion state.
void main() {
  late Directory tempDir;
  late EditorViewModel vm;
  const project = LuminaProject(projectName: 'FolderGame');

  Future<EditorViewModel> openEditor() async {
    final editor = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await editor.ensureDefaultLevelAssets();
    return editor;
  }

  EditorActorNode node(String id) => vm.actors.firstWhere((a) => a.id == id);
  EditorActorNode named(String name) => vm.actors.firstWhere((a) => a.name == name);

  /// A real primitive, spawned the way the Add menu spawns it.
  String addCrate(String name, List<double> location, {String? parentId}) {
    vm.spawnNewActor('Primitive', parentId: parentId);
    final crate = vm.actors.last;
    vm.renameActorWithTransaction(crate.id, name);
    crate.location = List<double>.from(location);
    return crate.id;
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_outliner_folders_');
    vm = await openEditor();
  });

  tearDown(() {
    vm.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('createFolder with nothing selected makes a selected, expanded root folder; undo removes only the last', () {
    vm.clearSelection();
    final first = vm.createFolder();
    expect(node(first).type, 'Folder');
    expect(node(first).name, 'NewFolder');
    expect(node(first).parentId, isNull);
    expect(node(first).location, [0.0, 0.0, 0.0]);
    expect(vm.selectedActorId, first);
    expect(vm.isOutlinerExpanded(first), isTrue);

    vm.clearSelection();
    final second = vm.createFolder();
    expect(node(second).name, 'NewFolder_1');

    vm.transactions.undo();
    expect(vm.actors.any((a) => a.id == second), isFalse);
    expect(vm.actors.any((a) => a.id == first), isTrue);
  });

  test('createFolder wraps the selection in one undoable step, keeping world locations', () {
    final a = addCrate('Crate_01', [3, 0, -2]);
    final b = addCrate('Crate_02', [5, 0, -2]);
    vm.selectActorById(a);
    vm.toggleActorSelection(b);

    final folder = vm.createFolder(wrapIds: vm.selectedActorIds);
    expect(node(a).parentId, folder);
    expect(node(b).parentId, folder);
    expect(node(a).location, [3.0, 0.0, -2.0]);
    expect(node(b).location, [5.0, 0.0, -2.0]);

    vm.transactions.undo();
    expect(vm.actors.any((x) => x.id == folder), isFalse);
    expect(node(a).parentId, isNull);
    expect(node(b).parentId, isNull);
    expect(node(a).location, [3.0, 0.0, -2.0]);

    vm.transactions.redo();
    expect(node(a).parentId, folder);
    expect(node(b).parentId, folder);
  });

  test('New Folder with a folder selected nests the new folder inside it', () {
    final props = vm.createFolder(name: 'Props');
    vm.selectActorById(props);
    vm.commands.execute('outliner.newFolder');
    final inner = vm.actors.last;
    expect(inner.type, 'Folder');
    expect(inner.parentId, props);
  });

  test('moveToFolder moves only the topmost of a selected chain, rejects cycles and folder-under-actor', () {
    final lighting = vm.createFolder(name: 'Lighting');
    final parent = addCrate('Parent', [1, 0, 0]);
    final child = addCrate('Child', [1, 0, 0], parentId: parent);

    vm.moveToFolder([parent, child], lighting);
    expect(node(parent).parentId, lighting);
    expect(node(child).parentId, parent, reason: 'the child travels with its parent');

    final outer = vm.createFolder(name: 'Outer');
    final innerFolder = vm.createFolder(name: 'Inner', parentFolderId: outer);
    expect(vm.canMoveToFolder(outer, innerFolder), isFalse);
    vm.moveToFolder([outer], innerFolder);
    expect(node(outer).parentId, isNull, reason: 'a folder cannot move into its own descendant');
    // The rejected move recorded nothing: undo takes back the Inner folder.
    vm.transactions.undo();
    expect(vm.actors.any((a) => a.id == innerFolder), isFalse);

    expect(vm.canReparent(outer, parent), isFalse, reason: 'a folder never goes under a plain actor');

    vm.moveToFolder([parent], null);
    expect(node(parent).parentId, isNull);
  });

  test('a folder tree survives save and reload and never reaches the generated level', () async {
    final props = vm.createFolder(name: 'Props');
    final crates = vm.createFolder(name: 'Crates', parentFolderId: props);
    final crate = addCrate('Crate_01', [2, 0, 4]);
    vm.moveToFolder([crate], crates);

    await vm.saveLevelAndGenerateCode();
    final level = File('${tempDir.path}/FolderGame/lib/levels/${vm.project.activeLevel.split('/').last.replaceAll('.lmas', '')}.dart')
        .readAsStringSync();
    expect(level, contains("'$crate'"));
    expect(level, isNot(contains('Props')));
    expect(level, isNot(contains('Crates')));
    expect(level, isNot(contains('Folder')));

    final reloaded = await openEditor();
    addTearDown(reloaded.dispose);
    EditorActorNode r(String id) => reloaded.actors.firstWhere((a) => a.id == id);
    expect(r(props).type, 'Folder');
    expect(r(crates).parentId, props);
    expect(r(crate).parentId, crates);
    expect(r(crate).location, [2.0, 0.0, 4.0]);
  });

  test('outliner expansion: toggle, collapse all, expand a subtree, prune on delete, reveal the selection', () {
    final props = vm.createFolder(name: 'Props');
    final crates = vm.createFolder(name: 'Crates', parentFolderId: props);
    final lighting = vm.createFolder(name: 'Lighting');
    final crate = addCrate('Crate_01', [0, 0, 0]);
    vm.moveToFolder([crate], crates);

    expect(vm.isOutlinerExpanded(props), isTrue);
    vm.toggleOutlinerExpanded(props);
    expect(vm.isOutlinerExpanded(props), isFalse);

    vm.collapseAllInOutliner();
    expect(vm.outlinerExpandedIds, isEmpty);

    vm.expandAllInOutliner(under: props);
    expect(vm.isOutlinerExpanded(props), isTrue);
    expect(vm.isOutlinerExpanded(crates), isTrue);
    expect(vm.isOutlinerExpanded(lighting), isFalse);

    vm.collapseAllInOutliner();
    vm.selectActorById(crate);
    expect(vm.isOutlinerExpanded(crates), isTrue, reason: 'selecting reveals the node');
    expect(vm.isOutlinerExpanded(props), isTrue);

    vm.deleteActorSubtreeWithTransaction(lighting);
    vm.setOutlinerExpanded(lighting, true);
    expect(vm.outlinerExpandedIds.contains(lighting), isFalse, reason: 'deleted ids are pruned');
  });

  test('folderPaths lists every folder by its path', () {
    final props = vm.createFolder(name: 'Props');
    vm.createFolder(name: 'Crates', parentFolderId: props);
    expect(vm.folderPaths.map((f) => f.path), containsAll(<String>['Props', 'Props / Crates']));
  });

  test('siblings sort folders first, alphabetically, then actors in their order', () {
    final parent = vm.createFolder(name: 'Parent');
    final crate = addCrate('Crate_01', [0, 0, 0]);
    final barrel = addCrate('Barrel_01', [0, 0, 0]);
    vm.moveToFolder([crate, barrel], parent);
    vm.createFolder(name: 'Zeta', parentFolderId: parent);
    vm.createFolder(name: 'Alpha', parentFolderId: parent);
    expect(vm.outlinerChildrenOf(parent).map((a) => a.name).toList(), ['Alpha', 'Zeta', 'Crate_01', 'Barrel_01']);
  });

  test('folders are never drawn or picked in the viewport', () {
    final props = vm.createFolder(name: 'Props');
    final crate = addCrate('Crate_01', [0, 0, 0]);
    expect(vm.isViewportRepresented(props), isFalse);
    expect(vm.isViewportRepresented(crate), isTrue);
    expect(named('Props').type, 'Folder');

    // The picker's non-mesh fallback hits every actor it is given; a folder
    // must never be one of them.
    final ray = Ray.originDirection(Vector3(0, 0, 10), Vector3(0, 0, -1));
    final hits = ViewportPicker().pickActors([named('Props'), named('DirectionalLight_Sun')], ray, Matrix4.identity());
    expect(hits.map((h) => h.actor.name), isNot(contains('Props')));
    expect(hits.map((h) => h.actor.name), contains('DirectionalLight_Sun'));
  });

  test('F2 (outliner.rename) puts the selected row into inline rename', () {
    final crate = addCrate('Crate_01', [0, 0, 0]);
    vm.selectActorById(crate);
    expect(vm.commands.byId('outliner.rename')!.shortcutLabel, 'F2');
    expect(vm.commands.execute('outliner.rename'), isTrue);
    expect(vm.outlinerRenamingId, crate);
    vm.endOutlinerRename();
    expect(vm.outlinerRenamingId, isNull);
  });
}
