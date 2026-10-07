import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/views/ai_agent_files_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Tools → Set Up AI Agent Files... on a project created before the feature:
/// the command installs the skills and the documents into the open project,
/// and an AGENTS.md / CLAUDE.md the user edited is replaced only when the
/// user answers Replace. Real temp projects, the real editor view model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_agent_cmd_'));
  tearDown(() => deleteTempProject(temp));

  Directory writeProject(String name) {
    final dir = Directory('${temp.path}/$name')..createSync(recursive: true);
    Directory('${dir.path}/contents/levels').createSync(recursive: true);
    final project = LuminaProject(projectName: name, activeLevel: 'contents/levels/L_Main.lmas');
    File('${dir.path}/$name.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    return dir;
  }

  test('tools.aiAgentFiles is registered and installs the agent files into the open project', () async {
    final dir = writeProject('old_project');
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'old_project', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.close);
    final command = vm.commands.byId('tools.aiAgentFiles');
    expect(command, isNotNull);
    expect(command!.label, 'Set Up AI Agent Files...');
    expect(command.canExecute(), isTrue);

    await command.execute(null);
    expect(File('${dir.path}/.claude/skills/lumina-mcp/SKILL.md').existsSync(), isTrue);
    expect(File('${dir.path}/.agents/skills/lumina-engine/SKILL.md').existsSync(), isTrue);
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), contains('# old_project'));
    expect(File('${dir.path}/CLAUDE.md').readAsStringSync(), contains('@AGENTS.md'));
  });

  test('without a context an edited AGENTS.md is kept; the skills are still refreshed', () async {
    final dir = writeProject('kept_project');
    File('${dir.path}/AGENTS.md').writeAsStringSync('# Team notes\n');
    const project = LuminaProject(projectName: 'kept_project');
    final report = await setUpAiAgentFiles(projectDir: dir.path, project: project);
    expect(report.keptDocs, ['AGENTS.md']);
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), '# Team notes\n');
    expect(File('${dir.path}/CLAUDE.md').existsSync(), isTrue);
    expect(File('${dir.path}/.claude/skills/create-plugin/SKILL.md').existsSync(), isTrue);
  });

  test('the answer to the question decides whether edited documents are replaced', () async {
    final dir = writeProject('asked_project');
    File('${dir.path}/AGENTS.md').writeAsStringSync('# Team notes\n');
    const project = LuminaProject(projectName: 'asked_project');

    List<String>? asked;
    final keep = await setUpAiAgentFiles(
      projectDir: dir.path,
      project: project,
      askReplace: (docs) async {
        asked = docs;
        return false;
      },
    );
    expect(asked, ['AGENTS.md']);
    expect(keep.keptDocs, ['AGENTS.md']);
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), '# Team notes\n');

    final replace = await setUpAiAgentFiles(projectDir: dir.path, project: project, askReplace: (_) async => true);
    expect(replace.writtenDocs, contains('AGENTS.md'));
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), contains('# asked_project'));

    // Nothing edited any more: no question.
    var askedAgain = false;
    await setUpAiAgentFiles(
      projectDir: dir.path,
      project: project,
      askReplace: (_) async => askedAgain = true,
    );
    expect(askedAgain, isFalse);
  });

  testWidgets('the Tools menu lists Set Up AI Agent Files... next to AI Agent Access (MCP)', (tester) async {
    final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: MenuBarWidget(engineVersion: '1.0.0', activeLevelName: 'Test', onSave: () {}, viewModel: vm),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    expect(find.text('AI Agent Access (MCP)...'), findsOneWidget);
    final item = find.ancestor(of: find.text('Set Up AI Agent Files...'), matching: find.byType(MenuButton));
    expect(item, findsOneWidget);
    expect(tester.widget<MenuButton>(item).onPressed, isNotNull);
  });

  Future<bool?> openDialog(WidgetTester tester, String tap) async {
    bool? answer;
    await tester.pumpWidget(
      ShadcnApp(
        home: Builder(
          builder: (context) => Center(
            child: PrimaryButton(
              onPressed: () async => answer = await askReplaceEditedAgentDocs(context, ['AGENTS.md', 'CLAUDE.md']),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Replace edited agent files?'), findsOneWidget);
    expect(find.textContaining('AGENTS.md, CLAUDE.md'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(tap)));
    await tester.pumpAndSettle();
    expect(find.text('Replace edited agent files?'), findsNothing);
    return answer;
  }

  testWidgets('the dialog names the edited files; Keep mine answers false', (tester) async {
    expect(await openDialog(tester, 'agent_files_keep'), isFalse);
  });

  testWidgets('the dialog\'s Replace answers true', (tester) async {
    expect(await openDialog(tester, 'agent_files_replace'), isTrue);
  });
}
