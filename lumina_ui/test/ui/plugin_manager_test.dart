import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'dart:convert';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempRoot;
  late Directory enginePluginsDir;
  late Directory projectPluginsDir;
  late Directory projectDir;
  late PluginRegistryService registryService;
  late PluginManagerViewModel viewModel;
  
  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('plugin_manager_test');
    
    enginePluginsDir = Directory('${tempRoot.path}/engine_plugins')..createSync();
    projectPluginsDir = Directory('${tempRoot.path}/project_plugins')..createSync();
    projectDir = Directory('${tempRoot.path}/project')..createSync();
    
    // Engine plugins
    File('${enginePluginsDir.path}/engine_p1/engine_p1.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'engine_p1',
        'version': '1.0.0',
        'category': 'Core',
        'modules': [{'name': 'M', 'type': 'runtime', 'entry_library': 'm.dart', 'registration_class': 'MC'}]
      }));
      
    File('${enginePluginsDir.path}/engine_p2/engine_p2.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'engine_p2',
        'version': '1.0.0',
        'category': 'Rendering',
        'modules': [{'name': 'M', 'type': 'runtime', 'entry_library': 'm.dart', 'registration_class': 'MC'}]
      }));
      
    // Project plugins
    File('${projectPluginsDir.path}/water_system/water_system.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'water_system',
        'friendly_name': 'Water System',
        'version': '1.0.0',
        'description': 'Advanced fluid dynamics',
        'category': 'Physics',
        'modules': [{'name': 'M', 'type': 'runtime', 'entry_library': 'm.dart', 'registration_class': 'MC'}],
        'dependencies': [{'name': 'engine_p1', 'version': '>=1.0.0'}]
      }));

    File('${projectPluginsDir.path}/ocean_tools/ocean_tools.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'ocean_tools',
        'version': '1.0.0',
        'description': 'Tools for water',
        'category': 'Physics',
        'modules': [{'name': 'M', 'type': 'editor', 'entry_library': 'm.dart', 'registration_class': 'MC'}],
        'dependencies': [{'name': 'water_system', 'version': '>=1.0.0'}]
      }));
      
    // Content only plugin
    File('${projectPluginsDir.path}/content_pack/content_pack.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'content_pack',
        'version': '1.0.0',
        'category': 'Content',
        'can_contain_content': true
      }));
      
    // Broken manifest
    File('${projectPluginsDir.path}/broken/broken.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync('not json');
      
    // Missing dep plugin
    File('${projectPluginsDir.path}/missing_dep/missing_dep.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'missing_dep',
        'version': '1.0.0',
        'dependencies': [{'name': 'does_not_exist', 'version': '>=1.0.0'}]
      }));
      
    // Engine version failing constraint
    File('${projectPluginsDir.path}/bad_engine/bad_engine.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'bad_engine',
        'version': '1.0.0',
        'engine_version': '>=99.0.0'
      }));

    File('${projectDir.path}/project.lmproject')
      .writeAsStringSync(jsonEncode({
        'project_name': 'test_project',
        'engine_version': '0.0.1',
        'active_level': 'contents/levels/L_DefaultLevel.lmas',
        'is_dirty': false,
        'last_modified_timestamp': DateTime.now().toIso8601String(),
        'last_code_generated_timestamp': DateTime.now().toIso8601String(),
        'settings': {
          'target_fps': 60,
          'vsync_enabled': true,
          'quality_preset': 'epic',
          'scalability': {
            'view_distance': 'epic',
            'shadow_quality': 'high',
            'anti_aliasing': 'fxaa',
            'post_processing': 'epic',
            'texture_quality': 'high',
            'shading_quality': 'epic'
          },
          'auto_organize_files': true,
          'auto_save_interval_seconds': 60
        }
      }));
      
    final repo = PluginRepository(roots: [
      PluginScanRoot(dir: enginePluginsDir, origin: PluginOrigin.engine),
      PluginScanRoot(dir: projectPluginsDir, origin: PluginOrigin.project),
    ]);
    final projectRepo = ProjectRepository();
    
    registryService = PluginRegistryService(repo: repo, projectRepo: projectRepo);
    await registryService.initialize(projectDir.path);
    viewModel = PluginManagerViewModel(registryService: registryService);
  });
  
  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });
  
  Widget buildApp() {
    return ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: PluginManagerView(viewModel: viewModel),
      ),
    );
  }

  testWidgets('basic counts', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    
    expect(find.text('BUILT-IN'), findsOneWidget);
    expect(find.text('INSTALLED'), findsOneWidget);
    
    final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
    printOnFailure('$texts');
    
    expect(find.text('7 plugins · 0 enabled'), findsOneWidget);
  });
}
