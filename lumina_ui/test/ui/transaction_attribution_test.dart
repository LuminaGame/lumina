import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// One agent call is one undo step per stack, marked by a
/// Zone — never by a flag a user's click could fall under.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const agent = TransactionOrigin.mcp(sessionId: 's1', clientName: 'claude-code', tool: 'set_actor_transform');

  test('records inside runAttributed become one composite per manager; undo reverts all, redo re-applies in order', () async {
    final level = TransactionManager();
    final tab = TransactionManager();
    final log = <String>[];
    EditorTransaction step(String name) =>
        EditorTransaction(label: name, undo: () => log.add('undo $name'), redo: () => log.add('redo $name'));

    level.record(step('User Edit'));
    await TransactionManager.runAttributed(agent, () async {
      level.record(step('Move A'));
      await Future<void>.delayed(Duration.zero);
      level.record(step('Rotate A'));
      tab.record(step('Add Node'));
      level.record(step('Scale A'));
    });
    expect(level.history().map((h) => h.label), ['MCP: Move A (+2)', 'User Edit']);
    expect(level.undoTopOrigin!.tool, 'set_actor_transform');
    expect(level.undoTopOrigin!.sessionId, 's1');
    expect(level.history().last.origin.isAgent, isFalse);
    expect(tab.undoLabel, 'Undo MCP: Add Node');

    level.undo();
    expect(log, ['undo Scale A', 'undo Rotate A', 'undo Move A']);
    log.clear();
    level.redo();
    expect(log, ['redo Move A', 'redo Rotate A', 'redo Scale A']);
    expect(TransactionManager.currentOrigin, isNull, reason: 'outside the call the mark is gone');
  });

  test('a user edit made in the root zone while an agent call awaits stays a separate user step', () async {
    final root = Directory.systemTemp.createTempSync('lumina_attr_');
    addTearDown(() => deleteTempProject(root));
    final projectDir = Directory('${root.path}/AttrGame')..createSync();
    const project = LuminaProject(projectName: 'AttrGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/AttrGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.close);
    vm.spawnNewActor('PointLight');
    final userActor = vm.actors.last;

    final importing = Completer<void>();
    final agentCall = TransactionManager.runAttributed(
      const TransactionOrigin.mcp(sessionId: 's1', clientName: 'claude-code', tool: 'spawn_actor_from_asset'),
      () async {
        vm.spawnNewActor('Primitive');
        await importing.future; // the slow import the agent awaits
        vm.renameActorWithTransaction(vm.actors.last.id, 'AgentBarrel');
      },
    );
    // The user, meanwhile, in the root zone.
    await Future<void>.delayed(Duration.zero);
    vm.selectActors([userActor.id]);
    vm.updateActorLocation([5, 6, 7]);
    importing.complete();
    await agentCall;

    final history = vm.transactions.history();
    final userSteps = history.where((h) => !h.origin.isAgent).map((h) => h.label).toList();
    final agentSteps = history.where((h) => h.origin.isAgent).toList();
    expect(agentSteps, hasLength(1), reason: 'the whole agent call is one step');
    expect(agentSteps.single.label, startsWith('MCP: '));
    expect(agentSteps.single.label, endsWith('(+1)'));
    expect(userSteps, contains('Multi-edit location'), reason: 'the user move is its own user step');
  });
}
