import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/create_project_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('Project Creation Pipeline Tests', () {
    late Directory tempConfigDir;
    late Directory tempWorkspace;

    setUp(() {
      tempConfigDir = Directory.systemTemp.createTempSync('lumina_test_config_');
      tempWorkspace = Directory.systemTemp.createTempSync('lumina_test_workspace_');
    });

    tearDown(() {
      if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
      if (tempWorkspace.existsSync()) tempWorkspace.deleteSync(recursive: true);
    });

    test('Project name and location validation rules', () {
      expect(ProjectRepository.validateProjectName('MyFirstLuminaGame'), isNotNull);
      expect(ProjectRepository.validateProjectName('123game'), isNotNull);
      expect(ProjectRepository.validateProjectName('class'), isNotNull);
      expect(ProjectRepository.validateProjectName(''), isNotNull);
      expect(ProjectRepository.validateProjectName('my_lumina_game'), isNull);

      expect(ProjectRepository.validateLocation('/non_existent_folder_xyz_123'), isNotNull);
      expect(ProjectRepository.validateLocation(tempWorkspace.path), isNull);
    });

    test('Pre-existing directory fails with ProjectCreationException and leaves dir untouched', () async {
      final existingDir = Directory('${tempWorkspace.path}/existing_game')..createSync();
      File('${existingDir.path}/keep_me.txt').writeAsStringSync('important');

      final repo = ProjectRepository(configDir: tempConfigDir);
      final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
      final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
      vm.updateName('existing_game');
      vm.updateLocation(tempWorkspace.path);

      await vm.createProject();

      expect(vm.creationError, contains('Project directory already exists'));
      expect(File('${existingDir.path}/keep_me.txt').existsSync(), isTrue);
    });

    test('Scripted process runner pipeline creates tree, protobuf level, and valid pubspec', () async {
      Future<ProcessResult> fakeRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        if (args.contains('create')) {
          // Simulate flutter create output
          final target = args.last;
          final dir = Directory(target);
          if (!dir.existsSync()) dir.createSync(recursive: true);
          File('$target/pubspec.yaml').writeAsStringSync('''
name: my_test_project
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.2.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
        }
        return ProcessResult(1234, 0, 'Success', '');
      }

      final repo = ProjectRepository(configDir: tempConfigDir, processRunner: fakeRunner);
      final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
      final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
      vm.updateName('my_scripted_game');
      vm.updateLocation(tempWorkspace.path);

      final stepsEmitted = <ProjectCreationStep>[];
      await for (final p in repo.createProjectStream(
        projectName: 'my_scripted_game',
        projectLocation: tempWorkspace.path,
      )) {
        stepsEmitted.add(p.step);
      }

      expect(stepsEmitted, equals([
        ProjectCreationStep.folderSetup,
        ProjectCreationStep.flutterCreate,
        ProjectCreationStep.contentsTree,
        ProjectCreationStep.pubspecPatch,
        ProjectCreationStep.pubGet,
        ProjectCreationStep.manifestAndLevel,
        ProjectCreationStep.openingEditor,
      ]));

      final projDir = Directory('${tempWorkspace.path}/my_scripted_game');
      expect(projDir.existsSync(), isTrue);

      // Verify 9 contents/ subdirectories
      for (final sub in [
        'meshes/static',
        'meshes/skeletal',
        'materials',
        'textures',
        'animations',
        'audio',
        'particles',
        'levels',
        'ui',
      ]) {
        expect(Directory('${projDir.path}/contents/$sub').existsSync(), isTrue, reason: 'contents/$sub must exist');
      }

      // Verify single flutter: section in pubspec.yaml
      final pubspecContent = File('${projDir.path}/pubspec.yaml').readAsStringSync();
      final flutterMatches = RegExp(r'^flutter:', multiLine: true).allMatches(pubspecContent);
      expect(flutterMatches.length, equals(1));
      expect(pubspecContent, contains('lumina:'));
      expect(pubspecContent, contains('- contents/meshes/static/'));

      // L_DefaultLevel.lmas is the same JSON level container the editor's Save
      // Level writes (the editor reads levels with jsonDecode), already seeded
      // with the chosen template's actors.
      final levelFile = File('${projDir.path}/contents/levels/L_DefaultLevel.lmas');
      expect(levelFile.existsSync(), isTrue);
      final levelMap = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      expect(levelMap['type'], equals('level'));
      expect(levelMap['name'], equals('L_DefaultLevel'));
      expect(levelMap['metadata']['actors'], isA<List>());
      expect((levelMap['metadata']['actors'] as List), isNotEmpty);

      // Verify .lmproject JSON
      final manifestFile = File('${projDir.path}/my_scripted_game.lmproject');
      expect(manifestFile.existsSync(), isTrue);
      final manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final project = LuminaProject.fromMap(manifestJson);
      expect(project.projectName, equals('my_scripted_game'));
      expect(project.activeLevel, equals('contents/levels/L_DefaultLevel.lmas'));
      expect(project.settings.scalability.viewDistance, equals('epic'));
      expect(project.settings.autoOrganizeFiles, isTrue);
      expect(project.settings.autoSaveIntervalSeconds, equals(60));
    });

    test('Rollback on failure deletes created directory and leaves recents untouched', () async {
      Future<ProcessResult> failingRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        return ProcessResult(1234, 1, '', 'Simulated fatal flutter error');
      }

      final repo = ProjectRepository(configDir: tempConfigDir, processRunner: failingRunner);
      final targetDir = Directory('${tempWorkspace.path}/rollback_game');

      await expectLater(
        () => repo.createProject(
          projectName: 'rollback_game',
          projectLocation: tempWorkspace.path,
        ),
        throwsA(isA<ProjectCreationException>()),
      );

      // Verify directory was rolled back and deleted
      expect(targetDir.existsSync(), isFalse);

      final recents = await repo.getRecentProjects();
      expect(recents, isEmpty);
    });

    testWidgets('CreateProjectDialog validation and progress UI test', (tester) async {
      final completer = Completer<void>();
      Future<ProcessResult> fakeRunner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        // Only `flutter create <target>` scaffolds a project; `flutter pub get`
        // must not treat its trailing "get" argument as a directory.
        if (args.isNotEmpty && args.first == 'create') {
          final target = args.last;
          final dir = Directory(target);
          if (!dir.existsSync()) dir.createSync(recursive: true);
          File('$target/pubspec.yaml').writeAsStringSync('name: test\nflutter:\n');
        }
        if (!completer.isCompleted) {
          await completer.future;
        }
        return ProcessResult(1234, 0, 'OK', '');
      }

      final repo = ProjectRepository(configDir: tempConfigDir, processRunner: fakeRunner);
      // This test is about the dialog; writing the editor host is
      // real async IO, which never completes in a widget test's fake-async
      // zone (create_project_editor_host_test.dart covers it with real IO).
      EditorPreferences.load(configDir: tempConfigDir).setPerProjectEditors(false);
      final launcherVM = LauncherViewModel(configDir: tempConfigDir, projectRepo: repo);
      final vm = CreateProjectViewModel(launcherVM: launcherVM, projectRepo: repo);
      vm.updateLocation(tempWorkspace.path);

      bool successCalled = false;

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: CreateProjectDialog(
              viewModel: vm,
              onSuccess: () => successCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create New Project'), findsOneWidget);
      expect(find.text('Create Project'), findsOneWidget);

      // Enter invalid project name with uppercase
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'InvalidNameWithCaps');
      await tester.pumpAndSettle();

      expect(find.text('Project name must be lowercase with underscores (e.g. my_game)'), findsOneWidget);

      // Enter valid project name
      await tester.enterText(nameField, 'valid_test_app');
      await tester.pumpAndSettle();

      expect(find.text('Project name must be lowercase with underscores (e.g. my_game)'), findsNothing);

      // Tap Create Project
      await tester.tap(find.text('Create Project'));
      await tester.pump();

      expect(find.byType(Progress), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(successCalled, isTrue);
    });
  });
}
