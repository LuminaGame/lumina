import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A project created before centimetres / Z-up is flagged, not
/// migrated.
void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('lumina_legacy_units_'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> pumpMenu(WidgetTester tester, LuminaProject project) async {
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Column(children: [
          MenuBarWidget(viewModel: vm, engineVersion: '0.0.1', activeLevelName: 'L_Main', onSave: () {}),
        ]),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a legacy metre manifest shows the banner; a new project does not', (tester) async {
    const fresh = LuminaProject(projectName: 'cm_game');
    final legacyMap = fresh.toMap()
      ..remove('world_units')
      ..remove('up_axis');
    final legacy = LuminaProject.fromMap(legacyMap);
    expect(legacy.isLegacyMetreProject, isTrue);

    await pumpMenu(tester, legacy);
    expect(find.byKey(const ValueKey('legacy_units_banner')), findsOneWidget);
    expect(find.textContaining('created with metre units'), findsOneWidget);

    await pumpMenu(tester, fresh);
    expect(find.byKey(const ValueKey('legacy_units_banner')), findsNothing);
  });
}
