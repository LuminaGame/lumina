import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// A plugin's own JSON store, per user and per project.
void main() {
  late Directory temp;
  late PluginStorage storage;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('plugin_storage_');
    storage = PluginStorage(userDir: Directory('${temp.path}/user/probe'), projectDir: Directory('${temp.path}/project/.lumina/plugins/probe'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('JSON round-trips per user and per project, atomically', () async {
    expect(await storage.readJson('settings'), isNull);
    await storage.writeJson('settings', {'provider': 'local', 'maxTurns': 6});
    expect(await storage.readJson('settings'), {'provider': 'local', 'maxTurns': 6});
    expect(File('${temp.path}/user/probe/settings.json').existsSync(), isTrue);

    await storage.writeJson('chats', {'count': 2}, project: true);
    expect(await storage.readJson('chats', project: true), {'count': 2});
    expect(File('${temp.path}/project/.lumina/plugins/probe/chats.json').existsSync(), isTrue);

    final leftovers = Directory(temp.path).listSync(recursive: true).where((e) => e.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('a corrupt file is a FormatException naming it', () async {
    Directory('${temp.path}/user/probe').createSync(recursive: true);
    File('${temp.path}/user/probe/broken.json').writeAsStringSync('{not json');
    await expectLater(storage.readJson('broken'), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('broken.json'))));
  });

  test('no project open: the project store refuses; names are file names only', () async {
    final userOnly = PluginStorage(userDir: Directory('${temp.path}/user/probe'));
    await expectLater(userOnly.writeJson('chats', {}, project: true), throwsStateError);
    expect(await userOnly.readJson('chats', project: true), isNull);
    await expectLater(storage.writeJson('../escape', {}), throwsArgumentError);
    await expectLater(storage.writeJson('a/b', {}), throwsArgumentError);
    await expectLater(storage.readJson(r'a\b'), throwsArgumentError);
  });
}
