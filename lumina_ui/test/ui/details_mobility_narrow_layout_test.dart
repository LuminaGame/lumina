import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// In the default-width Details panel the Mobility buttons wrapped
/// their labels a few letters per line. A real temp project and actor.
void main() {
  late Directory root;
  late EditorViewModel vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_mobility_');
    final pDir = Directory('${root.path}/MobGame')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'MobGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/MobGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });
  // A widget test cannot await vm.close() (see deleteTempProject).
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  for (final width in [210.0, 360.0]) {
    testWidgets('at $width px each Mobility label is one line high', (tester) async {
      vm.spawnNewActor('Primitive');
      vm.selectActorById(vm.actors.last.id);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 900, child: DetailsWidget(viewModel: vm)))),
      ));
      await tester.pumpAndSettle();
      for (final label in ['Static', 'Stationary', 'Movable']) {
        final text = find.text(label);
        expect(text, findsOneWidget, reason: label);
        // 8 px text: one line is under 12 px on screen; two lines are not.
        final box = tester.getRect(text);
        expect(box.height, lessThan(12), reason: '$label is ${box.height} px tall');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
