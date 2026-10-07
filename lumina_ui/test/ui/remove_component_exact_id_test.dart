import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Details × on one component removed every component of that
/// type on every selected actor, and Undo re-added only the first one, at the
/// end. No mocks: a real temp project, real actors and components.
void main() {
  late Directory tempDir;
  late EditorViewModel vm;

  const project = LuminaProject(projectName: 'ComponentGame', activeLevel: 'contents/levels/L_Main.lmas');
  const meshType = 'LuminaStaticMeshComponent';

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_remove_component_');
    final projDir = Directory('${tempDir.path}/ComponentGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/ComponentGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
  });

  tearDown(() {
    vm.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorActorNode actorWithTwoMeshes(String name) {
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last;
    vm.renameActor(actor.id, name);
    vm.addComponentWithTransaction(actor.id, meshType);
    vm.addComponentWithTransaction(actor.id, meshType);
    return actor;
  }

  test('× on the second of two same-type components removes only it; Undo puts it back in place', () {
    final actor = actorWithTwoMeshes('Crate');
    final meshes = actor.components.where((c) => c.type == meshType).toList();
    expect(meshes.length, 2);
    expect(meshes[0].id, isNot(meshes[1].id), reason: 'two components added back to back get distinct ids');
    meshes[0].properties['staticMeshAsset'] = 'contents/meshes/static/fuel_barrel_red.lmas';
    meshes[1].properties['staticMeshAsset'] = 'contents/meshes/static/aircon_small.lmas';
    final orderBefore = actor.components.map((c) => c.id).toList();
    vm.selectActors([actor.id]);

    vm.removeComponentWithTransaction(actor.id, meshes[1].id);

    expect(actor.components.map((c) => c.id), isNot(contains(meshes[1].id)));
    expect(actor.components.map((c) => c.id), contains(meshes[0].id), reason: 'the other mesh stays');

    vm.transactions.undo();
    expect(actor.components.map((c) => c.id).toList(), orderBefore, reason: 'restored in its original position');
    final restored = actor.components.firstWhere((c) => c.id == meshes[1].id);
    expect(restored.properties['staticMeshAsset'], 'contents/meshes/static/aircon_small.lmas');

    vm.transactions.redo();
    expect(actor.components.map((c) => c.id), isNot(contains(meshes[1].id)));
    expect(actor.components.map((c) => c.id), contains(meshes[0].id));
  });

  test('× in single selection never touches another selected actor, and an unknown id is a no-op', () {
    final a = actorWithTwoMeshes('CrateA');
    final b = actorWithTwoMeshes('CrateB');
    vm.selectActors([a.id, b.id]);
    final bBefore = b.components.map((c) => c.id).toList();
    final aMesh = a.components.firstWhere((c) => c.type == meshType);

    vm.removeComponentWithTransaction(a.id, aMesh.id);
    expect(b.components.map((c) => c.id).toList(), bBefore, reason: 'the other selected actor keeps its components');

    final aBefore = a.components.map((c) => c.id).toList();
    vm.removeComponentWithTransaction(a.id, 'comp_does_not_exist');
    expect(a.components.map((c) => c.id).toList(), aBefore);
  });

  test('multi-select "remove this component type" removes it from every selected actor and undoes exactly', () {
    final a = actorWithTwoMeshes('CrateA');
    final b = actorWithTwoMeshes('CrateB');
    vm.selectActors([a.id, b.id]);
    final aBefore = a.components.map((c) => c.id).toList();
    final bBefore = b.components.map((c) => c.id).toList();

    vm.removeComponentTypeFromSelectionWithTransaction(meshType);
    expect(a.components.any((c) => c.type == meshType), isFalse);
    expect(b.components.any((c) => c.type == meshType), isFalse);

    vm.transactions.undo();
    expect(a.components.map((c) => c.id).toList(), aBefore, reason: 'every removed component returns, in order');
    expect(b.components.map((c) => c.id).toList(), bBefore);
  });
}
