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
}
