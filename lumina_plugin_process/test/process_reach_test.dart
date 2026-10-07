import 'dart:convert';
import 'dart:io';

import 'package:lumina_plugin_process/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A real plugin folder in a temp dir: a `.lmplugin`, a pubspec, `lib/`
/// files and a package config that maps the plugin to it and every other
/// package to the workspace's real ones.
Future<Directory> _plugin(Directory tmp, Map<String, String> libFiles, {String processClass = 'SampleProcess'}) async {
  final dir = Directory(p.join(tmp.path, 'sample_plugin'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: sample_plugin\n');
  File(p.join(dir.path, 'sample_plugin.lmplugin')).writeAsStringSync(
    jsonEncode({
      'name': 'sample_plugin',
      'isolation': 'process',
      'modules': [
        {
          'name': 'sample_plugin',
          'type': 'editor',
          'entry_library': 'lib/sample_plugin.dart',
          'process_class': processClass,
        },
      ],
    }),
  );
  for (final e in libFiles.entries) {
    File(p.join(dir.path, 'lib', e.key))
      ..createSync(recursive: true)
      ..writeAsStringSync(e.value);
  }
  final real = PluginPackageRoots.read();
  final packages = [
    for (final name in real.roots.keys)
      if (name != 'sample_plugin') {'name': name, 'rootUri': real.roots[name]!.uri.toString(), 'packageUri': 'lib/'},
    {'name': 'sample_plugin', 'rootUri': dir.uri.toString(), 'packageUri': 'lib/'},
  ];
  File(p.join(dir.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
  return dir;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('reach_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle; the temp dir is cleaned later.
    }
  });

  test('the header scan reads directives, conditional variants and parts, not imports inside strings', () {
    const source = '''
#!/usr/bin/env dart
// import 'package:commented/out.dart';
/* import 'package:block/comment.dart'; */
@Deprecated('see http://example.com // not a comment')
library;

import 'package:a/a.dart' as a show A;
import 'b.dart'
    if (dart.library.io) 'b_io.dart'
    if (dart.library.js_interop) 'b_web.dart';
export "package:c/c.dart" hide C;
part 'part.dart';

const template = """
import 'package:flutter/material.dart';
""";
import 'package:never/reached.dart';
''';
    expect(PluginProcessReach.headerUris(source), [
      'package:a/a.dart',
      'b.dart',
      'b_io.dart',
      'b_web.dart',
      'package:c/c.dart',
      'part.dart',
    ]);
    expect(PluginProcessReach.headerUris("part of 'lib.dart';\n\nclass X {}\n"), isEmpty);
  });

  test('a process part on pure packages lists them and reaches no Flutter', () async {
    final dir = await _plugin(tmp, {
      'sample_plugin.dart':
          "import 'package:flutter/widgets.dart';\nexport 'package:sample_plugin/src/process.dart';\n",
      'src/process.dart':
          "import 'package:lumina_plugin_process/lumina_plugin_process.dart';\n"
          "import 'package:sample_plugin/src/model.dart';\n\n"
          "class SampleProcess extends LuminaPluginProcess {}\n",
      'src/model.dart': "import 'package:path/path.dart' as p;\n\nString name(String f) => p.basename(f);\n",
    });
    final reach = PluginProcessReach.ofPlugin(dir, packages: PluginPackageRoots.read(dir));

    expect(reach.roots, [Uri.parse('package:sample_plugin/src/process.dart')]);
    expect(reach.directPackages, {'lumina_plugin_process', 'path'});
    expect(reach.allPackages, containsAll(['lumina_core', 'lumina_plugin_protocol', 'path']));
    expect(
      reach.ownLibraries,
      containsAll(['package:sample_plugin/src/process.dart', 'package:sample_plugin/src/model.dart']),
    );
    expect(
      reach.ownLibraries,
      isNot(contains('package:sample_plugin/sample_plugin.dart')),
      reason: 'the shell barrel is not part of the process part',
    );
    expect(reach.flutterPackages, isEmpty, reason: reach.describeFlutter());
    expect(reach.directFlutterPackages, isEmpty);
  });

  test('a process part that reaches Flutter or a Flutter package names it with its import chain', () async {
    final dir = await _plugin(tmp, {
      'src/process.dart': "import 'package:sample_plugin/src/helper.dart';\n\nfinal class SampleProcess {}\n",
      'src/helper.dart': "import 'package:lumina_editor_api/lumina_editor_api.dart';\nimport 'dart:ui' as ui;\n",
    });
    final reach = PluginProcessReach.ofPlugin(dir, packages: PluginPackageRoots.read(dir));

    expect(reach.directPackages, {'lumina_editor_api'});
    expect(reach.directFlutterPackages, {'lumina_editor_api', 'flutter'});
    expect(reach.flutterPackages, containsAll(['flutter', 'lumina_editor_api', 'lumina', 'lumina_widgets']));
    expect(reach.flutterPackages, isNot(contains('lumina_core')));
    expect(
      reach.describeFlutter(),
      contains(
        'lumina_editor_api: package:lumina_editor_api/lumina_editor_api.dart <- package:sample_plugin/src/helper.dart <- package:sample_plugin/src/process.dart',
      ),
    );
  });

  test('a plugin without a process class has no process part', () async {
    final dir = await _plugin(tmp, {'sample_plugin.dart': ''});
    File(p.join(dir.path, 'sample_plugin.lmplugin')).writeAsStringSync(
      jsonEncode({
        'name': 'sample_plugin',
        'modules': [
          {'name': 'sample_plugin', 'type': 'editor', 'entry_library': 'lib/sample_plugin.dart'},
        ],
      }),
    );
    expect(PluginProcessReach.processLibrariesOf(dir), isEmpty);
    expect(() => PluginProcessReach.ofPlugin(dir), throwsStateError);
  });
}
