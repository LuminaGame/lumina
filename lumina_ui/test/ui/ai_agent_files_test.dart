import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/ai_agent_files.dart';

/// The AI agent files a game project gets: the editor's skills for Claude
/// Code (`.claude/skills/`) and Antigravity (`.agents/skills/`), and the
/// project's `AGENTS.md` / `CLAUDE.md`. Everything is read from the asset
/// bundle, the way an installed editor reads it, and written into real temp
/// projects.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final skillsSource = Directory('${Directory.current.path}/skills');

  /// Every file of the source `skills/` tree, `/`-separated, relative to the
  /// package (`skills/lumina-mcp/SKILL.md`).
  List<String> sourceSkillFiles() {
    final root = Directory.current.path.replaceAll(r'\', '/');
    return [
      for (final f in skillsSource.listSync(recursive: true).whereType<File>())
        f.path.replaceAll(r'\', '/').substring(root.length + 1),
    ]..sort();
  }

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_agent_files_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Directory projectDir(String name) => Directory('${temp.path}/$name')..createSync(recursive: true);

  const project = LuminaProject(
    projectName: 'space_racer',
    engineVersion: '0.0.1-dev.12',
    activeLevel: 'contents/levels/L_Track.lmas',
    template: 'third_person',
  );

  test('every skill file ships in the asset bundle and loads byte-equal to its source', () async {
    final files = sourceSkillFiles();
    expect(files, contains('skills/lumina-mcp/SKILL.md'));
    expect(files, contains('skills/create-plugin/reference/extension_points.md'));
    final bundled = await AiAgentFiles().skillAssets();
    expect(bundled, files, reason: 'each skills/ folder (and reference/) must be listed in pubspec flutter: assets:');
    for (final f in files) {
      final bytes = await EditorAssets.bundle.load(f);
      expect(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), File(f).readAsBytesSync(), reason: f);
    }
  });

  test('the bundled skills carry their names and descriptions from SKILL.md', () async {
    final skills = await AiAgentFiles().skills();
    expect(skills.map((s) => s.name), containsAll(['lumina-engine', 'lumina-mcp', 'create-plugin']));
    final mcp = skills.firstWhere((s) => s.name == 'lumina-mcp');
    expect(mcp.description, startsWith('Operate a running Lumina Studio editor'));
    expect(mcp.files, contains('reference/tools.md'));
  });

  test('install writes every skill for Claude Code and Antigravity and both project documents', () async {
    final dir = projectDir('space_racer');
    final report = await AiAgentFiles().install(dir.path, project);

    final files = sourceSkillFiles();
    for (final f in files) {
      final rel = f.substring('skills/'.length);
      for (final target in [AiAgentFiles.claudeSkillsDir, AiAgentFiles.antigravitySkillsDir]) {
        final out = File('${dir.path}/$target/$rel');
        expect(out.existsSync(), isTrue, reason: out.path);
        expect(out.readAsBytesSync(), File(f).readAsBytesSync(), reason: out.path);
      }
    }
    expect(report.skills, containsAll(['lumina-engine', 'lumina-mcp', 'create-plugin']));
    expect(report.writtenDocs, ['AGENTS.md', 'CLAUDE.md']);
    expect(report.keptDocs, isEmpty);

    final agents = File('${dir.path}/AGENTS.md').readAsStringSync();
    expect(agents, contains('# space_racer'));
    expect(agents, contains('0.0.1-dev.12'));
    expect(agents, contains('space_racer.lmproject'));
    expect(agents, contains('contents/levels/L_Track.lmas'));
    expect(agents, contains('third_person'));
    expect(agents, contains('1 unit = 1 cm'));
    expect(agents, contains('Z is up'));
    for (final s in ['lumina-engine', 'lumina-mcp', 'create-plugin']) {
      expect(agents, contains('`$s`'), reason: s);
    }
    expect(agents, contains('.claude/skills/'));
    expect(agents, contains('.agents/skills/'));
    expect(agents, isNot(contains('{{')));

    final claude = File('${dir.path}/CLAUDE.md').readAsStringSync();
    expect(claude, contains('@AGENTS.md'));
    expect(claude, contains('space_racer'));
    expect(claude, isNot(contains('{{')));
  });

  test('an edited document is kept unless overwriteDocs; an unedited one follows the project', () async {
    final dir = projectDir('space_racer');
    final files = AiAgentFiles();
    await files.install(dir.path, project);
    final agents = File('${dir.path}/AGENTS.md');
    final claude = File('${dir.path}/CLAUDE.md');
    final edited = '${agents.readAsStringSync()}\n## House rules\n\nNo physics changes on Fridays.\n';
    agents.writeAsStringSync(edited);

    final moved = project.copyWith(activeLevel: 'contents/levels/L_Desert.lmas');
    expect(await files.editedDocs(dir.path), ['AGENTS.md']);
    final kept = await files.install(dir.path, moved);
    expect(kept.keptDocs, ['AGENTS.md']);
    expect(kept.writtenDocs, ['CLAUDE.md']);
    expect(agents.readAsStringSync(), edited);
    expect(claude.readAsStringSync(), contains('space_racer'));

    final replaced = await files.install(dir.path, moved, overwriteDocs: true);
    expect(replaced.writtenDocs, ['AGENTS.md', 'CLAUDE.md']);
    expect(agents.readAsStringSync(), isNot(contains('No physics changes')));
    expect(agents.readAsStringSync(), contains('contents/levels/L_Desert.lmas'));
    expect(await files.editedDocs(dir.path), isEmpty);
  });

  test('a user-written AGENTS.md without the editor marker counts as edited', () async {
    final dir = projectDir('space_racer');
    File('${dir.path}/AGENTS.md').writeAsStringSync('# My own notes\n');
    final files = AiAgentFiles();
    expect(await files.editedDocs(dir.path), ['AGENTS.md']);
    final report = await files.install(dir.path, project);
    expect(report.keptDocs, ['AGENTS.md']);
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), '# My own notes\n');
  });

  test('refreshing replaces the shipped skill folders and leaves the user\'s own skills alone', () async {
    final dir = projectDir('space_racer');
    final files = AiAgentFiles();
    await files.install(dir.path, project);
    final stale = File('${dir.path}/.claude/skills/lumina-mcp/reference/old_tools.md')..writeAsStringSync('old');
    final edited = File('${dir.path}/.agents/skills/lumina-engine/SKILL.md')..writeAsStringSync('changed');
    final own = File('${dir.path}/.claude/skills/my-level-rules/SKILL.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('---\nname: my-level-rules\n---\n');

    await files.install(dir.path, project);
    expect(stale.existsSync(), isFalse);
    expect(edited.readAsBytesSync(), File('skills/lumina-engine/SKILL.md').readAsBytesSync());
    expect(own.readAsStringSync(), startsWith('---\nname: my-level-rules'));
  });

  test('a legacy metre, Y-up project is described in metres with Y up', () async {
    final dir = projectDir('old_game');
    const legacy = LuminaProject(projectName: 'old_game', worldUnits: kWorldUnitsMetres, upAxis: kUpAxisY);
    await AiAgentFiles().install(dir.path, legacy);
    final agents = File('${dir.path}/AGENTS.md').readAsStringSync();
    expect(agents, contains('1 unit = 1 m'));
    expect(agents, contains('Y is up'));
    expect(agents, isNot(contains('1 unit = 1 cm')));
  });

  test('the documents load from the asset bundle as templates', () async {
    for (final t in [AiAgentFiles.agentsTemplate, AiAgentFiles.claudeTemplate]) {
      final text = await EditorAssets.bundle.loadString(t);
      expect(text, contains('{{project_name}}'), reason: t);
    }
  });
}
