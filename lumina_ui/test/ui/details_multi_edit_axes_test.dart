import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor is a Linux desktop app: its text fields select with a pan
/// recognizer there, which a scrub beats (widget tests default to Android,
/// whose horizontal text-drag recognizer wins the arena instead).
final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// With several actors selected, editing or scrubbing one axis wrote
/// the first actor's values into the other axes of every actor, collapsing the
/// mixed ones. Now only the edited axis changes, on every actor, and a
/// scrub moves each actor from its own value.
void main() {
  late Directory project;
  late EditorViewModel vm;
  late List<EditorActorNode> barrels;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_details_multi_axes_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'MultiAxes', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: project.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    barrels = [
      for (final (i, x) in [-150.0, 0.0, 150.0].indexed)
        EditorActorNode(
          id: 'barrel_$i',
          name: 'Barrel_$i',
          type: 'LuminaStaticMesh',
          location: [x, 0, 0],
          rotation: [0, 0, 10.0 * i],
          components: [
            EditorComponentNode(
              id: 'mesh_$i',
              type: 'LuminaMeshComponent',
              name: 'Mesh',
              properties: {'relativeLocation': [30.0 * i, 0.0, 0.0]},
            ),
          ],
        ),
    ];
    for (final b in barrels) {
      vm.addActorNodeForTest(b);
    }
    vm.selectActors(barrels.map((b) => b.id).toList());
  });

  tearDown(() {
    vm.dispose();
    project.deleteSync(recursive: true);
  });

  Future<void> pumpDetails(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: vm))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('3 Actors Selected'), findsOneWidget);
  }

  /// The [axis] field of the multi-edit row labelled [label].
  Finder axisOf(String label, int axis) {
    // The nearest row around the label that holds a vector editor.
    final rows = find.ancestor(of: find.text(label), matching: find.byType(Row)).evaluate();
    final row = rows.firstWhere(
      (e) => find.descendant(of: find.byElementPredicate((x) => x == e), matching: find.byType(VectorRow)).evaluate().isNotEmpty,
    );
    final vector = find.descendant(of: find.byElementPredicate((x) => x == row), matching: find.byType(VectorRow));
    return find.descendant(of: vector, matching: find.byType(ScrubNumericField)).at(axis);
  }

  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(find.descendant(of: field, matching: find.byType(EditableText)), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  Future<void> scrub(WidgetTester tester, Finder field, {int steps = 20}) async {
    final g = await tester.startGesture(tester.getCenter(field) + const Offset(10, 0), kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 3; i++) {
      await g.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < steps; i++) {
      await g.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<List<double>> locations() => barrels.map((b) => List<double>.from(b.location)).toList();

  testWidgets('typing Location Y writes Y on every actor and keeps each X', (tester) async {
    await pumpDetails(tester);
    await type(tester, axisOf('Location', 1), '40');
    expect(locations(), [
      [-150, 40, 0],
      [0, 40, 0],
      [150, 40, 0],
    ]);
    vm.transactions.undo();
    expect(locations(), [
      [-150, 0, 0],
      [0, 0, 0],
      [150, 0, 0],
    ], reason: 'one Undo restores every actor');
  }, variant: _linux);

  testWidgets('typing into the mixed X sets X on all and leaves Y/Z alone', (tester) async {
    barrels[1].location = [0, 25, 0];
    await pumpDetails(tester);
    await type(tester, axisOf('Location', 0), '75');
    expect(locations(), [
      [75, 0, 0],
      [75, 25, 0],
      [75, 0, 0],
    ]);
  }, variant: _linux);

  testWidgets('scrubbing Location Z lifts every actor and keeps each X', (tester) async {
    await pumpDetails(tester);
    await scrub(tester, axisOf('Location', 2));
    final z = barrels.first.location[2];
    expect(z, greaterThan(10));
    expect(locations(), [
      [-150, 0, z],
      [0, 0, z],
      [150, 0, z],
    ]);
    vm.transactions.undo();
    expect(locations().map((l) => l[2]), everyElement(0), reason: 'the scrub is one undo step');
  }, variant: _linux);

  testWidgets('scrubbing the mixed X moves each actor from its own X', (tester) async {
    await pumpDetails(tester);
    await scrub(tester, axisOf('Location', 0));
    final dx = barrels.first.location[0] + 150;
    expect(dx, greaterThan(10));
    expect(locations(), [
      [-150 + dx, 0, 0],
      [0 + dx, 0, 0],
      [150 + dx, 0, 0],
    ]);
  }, variant: _linux);

  testWidgets('typing Rotation X keeps each actor\'s own (mixed) yaw', (tester) async {
    await pumpDetails(tester);
    await type(tester, axisOf('Rotation', 0), '15');
    expect(barrels.map((b) => b.rotation).toList(), [
      [15, 0, 0],
      [15, 0, 10],
      [15, 0, 20],
    ]);
  }, variant: _linux);

  testWidgets('a component vector: typing Relative Location Y keeps each X', (tester) async {
    await pumpDetails(tester);
    await type(tester, axisOf('Relative Location', 1), '5');
    expect(barrels.map((b) => b.components.single.properties['relativeLocation']).toList(), [
      [0, 5, 0],
      [30, 5, 0],
      [60, 5, 0],
    ]);
  }, variant: _linux);
}
