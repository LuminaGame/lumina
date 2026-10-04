import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  late Directory projDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_preset_specs_test_');
    projDir = Directory('${tempDir.path}/SpecGame')..createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'SpecGame',
      activeLevel: 'contents/levels/L_Main.lmas',
      settings: EngineScalabilitySettings(qualityPreset: 'epic'),
    );
    final manifest = File('${projDir.path}/SpecGame.lmproject');
    manifest.writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('Project Settings Engine category renders technical preset specifications table', (tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await vm.load();

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ProjectSettingsSubEditor(
            assetName: 'SpecGame.lmproject',
            projectDirPath: projDir.path,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Engine & Graphics category
    await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await tester.pumpAndSettle();

    // Verify technical specs card exists
    expect(find.byKey(const ValueKey('project_settings_preset_specs_card')), findsOneWidget);
    expect(find.textContaining('Preset Technical Specifications'), findsOneWidget);

    // Verify all 5 preset tiers are listed
    expect(find.text('Low'), findsWidgets);
    expect(find.text('Medium'), findsWidgets);
    expect(find.text('High'), findsWidgets);
    expect(find.text('Epic'), findsWidgets);
    expect(find.text('Cinematic'), findsWidgets);

    // Verify specific technical parameters are presented
    expect(find.textContaining('4,000 m (400k cm)'), findsOneWidget);
    expect(find.textContaining('2,000 m (200k cm)'), findsOneWidget);
    expect(find.textContaining('1,000 m (100k cm)'), findsOneWidget);
    expect(find.textContaining('500 m (50k cm)'), findsOneWidget);
    expect(find.textContaining('250 m (25k cm)'), findsOneWidget);

    // Verify shadow & AA details
    expect(find.textContaining('4096px PCSS'), findsWidgets);
    expect(find.textContaining('4x MSAA + TAA'), findsWidgets);
    expect(find.textContaining('16x aniso'), findsOneWidget);
  });
}
