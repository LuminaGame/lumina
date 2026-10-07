import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A basic shape's Details show its shape and its size in cm, Z up like the
/// Transform (Size Z is the height); a committed size is one undo step and
/// redraws the shape. A real temp project and actor.
void main() {
  late Directory root;
  late EditorViewModel vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_shape_details_');
    final pDir = Directory('${root.path}/ShapeGame')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'ShapeGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/ShapeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  testWidgets('the Shape section edits the shape\'s height as Size Z, one undo step, and the viewport geometry follows',
      (tester) async {
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last;
    vm.selectActorById(actor.id);
    await tester.runAsync(() => vm.ensureActorMeshDataForTest(actor));
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, height: 1400, child: DetailsWidget(viewModel: vm)))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SHAPE'), findsOneWidget);
    expect(find.text('Size Z (height)'), findsOneWidget);
    expect(find.text('Size Y (depth)'), findsOneWidget);
    final sizeZ = tester.widget<ScrubNumericField>(find.byKey(const ValueKey('details_shape_sizeZ')));
    expect(sizeZ.value, 100.0);
    expect(sizeZ.unit, 'cm');

    sizeZ.onCommit(250.0);
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && (actor.meshData!.maxBounds[1] - actor.meshData!.minBounds[1] - 250.0).abs() > 1e-3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    final props = actor.components.firstWhere((c) => c.type == 'LuminaProceduralMeshComponent').properties;
    expect(props['sizeZ'], 250.0);
    expect(actor.meshData!.maxBounds[1] - actor.meshData!.minBounds[1], closeTo(250.0, 1e-3), reason: 'drawn 250 cm tall');
    expect(tester.widget<ScrubNumericField>(find.byKey(const ValueKey('details_shape_sizeZ'))).value, 250.0);

    vm.transactions.undo();
    expect(props['sizeZ'], 100.0, reason: 'one undo step');
    expect(tester.takeException(), isNull);
  });
}
