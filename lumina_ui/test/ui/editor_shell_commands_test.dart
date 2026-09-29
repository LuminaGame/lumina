import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_command.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'dart:io';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('EditorCommandRegistry completeness', () {
    test('every menu item id is registered', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      final registry = vm.commands;

      final expectedIds = {
        'file.newLevel', 'file.openLevel', 'file.saveLevel', 'file.saveAll', 'file.newAsset', 'file.exitStudio',
        'edit.undo', 'edit.redo', 'edit.duplicate', 'edit.delete', 'edit.projectSettings',
        'view.resetCamera', 'view.viewportMode.lit', 'view.viewportMode.unlit', 'view.viewportMode.wireframe', 'view.viewportMode.buffer',
        'view.cameraMode.perspective', 'view.cameraMode.top', 'view.cameraMode.front', 'view.cameraMode.right',
        'build.generateDartCode', 'build.buildManager',
        'debug.togglePie', 'debug.pausePie', 'debug.stopPie',
        'tools.materialEditor', 'tools.blueprintEditor', 'tools.meshInspector', 'tools.landscapeEditor', 'tools.environmentLighting', 'tools.sequencer', 'tools.umgDesigner', 'tools.navmeshGenerator',
        'window.toggleOutliner', 'window.toggleDetails', 'window.toggleBottomPanel', 'window.showOutputLog', 'window.resetLayout',
        'help.about',
      };

      for (final id in expectedIds) {
        final cmd = registry.byId(id);
        expect(cmd, isNotNull, reason: 'Command \$id is missing');
        expect(cmd!.label.isNotEmpty, isTrue);
      }
    });

    test('file.saveLevel saves level and clears is_dirty', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_test_');
      final project = LuminaProject(projectName: 'TestProj', activeLevel: 'contents/levels/L_Main.lmas');
      
      final projDir = Directory('${tempDir.path}/TestProj');
      projDir.createSync();
      Directory('${projDir.path}/contents/levels').createSync(recursive: true);
      
      final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);

      // A fresh in-memory session has no actors until a level is loaded from
      // disk; spawn one so there is something to save.
      vm.spawnNewActor('Mesh');
      vm.selectActor(vm.actors.first);
      vm.updateActorMobility('Static');
      expect(vm.project.isDirty, isTrue);
      
      vm.commands.execute('file.saveLevel'); await Future.delayed(const Duration(milliseconds: 50));
      
      final lmasFile = File('${projDir.path}/contents/levels/L_Main.lmas');
      expect(lmasFile.existsSync(), isTrue);
      expect(vm.project.isDirty, isFalse);
    });

    test('file.newAsset creates real .lmas on disk without adding actors', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_test_newAsset');
      final project = LuminaProject(projectName: 'TestProj', activeLevel: 'contents/levels/L_Main.lmas');
      final projDir = Directory('${tempDir.path}/TestProj');
      projDir.createSync();
      Directory('${projDir.path}/contents/meshes').createSync(recursive: true);
      
      final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);
      final initialActors = vm.actors.length;
      final initialAssets = vm.realAssets.length;
      
      // Simulate _promptNewAsset
      await vm.createNewAsset(type: AssetType.filamesh, subFolder: 'meshes');
      
      expect(vm.actors.length, equals(initialActors));
      expect(vm.realAssets.length, greaterThan(initialAssets));
    });

    test('file.openLevel switching loads that levels actors', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_test_openLevel');
      final project = LuminaProject(projectName: 'TestProj', activeLevel: 'contents/levels/L_Main.lmas');
      final projDir = Directory('${tempDir.path}/TestProj');
      projDir.createSync();
      Directory('${projDir.path}/contents/levels').createSync(recursive: true);
      
      File('${projDir.path}/contents/levels/L_Other.lmas').writeAsStringSync('{"metadata":{"actors":[{"id":"test1","name":"TestActor","type":"Mesh","location":[0,0,0],"rotation":[0,0,0],"scale":[1,1,1]}]}}');
      
      final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);
      
      vm.switchLevel('contents/levels/L_Other.lmas');
      expect(vm.activeLevelName, equals('L_Other'));
      expect(vm.actors.length, equals(1));
      expect(vm.actors.first.name, equals('TestActor'));
    });

    test('debug.stepPie is only available while a paused simulation runs', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      expect(vm.commands.byId('debug.stepPie'), isNotNull);
      expect(vm.commands.byId('debug.stepPie')!.canExecute(), isFalse);
      vm.startSimulation();
      expect(vm.commands.byId('debug.stepPie')!.canExecute(), isFalse, reason: 'running, not paused');
      vm.togglePauseSimulation();
      expect(vm.isPaused, isTrue);
      expect(vm.commands.byId('debug.stepPie')!.canExecute(), isTrue);
      vm.commands.execute('debug.stepPie'); // no mounted runtime: must be a safe no-op
      vm.togglePauseSimulation();
      expect(vm.isPaused, isFalse);
      vm.stopSimulation();
      expect(vm.commands.byId('debug.stepPie')!.canExecute(), isFalse);
    });

    test('edit.undo / edit.redo drive the transaction manager', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      expect(vm.commands.byId('edit.undo')!.canExecute(), isFalse);
      expect(vm.commands.byId('edit.redo')!.canExecute(), isFalse);

      vm.spawnNewActor('PointLight');
      expect(vm.actors.length, 1);
      expect(vm.commands.byId('edit.undo')!.canExecute(), isTrue);

      vm.commands.execute('edit.undo');
      expect(vm.actors, isEmpty);
      expect(vm.commands.byId('edit.redo')!.canExecute(), isTrue);

      vm.commands.execute('edit.redo');
      expect(vm.actors.length, 1);

      vm.transactions.isFrozen = true;
      expect(vm.commands.byId('edit.undo')!.canExecute(), isFalse, reason: 'frozen during PIE');
    });

    test('edit.duplicate and edit.delete behavior', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      
      expect(vm.commands.byId('edit.delete')!.canExecute(), isFalse);
      
      vm.spawnNewActor('PointLight');
      final initialActorsCount = vm.actors.length;
      vm.selectActor(vm.actors.first);
      
      expect(vm.commands.byId('edit.duplicate')!.canExecute(), isTrue);
      vm.commands.execute('edit.duplicate');
      
      expect(vm.actors.length, equals(initialActorsCount + 1));
      expect(vm.actors.last.name, endsWith('_Copy'));
      
      expect(vm.commands.byId('edit.delete')!.canExecute(), isTrue);
      vm.commands.execute('edit.delete');
      
      expect(vm.actors.length, equals(initialActorsCount));
    });

    test('debug.pausePie/stopPie canExecute flips', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      
      expect(vm.commands.byId('debug.pausePie')!.canExecute(), isFalse);
      expect(vm.commands.byId('debug.stopPie')!.canExecute(), isFalse);
      
      vm.commands.execute('debug.togglePie');
      expect(vm.isPlaying, isTrue);
      expect(vm.commands.byId('debug.pausePie')!.canExecute(), isTrue);
      expect(vm.commands.byId('debug.stopPie')!.canExecute(), isTrue);
      
      vm.commands.execute('debug.pausePie');
      expect(vm.isPaused, isTrue);
      expect(vm.commands.byId('debug.pausePie')!.canExecute(), isFalse);
    });

    testWidgets('Menubar widget test', (tester) async {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MenuBarWidget(
            engineVersion: '1.0.0',
            activeLevelName: 'Test',
            onSave: () {},
            viewModel: vm,
          ),
        ),
      ));
      
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Ctrl+Z'), findsOneWidget);
    });
    
    test('Every executed command emits an EngineLogEntry', () {
      final vm = EditorViewModel(enableTimers: false, autoInitAssets: false);
      vm.clearLogs();
      vm.commands.execute('view.resetCamera');
      expect(vm.logs.any((log) => log.source == 'EditorCommandRegistry' && log.message.contains('view.resetCamera')), isTrue);
    });
  });
}
