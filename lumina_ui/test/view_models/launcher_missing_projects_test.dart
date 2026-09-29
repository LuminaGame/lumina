import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';

/// The launcher listed every entry in `recent_projects.json`, including ones
/// whose directory no longer exists — opening those fails, so the list was
/// offering dead rows on first launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory configDir;
  late Directory projectsDir;

  setUp(() {
    configDir = Directory.systemTemp.createTempSync('launcher_cfg_');
    projectsDir = Directory.systemTemp.createTempSync('launcher_projects_');
  });

  tearDown(() {
    for (final dir in [configDir, projectsDir]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  /// Creates a real project directory with its `.lmproject` manifest.
  String createProjectOnDisk(String name) {
    final dir = Directory('${projectsDir.path}/$name')..createSync(recursive: true);
    File('${dir.path}/$name.lmproject').writeAsStringSync(
      jsonEncode(LuminaProject(projectName: name, activeLevel: 'contents/levels/L_Main.lmas').toMap()),
    );
    return dir.path;
  }

  void writeRecents(List<({String name, String dir})> entries) {
    File('${configDir.path}/recent_projects.json').writeAsStringSync(
      jsonEncode([
        for (final entry in entries)
          {
            'project': LuminaProject(
              projectName: entry.name,
              activeLevel: 'contents/levels/L_Main.lmas',
            ).toMap(),
            'project_dir': entry.dir,
            'last_opened': DateTime.now().toIso8601String(),
          }
      ]),
    );
  }

  LauncherViewModel viewModel() => LauncherViewModel(
        projectRepo: ProjectRepository(configDir: configDir),
        configDir: configDir,
      );

  test('a project whose directory no longer exists is left out of the list', () async {
    final livePath = createProjectOnDisk('AliveProject');
    writeRecents([
      (name: 'AliveProject', dir: livePath),
      (name: 'DeletedProject', dir: '${projectsDir.path}/DeletedProject'),
    ]);

    final vm = viewModel();
    await vm.loadRecentProjects();

    expect(
      vm.recentProjects.map((e) => e.project.projectName),
      equals(['AliveProject']),
      reason: 'an entry pointing at a directory that is gone cannot be opened, '
          'so the launcher must not offer it',
    );
  });

  test('the launcher reports how many entries it left out', () async {
    final livePath = createProjectOnDisk('AliveProject');
    writeRecents([
      (name: 'AliveProject', dir: livePath),
      (name: 'GoneA', dir: '${projectsDir.path}/GoneA'),
      (name: 'GoneB', dir: '${projectsDir.path}/GoneB'),
    ]);

    final vm = viewModel();
    await vm.loadRecentProjects();

    // Hidden, not deleted: an unmounted drive comes back, and silently losing
    // someone's project history would be worse than a stale row.
    expect(vm.missingProjectCount, equals(2));
    expect(vm.recentProjects, hasLength(1));

    final onDisk = jsonDecode(File('${configDir.path}/recent_projects.json').readAsStringSync()) as List;
    expect(onDisk, hasLength(3), reason: 'the entries are hidden, not pruned from disk');
  });

  test('a directory that exists but lost its .lmproject manifest is also left out', () async {
    Directory('${projectsDir.path}/Hollow').createSync(recursive: true);
    writeRecents([
      (name: 'Hollow', dir: '${projectsDir.path}/Hollow'),
    ]);

    final vm = viewModel();
    await vm.loadRecentProjects();

    expect(vm.recentProjects, isEmpty);
    expect(vm.missingProjectCount, equals(1));
  });

  test('nothing is hidden when every entry resolves', () async {
    writeRecents([
      (name: 'One', dir: createProjectOnDisk('One')),
      (name: 'Two', dir: createProjectOnDisk('Two')),
    ]);

    final vm = viewModel();
    await vm.loadRecentProjects();

    expect(vm.recentProjects, hasLength(2));
    expect(vm.missingProjectCount, isZero);
  });
}
