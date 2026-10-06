import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../../helpers/temp_project.dart';
import 'plugin_process_harness.dart';

/// Level edits a plugin process makes through `host.level` land in the open
/// level as editor transactions; a transaction it brackets is one undo step.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late EditorViewModel vm;
  late PluginProcessHarness h;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_plugin_process_level_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ProcLevel', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    await vm.ensureDefaultLevelAssets();
    h = await PluginProcessHarness.create(registry: vm.extensionRegistry);
    h.mode = 'normal';
  });

  tearDown(() async {
    await h.dispose();
    await vm.close();
    await deleteTempProject(root);
  });

  test('a transaction bracketed by the plugin process is one undo step in the editor', () async {
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    final before = vm.actors.length;
    final undoBefore = vm.transactions.undoLabel;
    final ids = await s.call('level') as List;
    expect(ids, hasLength(2));
    expect(vm.actors.length, before + 2);
    expect(vm.actors.where((a) => a.name.startsWith('Fake ')).map((a) => a.name), ['Fake A', 'Fake B']);
    expect(vm.transactions.undoLabel, 'Undo Fake scatter');
    vm.transactions.undo();
    expect(vm.actors.length, before, reason: 'one Undo removed both actors');
    expect(vm.transactions.undoLabel, undoBefore);
  });
}
