import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Project Settings ▸ Engine & Graphics ▸ Presentation: Flutter (default) or
/// Direct, saved in a real temporary `.lmproject` and read back.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_presentation_settings_');
    projDir = Directory('${tempDir.path}/DirectGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'DirectGame', activeLevel: 'contents/levels/L_Main.lmas');
    manifest = File('${projDir.path}/DirectGame.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a manifest without the key is Flutter; Direct is saved and read back with the other settings kept', () async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await vm.load();
    expect(vm.project.settings.presentation, 'flutter');
    vm.setStartFullscreen(true);
    vm.setPresentation('direct');
    vm.setPresentation('metal'); // not a mode: ignored
    expect(await vm.apply(), isTrue);
    final saved = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    expect((saved['settings'] as Map<String, dynamic>)['presentation'], 'direct');
    final reopened = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await reopened.load();
    expect(reopened.project.settings.presentation, 'direct');
    expect(reopened.project.settings.startFullscreen, isTrue);
    // Another graphics setting keeps the presentation.
    reopened.setTargetFps(120);
    expect(reopened.project.settings.presentation, 'direct');
  });

  testWidgets('the Graphics section shows Presentation and the choice reaches the view model', (tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ProjectSettingsSubEditor(assetName: 'DirectGame.lmproject', projectDirPath: projDir.path, viewModel: vm),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await tester.pumpAndSettle();
    final label = find.text('Presentation');
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
    expect(find.text('Flutter (default)'), findsOneWidget);
    expect(find.textContaining('editor viewport always uses Flutter'), findsOneWidget);

    await tester.tap(find.text('Flutter (default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direct').last);
    await tester.pumpAndSettle();
    expect(vm.project.settings.presentation, 'direct');
    expect(find.textContaining('Filament presents into the game window'), findsOneWidget);
  });
}
