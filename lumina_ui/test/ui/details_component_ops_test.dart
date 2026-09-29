import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// The Details panel's add-component entry point returns the
/// node it added, so a caller (the MCP `add_actor_component` tool) gets its
/// id; ids never collide in a burst; removal is exact (covered in
/// remove_component_exact_id_test.dart). A real temp project, real actors.
void main() {
  late Directory root;
  late EditorViewModel vm;

  const project = LuminaProject(projectName: 'OpsGame', activeLevel: 'contents/levels/L_Main.lmas');
  const lightType = 'LuminaPointLightComponent';

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_details_ops_');
    final projDir = Directory('${root.path}/OpsGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/OpsGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
  });

  tearDown(() async {
    await vm.close();
    await deleteTempProject(root);
  });

  test('addComponentWithTransaction returns the node it added, one undo step', () {
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last;
    final node = vm.addComponentWithTransaction(actor.id, lightType);
    expect(node, isNotNull);
    expect(node!.type, lightType);
    expect(actor.components.last, same(node));
    expect(vm.transactions.undoLabel, 'Undo Add Component');
    vm.transactions.undo();
    expect(actor.components.map((c) => c.id), isNot(contains(node.id)));
  });

  test('a burst of adds in the same millisecond gets distinct ids; an unknown actor returns null', () {
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last;
    final ids = [for (var i = 0; i < 20; i++) vm.addComponentWithTransaction(actor.id, lightType)!.id];
    expect(ids.toSet(), hasLength(20));
    expect(vm.addComponentWithTransaction('act_missing', lightType), isNull);
  });
}
