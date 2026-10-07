import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/create_project_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Performs the real on-disk effects of `flutter create`; `flutter pub get` is
/// a no-op because nothing in these tests resolves packages.
ProcessRunner scaffoldingRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final projectName = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $projectName\n'
        'environment:\n'
        "  sdk: ^3.12.0\n"
        'dependencies:\n'
        '  flutter:\n'
        '    sdk: flutter\n'
        'flutter:\n'
        '  uses-material-design: true\n',
      );
    }
    return ProcessResult(0, 0, '', '');
  };
}

void main() {
  late Directory tempConfigDir;
  late Directory tempWorkspace;

  setUp(() {
    tempConfigDir = Directory.systemTemp.createTempSync('lumina_tpl_ui_cfg_');
    tempWorkspace = Directory.systemTemp.createTempSync('lumina_tpl_ui_ws_');
  });

  tearDown(() {
    if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
    if (tempWorkspace.existsSync()) tempWorkspace.deleteSync(recursive: true);
  });

  group('Launcher template catalog is the single source of truth', () {
    test('LauncherViewModel.templates mirrors GameTemplateCatalog, with no pending labels', () {
      final vm = LauncherViewModel(configDir: tempConfigDir);
      expect(
        vm.templates.map((t) => t.id).toList(),
        GameTemplateCatalog.all.map((t) => t.id).toList(),
      );
      for (var i = 0; i < vm.templates.length; i++) {
        expect(vm.templates[i].title, GameTemplateCatalog.all[i].title);
        expect(vm.templates[i].description, GameTemplateCatalog.all[i].description);
        expect(vm.templates[i].title.toLowerCase(), isNot(contains('pending')));
        expect(vm.templates[i].description.toLowerCase(), isNot(contains('pending')));
      }
    });

    test("the editor's starter level actors come from the blank 3D template", () {
      final fromEditor = EditorViewModel.starterLevelActors().map((a) => a.toMap()).toList();
      final fromCatalog = GameTemplateCatalog.byId(kBlank3dTemplateId).levelActors;
      expect(fromEditor.length, fromCatalog.length);
      for (var i = 0; i < fromEditor.length; i++) {
        expect(fromEditor[i]['id'], fromCatalog[i]['id']);
        expect(fromEditor[i]['name'], fromCatalog[i]['name']);
        expect(fromEditor[i]['type'], fromCatalog[i]['type']);
        expect(fromEditor[i]['location'], fromCatalog[i]['location']);
      }
    });
  });

  group('CreateProjectDialog template chips', () {
    testWidgets('renders all three templates with honest descriptions and selects one', (tester) async {
      final repo = ProjectRepository(configDir: tempConfigDir, processRunner: scaffoldingRunner());
      final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
      final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
      vm.updateLocation(tempWorkspace.path);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: CreateProjectDialog(viewModel: vm, onSuccess: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final template in GameTemplateCatalog.all) {
        expect(find.text(template.title), findsOneWidget, reason: '${template.id} chip label');
        expect(find.text(template.description), findsOneWidget, reason: '${template.id} blurb');
      }
      expect(find.textContaining('(pending)'), findsNothing);

      expect(vm.template, kBlank3dTemplateId);
      await tester.tap(find.text('Third Person'));
      await tester.pumpAndSettle();
      expect(vm.template, kThirdPersonTemplateId);

      await tester.tap(find.text('First Person'));
      await tester.pumpAndSettle();
      expect(vm.template, kFirstPersonTemplateId);
    });
  });

  group('the UI widget library is chosen at creation', () {
    testWidgets('the dialog defaults to shadcn_flutter, Plain Flutter can be picked, and the project records it', (tester) async {
      final repo = ProjectRepository(configDir: tempConfigDir, processRunner: scaffoldingRunner());
      final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
      final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
      vm.updateName('ui_lib_probe');
      vm.updateLocation(tempWorkspace.path);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: CreateProjectDialog(viewModel: vm, onSuccess: () {})),
      ));
      await tester.pumpAndSettle();
      expect(find.text('UI Widget Library'), findsOneWidget);
      expect(find.text('shadcn_flutter'), findsOneWidget);
      expect(find.text('Plain Flutter widgets'), findsOneWidget);
      expect(vm.widgetLibrary, kUmgWidgetLibraryShadcn);

      await tester.ensureVisible(find.byKey(const ValueKey('create_project_widget_library_flutter')));
      await tester.tap(find.text('Plain Flutter widgets'));
      await tester.pumpAndSettle();
      expect(vm.widgetLibrary, kUmgWidgetLibraryFlutter);

      await tester.runAsync(() => vm.createProject());
      expect(vm.creationError, isNull);
      final projectDir = '${tempWorkspace.path}/ui_lib_probe';
      final manifest = jsonDecode(File('$projectDir/ui_lib_probe.lmproject').readAsStringSync()) as Map;
      expect(manifest['ui'], {'widget_library': 'flutter'});
      expect(File('$projectDir/pubspec.yaml').readAsStringSync(), isNot(contains('shadcn_flutter')));
    });
  });

  group('Creating a template project through the view model', () {
    testWidgets('First Person lands a playable scaffold on disk and names its steps', (tester) async {
      await tester.runAsync(() async {
        final repo = ProjectRepository(configDir: tempConfigDir, processRunner: scaffoldingRunner());
        final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
        final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
        vm.updateName('fp_ui_probe');
        vm.updateLocation(tempWorkspace.path);
        vm.updateTemplate(kFirstPersonTemplateId);

        await vm.createProject();
        expect(vm.creationError, isNull);

        final projectDir = '${tempWorkspace.path}/fp_ui_probe';

        // The seeded level is on disk before the editor ever opens it.
        final levelMap = jsonDecode(
          File('$projectDir/contents/levels/L_DefaultLevel.lmas').readAsStringSync(),
        ) as Map<String, dynamic>;
        final actors = (levelMap['metadata']['actors'] as List)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList();
        expect(actors.any((a) => a['type'] == 'PlayerStart'), isTrue);
        expect(actors.where((a) => a['type'] == 'Primitive').length, greaterThanOrEqualTo(5));

        // ...and the editor loads exactly that tree.
        final loaded = actors.map(EditorActorNode.fromMap).toList();
        expect(loaded.map((a) => a.name), contains('PlayerStart'));
        expect(loaded.map((a) => a.name), contains('Floor'));

        // User-owned gameplay source exists.
        expect(File('$projectDir/lib/pawns/fp_ui_probe_character.dart').existsSync(), isTrue);
        expect(File('$projectDir/lib/game/fp_ui_probe_game_mode.dart').existsSync(), isTrue);

        expect(vm.activeProject?.template, kFirstPersonTemplateId);
        expect(vm.activeProject?.mapsAndModes.defaultGameMode, 'FpUiProbeGameMode');

        // The progress log names the template-specific work, not a generic line.
        final log = vm.processOutput.join('\n');
        expect(log, contains('First Person input actions'));
        expect(log, contains('Seeding First Person level actors'));
        expect(log, contains('FpUiProbeCharacter'));
      });
    });

    testWidgets('Blank 3D writes no gameplay source and records its id', (tester) async {
      await tester.runAsync(() async {
        final repo = ProjectRepository(configDir: tempConfigDir, processRunner: scaffoldingRunner());
        final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
        final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
        vm.updateName('blank_ui_probe');
        vm.updateLocation(tempWorkspace.path);

        await vm.createProject();
        expect(vm.creationError, isNull);

        final projectDir = '${tempWorkspace.path}/blank_ui_probe';
        expect(Directory('$projectDir/lib/pawns').existsSync(), isFalse);
        expect(Directory('$projectDir/lib/game').existsSync(), isFalse);
        expect(vm.activeProject?.template, kBlank3dTemplateId);
        expect(vm.activeProject?.mapsAndModes.defaultGameMode, 'LuminaGameMode');
      });
    });
  });
}
