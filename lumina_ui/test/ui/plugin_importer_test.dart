import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:path/path.dart' as p;

const _mit = '''MIT License

Copyright (c) 2026 Lumina

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction.
''';

/// A real plugin package on disk: manifest, pubspec, library, license and
/// changelog, as `tool/pack_plugin.dart` expects them.
Map<String, String> pluginFiles(String name, {String version = '1.0.0', String? manifestName}) => {
      '$name.lmplugin': jsonEncode({
        'name': manifestName ?? name,
        'friendly_name': 'Import Test $name',
        'version': version,
        'description': 'A plugin imported by the tests',
        'category': 'Testing',
        'license': 'MIT',
        'engine_version': '>=0.0.1 <1.0.0',
        'modules': [
          {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
        ],
      }),
      'pubspec.yaml': 'name: $name\nversion: $version\nenvironment:\n  sdk: ^3.12.0\n',
      'lib/$name.dart': '// $name $version\nclass P {}\n',
      'LICENSE': _mit,
      'CHANGELOG.md': '## $version\n\n- First release.\n',
    };

void writeFiles(Directory dir, Map<String, String> files) {
  for (final MapEntry(key: rel, value: text) in files.entries) {
    File(p.join(dir.path, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
}

File writeZip(Directory dir, String fileName, List<ArchiveFile> entries) {
  final archive = Archive();
  for (final e in entries) {
    archive.addFile(e);
  }
  return File(p.join(dir.path, fileName))..writeAsBytesSync(ZipEncoder().encode(archive));
}

/// [zip] with the entry name [from] renamed to [to] (same length) in its
/// local and central headers: `ZipEncoder` writes `/` for every `\`, so a
/// backslash name has to be put in afterwards, as another zip tool would.
List<int> renameEntry(List<int> zip, String from, String to) {
  expect(to.length, from.length);
  final bytes = List<int>.of(zip);
  final a = utf8.encode(from), b = utf8.encode(to);
  var found = 0;
  for (var i = 0; i + a.length <= bytes.length; i++) {
    var hit = true;
    for (var j = 0; j < a.length && hit; j++) {
      hit = bytes[i + j] == a[j];
    }
    if (!hit) continue;
    bytes.setRange(i, i + b.length, b);
    found++;
  }
  expect(found, 2, reason: 'local + central header');
  return bytes;
}

/// [zip] with the central header of [name] marked "made by Unix", so the
/// symlink file type in its external attributes counts (`ZipEncoder` writes
/// MS-DOS).
List<int> markMadeByUnix(List<int> zip, String name) {
  final bytes = List<int>.of(zip);
  final encoded = utf8.encode(name);
  for (var i = 0; i + 46 <= bytes.length; i++) {
    if (bytes[i] != 0x50 || bytes[i + 1] != 0x4b || bytes[i + 2] != 0x01 || bytes[i + 3] != 0x02) continue;
    final nameLength = bytes[i + 28] | bytes[i + 29] << 8;
    if (nameLength != encoded.length) continue;
    final entryName = utf8.decode(bytes.sublist(i + 46, i + 46 + nameLength), allowMalformed: true);
    if (entryName == name) bytes[i + 5] = 3;
  }
  return bytes;
}

List<ArchiveFile> zipEntries(Map<String, String> files, {String? top}) => [
      for (final MapEntry(key: rel, value: text) in files.entries)
        ArchiveFile.bytes(top == null ? rel : '$top/$rel', utf8.encode(text)),
    ];

List<String> treeOf(Directory dir) => [
      for (final f in dir.listSync(recursive: true).whereType<File>()) p.relative(f.path, from: dir.path).replaceAll(r'\', '/'),
    ]..sort();

void main() {
  late Directory temp;
  late Directory userDir;
  late Directory staging;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lm_import_');
    userDir = Directory(p.join(temp.path, 'user_plugins'))..createSync();
    staging = Directory(p.join(temp.path, 'staging'))..createSync();
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment; the temp dir is left behind.
    }
  });

  PluginImporter importer({List<LuminaPluginDescriptor> existing = const []}) =>
      PluginImporter(userPluginDir: userDir, stagingRoot: staging, existing: existing);

  group('from a folder', () {
    test('copies the plugin without generated folders and overrides; the source stays', () async {
      final src = Directory(p.join(temp.path, 'src', 'folder_plugin'))..createSync(recursive: true);
      writeFiles(src, {
        ...pluginFiles('folder_plugin'),
        'build/out.txt': 'build output',
        '.dart_tool/package_config.json': '{}',
        'pubspec_overrides.yaml': 'dependency_overrides: {}\n',
        'lib/src/deep/more.dart': '// more\n',
      });
      final before = treeOf(src);

      final result = await importer().importFolder(src.path);

      expect(result.status, PluginImportStatus.installed, reason: result.messages.join('\n'));
      final dest = Directory(p.join(userDir.path, 'folder_plugin'));
      expect(result.installedDir?.path, dest.path);
      expect(treeOf(dest), [
        'CHANGELOG.md',
        'LICENSE',
        'folder_plugin.lmplugin',
        'lib/folder_plugin.dart',
        'lib/src/deep/more.dart',
        'pubspec.yaml',
      ]);
      expect(treeOf(src), before, reason: 'the source folder is untouched');
      final scanned = await PluginRepository(roots: [PluginScanRoot(dir: userDir, origin: PluginOrigin.user)]).scanAll();
      expect(scanned.plugins.map((d) => d.name), ['folder_plugin']);
    });

    test('a folder without a .lmplugin manifest is refused and nothing is written', () async {
      final src = Directory(p.join(temp.path, 'no_manifest'))..createSync();
      writeFiles(src, {'pubspec.yaml': 'name: no_manifest\n', 'lib/a.dart': '// a\n'});

      final result = await importer().importFolder(src.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('.lmplugin manifest'));
      expect(userDir.listSync(), isEmpty);
    });

    test('a manifest whose name differs from its file name is refused', () async {
      final src = Directory(p.join(temp.path, 'mismatch'))..createSync();
      writeFiles(src, pluginFiles('mismatch', manifestName: 'other_name'));

      final result = await importer().importFolder(src.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('does not match its file name'));
      expect(userDir.listSync(), isEmpty);
    });

    test('license and changelog findings only warn for a folder (a plugin under development)', () async {
      final src = Directory(p.join(temp.path, 'dev_plugin'))..createSync();
      final files = pluginFiles('dev_plugin')..remove('CHANGELOG.md');
      files['dev_plugin.lmplugin'] = files['dev_plugin.lmplugin']!.replaceFirst('"license":"MIT"', '"license":"Proprietary"');
      writeFiles(src, files);

      final result = await importer().importFolder(src.path);

      expect(result.status, PluginImportStatus.installed, reason: result.messages.join('\n'));
      expect(result.warnings.join('\n'), contains('Proprietary'));
    });
  });

  group('from a zip', () {
    test('the pack_plugin layout (<name>/ top folder) installs to <user dir>/<name>/', () async {
      final zip = writeZip(temp, 'zip_plugin-1.0.0.zip', zipEntries(pluginFiles('zip_plugin'), top: 'zip_plugin'));

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.installed, reason: result.messages.join('\n'));
      final dest = Directory(p.join(userDir.path, 'zip_plugin'));
      expect(treeOf(dest), ['CHANGELOG.md', 'LICENSE', 'lib/zip_plugin.dart', 'pubspec.yaml', 'zip_plugin.lmplugin']);
      expect(staging.listSync(), isEmpty, reason: 'the staging copy is removed');
    });

    for (final (label, bad) in [
      ('a parent-directory entry', '../evil.txt'),
      ('an absolute drive entry', 'C:/evil.txt'),
      ('an absolute entry', '/evil.txt'),
    ]) {
      test('$label is refused, naming the entry, and nothing is written', () async {
        final zip = writeZip(temp, 'bad.zip', [
          ...zipEntries(pluginFiles('zip_plugin'), top: 'zip_plugin'),
          ArchiveFile.bytes(bad, utf8.encode('evil')),
        ]);

        final result = await importer().importZip(zip.path);

        expect(result.status, PluginImportStatus.invalid);
        expect(result.messages.join('\n'), contains('not safe'));
        expect(userDir.listSync(), isEmpty);
        expect(File(p.join(temp.path, 'evil.txt')).existsSync(), isFalse);
        expect(staging.listSync(), isEmpty);
      });
    }

    test('a backslash entry is refused, naming the entry, and nothing is written', () async {
      final zip = writeZip(temp, 'backslash.zip', [
        ...zipEntries(pluginFiles('zip_plugin'), top: 'zip_plugin'),
        ArchiveFile.bytes('zip_plugin/../../evil.txt', utf8.encode('evil')),
      ]);
      zip.writeAsBytesSync(renameEntry(zip.readAsBytesSync(), 'zip_plugin/../../evil.txt', r'zip_plugin\..\..\evil.txt'));

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('not safe'));
      expect(userDir.listSync(), isEmpty);
      expect(File(p.join(temp.path, 'evil.txt')).existsSync(), isFalse);
      expect(staging.listSync(), isEmpty);
    });

    test('a symbolic link entry is refused', () async {
      final link = ArchiveFile.bytes('zip_plugin/lib/link.dart', utf8.encode('../../outside.dart'))..mode = 0xA1FF;
      final zip = writeZip(temp, 'link.zip', [
        ...zipEntries(pluginFiles('zip_plugin'), top: 'zip_plugin'),
        link,
      ]);
      zip.writeAsBytesSync(markMadeByUnix(zip.readAsBytesSync(), 'zip_plugin/lib/link.dart'));
      expect(ZipDecoder().decodeBytes(zip.readAsBytesSync()).findFile('zip_plugin/lib/link.dart')?.isSymbolicLink, isTrue,
          reason: 'the archive really carries a symbolic link');

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('symbolic link'));
      expect(userDir.listSync(), isEmpty);
    });

    test('a file outside the marketplace allow-list is refused, naming its path', () async {
      final zip = writeZip(temp, 'exe.zip', [
        ...zipEntries(pluginFiles('zip_plugin'), top: 'zip_plugin'),
        ArchiveFile.bytes('zip_plugin/tool/helper.exe', [0x4d, 0x5a]),
      ]);

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('zip_plugin/tool/helper.exe'));
      expect(userDir.listSync(), isEmpty);
    });

    test('a top folder not named after the plugin is refused', () async {
      final zip = writeZip(temp, 'top.zip', zipEntries(pluginFiles('zip_plugin'), top: 'wrong_top'));

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('must be named after the plugin'));
      expect(userDir.listSync(), isEmpty);
    });

    test('a license outside the free-license allow-list refuses a zip (the marketplace package format)', () async {
      final files = pluginFiles('zip_plugin');
      files['zip_plugin.lmplugin'] = files['zip_plugin.lmplugin']!.replaceFirst('"license":"MIT"', '"license":"Proprietary"');
      final zip = writeZip(temp, 'proprietary.zip', zipEntries(files, top: 'zip_plugin'));

      final result = await importer().importZip(zip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('Proprietary'));
      expect(userDir.listSync(), isEmpty);
    });

    test('a file that is not a zip is refused', () async {
      final notZip = File(p.join(temp.path, 'plain.zip'))..writeAsStringSync('not a zip');

      final result = await importer().importZip(notZip.path);

      expect(result.status, PluginImportStatus.invalid);
      expect(result.messages.join('\n'), contains('not a valid zip'));
    });
  });

  group('already installed', () {
    test('a plugin in the user dir asks; replace installs the new version, cancel keeps the old', () async {
      final v1 = writeZip(temp, 'v1.zip', zipEntries(pluginFiles('twice'), top: 'twice'));
      final v2Files = pluginFiles('twice', version: '2.0.0')..['lib/added_in_v2.dart'] = '// v2\n';
      final v2 = writeZip(temp, 'v2.zip', zipEntries(v2Files, top: 'twice'));
      final dest = Directory(p.join(userDir.path, 'twice'));

      expect((await importer().importZip(v1.path)).status, PluginImportStatus.installed);
      File(p.join(dest.path, 'lib', 'stale_v1_only.dart')).writeAsStringSync('// stale\n');

      final imp = importer();
      final pending = await imp.importZip(v2.path);
      expect(pending.status, PluginImportStatus.alreadyInstalled);
      expect(pending.existingDir?.path, dest.path);
      expect(File(p.join(dest.path, 'lib', 'twice.dart')).readAsStringSync(), contains('1.0.0'), reason: 'nothing replaced yet');

      imp.discard(pending);
      expect(staging.listSync(), isEmpty, reason: 'cancel drops the staged copy');
      expect(File(p.join(dest.path, 'lib', 'twice.dart')).readAsStringSync(), contains('1.0.0'));

      final again = await imp.importZip(v2.path);
      final replaced = await imp.install(again.candidate!, replace: true);
      expect(replaced.status, PluginImportStatus.installed, reason: replaced.messages.join('\n'));
      expect(File(p.join(dest.path, 'lib', 'twice.dart')).readAsStringSync(), contains('2.0.0'));
      expect(File(p.join(dest.path, 'lib', 'added_in_v2.dart')).existsSync(), isTrue);
      expect(File(p.join(dest.path, 'lib', 'stale_v1_only.dart')).existsSync(), isFalse, reason: 'a replace does not merge');
      expect(userDir.listSync().map((e) => p.basename(e.path)), ['twice'], reason: 'no set-aside folder is left');
    });

    test('a failed replace puts the previous copy back', () async {
      final src = Directory(p.join(temp.path, 'src', 'restorable'))..createSync(recursive: true);
      writeFiles(src, pluginFiles('restorable'));
      expect((await importer().importFolder(src.path)).status, PluginImportStatus.installed);
      final dest = Directory(p.join(userDir.path, 'restorable'));
      final installed = treeOf(dest);

      final imp = importer();
      final pending = await imp.importFolder(src.path);
      expect(pending.status, PluginImportStatus.alreadyInstalled);
      // The source loses a file between the check and the copy.
      File(p.join(src.path, 'lib', 'restorable.dart')).deleteSync();
      final failed = await imp.install(pending.candidate!, replace: true);

      expect(failed.status, PluginImportStatus.failed);
      expect(treeOf(dest), installed, reason: 'the previous install is restored');
    });

    test('a built-in plugin with the same name: the user copy is installed, with a warning', () async {
      final builtIn = Directory(p.join(temp.path, 'engine', 'overridden'))..createSync(recursive: true);
      writeFiles(builtIn, pluginFiles('overridden'));
      final existing = (await PluginRepository(roots: [
        PluginScanRoot(dir: builtIn.parent, origin: PluginOrigin.engine),
      ]).scanAll())
          .plugins;
      final zip = writeZip(temp, 'overridden.zip', zipEntries(pluginFiles('overridden', version: '1.1.0'), top: 'overridden'));

      final result = await importer(existing: existing).importZip(zip.path);

      expect(result.status, PluginImportStatus.installed, reason: result.messages.join('\n'));
      expect(result.warnings.join('\n'), allOf(contains('built-in'), contains(builtIn.path)));
      final scan = await PluginRepository(roots: [
        PluginScanRoot(dir: builtIn.parent, origin: PluginOrigin.engine),
        PluginScanRoot(dir: userDir, origin: PluginOrigin.user),
      ]).scanAll();
      final listed = scan.plugins.singleWhere((d) => d.name == 'overridden');
      expect(listed.origin, PluginOrigin.user);
      expect(listed.version.toString(), '1.1.0');
    });

    test('a project plugin with the same name is refused, naming its folder', () async {
      final projectPlugin = Directory(p.join(temp.path, 'project', 'plugins', 'shadowed'))..createSync(recursive: true);
      writeFiles(projectPlugin, pluginFiles('shadowed'));
      final existing = (await PluginRepository(roots: [
        PluginScanRoot(dir: projectPlugin.parent, origin: PluginOrigin.project),
      ]).scanAll())
          .plugins;
      final zip = writeZip(temp, 'shadowed.zip', zipEntries(pluginFiles('shadowed'), top: 'shadowed'));

      final result = await importer(existing: existing).importZip(zip.path);

      expect(result.status, PluginImportStatus.conflict);
      expect(result.messages.join('\n'), contains('project plugin'));
      expect(result.messages.join('\n'), contains(projectPlugin.path));
      expect(userDir.listSync(), isEmpty);
      expect(staging.listSync(), isEmpty);
    });
  });
}
