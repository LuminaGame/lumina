import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/services/project_trash.dart';

/// The project trash on real temp projects.
void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_trash_');
    Directory('${project.path}/contents/meshes').createSync(recursive: true);
    File('${project.path}/contents/meshes/SM_Rock.lmas').writeAsStringSync('{"type":"filamesh"}');
    File('${project.path}/contents/meshes/rock.glb').writeAsBytesSync(List.generate(5000, (i) => i % 251));
  });
  tearDown(() {
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  const files = ['contents/meshes/SM_Rock.lmas', 'contents/meshes/rock.glb'];

  test('moveToTrash writes a manifest with matching sha256s; restore brings the files back byte-identical', () async {
    final trash = ProjectTrash(project.path);
    final originals = {for (final f in files) f: File('${project.path}/$f').readAsBytesSync()};
    final entry = await trash.moveToTrash(
      files,
      reason: 'Delete Asset SM_Rock',
      origin: const TransactionOrigin.mcp(sessionId: 's', clientName: 'claude-code', tool: 'delete_asset'),
      actors: [
        {'id': 'actor_1', 'name': 'Rock'},
      ],
    );
    expect(entry.id, matches(RegExp(r'^\d{8}-\d{6}-\d+$')));
    for (final f in files) {
      expect(File('${project.path}/$f').existsSync(), isFalse, reason: f);
    }
    final manifest = jsonDecode(File('${trash.root.path}/${entry.id}/manifest.json').readAsStringSync()) as Map;
    expect((manifest['origin'] as Map)['tool'], 'delete_asset');
    expect((manifest['actors'] as List).single, {'id': 'actor_1', 'name': 'Rock'});
    for (final f in (manifest['files'] as List).cast<Map>()) {
      final stored = File('${trash.root.path}/${entry.id}/${f['stored']}').readAsBytesSync();
      expect(sha256.convert(stored).toString(), f['sha256']);
      expect(stored, originals[f['original']]);
    }
    expect(trash.list().map((e) => e.id), [entry.id]);
    expect(trash.sizeBytes, greaterThan(5000));

    final restored = await trash.restore(entry.id);
    expect(restored.actors.single['name'], 'Rock');
    for (final f in files) {
      expect(File('${project.path}/$f').readAsBytesSync(), originals[f], reason: f);
    }
    expect(trash.list(), isEmpty);
  });

  test('restore refuses, listing them, when a path exists again, and changes nothing', () async {
    final trash = ProjectTrash(project.path);
    final entry = await trash.moveToTrash(files, reason: 'Delete');
    File('${project.path}/contents/meshes/SM_Rock.lmas').writeAsStringSync('someone made a new one');
    await expectLater(
      trash.restore(entry.id),
      throwsA(isA<TrashConflict>().having((e) => e.paths, 'paths', ['contents/meshes/SM_Rock.lmas'])),
    );
    expect(File('${project.path}/contents/meshes/rock.glb').existsSync(), isFalse, reason: 'nothing restored');
    expect(trash.list(), hasLength(1));
  });

  test('the copy + delete path: a trash on a second temp root', () async {
    final other = Directory.systemTemp.createTempSync('lumina_trash_elsewhere_');
    addTearDown(() => other.deleteSync(recursive: true));
    final trash = ProjectTrash(project.path, root: Directory('${other.path}/trash'))..forceCopy = true;
    final bytes = File('${project.path}/contents/meshes/rock.glb').readAsBytesSync();
    final entry = await trash.moveToTrash(files, reason: 'Delete');
    expect(File('${project.path}/contents/meshes/rock.glb').existsSync(), isFalse);
    expect(File('${other.path}/trash/${entry.id}/files/contents/meshes/rock.glb').readAsBytesSync(), bytes);
    await trash.restore(entry.id);
    expect(File('${project.path}/contents/meshes/rock.glb').readAsBytesSync(), bytes);
  });

  test('two trashes within one second get distinct ids; empty erases everything', () async {
    final trash = ProjectTrash(project.path);
    final a = await trash.moveToTrash([files[0]], reason: 'a');
    final b = await trash.moveToTrash([files[1]], reason: 'b');
    expect(a.id, isNot(b.id));
    expect(trash.list(), hasLength(2));
    await trash.empty();
    expect(trash.list(), isEmpty);
    expect(trash.sizeBytes, 0);
  });
}
