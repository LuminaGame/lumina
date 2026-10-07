import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../helpers/analyze_generated_project.dart';
import 'project_template_test.dart' show realFilesystemRunner;

/// The generated launcher registers the project's compiled widget
/// classes and stacks [LuminaWidgetLayer] over the game. The widget class and
/// the registry file are written here in the exact shape lumina_ui's
/// `UmgWidgetCodegen` emits (its own tests cover the emission); this test
/// proves the launcher + registry + layer compile together in a real
/// scaffolded project.
void main() {
  final generator = DartCodeGeneratorService();

  test('generateMainDart registers the widget classes and stacks LuminaWidgetLayer over the game', () {
    final withWidgets = generator.generateMainDart(projectName: 'my_game', widgetClasses: true);
    expect(withWidgets, contains("import 'widgets/widget_registry.g.dart';"));
    expect(withWidgets, contains('registerProjectWidgetClasses();'));
    expect(withWidgets.indexOf('registerProjectWidgetClasses();'), lessThan(withWidgets.indexOf('runApp(')), reason: 'registered before the world starts');
    expect(withWidgets, contains('LuminaWidgetLayer.forGame(game: _game)'));
    expect(withWidgets.indexOf('LuminaGameWidget(game: _game)'), lessThan(withWidgets.indexOf('LuminaWidgetLayer.forGame')), reason: 'the layer is stacked above the 3D view');

    final without = generator.generateMainDart(projectName: 'my_game');
    expect(without, isNot(contains('widget_registry.g.dart')));
    expect(without, isNot(contains('registerProjectWidgetClasses')));
    expect(without, contains('LuminaWidgetLayer.forGame(game: _game)'), reason: 'unknown classes still render their fallback card');
  });

  for (final library in [kUmgWidgetLibraryFlutter, kUmgWidgetLibraryShadcn]) {
    test('$library: a scaffolded project with widgets/widget_registry.g.dart registering WBP_HUD analyzes clean', () async {
      final root = Directory.systemTemp.createTempSync('lumina_widget_layer_');
      final configDir = Directory.systemTemp.createTempSync('lumina_widget_layer_cfg_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
        if (configDir.existsSync()) configDir.deleteSync(recursive: true);
      });
      final repo = ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner(offlinePubGet: true));
      final name = 'hud_$library';
      final project = await repo.createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId, widgetLibrary: library);
      final projectDir = '${root.path}/$name';
      final plain = library == kUmgWidgetLibraryFlutter;

      // What UmgWidgetCodegen writes for a WBP_HUD with a Text `FPSCounter`.
      Directory('$projectDir/lib/widgets').createSync(recursive: true);
      File('$projectDir/lib/widgets/wbp_hud.dart').writeAsStringSync('''
// GENERATED CODE - DO NOT MODIFY BY HAND (edit only inside USER CODE regions)
// ignore_for_file: file_names, unused_import, prefer_const_constructors

${plain ? "import 'package:flutter/widgets.dart';" : "import 'package:shadcn_flutter/shadcn_flutter.dart';"}
import 'package:lumina/lumina_runtime.dart' show LuminaUmgElement, LuminaUmgElementBinding;

/// `WBP_HUD` as designed in Lumina Studio.
class WBPHUD extends StatelessWidget {
  const WBPHUD({super.key, this.instance});

  /// The widget instance this class renders (`Create Widget`), null in a preview.
  final Map<String, Object?>? instance;

  @override
  Widget build(BuildContext context) {
    return LuminaUmgElement(
      instance: instance,
      name: 'FPSCounter',
      builder: (context, e) => Text(
        key: const ValueKey('fpsCounter'),
        LuminaUmgElementBinding.value<String>(e, 'text', 'FPS: 0'),
        style: TextStyle(fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 16.0), color: LuminaUmgElementBinding.color(e, 'color', Color(0xFFFFFFFF))),
      ),
    );
  }
}
''');
      File('$projectDir/lib/widgets/widget_registry.g.dart').writeAsStringSync('''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: prefer_const_constructors

import 'package:lumina/lumina_runtime.dart';

import 'wbp_hud.dart';

/// Registers every UMG widget class of the project.
void registerProjectWidgetClasses() {
  LuminaWidgetBuilderRegistry.register(
    'WBP_HUD',
    const LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
      LuminaBlueprintWidgetElement(name: 'FPSCounter', fieldName: 'fpsCounter', typeName: 'text', props: {'text': 'FPS: 0', 'fontSize': 16.0, 'color': '#FFFFFF'}),
    ]),
    (context, instance) => WBPHUD(instance: instance),
  );
}
''');

      // Regenerating the launcher (what the editor does on save) picks the registry up.
      final level = File('$projectDir/contents/levels/L_DefaultLevel.lmas');
      final actors = ((jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      final result = await GenerateDartCodeUseCase()(projectDir: projectDir, levelName: 'L_DefaultLevel', actors: actors, project: project);
      expect(result.isSuccess, isTrue, reason: result.error);
      final main = File('$projectDir/lib/main.dart').readAsStringSync();
      expect(main, contains('registerProjectWidgetClasses();'));
      expect(main, contains('LuminaWidgetLayer.forGame(game: _game)'));
      final registry = File('$projectDir/lib/widgets/widget_registry.g.dart').readAsStringSync();
      expect(registry, contains("'WBP_HUD'"));
      expect(registry, contains("name: 'FPSCounter'"));
      expect(registry, contains("typeName: 'text'"));

      File('$projectDir/analysis_options.yaml').writeAsStringSync('');
      final analyze = await analyzeGeneratedProject(projectDir);
      expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
