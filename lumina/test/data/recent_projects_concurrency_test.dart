import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Adds [count] projects `<prefix>_<i>` (directories under [projectsPath]) to
/// the recent list in [configPath], from an isolate of its own: a separate
/// writer, running in parallel with the others.
Future<void> _addFromIsolate(String configPath, String projectsPath, String prefix, int count) => Isolate.run(() async {
      final repo = ProjectRepository(configDir: Directory(configPath));
      for (var i = 0; i < count; i++) {
        await repo.addRecentProject(LuminaProject(projectName: '${prefix}_$i'), projectDir: '$projectsPath/${prefix}_$i');
      }
    });

/// addRecentProject read the list while another writer was rewriting
/// it in place, took the half-written file for an empty list and wrote a list
/// holding only its own entry; two writers also overwrote each other's change.
void main() {
  late Directory root;
  late Directory config;
  late File recents;

  setUp(() {
    root = Directory.systemTemp.createTempSync('recent_projects_concurrency_');
    config = Directory('${root.path}/config')..createSync();
    recents = File('${config.path}/recent_projects.json');
  });
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  String projectDir(String name) => '${root.path}/projects/$name';

  test('writers in several isolates at once keep every entry', () async {
    const writers = 4;
    const perWriter = 25;
    await Future.wait([
      for (var w = 0; w < writers; w++) _addFromIsolate(config.path, '${root.path}/projects', 'w$w', perWriter),
    ]);

    final entries = await ProjectRepository(configDir: config).getRecentProjects();
    final dirs = entries.map((e) => e.projectDir).toList();
    final expected = {
      for (var w = 0; w < writers; w++)
        for (var i = 0; i < perWriter; i++) projectDir('w${w}_$i'),
    };
    expect(expected.difference(dirs.toSet()), isEmpty, reason: 'no writer may lose another writer\'s entries');
    expect(dirs, hasLength(writers * perWriter), reason: 'each project is listed once');
  });

  test('a file caught mid-write is read again, never taken for an empty list', () async {
    final existing = [
      for (final name in ['a', 'b', 'c'])
        RecentProjectEntry(project: LuminaProject(projectName: name), projectDir: projectDir(name), lastOpened: DateTime(2026, 9, 24))
            .toMap(),
    ];
    final full = jsonEncode(existing);
    // A writer that rewrites the file in place has truncated it and written
    // half of the list so far; it finishes a moment later, from elsewhere.
    recents.writeAsStringSync(full.substring(0, full.length ~/ 2));
    final path = recents.path;
    final finishing = Isolate.run(() {
      sleep(const Duration(milliseconds: 150));
      File(path).writeAsStringSync(full);
    });

    final repo = ProjectRepository(configDir: config);
    await repo.addRecentProject(const LuminaProject(projectName: 'late'), projectDir: projectDir('late'));
    await finishing;

    final dirs = (await repo.getRecentProjects()).map((e) => e.projectDir);
    expect(dirs, containsAll([projectDir('a'), projectDir('b'), projectDir('c'), projectDir('late')]));
  });

  test('a file that stays unreadable is kept aside, never overwritten', () async {
    const corrupt = '[{"project": {"project_name": "kept"';
    recents.writeAsStringSync(corrupt);
    final repo = ProjectRepository(configDir: config);

    expect(await repo.getRecentProjects(), isEmpty);
    expect(recents.readAsStringSync(), corrupt, reason: 'reading never rewrites the file');

    await repo.addRecentProject(const LuminaProject(projectName: 'next'), projectDir: projectDir('next'));

    final keptAside = config
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('recent_projects.json.unreadable-'))
        .toList();
    expect(keptAside, hasLength(1), reason: 'the unreadable list is kept next to the new one');
    expect(keptAside.single.readAsStringSync(), corrupt);
    expect((await repo.getRecentProjects()).map((e) => e.projectDir), [projectDir('next')]);
  });

  group('ConfigJsonFile', () {
    test('a reader in another isolate never sees a half-written file', () async {
      final path = '${config.path}/launcher_settings.json';
      ConfigJsonFile(File(path)).write({'n': -1});
      final big = [for (var i = 0; i < 400; i++) 'entry number $i of a list long enough to take more than one write'];
      final writer = Isolate.run(() {
        for (var n = 0; n < 200; n++) {
          ConfigJsonFile(File(path)).write({'n': n, 'items': big});
        }
      });
      final unreadable = await Isolate.run(() {
        var failures = 0;
        for (var n = 0; n < 2000; n++) {
          try {
            jsonDecode(File(path).readAsStringSync());
          } on FormatException {
            failures++;
          }
        }
        return failures;
      });
      await writer;
      expect(unreadable, 0, reason: 'writes replace the file atomically');
      expect(config.listSync().map((e) => e.uri.pathSegments.last), isNot(contains(startsWith('launcher_settings.json.tmp'))),
          reason: 'no temp file is left behind');
    });

    test('a lock left behind by a writer that died is broken', () {
      final file = ConfigJsonFile(File('${config.path}/editor_quality.json'));
      file.lockFile
        ..createSync()
        ..setLastModifiedSync(DateTime.now().subtract(ConfigJsonFile.staleLockAge * 2));
      final watch = Stopwatch()..start();
      file.update((current) => {'p': 1});
      expect(watch.elapsed, lessThan(ConfigJsonFile.staleLockAge));
      expect(file.read(), {'p': 1});
      expect(file.lockFile.existsSync(), isFalse, reason: 'update releases the lock');
    });
  });
}
