import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_fonts.dart';
import '../helpers/temp_project.dart';

/// Small controls are drawn at the editor's standard sizes: the Details
/// panel's Mobility buttons as tall as the transform fields above them, the
/// Content Browser's type filter chips and Show All at the chip height, and
/// their labels at the label size rather than the 8 px micro size. A real
/// temp project on disk.
void main() {
  late Directory root;
  late EditorViewModel vm;

  // Real line heights: a field's height follows its font.
  setUpAll(loadEditorMonoFont);

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_sizes_');
    final pDir = Directory('${root.path}/SizeGame')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'SizeGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SizeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pump(WidgetTester tester, Widget child, {double width = 1600}) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 900, child: child))),
    ));
    await tester.pumpAndSettle();
  }

  double fontOf(WidgetTester tester, Finder text) => tester.widget<Text>(text).style!.fontSize!;

  for (final width in [210.0, 360.0]) {
    testWidgets('at $width px the Mobility buttons are as tall as the transform fields, with label-size text',
        (tester) async {
      vm.spawnNewActor('Primitive');
      vm.selectActorById(vm.actors.last.id);
      await pump(tester, DetailsWidget(viewModel: vm), width: width);
      final field = tester.getSize(find.byType(ScrubNumericField).first).height;
      expect(field, EditorDensity.inlineFieldHeight, reason: 'the constant tracks the rendered field');
      for (final label in ['Static', 'Stationary', 'Movable']) {
        final button = find.byKey(ValueKey('details_mobility_$label'));
        expect(button, findsOneWidget, reason: label);
        expect(tester.getSize(button).height, field, reason: '$label button vs a transform field');
        expect(fontOf(tester, find.text(label)), EditorTypography.labelSize, reason: label);
        // One line: the label fits (scaled down if the panel is narrow).
        expect(tester.getRect(find.text(label)).height, lessThan(field), reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Content Browser filter chips and Show All are chip height with label-size text', (tester) async {
    await pump(tester, ListenableBuilder(listenable: vm, builder: (_, _) => ContentBrowserWidget(viewModel: vm)));
    for (final key in ['content_browser_filter_all', 'content_browser_filter_level', 'content_browser_filter_filamesh', 'content_browser_show_all']) {
      final chip = find.byKey(ValueKey(key));
      expect(chip, findsOneWidget, reason: key);
      expect(tester.getSize(chip).height, EditorDensity.chipHeight, reason: key);
    }
    for (final label in ['All', 'Show All']) {
      expect(fontOf(tester, find.text(label)), EditorTypography.labelSize, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("the World Outliner's Add button is chip height with label-size text", (tester) async {
    await pump(tester, ListenableBuilder(listenable: vm, builder: (_, _) => OutlinerWidget(viewModel: vm)), width: 360);
    expect(tester.getSize(find.byKey(const ValueKey('outliner_add_actor'))).height, EditorDensity.chipHeight);
    expect(fontOf(tester, find.text('Add')), EditorTypography.labelSize);
    expect(tester.takeException(), isNull);
  });
}
