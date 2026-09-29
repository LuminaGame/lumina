import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_plugin_miniai/lumina_plugin_miniai.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// "Undo this turn" restores the files a turn's `fs_*` calls
/// changed, through the real MCP file tools and snapshots.
void main() {
  late Directory root;
  late EditorViewModel vm;
  late LuminaPluginMiniaiPlugin plugin;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_miniai_undo_files_');
    final projectDir = Directory('${root.path}/UndoGame')..createSync();
    const project = LuminaProject(projectName: 'UndoGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/UndoGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/lib').createSync();
    File('${projectDir.path}/lib/main.dart').writeAsStringSync('void main() {}\n');
    PluginDataDir.override = Directory('${root.path}/plugin_data');
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    plugin = LuminaPluginMiniaiPlugin();
    vm.extensionRegistry.registerPlugin(plugin);
  });

  tearDown(() async {
    PluginDataDir.override = null;
    await vm.close();
    await deleteTempProject(root);
  });

  test('a turn that created one file and edited another is undone file by file', () async {
    final c = plugin.controller!;
    final mcp = c.mcp;
    // The turn as the agent loop records it; its calls carry its caller.
    final turn = TurnRecord(id: '${c.chat.id}:1', label: 'AI: Add a note', userItemIndex: 0);
    c.chat.turns.add(turn);
    c.chat.items.add(UserItem('Add a note and touch main'));

    final created = await mcp.callTool('fs_write', {'path': 'lib/agent/note.dart', 'content': '// note\n'}, caller: turn.caller);
    expect(created.isError, isFalse, reason: created.content.toString());
    final edited = await mcp.callTool('fs_edit', {'path': 'lib/main.dart', 'old_string': 'void main() {}', 'new_string': 'void main() { print(1); }'}, caller: turn.caller);
    expect(edited.isError, isFalse, reason: edited.content.toString());
    final edited2 = await mcp.callTool('fs_edit', {'path': 'lib/main.dart', 'old_string': 'print(1);', 'new_string': 'print(2);'}, caller: turn.caller);
    expect(edited2.isError, isFalse);
    turn.fileWrites = 3;
    // Another turn's write is not touched.
    await mcp.callTool('fs_write', {'path': 'lib/other.dart', 'content': '// other\n'}, caller: 'miniai:${c.chat.id}:2');

    final dir = vm.projectDirPath;
    expect(File('$dir/lib/main.dart').readAsStringSync(), 'void main() { print(2); }\n');
    expect(c.canUndoTurn(turn).$1, isTrue);

    await c.undoTurn(turn.id);
    expect(File('$dir/lib/agent/note.dart').existsSync(), isFalse, reason: 'the created file went to the trash');
    expect(File('$dir/lib/main.dart').readAsStringSync(), 'void main() {}\n', reason: 'the original bytes');
    expect(File('$dir/lib/other.dart').existsSync(), isTrue);
    expect(turn.undone, isTrue);
    expect((c.chat.items.last as NoteItem).text, 'Undone: 2 files restored.');
  });
}
