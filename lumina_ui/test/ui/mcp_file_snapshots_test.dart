import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/services/project_trash.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_file_snapshots.dart';
import 'package:path/path.dart' as p;

/// The pre-write snapshot store under
/// `<project>/.lumina/mcp/snapshots/` — real files in a temp project.
void main() {
  late Directory projectDir;
  late McpFileSnapshots snapshots;

  const agent = McpSnapshotContext(sessionId: 'in-process:MiniAI#turn-7', client: 'MiniAI#turn-7', caller: 'MiniAI#turn-7');
  const http = McpSnapshotContext(sessionId: 'abc', client: 'claude-code');

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_snapshots_');
    Directory(p.join(projectDir.path, 'lib')).createSync();
    snapshots = McpFileSnapshots(projectDir.path, trash: ProjectTrash(projectDir.path));
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  File file(String rel) => File(p.join(projectDir.path, rel));

  test('a snapshot records the previous bytes and who took it; a missing file is existed: false', () {
    file('lib/a.dart').writeAsStringSync('original\n');
    final s = snapshots.take('lib/a.dart', 'fs_write', agent);
    expect(s.id, '000001-fs_write');
    expect(s.existed, isTrue);
    expect(s.bytes, 9);
    expect(s.sha256, sha256.convert(utf8.encode('original\n')).toString());
    final dir = Directory(p.join(projectDir.path, '.lumina', 'mcp', 'snapshots', s.id));
    final manifest = jsonDecode(File(p.join(dir.path, 'manifest.json')).readAsStringSync()) as Map;
    expect(manifest, containsPair('path', 'lib/a.dart'));
    expect(manifest, containsPair('tool', 'fs_write'));
    expect(manifest, containsPair('caller', 'MiniAI#turn-7'));
    expect(manifest, containsPair('session_id', 'in-process:MiniAI#turn-7'));
    expect(manifest, containsPair('client', 'MiniAI#turn-7'));
    expect(manifest.keys, containsAll(['id', 'existed', 'bytes', 'sha256', 'created']));
    expect(File(p.join(dir.path, 'before')).readAsStringSync(), 'original\n');

    final missing = snapshots.take('lib/new.dart', 'fs_write', http);
    expect(missing.existed, isFalse);
    expect(missing.caller, isNull);
    expect(missing.id, '000002-fs_write');
  });

  test('list: newest first, by path, by caller and caller prefix', () {
    file('lib/a.dart').writeAsStringSync('1');
    snapshots.take('lib/a.dart', 'fs_write', agent);
    snapshots.take('lib/b.dart', 'fs_write', http);
    snapshots.take('lib/a.dart', 'fs_edit', const McpSnapshotContext(sessionId: 'in-process:MiniAI#turn-8', client: 'MiniAI#turn-8', caller: 'MiniAI#turn-8'));
    expect(snapshots.list().map((s) => s.id), ['000003-fs_edit', '000002-fs_write', '000001-fs_write']);
    expect(snapshots.list(path: 'lib/a.dart').map((s) => s.id), ['000003-fs_edit', '000001-fs_write']);
    expect(snapshots.list(caller: 'MiniAI#turn-7').map((s) => s.id), ['000001-fs_write']);
    expect(snapshots.list(callerPrefix: 'MiniAI#').map((s) => s.id), ['000003-fs_edit', '000001-fs_write']);
    expect(snapshots.list(limit: 1).map((s) => s.id), ['000003-fs_edit']);
    // A fresh store on the same project reads what is on disk.
    expect(McpFileSnapshots(projectDir.path, trash: ProjectTrash(projectDir.path)).list().length, 3);
  });

  test('restore writes the old bytes back after snapshotting the current state; a created file goes to the trash', () {
    file('lib/a.dart').writeAsStringSync('v1');
    final first = snapshots.take('lib/a.dart', 'fs_write', http);
    file('lib/a.dart').writeAsStringSync('v2');
    final r = snapshots.restore(first.id, http);
    expect(file('lib/a.dart').readAsStringSync(), 'v1');
    expect(r.restoredBytes, 2);
    expect(r.replaced.tool, 'fs_restore');
    expect(File(p.join(snapshots.root.path, r.replaced.id, 'before')).readAsStringSync(), 'v2');
    // The restore is itself reversible.
    snapshots.restore(r.replaced.id, http);
    expect(file('lib/a.dart').readAsStringSync(), 'v2');

    final created = snapshots.take('lib/new.dart', 'fs_write', http);
    file('lib/new.dart').writeAsStringSync('fresh');
    final undoCreate = snapshots.restore(created.id, http);
    expect(file('lib/new.dart').existsSync(), isFalse);
    expect(undoCreate.trashId, isNotNull);
    expect(File(p.join(projectDir.path, '.lumina', 'trash', undoCreate.trashId!, 'files', 'lib', 'new.dart')).readAsStringSync(), 'fresh');
    expect(() => snapshots.restore('999999-nope', http), throwsA(isA<StateError>()));
  });

  test('retention: 501 snapshots leave the newest 500; the byte cap prunes the oldest', () {
    file('lib/a.dart').writeAsStringSync('x');
    for (var i = 0; i < 501; i++) {
      snapshots.take('lib/a.dart', 'fs_write', http);
    }
    final all = snapshots.list(limit: 1000);
    expect(all, hasLength(500));
    expect(all.last.id, '000002-fs_write');
    expect(snapshots.root.listSync().whereType<Directory>(), hasLength(500));

    final capped = McpFileSnapshots(p.join(projectDir.path, 'sub'), trash: ProjectTrash(projectDir.path), maxBytes: 250);
    Directory(p.join(projectDir.path, 'sub', 'lib')).createSync(recursive: true);
    File(p.join(projectDir.path, 'sub', 'lib', 'big.txt')).writeAsStringSync('b' * 100);
    for (var i = 0; i < 4; i++) {
      capped.take('lib/big.txt', 'fs_write', http);
    }
    expect(capped.list().map((s) => s.id), ['000004-fs_write', '000003-fs_write']);
  });
}
