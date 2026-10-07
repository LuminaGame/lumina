import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/project_dart_sdk.dart';
import 'package:path/path.dart' as p;

import '../helpers/mcp_test_client.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// The file and code tools through a real MCP client over
/// HTTP against a real editor on real temp projects; `dart_analyze` runs the
/// real SDK on a scaffolded project whose packages `flutter pub get
/// --offline` resolved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final barrelGlb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb');

  Map<String, Object?> jsonOf(McpToolReply r) => Map<String, Object?>.from(jsonDecode(r.text) as Map);
  String sha(List<int> bytes) => sha256.convert(bytes).toString();

  group('fs tools on a plain project', () {
    late Directory root;
    late Directory configDir;
    late EditorViewModel vm;
    late McpServerService server;
    late McpTestClient client;
    late String dir;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('lumina_mcp_fs_');
      configDir = Directory('${root.path}/config')..createSync();
      final projectDir = Directory('${root.path}/Lumina Projects/FsProject')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'FsProject', activeLevel: 'contents/levels/L_Main.lmas');
      File('${projectDir.path}/FsProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
      vm = EditorViewModel(
          initialProject: project, projectLocation: '${root.path}/Lumina Projects', enableTimers: false, autoInitAssets: false);
      dir = vm.projectDirPath;
      server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      expect(await server.start(port: 0), isTrue);
      client = McpTestClient(server.url!, server.token);
      await client.handshake();
    });

    tearDown(() async {
      client.close();
      await server.stop();
      await vm.close();
      await deleteTempProject(root);
    });

    File file(String rel) => File(p.join(dir, rel));

    Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
      final r = await client.callTool(tool, args);
      expect(r.isError, isFalse, reason: '$tool: ${r.text}');
      return r.data;
    }

    Future<String> fails(String tool, Map<String, Object?> args) async {
      final r = await client.callTool(tool, args);
      expect(r.isError, isTrue, reason: '$tool should fail: ${r.text}');
      return r.text;
    }

    test('write denial: each denied path is a tool error with its reason and the file untouched', () async {
      await ok('save_level');
      file('.lumina/editor_layout.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{"layout": true}');
      final denied = {
        '.lumina/editor_layout.json': 'editor state',
        'build/x': 'build',
        '.dart_tool/x': '.dart_tool',
        '.git/config': '.git',
        'contents/meshes/a.txt': 'import_asset',
        'FsProject.lmproject': 'settings tools',
        'contents/levels/L_Main.lmas': '.lmas',
        'pubspec.lock': 'pubspec.lock',
      };
      for (final e in denied.entries) {
        final before = file(e.key).existsSync() ? file(e.key).readAsBytesSync() : null;
        final text = await fails('fs_write', {'path': e.key, 'content': 'agent was here'});
        expect(text, contains(e.value), reason: e.key);
        final after = file(e.key).existsSync() ? file(e.key).readAsBytesSync() : null;
        expect(after, before, reason: '${e.key} untouched');
      }
      expect(await fails('fs_write', {'path': 'lib/x.dart', 'content': 'a\u0000b'}), contains('binary content'));
      expect(file('lib/x.dart').existsSync(), isFalse);

      expect(barrelGlb.existsSync(), isTrue, reason: 'test-assets must hold empty_barrel.glb');
      await vm.processImportPipeline(sourceFilePath: barrelGlb.path);
      final glb = vm.realAssets.map((a) => a.relativePath).firstWhere((r) => r.endsWith('.glb'), orElse: () => '');
      final glbPath = glb.isNotEmpty
          ? glb
          : Directory(p.join(dir, 'contents'))
              .listSync(recursive: true)
              .whereType<File>()
              .firstWhere((f) => f.path.endsWith('.glb'))
              .path;
      final glbFile = File(p.isAbsolute(glbPath) ? glbPath : p.join(dir, glbPath));
      expect(await fails('fs_read', {'path': glbFile.path}), contains('binary file (${glbFile.lengthSync()} bytes)'));
      final layout = await ok('fs_read', {'path': '.lumina/editor_layout.json'});
      expect(layout['content'], contains('layout'));
    });

    test('fs_list: a recursive glob listing, max_entries and skipped build/', () async {
      await ok('save_level');
      file('build/out/skip.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// build');
      final listed = await ok('fs_list', {'path': 'lib', 'recursive': true, 'glob': '**/*.dart'});
      final paths = [for (final e in listed['entries'] as List) (e as Map)['path']];
      expect(paths, containsAll(['lib/main.dart', 'lib/levels/l_main.dart']));
      expect(listed['truncated'], isFalse);
      final one = await ok('fs_list', {'path': 'lib', 'recursive': true, 'max_entries': 1});
      expect(one['entries'], hasLength(1));
      expect(one['truncated'], isTrue);
      final rootList = await ok('fs_list', {'recursive': true});
      final rootPaths = [for (final e in rootList['entries'] as List) (e as Map)['path'] as String];
      expect(rootPaths, contains('build'));
      expect(rootPaths.where((r) => r.startsWith('build/')), isEmpty);
      expect(rootPaths, contains('lib/main.dart'));
      final inBuild = await ok('fs_list', {'path': 'build', 'recursive': true});
      expect([for (final e in inBuild['entries'] as List) (e as Map)['path']], contains('build/out/skip.dart'));
      final entry = (listed['entries'] as List).cast<Map>().firstWhere((e) => e['path'] == 'lib/main.dart');
      expect(entry['type'], 'file');
      expect(entry['bytes'], file('lib/main.dart').lengthSync());
    });

    test('fs_read: a line range, the whole-file sha256, the 256 KiB cap', () async {
      await ok('save_level');
      final lines = file('lib/main.dart').readAsStringSync().split('\n');
      final r = await ok('fs_read', {'path': 'lib/main.dart', 'offset': 2, 'limit': 3});
      expect(r['start_line'], 2);
      expect(r['end_line'], 4);
      expect(r['content'], lines.sublist(1, 4).join('\n'));
      expect(r['sha256'], sha(file('lib/main.dart').readAsBytesSync()));
      expect(r['total_lines'], greaterThan(4));

      final big = StringBuffer();
      for (var i = 0; big.length < 300 * 1024; i++) {
        big.writeln('// line $i ${'x' * 90}');
      }
      file('lib/big.dart').writeAsStringSync(big.toString());
      final b = await ok('fs_read', {'path': 'lib/big.dart', 'limit': 100000});
      expect(b['truncated'], isTrue);
      expect(utf8.encode(b['content'] as String).length, lessThanOrEqualTo(256 * 1024));
      expect(b['sha256'], sha(file('lib/big.dart').readAsBytesSync()));
    });

    test('fs_search: regex with line and column, a bad pattern is -32602, max_results truncates', () async {
      await ok('save_level');
      final found = await ok('fs_search', {'pattern': r'class \w+ extends \w+Level\b', 'glob': 'lib/**/*.dart'});
      final hits = (found['results'] as List).cast<Map>();
      expect(hits, isNotEmpty);
      final hit = hits.firstWhere((h) => h['path'] == 'lib/levels/l_main.dart');
      final lineText = file('lib/levels/l_main.dart').readAsStringSync().split('\n')[(hit['line'] as int) - 1];
      expect(lineText.substring((hit['column'] as int) - 1), startsWith('class '));
      expect(hit['text'], contains('Level'));
      expect(found['files_scanned'], greaterThan(0));

      await expectLater(
        client.callTool('fs_search', {'pattern': '('}),
        throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602).having((e) => e.message, 'message', contains('regular expression'))),
      );

      file('lib/five.txt').writeAsStringSync(List.generate(5, (i) => 'barrel $i').join('\n'));
      final capped = await ok('fs_search', {'pattern': 'barrel \\d', 'path': 'lib', 'max_results': 2});
      expect(capped['results'], hasLength(2));
      expect(capped['truncated'], isTrue);
    });

    test('fs_write: creates file and folder with a snapshot; a stale sha256 is refused; a generated file says so', () async {
      final w = await ok('fs_write', {'path': 'lib/agent/barrel_math.dart', 'content': 'double half(double x) => x / 2;\n'});
      expect(w['created'], isTrue);
      expect(w['generated'], isFalse);
      expect(file('lib/agent/barrel_math.dart').readAsStringSync(), 'double half(double x) => x / 2;\n');
      final manifest = jsonDecode(File(p.join(dir, '.lumina', 'mcp', 'snapshots', w['snapshot_id'] as String, 'manifest.json')).readAsStringSync()) as Map;
      expect(manifest['existed'], isFalse);
      expect(manifest['client'], 'lumina-ui-test-client');
      expect(file('lib/agent/barrel_math.dart.lumina-tmp').existsSync(), isFalse);

      final read = await ok('fs_read', {'path': 'lib/agent/barrel_math.dart'});
      file('lib/agent/barrel_math.dart').writeAsStringSync('// the user edited this in the IDE\n');
      final stale = await fails('fs_write', {'path': 'lib/agent/barrel_math.dart', 'content': 'x', 'expected_sha256': read['sha256']});
      expect(stale, contains('changed since you read it'));
      expect(file('lib/agent/barrel_math.dart').readAsStringSync(), '// the user edited this in the IDE\n');
      final fresh = await ok('fs_read', {'path': 'lib/agent/barrel_math.dart'});
      final second = await ok('fs_write', {'path': 'lib/agent/barrel_math.dart', 'content': 'y', 'expected_sha256': fresh['sha256']});
      expect(second['created'], isFalse);

      await ok('save_level');
      final gen = await ok('fs_write', {'path': 'lib/main.dart', 'content': file('lib/main.dart').readAsStringSync()});
      expect(gen['generated'], isTrue);
      expect(gen['overwritten_by'], contains('run_codegen'));
      // The Recent calls row carries the path and the snapshot id.
      expect(server.recentCalls.first.detail, allOf(contains('lib/main.dart'), contains(gen['snapshot_id'] as String)));
    });

    test('fs_edit: a unique replacement with a one-hunk diff, ambiguity, replace_all, not found', () async {
      await ok('fs_write', {'path': 'lib/agent/e.dart', 'content': 'a\nb\nkey = 1;\nc\nd\nkey = 1;\ne\n'});
      await ok('fs_write', {'path': 'lib/agent/u.dart', 'content': 'one\ntwo\nthree\n'});
      final u = await ok('fs_edit', {'path': 'lib/agent/u.dart', 'old_string': 'two', 'new_string': 'TWO'});
      expect(u['replacements'], 1);
      expect(file('lib/agent/u.dart').readAsStringSync(), 'one\nTWO\nthree\n');
      final diff = u['diff'] as String;
      expect(RegExp(r'^@@ ', multiLine: true).allMatches(diff), hasLength(1));
      expect(diff, contains('-two'));
      expect(diff, contains('+TWO'));
      expect(u['snapshot_id'], isA<String>());

      final twice = await fails('fs_edit', {'path': 'lib/agent/e.dart', 'old_string': 'key = 1;', 'new_string': 'key = 2;'});
      expect(twice, allOf(contains('3'), contains('6')));
      final all = await ok('fs_edit', {'path': 'lib/agent/e.dart', 'old_string': 'key = 1;', 'new_string': 'key = 2;', 'replace_all': true});
      expect(all['replacements'], 2);
      expect(file('lib/agent/e.dart').readAsStringSync(), isNot(contains('key = 1;')));
      expect(await fails('fs_edit', {'path': 'lib/agent/e.dart', 'old_string': 'nope', 'new_string': 'x'}), contains('not found'));
      expect(await fails('fs_edit', {'path': 'lib/agent/e.dart', 'old_string': 'a', 'new_string': 'a'}), contains('same'));
    });

    test('snapshots and restore: history newest first, restore the original, undo a create, 3 snapshots per file', () async {
      file('lib/agent/s.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('original\n');
      final originalSha = sha(file('lib/agent/s.dart').readAsBytesSync());
      final w = await ok('fs_write', {'path': 'lib/agent/s.dart', 'content': 'v1 alpha\n'});
      final e1 = await ok('fs_edit', {'path': 'lib/agent/s.dart', 'old_string': 'v1', 'new_string': 'v2'});
      final e2 = await ok('fs_edit', {'path': 'lib/agent/s.dart', 'old_string': 'alpha', 'new_string': 'beta'});
      final history = await ok('fs_history', {'path': 'lib/agent/s.dart'});
      final ids = [for (final s in history['snapshots'] as List) (s as Map)['id']];
      expect(ids, [e2['snapshot_id'], e1['snapshot_id'], w['snapshot_id']]);
      final restored = await ok('fs_restore', {'snapshot_id': w['snapshot_id']});
      expect(sha(file('lib/agent/s.dart').readAsBytesSync()), originalSha);
      expect(restored['restored_bytes'], 'original\n'.length);
      expect(restored['snapshot_id'], isNot(w['snapshot_id']));
      final replaced = await ok('fs_restore', {'snapshot_id': restored['snapshot_id']});
      expect(file('lib/agent/s.dart').readAsStringSync(), 'v2 beta\n');
      expect(replaced['path'], 'lib/agent/s.dart');

      final created = await ok('fs_write', {'path': 'lib/agent/created.dart', 'content': '// new\n'});
      final undo = await ok('fs_restore', {'snapshot_id': created['snapshot_id']});
      expect(file('lib/agent/created.dart').existsSync(), isFalse);
      expect(File(p.join(dir, '.lumina', 'trash', undo['trash_id'] as String, 'files', 'lib', 'agent', 'created.dart')).existsSync(), isTrue);

      // The caller filter an in-process caller (MiniAI's turn) uses.
      final byClient = await ok('fs_history', {'caller': 'lumina-ui-test-client'});
      expect(byClient['snapshots'], isEmpty, reason: 'HTTP calls carry no in-process caller');
      final byPrefix = await ok('fs_history', {'client': 'lumina-ui-test-client', 'limit': 100});
      expect((byPrefix['snapshots'] as List), hasLength(greaterThanOrEqualTo(6)));
    });

    test('fs_delete: into the project trash and back byte-identical; a directory is refused', () async {
      await ok('fs_write', {'path': 'lib/agent/barrel_math.dart', 'content': 'double stack(int n) => n * 90.0;\n'});
      final bytes = file('lib/agent/barrel_math.dart').readAsBytesSync();
      final d = await ok('fs_delete', {'path': 'lib/agent/barrel_math.dart'});
      expect(file('lib/agent/barrel_math.dart').existsSync(), isFalse);
      expect(File(p.join(dir, '.lumina', 'trash', d['trash_id'] as String, 'files', 'lib', 'agent', 'barrel_math.dart')).existsSync(), isTrue);
      await ok('fs_restore', {'snapshot_id': d['snapshot_id']});
      expect(file('lib/agent/barrel_math.dart').readAsBytesSync(), bytes);
      expect(await fails('fs_delete', {'path': 'lib'}), contains('files only'));
      expect(await fails('fs_delete', {'path': 'FsProject.lmproject'}), contains('settings tools'));
      expect(file('FsProject.lmproject').existsSync(), isTrue);
    });

    test('run_codegen: writes main + level Dart after snapshotting them, refuses during Play, lists stale Blueprints', () async {
      await ok('save_level');
      await ok('fs_edit', {'path': 'lib/main.dart', 'old_string': 'Future<void> main() async {', 'new_string': '// hand edit\nFuture<void> main() async {'});
      final handEdited = file('lib/main.dart').readAsBytesSync();
      final mainBefore = file('lib/main.dart').lastModifiedSync();
      final levelBefore = file('lib/levels/l_main.dart').lastModifiedSync();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final r = await ok('run_codegen');
      expect(r['written_files'], containsAll(['lib/main.dart', 'lib/levels/l_main.dart']));
      expect(r['level'], 'L_Main');
      expect(file('lib/main.dart').lastModifiedSync().isAfter(mainBefore), isTrue);
      expect(file('lib/levels/l_main.dart').lastModifiedSync().isAfter(levelBefore), isTrue);
      expect(file('lib/main.dart').readAsStringSync(), isNot(contains('// hand edit')));
      final snaps = (r['snapshots'] as List).cast<Map>();
      final mainSnap = snaps.firstWhere((s) => s['path'] == 'lib/main.dart');
      await ok('fs_restore', {'snapshot_id': mainSnap['id']});
      expect(file('lib/main.dart').readAsBytesSync(), handEdited);
      expect(snaps.map((s) => s['path']), contains('contents/levels/L_Main.lmas'));

      await ok('create_asset', {'type': 'actor', 'name': 'BP_Agent', 'parent_class': 'LuminaActor'});
      final compiled = await ok('compile_blueprint', {'asset': 'contents/blueprints/BP_Agent.lmas', 'save': true});
      expect(compiled['generated_file_exists'], isTrue, reason: '$compiled');
      final bp = file('contents/blueprints/BP_Agent.lmas');
      bp.setLastModifiedSync(file('lib/actors/bp_agent.dart').lastModifiedSync().add(const Duration(minutes: 1)));
      final stale = await ok('run_codegen');
      expect(stale['stale_blueprints'], contains('contents/blueprints/BP_Agent.lmas'));

      vm.transactions.isFrozen = true;
      try {
        expect(await fails('run_codegen', const {}), contains('Stop Play first'));
      } finally {
        vm.transactions.isFrozen = false;
      }
    });

    test('risk and groups: the file tools in the risk table; Look only hides and denies fs_write', () async {
      final tools = {for (final t in await client.listTools()) t['name'] as String: t};
      String risk(String n) => (tools[n]!['_meta'] as Map)['lumina/risk'] as String;
      for (final n in ['fs_list', 'fs_read', 'fs_search', 'fs_history', 'dart_analyze']) {
        expect(risk(n), 'readOnly', reason: n);
      }
      for (final n in ['fs_write', 'fs_edit', 'fs_restore', 'run_codegen']) {
        expect(risk(n), 'mutating', reason: n);
      }
      expect(risk('fs_delete'), 'destructive');
      expect((tools['dart_analyze']!['annotations'] as Map)['openWorldHint'], isFalse);
      expect((tools['run_codegen']!['annotations'] as Map)['idempotentHint'], isTrue);
      final fs = await client.listTools(groups: ['fs']);
      expect(fs.where((t) => ((t['_meta'] as Map)['lumina/groups'] as List).contains('fs')), hasLength(8));
      final code = await client.listTools(groups: ['code']);
      expect(code.where((t) => ((t['_meta'] as Map)['lumina/groups'] as List).contains('code')).map((t) => t['name']).toSet(),
          {'dart_analyze', 'run_codegen'});

      server.settings.setMaxRisk(McpToolRisk.readOnly);
      final names = (await client.listTools()).map((t) => t['name']).toSet();
      expect(names, isNot(contains('fs_write')));
      expect(names, contains('fs_read'));
      final denied = await client.callTool('fs_write', {'path': 'lib/agent/no.dart', 'content': 'x'});
      expect(jsonOf(denied)['status'], 'denied');
      expect(file('lib/agent/no.dart').existsSync(), isFalse);
      server.settings.setMaxRisk(McpToolRisk.external);
    });
  });

  group('dart_analyze and the Blueprint palette on a scaffolded project', () {
    late Directory root;
    late String dir;
    late Directory configDir;
    late EditorViewModel vm;
    late McpServerService server;
    late McpTestClient client;
    String? skip;

    setUpAll(() async {
      root = Directory.systemTemp.createTempSync('lumina_mcp_code_');
      configDir = Directory('${root.path}/config')..createSync();
      dir = await scaffoldGameProject(root, name: 'code_game', widgetLibrary: 'flutter');
      if (!File('$dir/.dart_tool/package_config.json').existsSync() || ProjectDartSdk.resolve(dir) == null) {
        skip = 'no resolvable Flutter SDK / packages for the scaffolded project';
        return;
      }
      final project = await ProjectRepository().loadProject('$dir/code_game.lmproject');
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      expect(await server.start(port: 0), isTrue);
      client = McpTestClient(server.url!, server.token);
      await client.handshake();
    });

    tearDownAll(() async {
      if (skip == null) {
        client.close();
        await server.stop();
        await vm.close();
      }
      LuminaBlueprintFunctionRegistry.clearDeclared();
      await deleteTempProject(root, timeout: const Duration(seconds: 30));
    });

    Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
      final r = await client.callTool(tool, args);
      expect(r.isError, isFalse, reason: '$tool: ${r.text}');
      return r.data;
    }

    test('an error is reported with file, line and code; the fix makes it clean; min_severity; paths stay in the sandbox',
        () async {
      if (skip != null) {
        markTestSkipped(skip!);
        return;
      }
      await ok('fs_write', {
        'path': 'lib/agent/barrel_math.dart',
        'content': '/// Half of [x].\ndouble half(double x) {\n  return \'half\';\n}\n',
      });
      final broken = await ok('dart_analyze', {'paths': ['lib/agent']});
      expect(broken['ok'], isFalse);
      final errors = (broken['diagnostics'] as List).cast<Map>().where((d) => d['severity'] == 'error').toList();
      expect(errors, hasLength(1), reason: '$broken');
      expect(errors.single['file'], 'lib/agent/barrel_math.dart');
      expect(errors.single['line'], 3);
      expect(errors.single['code'], 'return_of_invalid_type');
      expect((broken['counts'] as Map)['error'], 1);
      expect(broken['sdk'], isA<String>());

      await ok('fs_edit', {'path': 'lib/agent/barrel_math.dart', 'old_string': "return 'half';", 'new_string': 'return x / 2;'});
      final fixed = await ok('dart_analyze', {'paths': ['lib/agent/barrel_math.dart']});
      expect(fixed['ok'], isTrue, reason: '$fixed');
      expect((fixed['counts'] as Map)['error'], 0);

      await ok('fs_write', {'path': 'lib/agent/info.dart', 'content': 'import \'dart:math\';\n\nint unusedImport() => 1;\n'});
      final all = await ok('dart_analyze', {'paths': ['lib/agent']});
      expect((all['diagnostics'] as List).cast<Map>().where((d) => d['severity'] != 'error'), isNotEmpty, reason: '$all');
      final errorsOnly = await ok('dart_analyze', {'paths': ['lib/agent'], 'min_severity': 'error'});
      expect((errorsOnly['diagnostics'] as List).cast<Map>().where((d) => d['severity'] != 'error'), isEmpty);

      final outside = await client.callTool('dart_analyze', {'paths': ['../']});
      expect(outside.isError, isTrue);
      expect(outside.text, contains('outside the project'));
    }, timeout: const Timeout(Duration(minutes: 6)));

    test('an fs_write of a @BlueprintCallable function reaches the palette within 5 s (the lib/ watcher)', () async {
      if (skip != null) {
        markTestSkipped(skip!);
        return;
      }
      final fns = vm.blueprintFunctions;
      await fns.open();
      // Warm the analyzer once, as the editor has by the time an agent edits.
      await ok('fs_write', {
        'path': 'lib/agent/warmup.dart',
        'content': "import 'package:lumina/lumina_runtime.dart';\n\n/// Warms the analyzer.\n@BlueprintPure()\ndouble warmup(double x) => x;\n",
      });
      await fns.scan();
      final sw = Stopwatch()..start();
      await ok('fs_write', {
        'path': 'lib/agent/barrel_stack.dart',
        'content': "import 'package:lumina/lumina_runtime.dart';\n\n/// The height of [count] stacked barrels, in cm.\n"
            "@BlueprintCallable(category: 'Agent')\ndouble barrelStackHeight(int count) => count * 90.0;\n",
      });
      while (!fns.functions.any((f) => f.spec.id.endsWith('#barrelStackHeight')) && sw.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(fns.functions.map((f) => f.spec.id), contains(endsWith('#barrelStackHeight')), reason: '${fns.diagnostics}');
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
