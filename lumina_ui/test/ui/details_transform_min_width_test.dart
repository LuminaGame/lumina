import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_fonts.dart';
import '../helpers/temp_project.dart';

/// The left column (World Outliner over Details) has a minimum width the
/// splitter cannot go under, and at that width every Details number field
/// keeps its axis letter, its value and its reset button apart: the reset
/// button used to be drawn over the next field's axis letter, and a long
/// value was cut to its first digits. A real temp project on disk.
void main() {
  late Directory root;
  late EditorViewModel vm;

  // Real glyph widths and line heights, not the test font's 1 em squares.
  setUpAll(loadEditorMonoFont);

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_min_left_');
    File('${root.path}/my_project.lmproject').writeAsStringSync('{}');
    vm = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder workspaceSplitter() => find.byElementPredicate((e) =>
      e.widget is HorizontalResizableDragger && e.findAncestorWidgetOfExactType<ContentBrowserWidget>() == null);

  test('a saved or set left column narrower than the minimum is widened to it', () {
    expect(EditorLayoutState.defaultOutlinerWidth, greaterThanOrEqualTo(EditorLayoutState.minOutlinerWidth));
    expect(EditorLayoutState.fromJson({'outlinerWidth': 150.0, 'bottomPinned': true}).outlinerWidth,
        EditorLayoutState.minOutlinerWidth);
    final s = EditorLayoutState()..outlinerWidth = 100;
    expect(s.outlinerWidth, EditorLayoutState.minOutlinerWidth);
  });

  testWidgets('the left column splitter stops at the minimum width', (tester) async {
    await pumpEditor(tester);
    await tester.dragFrom(tester.getCenter(workspaceSplitter()), const Offset(-250, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byType(OutlinerWidget)).width,
        moreOrLessEquals(EditorLayoutState.minOutlinerWidth, epsilon: 1));
    expect(vm.layoutState.outlinerWidth, greaterThanOrEqualTo(EditorLayoutState.minOutlinerWidth - 0.5));
  });

  testWidgets('at the minimum width the transform fields keep label, value and reset apart', (tester) async {
    vm.spawnNewActor('Primitive');
    vm.selectActorById(vm.actors.last.id);
    vm.updateActorLocation([12810.7, -12809.0, 0.0]);
    vm.updateActorRotation([0.0, 90.0, -179.5]);
    vm.updateActorScale([1.25, 1.0, 12.5], isCommit: true);
    await pumpEditor(tester);
    await tester.dragFrom(tester.getCenter(workspaceSplitter()), const Offset(-250, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byType(DetailsWidget)).width,
        moreOrLessEquals(EditorLayoutState.minOutlinerWidth, epsilon: 1));

    final fields = find.descendant(of: find.byType(DetailsWidget), matching: find.byType(ScrubNumericField));
    // Location, rotation, scale.
    final transform = fields.evaluate().take(9).toList();
    expect(transform, hasLength(9));
    final labels = <Rect>[];
    final resets = <Rect>[];
    for (final e in transform) {
      final field = find.byElementPredicate((c) => identical(c, e));
      final widget = e.widget as ScrubNumericField;
      final fieldRect = tester.getRect(field);
      final label = tester.getRect(find.descendant(of: field, matching: find.text(widget.label)));
      labels.add(label);
      final RenderEditable editable =
          tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText))).renderEditable;
      final editableRect = tester.getRect(find.descendant(of: field, matching: find.byType(EditableText)));
      expect(label.overlaps(editableRect), isFalse, reason: '${widget.label}: letter and value apart');
      // The value's text fits its box: nothing cut to "1281".
      expect(editable.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(editable.size.width + 0.5),
          reason: '${widget.label} = ${widget.value} fits (shown "${editable.text?.toPlainText()}")');
      final reset = find.descendant(of: field, matching: find.byIcon(LucideIcons.rotateCcw));
      if ((widget.value - widget.defaultValue).abs() > 0.001) {
        expect(reset, findsOneWidget, reason: '${widget.label} = ${widget.value} is not its default');
        final r = tester.getRect(reset);
        resets.add(r);
        expect(r.overlaps(editableRect), isFalse, reason: '${widget.label}: reset beside the value');
        expect(fieldRect.contains(r.topLeft) && fieldRect.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue,
            reason: '${widget.label}: reset inside its own field ($r in $fieldRect)');
      }
    }
    expect(resets, isNotEmpty);
    for (final r in resets) {
      for (final l in labels) {
        expect(r.overlaps(l), isFalse, reason: 'a reset button ($r) is drawn over an axis letter ($l)');
      }
    }
    expect(tester.takeException(), isNull);
  });
}
