import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_editor_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart';

/// A real `.mat` source; the empty line inside material() keeps its
/// indentation, where the tests type.
const _source =
    'material {\n'
    '    name : "M_Completion",\n'
    '    shadingModel : lit,\n'
    '    parameters : [ { type : sampler2d, name : albedoMap } ],\n'
    '    requires : [ uv0 ]\n'
    '}\n'
    '\n'
    'fragment {\n'
    '    void material(inout MaterialInputs material) {\n'
    '        prepareMaterial(material);\n'
    '        \n'
    '    }\n'
    '}\n';

/// The empty line inside material(), where the tests type.
final int _bodyOffset = _source.indexOf('prepareMaterial(material);\n') + 'prepareMaterial(material);\n        '.length;

class _Harness {
  final GlslCodeController controller;
  final FocusNode focusNode;
  final GlobalKey<MaterialGlslEditorWidgetState> key;
  _Harness(this.controller, this.focusNode, this.key);

  MaterialGlslEditorWidgetState get state => key.currentState!;
  List<String> get labels => [for (final i in state.completionItems) i.label];
}

Future<_Harness> _pumpEditor(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final vm = MaterialEditorViewModel(assetPath: 'contents/materials/M_Completion.lmas');
  final controller = GlslCodeController(text: _source);
  final focusNode = FocusNode();
  final key = GlobalKey<MaterialGlslEditorWidgetState>();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: MaterialGlslEditorWidget(key: key, viewModel: vm, controller: controller, focusNode: focusNode),
      ),
    ),
  );
  focusNode.requestFocus();
  await tester.pump();
  controller.selection = TextSelection.collapsed(offset: _bodyOffset);
  await tester.pump();
  return _Harness(controller, focusNode, key);
}

/// Types [text] one character at a time at the caret, as the keyboard does.
Future<void> _type(WidgetTester tester, _Harness h, String text) async {
  for (final ch in text.split('')) {
    final value = h.controller.value;
    final caret = value.selection.baseOffset;
    h.controller.value = TextEditingValue(
      text: value.text.replaceRange(caret, caret, ch),
      selection: TextSelection.collapsed(offset: caret + 1),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('typing getW in the fragment block opens the popup below the caret with getWorldPosition', (
    tester,
  ) async {
    final h = await _pumpEditor(tester);
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsNothing);

    await _type(tester, h, 'getW');
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsOneWidget);
    expect(h.labels, contains('getWorldPosition'));
    expect(h.labels.take(5), everyElement(startsWith('getW')), reason: 'prefix matches rank first');
    expect(find.byKey(const ValueKey('mat_completion_details')), findsOneWidget);

    // Anchored just below the caret's line: the line of `getW` is line 11
    // (index 10), each 20 px tall, below the code area's 8 px padding.
    final field = tester.getTopLeft(find.byKey(const ValueKey('material_glsl_code')));
    final list = tester.getRect(find.byKey(const ValueKey('mat_completion_list')));
    expect(list.top, moreOrLessEquals(field.dy + 11 * 20, epsilon: 1));
    final lineStart = _source.lastIndexOf('\n', _bodyOffset - 1) + 1;
    final charWidth = _measuredCharWidth();
    expect(list.left, moreOrLessEquals(field.dx + (_bodyOffset - lineStart) * charWidth - 26, epsilon: 1));
  });

  testWidgets('Down then Enter inserts the second suggestion and puts the caret inside its parentheses', (
    tester,
  ) async {
    final h = await _pumpEditor(tester);
    await _type(tester, h, 'mulMat');
    expect(h.labels, ['mulMat3x3Float3', 'mulMat4x4Float3']);
    expect(h.state.selectedCompletionIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(h.state.selectedCompletionIndex, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byKey(const ValueKey('mat_completion_popup')), findsNothing);
    expect(h.controller.text, _source.replaceRange(_bodyOffset, _bodyOffset, 'mulMat4x4Float3()'));
    expect(h.controller.selection.baseOffset, _bodyOffset + 'mulMat4x4Float3('.length);
  });

  testWidgets('Escape closes the popup and Ctrl+Space opens it with an empty prefix', (tester) async {
    final h = await _pumpEditor(tester);
    await _type(tester, h, 'satu');
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsNothing);
    expect(h.controller.text, contains('satu'), reason: 'Escape leaves the text alone');

    // Remove the word, then ask explicitly with nothing typed.
    h.controller.value = TextEditingValue(text: _source, selection: TextSelection.collapsed(offset: _bodyOffset));
    await tester.pump();
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsOneWidget);
    expect(h.labels, containsAll(['material', 'materialParams_albedoMap', 'getUV0', 'texture']));
  });

  testWidgets('typing material. lists the MaterialInputs fields and Tab accepts the selected one', (tester) async {
    final h = await _pumpEditor(tester);
    await _type(tester, h, 'material.');
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsOneWidget);
    expect(h.labels, contains('baseColor'));
    expect(find.text('float4'), findsWidgets);

    await _type(tester, h, 'baseC');
    expect(h.labels.first, 'baseColor');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(h.controller.text, _source.replaceRange(_bodyOffset, _bodyOffset, 'material.baseColor'));
    expect(h.controller.selection.baseOffset, _bodyOffset + 'material.baseColor'.length);
  });

  testWidgets('clicking a row accepts it and arrow keys move the caret again once the popup is closed', (
    tester,
  ) async {
    final h = await _pumpEditor(tester);
    await _type(tester, h, 'getUV');
    expect(h.labels.take(2), ['getUV0', 'getUV1']);
    await tester.tap(find.text('getUV1'));
    await tester.pump();
    expect(h.controller.text, _source.replaceRange(_bodyOffset, _bodyOffset, 'getUV1()'));
    expect(find.byKey(const ValueKey('mat_completion_popup')), findsNothing);

    final before = h.controller.selection.baseOffset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(h.controller.selection.baseOffset, before - 1, reason: 'the field handles keys while the popup is closed');
  });
}

/// The code font's character width, measured the way the editor does.
double _measuredCharWidth() {
  final painter = TextPainter(
    text: const TextSpan(
      text: 'MMMMMMMMMM',
      style: TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 13, height: 20 / 13),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width / 10;
  painter.dispose();
  return width;
}
