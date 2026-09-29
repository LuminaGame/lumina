import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart' show Widget, BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina/data/services/plugin_template_generator_service.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/new_plugin_wizard.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempRoot;
  late Directory projectDir;
  late Directory enginePluginsDir;
  late Directory projectPluginsDir;
  late Directory editorApiDir;
  late File configFile;
  late PluginRegistryService registryService;
  late PluginManagerViewModel viewModel;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('wizard_ui_test_');
    projectDir = Directory('${tempRoot.path}/my_project')..createSync(recursive: true);
    enginePluginsDir = Directory('${tempRoot.path}/engine_plugins')..createSync(recursive: true);
    projectPluginsDir = Directory('${projectDir.path}/plugins')..createSync(recursive: true);
    editorApiDir = Directory('${tempRoot.path}/lumina_editor_api')..createSync(recursive: true);
    configFile = File('${tempRoot.path}/plugin_wizard.json');

    // Create existing plugin for collision testing
    File('${projectPluginsDir.path}/water_system/water_system.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'water_system',
        'friendly_name': 'Water System',
        'version': '1.0.0',
      }));

    File('${projectDir.path}/project.lmproject')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'project_name': 'my_project',
        'engine_version': '0.0.1',
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
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  Widget buildApp({PluginTemplateGeneratorService? generatorService}) {
    return ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Builder(
          builder: (context) {
            return Center(
              child: PrimaryButton(
                child: const Text('Open Wizard'),
                onPressed: () {
                  showNewPluginWizard(
                    context,
                    viewModel: viewModel,
                    generatorService: generatorService,
                    configFilePath: configFile.path,
                    projectRoot: projectDir,
                    editorApiRoot: editorApiDir,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('Wizard opens and renders templates list and form', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Click to open wizard
    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    expect(find.text('New Plugin Wizard'), findsOneWidget);
    expect(find.text('Blank editor plugin'), findsOneWidget);
    expect(find.text('Content-only'), findsOneWidget);
    expect(find.text('Editor panel'), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);
    expect(find.text('Plugin Name (package)'), findsOneWidget);
    expect(find.text('Friendly Name'), findsOneWidget);
    expect(find.text('Author'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Create Plugin'), findsOneWidget);

    // Initial button state disabled because name is empty
    final createBtn = tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin'));
    expect(createBtn.onPressed, isNull);
  });

  testWidgets('Template selection updates summary description', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Generates: <name>.lmplugin, pubspec.yaml, lib/<name>.dart'), findsOneWidget);

    // Select Content-only
    await tester.tap(find.text('Content-only'));
    await tester.pumpAndSettle();
    expect(find.textContaining('content/materials/, content/meshes/, content/textures/'), findsOneWidget);

    // Select Editor panel
    await tester.tap(find.text('Editor panel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dockable Card panel widget'), findsOneWidget);

    // Select Importer
    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('.txt file importer'), findsOneWidget);
  });

  testWidgets('Live name validation blocks invalid/reserved/colliding names', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const Key('plugin_name_field'));

    // 1. Invalid uppercase
    await tester.enterText(nameField, 'MyPlugin');
    await tester.pumpAndSettle();
    expect(find.textContaining('lowercase'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNull);

    // 2. Starts with digit
    await tester.enterText(nameField, '1plugin');
    await tester.pumpAndSettle();
    expect(find.textContaining('start with a lowercase letter'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNull);

    // 3. Reserved Dart keyword
    await tester.enterText(nameField, 'class');
    await tester.pumpAndSettle();
    expect(find.textContaining('reserved Dart keyword'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNull);

    // 4. Reserved package name
    await tester.enterText(nameField, 'flutter');
    await tester.pumpAndSettle();
    expect(find.textContaining('reserved package name'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNull);

    // 5. Existing plugin collision
    await tester.enterText(nameField, 'water_system');
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNull);

    // 6. Valid unique name enables Create Plugin
    await tester.enterText(nameField, 'new_cool_tool');
    await tester.pumpAndSettle();
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create Plugin')).onPressed, isNotNull);
  });

  testWidgets('Wizard creation workflow triggers generator, persists author, and shows Enable prompt', (tester) async {
    ProcessRunner mockRunner = (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
      if (args.contains('create')) {
        Directory(args.last).createSync(recursive: true);
      }
      return ProcessResult(0, 0, 'ok', '');
    };

    final generatorService = PluginTemplateGeneratorService(
      projectRoot: projectDir,
      editorApiRoot: editorApiDir,
      runner: mockRunner,
    );

    await tester.pumpWidget(buildApp(generatorService: generatorService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Wizard'));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const Key('plugin_name_field'));
    await tester.enterText(nameField, 'magic_wand');
    await tester.pumpAndSettle();

    final authorField = find.byKey(const Key('author_field'));
    await tester.enterText(authorField, 'Gandalf');
    await tester.pumpAndSettle();

    // Click Create Plugin
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create Plugin'));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Wizard dialog should have closed
    expect(find.text('New Plugin Wizard'), findsNothing);

    // Confirmation dialog should appear
    expect(find.text('Plugin Created'), findsOneWidget);
    expect(find.textContaining('Successfully created plugin "Magic Wand"'), findsOneWidget);
    expect(find.text('Enable now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    // Verify config persistence
    expect(configFile.existsSync(), isTrue);
    expect(configFile.readAsStringSync(), contains('Gandalf'));

    // Verify plugin exists in registry entries
    expect(viewModel.registryService.entries.any((e) => e.descriptor.name == 'magic_wand'), isTrue);

    // Click Enable now
    await tester.tap(find.text('Enable now'));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Plugin Created'), findsNothing);
    final entry = viewModel.registryService.entries.firstWhere((e) => e.descriptor.name == 'magic_wand');
    expect(entry.enabled, isTrue);
  });
}
