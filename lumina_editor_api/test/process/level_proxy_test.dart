import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'support/loopback_host.dart';
import 'support/sample_process.dart';

void main() {
  late LoopbackHost host;
  late SampleProcess process;
  late Future<int> exit;

  setUp(() async {
    host = await LoopbackHost.start();
    host.level.actors.add(const EditorActorSnapshot(
      id: 'floor',
      name: 'Floor',
      type: 'StaticMesh',
      location: [0, 0, 0],
      rotation: [0, 0, 0],
      scale: [10, 10, 1],
    ));
    process = SampleProcess();
    exit = runPluginProcessMain(host.launch('sample'), process);
    await host.contributions;
  });

  tearDown(() async {
    await host.call(PluginMethods.shutdown);
    expect(await exit, PluginProcessExitCodes.ok);
    await host.close();
  });

  Future<Object?> call(String method, [Map<String, Object?> args = const {}]) =>
      host.call(PluginMethods.call, {'method': method, 'args': args});

  test('the level is visible from register on, through the snapshot', () async {
    expect(await call('levelState'), {
      'project': host.project!.dir,
      'active': 'contents/levels/L_Main.lmas',
      'names': ['Floor'],
      'selected': <String>[],
      'undoTop': null,
      'light': null,
    });
  });

  test('edits inside runTransaction become one undo step, nested calls join it', () async {
    final ids = await call('scatter', {'n': 3}) as List;
    expect(ids, hasLength(3));
    expect(host.level.undo, hasLength(1));
    expect(host.level.undo.single.$1, 'Scatter');
    expect(host.level.undo.single.$2, ['addActors', 'setComponentProperty', 'addActors']);

    final edits = host.level.received.where((a) => a['op'] != 'snapshot' && !'${a['op']}'.endsWith('Transaction'));
    expect(edits.map((a) => a['tx']).toSet(), {1}, reason: 'every edit carries the transaction id');
    expect(host.level.received.where((a) => a['op'] == 'beginTransaction'), hasLength(1));

    final state = await call('levelState') as Map;
    expect(state['names'], ['Floor', 'Rock0', 'Rock1', 'Rock2', 'Last']);
    expect(state['undoTop'], 'Scatter');
    expect(host.level.actors[1].componentOfType('Light')!.properties['intensity'], 5);
  });

  test('synchronous edits apply at once and reach the editor; save and open levels', () async {
    await call('scatter', {'n': 1});
    final r = await call('levelEdits') as Map;
    expect(r['afterRemove'], ['Floor', 'Rock0'], reason: 'the removal shows before the editor answers');
    expect(r['undone'], isTrue);
    expect(r['opened'], isFalse);
    expect(r['reopened'], isTrue);

    await host.call(PluginMethods.ping);
    expect(host.level.selected, ['floor']);
    final saved = jsonDecode(File('${host.project!.dir}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
    expect(saved['actors'], isA<List>());
    final ops = [for (final a in host.level.received) a['op']].where((o) => o != 'snapshot').toList();
    expect(ops, containsAllInOrder(['selectActors', 'removeActors', 'undoIfTop', 'saveLevel', 'openLevel', 'openLevel']));
  });

  test('core.levelChanged refreshes the proxy and fires changes', () async {
    var fired = 0;
    process.context.level.changes.addListener(() => fired++);
    host.level.actors.add(const EditorActorSnapshot(
      id: 'cam',
      name: 'Camera',
      type: 'Camera',
      location: [1, 2, 3],
      rotation: [0, 0, 90],
      scale: [1, 1, 1],
    ));
    host.connection.notify(PluginMethods.levelChanged, {'activeLevelPath': 'contents/levels/L_Main.lmas', 'actorCount': 2});
    while (fired == 0) {
      await host.call(PluginMethods.ping);
    }
    final cam = process.context.level.actors.last;
    expect(cam.name, 'Camera');
    expect(cam.location, [1.0, 2.0, 3.0]);
    expect(cam.rotation, [0.0, 0.0, 90.0]);
  });

  test('EditorLevelJson round-trips snapshots and specs', () {
    const snap = EditorActorSnapshot(
      id: 'a',
      name: 'A',
      type: 'StaticMesh',
      parentId: 'p',
      location: [1, 2, 3],
      rotation: [4, 5, 6],
      scale: [7, 8, 9],
      isVisible: false,
      meshAssetPath: '/m.glb',
      components: [EditorComponentSnapshot(id: 'c', type: 'Light', name: 'L', enabled: false, properties: {'k': 1})],
    );
    final back = EditorLevelJson.snapshotFromJson(jsonDecode(jsonEncode(EditorLevelJson.snapshotToJson(snap))) as Map<String, Object?>);
    expect(EditorLevelJson.snapshotToJson(back), EditorLevelJson.snapshotToJson(snap));

    const spec = EditorActorSpec(
      name: 'S',
      type: 'Empty',
      location: [1, 1, 1],
      components: [EditorComponentSpec(type: 'Tag', name: 'T', properties: {'x': 'y'})],
    );
    final specBack = EditorLevelJson.specFromJson(jsonDecode(jsonEncode(EditorLevelJson.specToJson(spec))) as Map<String, Object?>);
    expect(EditorLevelJson.specToJson(specBack), EditorLevelJson.specToJson(spec));
  });
}
