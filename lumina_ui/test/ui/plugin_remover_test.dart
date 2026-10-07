import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart' show InstallKind, ListingCategory;
import 'package:lumina_ui/ui/core/services/folder_install.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_remover.dart';
import 'package:path/path.dart' as p;

/// Writes a code plugin `<parent>/<name>/` (manifest, pubspec, one library)
/// and returns its folder.
Directory writePlugin(Directory parent, String name, {String version = '1.0.0', List<String> dependsOn = const []}) {
  final dir = Directory(p.join(parent.path, name))..createSync(recursive: true);
  File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
    'name': name,
    'friendly_name': 'Plugin $name',
    'version': version,
    'category': 'Testing',
    'dependencies': [for (final d in dependsOn) {'name': d, 'version': '^1.0.0'}],
    'modules': [
      {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
    ],
  }));
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: $name\nversion: $version\n');
  File(p.join(dir.path, 'lib', '$name.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync('// $name $version\nclass P {}\n');
  return dir;
}

/// A real directory link: a junction on Windows (`mklink /J`, what a
/// developer uses to link a source checkout), a symbolic link elsewhere.
/// Synchronous, so a widget test's fake clock does not hold it up.
void linkFolder(String link, String target) {
  if (Platform.isWindows) {
    String win(String s) => s.replaceAll('/', r'\');
    final r = Process.runSync('cmd', ['/c', 'mklink', '/J', win(link), win(target)]);
    if (r.exitCode != 0) throw StateError('mklink failed: ${r.stdout}${r.stderr}');
  } else {
    Link(link).createSync(target);
  }
}

/// Makes [dir] impossible to rename or delete until the returned callback
/// runs: an open file inside it on Windows (as a loaded DLL is), a
/// read-only parent elsewhere.
void Function() lockFolder(Directory dir) {
  if (Platform.isWindows) {
    final handle = File(p.join(dir.path, 'lib', 'locked.bin'))..writeAsBytesSync([1, 2, 3]);
    final raf = handle.openSync(mode: FileMode.append);
    return raf.closeSync;
  }
  Process.runSync('chmod', ['a-w', dir.parent.path]);
  return () => Process.runSync('chmod', ['u+w', dir.parent.path]);
}

List<String> filesUnder(Directory dir) => [
      for (final f in dir.listSync(recursive: true, followLinks: false).whereType<File>())
        p.relative(f.path, from: dir.path).replaceAll(r'\', '/'),
    ]..sort();

void main() {
  late Directory temp;
  late Directory engineDir;
  late Directory userDir;
  late Directory projectDir;
  late Directory dataDir;
  late Directory configDir;
  late PluginRegistryService registry;
  late MarketplaceInstallDirs marketplaceDirs;

  PluginRemover remover() => PluginRemover(pluginDataDir: dataDir, marketplaceDirs: marketplaceDirs);

  PluginEntry entry(String name) => registry.entries.singleWhere((e) => e.descriptor.name == name);

  PluginRemovalPlan plan(String name, {bool loaded = false}) => remover().plan(
        entry(name),
        entries: registry.entries,
        roots: registry.repo.roots,
        projectDir: projectDir.path,
        loaded: loaded,
      );

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('lm_rm_');
    engineDir = Directory(p.join(temp.path, 'engine'))..createSync();
    userDir = Directory(p.join(temp.path, 'user'))..createSync();
    projectDir = Directory(p.join(temp.path, 'project'))..createSync();
    dataDir = Directory(p.join(temp.path, 'plugin_data'))..createSync();
    configDir = Directory(p.join(temp.path, 'config'))..createSync();
    Directory(p.join(projectDir.path, 'plugins')).createSync();
    File(p.join(projectDir.path, 'project.lmproject'))
        .writeAsStringSync(jsonEncode({'project_name': 'project', 'engine_version': '0.0.1', 'enabled_plugins': <String>[]}));
    marketplaceDirs = MarketplaceInstallDirs(
      projectRoot: projectDir.path,
      pluginDir: userDir.path,
      themesDir: p.join(configDir.path, 'themes'),
      templatesDir: p.join(configDir.path, 'templates'),
      editorLicensesFile: p.join(configDir.path, 'marketplace', 'licenses.json'),
    );
    registry = PluginRegistryService(
      repo: PluginRepository(roots: [
        PluginScanRoot(dir: engineDir, origin: PluginOrigin.engine),
        PluginScanRoot(dir: Directory(p.join(projectDir.path, 'plugins')), origin: PluginOrigin.project),
        PluginScanRoot(dir: userDir, origin: PluginOrigin.user),
      ]),
      projectRepo: ProjectRepository(),
    );
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment; the temp dir is left behind.
    }
  });

  group('FolderInstall.remove', () {
    test('removes a folder and leaves no set-aside copy', () {
      final dir = writePlugin(userDir, 'gone_plugin');
      final removal = FolderInstall.remove(dir);
      expect(removal.removed, isTrue);
      expect(removal.link, isFalse);
      expect(removal.error, isNull);
      expect(dir.existsSync(), isFalse);
      expect(userDir.listSync(), isEmpty);
    });

    test('removes a linked folder as a link and keeps the target', () async {
      final target = writePlugin(Directory(p.join(temp.path, 'checkout')), 'linked_plugin');
      final before = filesUnder(target);
      final link = p.join(userDir.path, 'linked_plugin');
      linkFolder(link, target.path);
      expect(FileSystemEntity.isLinkSync(link), isTrue);

      final removal = FolderInstall.remove(Directory(link));

      expect(removal.removed, isTrue);
      expect(removal.link, isTrue);
      expect(FileSystemEntity.typeSync(link, followLinks: false), FileSystemEntityType.notFound);
      expect(filesUnder(target), before);
      expect(userDir.listSync(), isEmpty);
    });

    test('never follows a link inside the folder it removes', () async {
      final outside = Directory(p.join(temp.path, 'outside'))..createSync();
      File(p.join(outside.path, 'keep.txt')).writeAsStringSync('keep');
      final dir = writePlugin(userDir, 'with_link');
      linkFolder(p.join(dir.path, 'assets'), outside.path);

      expect(FolderInstall.remove(dir).removed, isTrue);

      expect(dir.existsSync(), isFalse);
      expect(File(p.join(outside.path, 'keep.txt')).readAsStringSync(), 'keep');
    });

    test('a folder that cannot be moved is left whole', () async {
      final dir = writePlugin(userDir, 'locked_plugin');
      final unlock = lockFolder(dir);
      final before = filesUnder(dir);
      FolderRemoval removal;
      try {
        removal = FolderInstall.remove(dir);
      } finally {
        unlock();
      }
      expect(removal.removed, isFalse);
      expect(removal.error, isNotNull);
      expect(filesUnder(dir), before);
      expect([for (final e in userDir.listSync()) p.basename(e.path)], ['locked_plugin']);
    });
  });

  group('PluginRemover', () {
    test('plans a user plugin: its folder, files, size, data and the built-in it replaced', () async {
      writePlugin(engineDir, 'shared_plugin');
      final dir = writePlugin(userDir, 'shared_plugin', version: '2.0.0');
      final userData = Directory(p.join(dataDir.path, 'shared_plugin'))..createSync();
      File(p.join(userData.path, 'settings.json')).writeAsStringSync('{"a": 1}');
      final projectData = Directory(p.join(projectDir.path, '.lumina', 'plugins', 'shared_plugin'))..createSync(recursive: true);
      File(p.join(projectData.path, 'chat.json')).writeAsStringSync('[1, 2, 3, 4]');
      await registry.initialize(projectDir.path);

      final pl = plan('shared_plugin', loaded: true);

      expect(pl.origin, PluginOrigin.user);
      expect(p.equals(pl.pluginDir.path, dir.path), isTrue);
      expect(pl.linkTarget, isNull);
      expect(pl.fileCount, 3);
      expect(pl.bytes, filesUnder(dir).map((f) => File(p.join(dir.path, f)).lengthSync()).reduce((a, b) => a + b));
      expect(pl.enabled, isFalse);
      expect(pl.loaded, isTrue);
      expect(pl.revealedOrigin, PluginOrigin.engine);
      expect(p.equals(pl.revealedDir!.path, p.join(engineDir.path, 'shared_plugin')), isTrue);
      expect(pl.data.map((d) => d.kind).toList(), [PluginDataKind.user, PluginDataKind.project]);
      expect(pl.data.first.bytes, 8);
      expect(pl.data.last.bytes, 12);
      expect(pl.marketplaceRecord, isNull);
      final json = pl.toJson();
      expect(json['plugin_dir'], dir.path);
      expect((json['data'] as List).length, 2);
    });

    test('keeps saved data unless asked, and removes both data folders when asked', () async {
      writePlugin(userDir, 'data_plugin');
      writePlugin(userDir, 'other_plugin');
      final userData = Directory(p.join(dataDir.path, 'data_plugin'))..createSync();
      File(p.join(userData.path, 'a.json')).writeAsStringSync('{}');
      final projectData = Directory(p.join(projectDir.path, '.lumina', 'plugins', 'data_plugin'))..createSync(recursive: true);
      File(p.join(projectData.path, 'b.json')).writeAsStringSync('{}');
      await registry.initialize(projectDir.path);

      final kept = remover().remove(plan('data_plugin'));
      expect(kept.removed, isTrue);
      expect(Directory(p.join(userDir.path, 'data_plugin')).existsSync(), isFalse);
      expect(userData.existsSync(), isTrue);
      expect(projectData.existsSync(), isTrue);

      final other = remover().remove(plan('other_plugin'), deleteData: true);
      expect(other.removed, isTrue);
      expect(userData.existsSync(), isTrue, reason: 'only the removed plugin\'s data');

      writePlugin(userDir, 'data_plugin');
      await registry.refresh();
      final gone = remover().remove(plan('data_plugin'), deleteData: true);
      expect(gone.removed, isTrue);
      expect(gone.notRemoved, isEmpty);
      expect(userData.existsSync(), isFalse);
      expect(projectData.existsSync(), isFalse);
      expect(gone.removedPaths.length, 3);
    });

    test('a Marketplace install goes through the Marketplace uninstall and drops its license record', () async {
      final dir = writePlugin(userDir, 'market_plugin');
      File(p.join(dir.path, 'LICENSE-market-plugin.txt')).writeAsStringSync('MIT');
      final records = MarketplaceLicenseRecords(File(marketplaceDirs.editorLicensesFile));
      records.upsert(MarketplaceInstallRecord(
        listingId: 'listing-1',
        slug: 'market-plugin',
        title: 'Market Plugin',
        version: '1.0.0',
        category: ListingCategory.plugin,
        installKind: InstallKind.plugin,
        publisherUsername: 'pub',
        publisherDisplayName: 'Publisher',
        installedTo: dir.path.replaceAll(r'\', '/'),
        licenseFile: p.join(dir.path, 'LICENSE-market-plugin.txt'),
        licenses: const [],
        installedAt: DateTime.utc(2026, 10, 1),
        source: 'http://127.0.0.1/listings/market-plugin',
      ));
      await registry.initialize(projectDir.path);

      final pl = plan('market_plugin');
      expect(pl.marketplaceRecord?.listingId, 'listing-1');
      expect(pl.toJson()['marketplace'], isNotNull);

      final result = remover().remove(pl);
      expect(result.removed, isTrue);
      expect(dir.existsSync(), isFalse);
      expect(records.read(), isEmpty);
    });

    test('plans a linked install by its link target, counting none of its files', () async {
      final target = writePlugin(Directory(p.join(temp.path, 'checkout')), 'dev_plugin');
      linkFolder(p.join(userDir.path, 'dev_plugin'), target.path);
      await registry.initialize(projectDir.path);

      final pl = plan('dev_plugin');
      expect(pl.linkTarget, isNotNull);
      expect(p.equals(p.normalize(pl.linkTarget!), p.normalize(target.path)), isTrue);
      expect(pl.fileCount, 0);

      expect(remover().remove(pl).removed, isTrue);
      expect(FileSystemEntity.typeSync(p.join(userDir.path, 'dev_plugin'), followLinks: false), FileSystemEntityType.notFound);
      expect(filesUnder(target), ['dev_plugin.lmplugin', 'lib/dev_plugin.dart', 'pubspec.yaml']);
    });

    test('names the enabled plugins that depend on it', () async {
      writePlugin(projectDir.childPlugins, 'base_plugin');
      writePlugin(projectDir.childPlugins, 'top_plugin', dependsOn: ['base_plugin']);
      await registry.initialize(projectDir.path);
      await registry.setEnabled('top_plugin', true);

      final pl = plan('base_plugin');
      expect(pl.origin, PluginOrigin.project);
      expect(pl.enabled, isTrue);
      expect(pl.dependents, ['top_plugin']);
    });

    test('refuses a built-in', () async {
      writePlugin(engineDir, 'engine_plugin');
      await registry.initialize(projectDir.path);
      expect(() => plan('engine_plugin'), throwsArgumentError);
    });

    test('a failed removal reports what was not removed and removes no data', () async {
      final dir = writePlugin(userDir, 'stuck_plugin');
      final userData = Directory(p.join(dataDir.path, 'stuck_plugin'))..createSync();
      File(p.join(userData.path, 'a.json')).writeAsStringSync('{}');
      await registry.initialize(projectDir.path);
      final unlock = lockFolder(dir);
      PluginRemovalResult result;
      try {
        result = remover().remove(plan('stuck_plugin'), deleteData: true);
      } finally {
        unlock();
      }
      expect(result.removed, isFalse);
      expect(result.removedPaths, isEmpty);
      expect(result.notRemoved.single, contains(dir.path));
      expect(dir.existsSync(), isTrue);
      expect(userData.existsSync(), isTrue, reason: 'data goes only once the plugin is gone');
    });
  });
}

extension on Directory {
  Directory get childPlugins => Directory(p.join(path, 'plugins'));
}
