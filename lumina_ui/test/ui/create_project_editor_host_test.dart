import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';

/// A project created from the launcher gets its own editor host
/// (`.lumina/editor`, plugin-less) at once, so its first Open builds it.
/// With the preference off, nothing is written. A real ProjectRepository on a
/// temp workspace; `flutter create` / `pub get` scripted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory config;
  late Directory workspace;

  setUp(() {
    config = Directory.systemTemp.createTempSync('lumina_create_host_config_');
    workspace = Directory.systemTemp.createTempSync('lumina_create_host_ws_');
  });
  tearDown(() {
    for (final d in [config, workspace]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.contains('create')) {
      final target = args.last;
      Directory(target).createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync('''
name: created_game
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.2.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    }
    return ProcessResult(1, 0, '', '');
  }

  Future<String> create(String name) async {
    final repo = ProjectRepository(configDir: config, processRunner: runner);
    final launcherVM = LauncherViewModel(configDir: config, projectRepo: repo);
    final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
    vm.updateName(name);
    vm.updateLocation(workspace.path);
    await vm.createProject();
    expect(vm.creationError, isNull);
    return '${workspace.path}/$name';
  }

  test('a new project has its plugin-less editor host', () async {
    final dir = await create('created_game');
    final host = '$dir/.lumina/editor';
    expect(File('$host/pubspec.yaml').existsSync(), isTrue);
    expect(File('$host/pubspec.yaml').readAsStringSync(), contains('name: created_game_editor'));
    expect(File('$host/lib/plugin_registrar.dart').existsSync(), isTrue);
    expect(File('$host/lib/main.dart').existsSync(), isTrue);
  });

  test('a new project has the AI agent skills for Claude Code and Antigravity and its AGENTS.md / CLAUDE.md', () async {
    final dir = await create('agent_game');
    for (final skill in ['lumina-engine', 'lumina-mcp', 'create-plugin']) {
      expect(File('$dir/.claude/skills/$skill/SKILL.md').existsSync(), isTrue, reason: skill);
      expect(File('$dir/.agents/skills/$skill/SKILL.md').existsSync(), isTrue, reason: skill);
    }
    expect(File('$dir/.claude/skills/lumina-mcp/reference/tools.md').existsSync(), isTrue);
    final agents = File('$dir/AGENTS.md').readAsStringSync();
    expect(agents, contains('# agent_game'));
    expect(agents, contains('agent_game.lmproject'));
    expect(File('$dir/CLAUDE.md').readAsStringSync(), contains('@AGENTS.md'));
  });

  test('with per-project editors off, no host is written', () async {
    EditorPreferences.load(configDir: config).setPerProjectEditors(false);
    final dir = await create('plain_game');
    expect(Directory('$dir/.lumina/editor').existsSync(), isFalse);
  });
}
