import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_quality_settings.dart';

/// Applied to `editor_quality.json`: the store read the whole
/// map, set one project's entry and wrote the map back in place. A read that
/// caught another writer mid-write started from an empty map, and two editors
/// saving at once overwrote each other's projects.
void main() {
  late Directory root;
  late Directory config;

  setUp(() {
    root = Directory.systemTemp.createTempSync('editor_quality_concurrency_');
    config = Directory('${root.path}/config')..createSync();
  });
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('settings saved from several isolates at once are all kept', () async {
    const writers = 3;
    const perWriter = 20;
    final configPath = config.path;
    await Future.wait([
      for (var w = 0; w < writers; w++)
        Isolate.run(() async {
          final store = EditorQualityStore(configDir: Directory(configPath));
          for (var i = 0; i < perWriter; i++) {
            await store.save('/projects/w${w}_$i', const EditorQualitySettings(preset: 'low'));
          }
        }),
    ]);

    final saved = jsonDecode(File('${config.path}/editor_quality.json').readAsStringSync()) as Map;
    final expected = {
      for (var w = 0; w < writers; w++)
        for (var i = 0; i < perWriter; i++) '/projects/w${w}_$i',
    };
    expect(expected.difference(saved.keys.toSet()), isEmpty, reason: 'no editor may lose another editor\'s projects');
  });

  test('an unreadable editor_quality.json is kept aside, never overwritten', () async {
    const corrupt = '{"/projects/kept": {"preset": "low"';
    final file = File('${config.path}/editor_quality.json')..writeAsStringSync(corrupt);
    final store = EditorQualityStore(configDir: config);

    expect((await store.load('/projects/kept')).preset, const EditorQualitySettings().preset);
    expect(file.readAsStringSync(), corrupt, reason: 'loading never rewrites the file');

    await store.save('/projects/next', const EditorQualitySettings(preset: 'medium'));

    final keptAside = config
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('editor_quality.json.unreadable-'))
        .toList();
    expect(keptAside, hasLength(1), reason: 'the unreadable settings are kept next to the new file');
    expect(keptAside.single.readAsStringSync(), corrupt);
    expect((await store.load('/projects/next')).preset, 'medium');
  });
}
