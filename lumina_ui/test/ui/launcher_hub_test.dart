import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  Future<LuminaProject> createMockProject(ProjectRepository repo, {required String projectName, required String projectLocation}) async {
    final dir = Directory('$projectLocation/$projectName');
    dir.createSync(recursive: true);
  Directory("${dir.path}/contents/levels").createSync(recursive: true);
    final p = LuminaProject(
      projectName: projectName,
      activeLevel: 'contents/levels/L_DefaultLevel.lmas',
    );
    final file = File('${dir.path}/$projectName.lmproject');
    file.writeAsStringSync(jsonEncode(p.toMap()));
    await repo.addRecentProject(p, projectDir: dir.path);
    return p;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempConfigDir;
  late Directory tempProjectsDir;

  setUp(() {
    tempConfigDir = Directory.systemTemp.createTempSync('lumina_config_test_');
    tempProjectsDir = Directory.systemTemp.createTempSync('lumina_projects_test_');
  });

  tearDown(() {
    if (tempConfigDir.existsSync()) {
      tempConfigDir.deleteSync(recursive: true);
    }
    if (tempProjectsDir.existsSync()) {
      tempProjectsDir.deleteSync(recursive: true);
    }
  });

  group('Launcher Hub ViewModel & Repository Tests', () {
    test('Round-trips recent projects through entry shape with project_dir, last_opened, and cover', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);

      // Create two real temp projects on disk
      await createMockProject(repo, 
        projectName: 'ProjectAlpha',
        projectLocation: tempProjectsDir.path,
      );
      await createMockProject(repo, 
        projectName: 'ProjectBeta',
        projectLocation: tempProjectsDir.path,
      );

      final recents = await repo.getRecentProjects();
      expect(recents.length, equals(2));
      expect(recents[0].project.projectName, equals('ProjectBeta'));
      expect(recents[0].projectDir, contains('ProjectBeta'));
      expect(recents[0].isMissing, isFalse);
      expect(recents[1].project.projectName, equals('ProjectAlpha'));
      expect(recents[1].projectDir, contains('ProjectAlpha'));
      expect(recents[1].isMissing, isFalse);

      // Verify recent_projects.json file contents directly
      final jsonFile = File('${tempConfigDir.path}/recent_projects.json');
      expect(jsonFile.existsSync(), isTrue);
      final rawList = jsonDecode(jsonFile.readAsStringSync()) as List;
      expect(rawList.length, equals(2));
      expect(rawList[0]['project_dir'], equals(recents[0].projectDir));
      expect(rawList[0]['last_opened'], isNotNull);
    });

    test('Missing project detection and locateProject repair action', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      // Create a project
      await createMockProject(repo, 
        projectName: 'MoveableProject',
        projectLocation: tempProjectsDir.path,
      );
      await vm.loadRecentProjects();
      expect(vm.recentProjects.length, equals(1));
      expect(vm.recentProjects[0].isMissing, isFalse);

      // Simulate moving/deleting directory from original location
      final originalDir = Directory('${tempProjectsDir.path}/MoveableProject');
      final newParentDir = Directory.systemTemp.createTempSync('lumina_relocated_');
      final targetMovedDir = Directory('${newParentDir.path}/MoveableProject');
      originalDir.renameSync(targetMovedDir.path);

      // Reload recents. Unreachable projects are out of the default list now —
      // they are still recorded, and showMissingProjects brings them back with
      // the Missing badge and the Locate… repair action.
      await vm.loadRecentProjects();
      expect(vm.recentProjects, isEmpty);
      expect(vm.missingProjectCount, equals(1));
      vm.setShowMissingProjects(true);
      expect(vm.recentProjects[0].isMissing, isTrue);

      // Repair via locateProject
      final newLmproject = '${targetMovedDir.path}/MoveableProject.lmproject';
      final repaired = await vm.locateProject(vm.recentProjects[0], newLmproject);
      expect(repaired, isNotNull);
      expect(vm.recentProjects[0].isMissing, isFalse);
      expect(vm.recentProjects[0].projectDir, equals(targetMovedDir.path));

      if (newParentDir.existsSync()) {
        newParentDir.deleteSync(recursive: true);
      }
    });

    test('Remove from Hub removes entry from recents while leaving directory on disk', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      await createMockProject(repo, 
        projectName: 'KeepDiskProject',
        projectLocation: tempProjectsDir.path,
      );
      await vm.loadRecentProjects();
      expect(vm.recentProjects.length, equals(1));

      final entry = vm.recentProjects[0];
      final diskDir = Directory(entry.projectDir);
      expect(diskDir.existsSync(), isTrue);

      // Remove from hub
      await vm.removeFromHub(entry);
      expect(vm.recentProjects.isEmpty, isTrue);

      // Directory must remain on disk untouched
      expect(diskDir.existsSync(), isTrue);
      expect(File('${diskDir.path}/KeepDiskProject.lmproject').existsSync(), isTrue);
    });

    test('Delete from Disk deletes project directory and removes recents entry', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      await createMockProject(repo, 
        projectName: 'DoomedProject',
        projectLocation: tempProjectsDir.path,
      );
      await vm.loadRecentProjects();
      expect(vm.recentProjects.length, equals(1));

      final entry = vm.recentProjects[0];
      final diskDir = Directory(entry.projectDir);
      expect(diskDir.existsSync(), isTrue);

      // Delete from disk
      await vm.deleteFromDisk(entry);
      expect(vm.recentProjects.isEmpty, isTrue);
      expect(diskDir.existsSync(), isFalse);
    });

    test('renameProject renames folder, manifest, project_name field and updates recents', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      await createMockProject(repo, 
        projectName: 'OldNameProject',
        projectLocation: tempProjectsDir.path,
      );
      await vm.loadRecentProjects();
      final entry = vm.recentProjects[0];

      // Rename project
      await vm.renameProject(entry, 'NewNameProject');

      expect(vm.recentProjects.length, equals(1));
      expect(vm.recentProjects[0].project.projectName, equals('NewNameProject'));
      expect(vm.recentProjects[0].projectDir, contains('NewNameProject'));

      // Check on disk
      final newDir = Directory(vm.recentProjects[0].projectDir);
      expect(newDir.existsSync(), isTrue);
      expect(File('${newDir.path}/NewNameProject.lmproject').existsSync(), isTrue);
      expect(File('${newDir.path}/OldNameProject.lmproject').existsSync(), isFalse);

      final manifestContent = File('${newDir.path}/NewNameProject.lmproject').readAsStringSync();
      expect(manifestContent, contains('"project_name":"NewNameProject"'));
    });

    test('duplicateProject creates sibling directory copy with renamed manifest and new recents entry', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      await createMockProject(repo, 
        projectName: 'OriginalGame',
        projectLocation: tempProjectsDir.path,
      );
      await vm.loadRecentProjects();
      final entry = vm.recentProjects[0];

      // Write a dummy custom asset file to verify deep copy
      final customAsset = File('${entry.projectDir}/contents/levels/L_Custom.lmas');
      customAsset.writeAsStringSync('{"assetId":"custom_asset"}');

      // Duplicate project
      await vm.duplicateProject(entry);

      expect(vm.recentProjects.length, equals(2));
      final duplicated = vm.recentProjects.firstWhere((p) => p.project.projectName.contains('OriginalGame_Copy'));
      expect(Directory(duplicated.projectDir).existsSync(), isTrue);
      expect(File('${duplicated.projectDir}/${duplicated.project.projectName}.lmproject').existsSync(), isTrue);
      expect(File('${duplicated.projectDir}/contents/levels/L_Custom.lmas').readAsStringSync(), equals('{"assetId":"custom_asset"}'));
    });

    test('Deduplication keeps same-name projects in different folders and re-opening moves to index 0', () async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      final subFolderA = Directory('${tempProjectsDir.path}/FolderA')..createSync();
      final subFolderB = Directory('${tempProjectsDir.path}/FolderB')..createSync();

      final pA = await createMockProject(repo, projectName: 'MyGame', projectLocation: subFolderA.path);
      await createMockProject(repo, projectName: 'MyGame', projectLocation: subFolderB.path);

      var recents = await repo.getRecentProjects();
      expect(recents.length, equals(2));
      expect(recents[0].projectDir, equals('${subFolderB.path}/MyGame'));
      expect(recents[1].projectDir, equals('${subFolderA.path}/MyGame'));

      // Re-add/open project A -> moves to index 0
      await repo.addRecentProject(pA, projectDir: '${subFolderA.path}/MyGame');
      recents = await repo.getRecentProjects();
      expect(recents.length, equals(2));
      expect(recents[0].projectDir, equals('${subFolderA.path}/MyGame'));
      expect(recents[1].projectDir, equals('${subFolderB.path}/MyGame'));
    });

    test('Theme switch persists to launcher_settings.json and fresh ViewModel loads persisted theme', () async {
      final vm1 = LauncherViewModel(configDir: tempConfigDir);
      await vm1.loadSettings();
      expect(vm1.themeMode, equals(ThemeMode.dark));

      // Toggle theme to light
      await vm1.setThemeMode(ThemeMode.light);
      expect(vm1.themeMode, equals(ThemeMode.light));

      final settingsFile = File('${tempConfigDir.path}/launcher_settings.json');
      expect(settingsFile.existsSync(), isTrue);
      final settingsJson = jsonDecode(settingsFile.readAsStringSync());
      expect(settingsJson['theme_mode'], equals('light'));

      // Boot fresh ViewModel from same config directory
      final vm2 = LauncherViewModel(configDir: tempConfigDir);
      await vm2.loadSettings();
      expect(vm2.themeMode, equals(ThemeMode.light));
    });
  });

  group('Launcher View Widget Tests', () {
    testWidgets('Renders empty state when no recent projects exist', (tester) async {
      final vm = LauncherViewModel(configDir: tempConfigDir);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.text('Create New Project'), findsWidgets);
    });

    testWidgets('Renders project grid cards with name, path, and version badge', (tester) async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      await createMockProject(repo, 
        projectName: 'HeroQuest',
        projectLocation: tempProjectsDir.path,
      );

      // Put cover PNG in HeroQuest (`.lumina/cover.png`)
      final coverDir = Directory('${tempProjectsDir.path}/HeroQuest/.lumina')..createSync(recursive: true);
      final coverFile = File('${coverDir.path}/cover.png');
      final pngBytes = SmokeArtifacts.encodeRgbaToPng(
        Uint8List.fromList(List.filled(16 * 16 * 4, 180)),
        16,
        16,
      );
      coverFile.writeAsBytesSync(pngBytes);

      final vm = LauncherViewModel(configDir: tempConfigDir);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HeroQuest'), findsOneWidget);
      expect(find.text('${tempProjectsDir.path}/HeroQuest'), findsOneWidget);
      expect(find.text('0.0.1'), findsWidgets);
      expect(find.text('Open'), findsOneWidget);
      expect(ProjectRepository.coverImageFile('${tempProjectsDir.path}/HeroQuest')?.path, coverFile.path);
    });

    testWidgets('Shows Missing badge for deleted project', (tester) async {
      final repo = ProjectRepository(configDir: tempConfigDir);
      await createMockProject(repo, 
        projectName: 'VanishedGame',
        projectLocation: tempProjectsDir.path,
      );

      // Delete folder from disk
      Directory('${tempProjectsDir.path}/VanishedGame').deleteSync(recursive: true);

      final vm = LauncherViewModel(configDir: tempConfigDir);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      // A fresh launch does not offer a project whose path is gone...
      expect(find.text('VanishedGame'), findsNothing);
      expect(find.textContaining('hidden — path not found'), findsOneWidget);

      // ...but the count reveals it, badge and repair action intact.
      await tester.tap(find.textContaining('hidden — path not found'));
      await tester.pumpAndSettle();

      expect(find.text('VanishedGame'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);
      expect(find.text('Locate...'), findsOneWidget);
    });
  });
}
