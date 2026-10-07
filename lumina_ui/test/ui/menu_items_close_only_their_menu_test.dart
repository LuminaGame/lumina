import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A shadcn menu (`showDropdown`, `ContextMenu`, `Menubar`) is an
/// overlay entry, not a route, and its `MenuButton` closes it on its own. An
/// item that also calls `Navigator.pop` pops the page under the menu: picking
/// "1 m" in the toolbar's grid menu closed the editor and left a black window.
void main() {
  Future<EditorViewModel> pumpToolbarPage(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_menu_pop_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'MenuPopGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    // The launcher opens the editor with pushReplacement, so the editor page
    // is the only route: popping it leaves nothing on screen.
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ToolbarWidget(viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> pick(WidgetTester tester, Finder opener, String item) async {
    await tester.tap(opener);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('picking a grid step closes the menu and keeps the editor page', (tester) async {
    final vm = await pumpToolbarPage(tester);
    final grid = find.byKey(const Key('toggle_grid_snap'));
    await pick(tester, find.descendant(of: grid, matching: find.byIcon(LucideIcons.chevronDown)), '1 m');

    expect(vm.editorGridStep, 100.0);
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'the grid menu popped the editor page');
    expect(find.text('5 m'), findsNothing, reason: 'the grid menu stays open');
  });

  testWidgets('picking a snap step closes the menu and keeps the editor page', (tester) async {
    final vm = await pumpToolbarPage(tester);
    await pick(tester, find.text('10 cm').first, '50 cm');

    expect(vm.translateSnapStep, 50.0);
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'the snap menu popped the editor page');
  });

  testWidgets('the view mode, buffer visualization and camera menus keep the editor page', (tester) async {
    final vm = await pumpToolbarPage(tester);

    await pick(tester, find.text('Lit'), 'Unlit');
    expect(vm.viewMode, 'Unlit');
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'the view mode menu popped the editor page');

    await tester.tap(find.text('Unlit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buffer Visualization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roughness').last);
    await tester.pumpAndSettle();
    expect(vm.viewMode, 'Buffer');
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'the buffer visualization submenu popped the editor page');

    await pick(tester, find.text('Perspective'), 'Top');
    expect(vm.cameraMode, 'Top');
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'the camera menu popped the editor page');
  });

  testWidgets('a launcher project context menu item keeps the launcher page', (tester) async {
    final configDir = Directory.systemTemp.createTempSync('lumina_menu_pop_config_');
    final projectsDir = Directory.systemTemp.createTempSync('lumina_menu_pop_projects_');
    addTearDown(() {
      configDir.deleteSync(recursive: true);
      projectsDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = ProjectRepository(configDir: configDir);
    final dir = Directory('${projectsDir.path}/HubGame')..createSync(recursive: true);
    Directory('${dir.path}/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'HubGame', activeLevel: 'contents/levels/L_DefaultLevel.lmas');
    File('${dir.path}/HubGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    await repo.addRecentProject(project, projectDir: dir.path);

    final vm = LauncherViewModel(configDir: configDir);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.text('HubGame'), findsOneWidget);

    await tester.tap(find.text('HubGame'), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from Hub').last);
    await tester.pumpAndSettle();

    expect(find.byType(LauncherView), findsOneWidget, reason: 'the context menu popped the launcher page');
    expect(find.text('HubGame'), findsNothing);
    expect(Directory(dir.path).existsSync(), isTrue, reason: 'Remove from Hub leaves the folder on disk');
  });

  testWidgets('removing a missing project from the hub keeps the launcher page', (tester) async {
    final configDir = Directory.systemTemp.createTempSync('lumina_menu_pop_config_');
    final projectsDir = Directory.systemTemp.createTempSync('lumina_menu_pop_projects_');
    addTearDown(() {
      configDir.deleteSync(recursive: true);
      projectsDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = ProjectRepository(configDir: configDir);
    final dir = Directory('${projectsDir.path}/GoneGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'GoneGame', activeLevel: 'contents/levels/L_DefaultLevel.lmas');
    File('${dir.path}/GoneGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    await repo.addRecentProject(project, projectDir: dir.path);
    dir.deleteSync(recursive: true);

    final vm = LauncherViewModel(configDir: configDir);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: vm)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('hidden — path not found'));
    await tester.pumpAndSettle();
    expect(find.text('GoneGame'), findsOneWidget);

    await tester.tap(find.text('GoneGame'), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from Hub').last);
    await tester.pumpAndSettle();

    expect(find.byType(LauncherView), findsOneWidget, reason: 'the context menu popped the launcher page');
    expect(find.text('GoneGame'), findsNothing);
    expect(find.text('Templates'), findsWidgets, reason: 'the launcher tabs are still on screen');
  });

  test('no menu item in lib/ pops the navigator: MenuButton closes its own menu', () {
    final offenders = <String>[];
    final menuItem = RegExp(r'\bMenuButton\(');
    final pop = RegExp(r'Navigator\s*\.\s*(of\s*\([^)]*\)\s*\.\s*)?(pop|maybePop)\b');
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in menuItem.allMatches(source)) {
        // The MenuButton(...) argument list, by bracket matching.
        var depth = 1;
        var i = match.end;
        while (i < source.length && depth > 0) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        final body = source.substring(match.start, i);
        for (final p in pop.allMatches(body)) {
          final line = '\n'.allMatches(source.substring(0, match.start + p.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(offenders.toSet().toList()..sort(), isEmpty,
        reason: 'a MenuButton inside showDropdown/ContextMenu/Menubar closes its menu itself; '
            'Navigator.pop there pops the page under the menu');
  });
}
