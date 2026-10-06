import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';

class MockPluginRepository extends PluginRepository {
  List<LuminaPluginDescriptor> descriptors = [];

  MockPluginRepository() : super(roots: []);
  
  @override
  Future<PluginScanResult> scanAll() async {
    return PluginScanResult(plugins: descriptors, errors: []);
  }

  @override
  Future<LuminaPluginDescriptor> load(File manifest) async {
    return descriptors.first;
  }
}

class MockProjectRepository extends ProjectRepository {
  LuminaProject? activeProject;

  MockProjectRepository({this.activeProject});
  
  @override
  Future<void> saveProject(LuminaProject proj, String path) async {
    activeProject = proj;
  }
  
  @override
  Future<LuminaProject?> loadProject(String path) async {
    return activeProject;
  }
}

void main() {
  group('PluginRegistryService', () {
    late MockPluginRepository pluginRepo;
    late MockProjectRepository projectRepo;
    late PluginRegistryService service;

    setUp(() {
      pluginRepo = MockPluginRepository();
      projectRepo = MockProjectRepository();
      service = PluginRegistryService(repo: pluginRepo, projectRepo: projectRepo);
    });

    test('Resolution auto-enables dependency, sorts topologically', () async {
      final bPlugin = LuminaPluginDescriptor(
        name: 'b_plugin',
        version: Version.parse('1.0.0'),
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
        modules: [PluginModuleDescriptor(name: 'b', type: PluginModuleType.editor, entryLibrary: 'b', registrationClass: 'B')],
      );
      final aPlugin = LuminaPluginDescriptor(
        name: 'a_plugin',
        version: Version.parse('1.0.0'),
        dependencies: [PluginDependencyRef(name: 'b_plugin', version: VersionConstraint.parse('^1.0.0'))],
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
        modules: [PluginModuleDescriptor(name: 'a', type: PluginModuleType.editor, entryLibrary: 'a', registrationClass: 'A')],
      );
      pluginRepo.descriptors = [aPlugin, bPlugin];
      projectRepo.activeProject = LuminaProject(projectName: 'test', enabledPlugins: []);
      
      await service.initialize('');
      
      final res = service.resolve({'a_plugin'});
      expect(res.issues, isEmpty);
      expect(res.resolvedPlugins.map((e) => e.name).toList(), ['b_plugin', 'a_plugin']); // B before A
    });

    test('Missing dependency on disk yields missingDependency issue, atomicity', () async {
      final aPlugin = LuminaPluginDescriptor(
        name: 'a_plugin',
        version: Version.parse('1.0.0'),
        dependencies: [PluginDependencyRef(name: 'b_plugin', version: VersionConstraint.parse('^1.0.0'))],
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
      );
      pluginRepo.descriptors = [aPlugin];
      projectRepo.activeProject = LuminaProject(projectName: 'test', enabledPlugins: []);
      
      await service.initialize('');
      
      final res = service.resolve({'a_plugin'});
      expect(res.issues.length, 1);
      expect(res.issues.first.type, PluginIssueType.missingDependency);
      expect(res.issues.first.message, contains('b_plugin'));
      expect(res.issues.first.message, contains('a_plugin'));
    });

    test('Version conflict and cycle detection', () async {
      final bPlugin = LuminaPluginDescriptor(
        name: 'b_plugin',
        version: Version.parse('2.0.0'),
        dependencies: [PluginDependencyRef(name: 'a_plugin', version: VersionConstraint.parse('any'))],
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
      );
      final aPlugin = LuminaPluginDescriptor(
        name: 'a_plugin',
        version: Version.parse('1.0.0'),
        dependencies: [PluginDependencyRef(name: 'b_plugin', version: VersionConstraint.parse('^1.0.0'))],
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
      );
      pluginRepo.descriptors = [aPlugin, bPlugin];
      projectRepo.activeProject = LuminaProject(projectName: 'test', enabledPlugins: []);
      
      await service.initialize('');
      
      final res = service.resolve({'a_plugin'});
      expect(res.issues.any((i) => i.type == PluginIssueType.versionConflict && i.message.contains('^1.0.0') && i.message.contains('2.0.0')), isTrue);
      expect(res.issues.any((i) => i.type == PluginIssueType.dependencyCycle && i.message.contains('a_plugin') && i.message.contains('b_plugin')), isTrue);
    });

    test('Disable dependency rejected unless cascade', () async {
      final bPlugin = LuminaPluginDescriptor(
        name: 'b_plugin',
        version: Version.parse('1.0.0'),
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
      );
      final aPlugin = LuminaPluginDescriptor(
        name: 'a_plugin',
        version: Version.parse('1.0.0'),
        dependencies: [PluginDependencyRef(name: 'b_plugin', version: VersionConstraint.parse('^1.0.0'))],
        pluginDir: Directory(''),
        origin: PluginOrigin.user,
      );
      pluginRepo.descriptors = [aPlugin, bPlugin];
      projectRepo.activeProject = LuminaProject(projectName: 'test', enabledPlugins: ['a_plugin', 'b_plugin']);
      
      await service.initialize('');
      
      final result = await service.setEnabled('b_plugin', false);
      expect(result.issues.length, 1);
      expect(result.issues.first.type, PluginIssueType.requiredBy);
      expect(result.issues.first.message, contains('a_plugin'));
      
      final resultCascade = await service.setEnabled('b_plugin', false, cascade: true);
      expect(resultCascade.issues, isEmpty);
      expect(projectRepo.activeProject!.enabledPlugins, isEmpty);
    });
  });

  group('PluginRegistryService on disk', () {
    late Directory temp;
    late Directory userDir;
    late PluginRegistryService service;

    void writePlugin(Directory parent, String folder, String name) {
      final dir = Directory('${parent.path}/$folder')..createSync(recursive: true);
      File('${dir.path}/$name.lmplugin').writeAsStringSync('{"name": "$name", "version": "1.0.0", "modules": '
          '[{"name": "$name", "type": "editor", "entry_library": "lib/$name.dart", "registration_class": "P"}]}');
    }

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('lm_registry_');
      userDir = Directory('${temp.path}/user')..createSync();
      File('${temp.path}/project.lmproject').writeAsStringSync('{"project_name": "project", "enabled_plugins": []}');
      service = PluginRegistryService(
        repo: PluginRepository(roots: [PluginScanRoot(dir: userDir, origin: PluginOrigin.user)]),
        projectRepo: ProjectRepository(),
      );
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });

    test('isolationOf follows the manifest; the project override forces it in process and is saved', () async {
      final dir = Directory('${userDir.path}/iso_plugin')..createSync(recursive: true);
      File('${dir.path}/iso_plugin.lmplugin').writeAsStringSync('{"name": "iso_plugin", "version": "1.0.0", '
          '"isolation": "process", "modules": [{"name": "iso_plugin", "type": "editor", '
          '"entry_library": "lib/iso_plugin.dart", "registration_class": "P", "process_class": "IsoProcess"}]}');
      writePlugin(userDir, 'plain_plugin', 'plain_plugin');
      await service.initialize(temp.path);
      expect(service.isolationOf('iso_plugin'), PluginIsolation.process);
      expect(service.isolationOf('plain_plugin'), PluginIsolation.inProcess);
      expect(service.isolationOf('missing_plugin'), PluginIsolation.inProcess);
      expect(service.isolationOverrideOf('iso_plugin'), isNull);

      await service.setEnabled('iso_plugin', true);
      service.entries.firstWhere((e) => e.descriptor.name == 'iso_plugin').restartPending = false;
      expect(await service.setIsolationOverride('iso_plugin', PluginIsolation.inProcess), isTrue);
      expect(service.isolationOf('iso_plugin'), PluginIsolation.inProcess);
      expect(service.entries.firstWhere((e) => e.descriptor.name == 'iso_plugin').restartPending, isTrue);
      final saved = jsonDecode(File('${temp.path}/project.lmproject').readAsStringSync()) as Map<String, dynamic>;
      expect(saved['plugin_isolation'], {'iso_plugin': 'in_process'});

      // A fresh registry reads the override back from the file.
      final reread = PluginRegistryService(
        repo: PluginRepository(roots: [PluginScanRoot(dir: userDir, origin: PluginOrigin.user)]),
        projectRepo: ProjectRepository(),
      );
      await reread.initialize(temp.path);
      expect(reread.isolationOf('iso_plugin'), PluginIsolation.inProcess);
      expect(reread.isolationOverrideOf('iso_plugin'), PluginIsolation.inProcess);

      // Clearing it: the manifest decides again; an override on a plugin
      // without a process part changes nothing.
      expect(await reread.setIsolationOverride('iso_plugin', null), isTrue);
      expect(reread.isolationOf('iso_plugin'), PluginIsolation.process);
      expect(await reread.setIsolationOverride('plain_plugin', PluginIsolation.process), isFalse);
      expect(reread.isolationOf('plain_plugin'), PluginIsolation.inProcess);
    });

    test('a scan root skips dot folders (set-aside installs and removals)', () async {
      writePlugin(userDir, 'kept_plugin', 'kept_plugin');
      writePlugin(userDir, '.gone_plugin.removing', 'gone_plugin');
      await service.initialize(temp.path);
      expect(service.entries.map((e) => e.descriptor.name), ['kept_plugin']);
      expect(service.scanErrors, isEmpty);
      expect(service.projectDirPath, temp.path);
    });

    test('a rescan keeps the restart a code plugin change is waiting for', () async {
      writePlugin(userDir, 'a_plugin', 'a_plugin');
      writePlugin(userDir, 'b_plugin', 'b_plugin');
      await service.initialize(temp.path);
      final result = await service.setEnabled('a_plugin', true);
      expect(result.restartRequired, isTrue);

      Directory('${userDir.path}/b_plugin').deleteSync(recursive: true);
      await service.refresh();

      expect(service.entries.map((e) => e.descriptor.name), ['a_plugin']);
      expect(service.entries.single.restartPending, isTrue);
      expect(service.entries.single.enabled, isTrue);
    });
  });
}
