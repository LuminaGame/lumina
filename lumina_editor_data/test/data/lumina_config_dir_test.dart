import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The user's own editor config directory, derived from HOME alone: where the
/// editor keeps its files outside tests. This test only stats files there; it
/// never writes them.
Directory _userConfigDir() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  return Directory('$home/.config/lumina');
}

String _stamp(File f) =>
    f.existsSync() ? '${f.lengthSync()} bytes, modified ${f.lastModifiedSync().toIso8601String()}' : 'absent';

void main() {
  // Every ProjectRepository() without a configDir registered its
  // (temp) project in the user's real recent_projects.json.
  test('a ProjectRepository without a configDir leaves the real ~/.config/lumina untouched', () async {
    final realRecents = File('${_userConfigDir().path}/recent_projects.json');
    final before = _stamp(realRecents);

    final repo = ProjectRepository();
    // Checked before anything is written, so a regression fails here without
    // touching the user's file.
    expect(repo.resolvedConfigDir.absolute.path, isNot(_userConfigDir().absolute.path),
        reason: 'a test run must never resolve the user\'s own config directory');

    final tempDir = Directory.systemTemp.createTempSync('lumina_config_isolation_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final projectDir = Directory('${tempDir.path}/isolation_game')..createSync();
    const project = LuminaProject(projectName: 'isolation_game');
    await repo.saveProject(project, projectDir.path);
    // Opening a project registers it as recent.
    expect(await repo.loadProject('${projectDir.path}/isolation_game.lmproject'), isNotNull);

    expect(_stamp(realRecents), before, reason: 'opening a project in a test must not touch the user\'s recent projects');
    final recents = await repo.getRecentProjects();
    expect(recents.map((e) => e.projectDir), contains(projectDir.absolute.path),
        reason: 'the entry lands in the isolated config directory instead');
  });

  test('LuminaConfigDir resolves explicit, then override, then LUMINA_CONFIG_DIR, then ~/.config/lumina', () {
    final isolated = LuminaConfigDir.override;
    expect(isolated, isNotNull, reason: 'test/flutter_test_config.dart isolates every test file');
    expect(LuminaConfigDir.resolve().path, isolated!.path);
    expect(ProjectRepository().resolvedConfigDir.path, isolated.path);

    final explicit = Directory('/explicit/config');
    expect(LuminaConfigDir.resolve(explicit: explicit).path, explicit.path);
    expect(ProjectRepository(configDir: explicit).resolvedConfigDir.path, explicit.path);
    expect(LuminaConfigDir.file('recent_projects.json', explicit: explicit).path, '/explicit/config/recent_projects.json');

    // Without the in-process override: the environment decides.
    LuminaConfigDir.override = null;
    addTearDown(() => LuminaConfigDir.override = isolated);
    expect(
      LuminaConfigDir.resolve(environment: {'LUMINA_CONFIG_DIR': '/env/config', 'HOME': '/home/someone'}).path,
      '/env/config',
    );
    expect(LuminaConfigDir.resolve(environment: {'LUMINA_CONFIG_DIR': '', 'HOME': '/home/someone'}).path,
        '/home/someone/.config/lumina');
    expect(LuminaConfigDir.resolve(environment: {'USERPROFILE': r'C:\Users\someone'}).path,
        r'C:\Users\someone/.config/lumina');
  });
}
