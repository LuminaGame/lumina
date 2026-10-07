import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// Reading a widget instance's per-element state.
void main() {
  const cls = LuminaBlueprintWidgetClass(name: 'WBP_Test', elements: [
    LuminaBlueprintWidgetElement(name: 'Label', typeName: 'text', props: {'text': 'Hi', 'fontSize': 12, 'color': '#FF0000'}),
    LuminaBlueprintWidgetElement(name: 'Agree', typeName: 'checkBox', props: {'checked': true, 'label': 'Agree'}),
    LuminaBlueprintWidgetElement(name: 'Quality', typeName: 'comboBox', props: {'options': 'Low, High', 'selected': 'High'}),
    LuminaBlueprintWidgetElement(name: 'Name', typeName: 'editableText', props: {'text': '', 'hint': 'Enter name'}),
  ]);

  setUp(() => LuminaWidgetClassRegistry.register(cls));
  tearDown(LuminaWidgetClassRegistry.clear);

  Map<String, Object?> instance() => <String, Object?>{'class': 'WBP_Test', 'elements': LuminaWidgetClassRegistry.elementsFor('WBP_Test')};

  test('elementValue reads the element state with number coercion and the fallback for missing keys', () {
    final inst = instance();
    expect(LuminaUmgElementBinding.elementValue<String>(inst, 'Label', 'text', 'x'), 'Hi');
    expect(LuminaUmgElementBinding.elementValue<double>(inst, 'Label', 'fontSize', 1.0), 12.0);
    expect(LuminaUmgElementBinding.elementValue<int>(inst, 'Label', 'fontSize', 1), 12);
    expect(LuminaUmgElementBinding.elementValue<double>(inst, 'Label', 'missing', 3.5), 3.5);
    expect(LuminaUmgElementBinding.elementValue<String>(inst, 'Nope', 'text', 'fallback'), 'fallback');
    expect(LuminaUmgElementBinding.elementValue<String>(null, 'Label', 'text', 'fallback'), 'fallback');
    expect(LuminaUmgElementBinding.element(inst, 'Label')!['type'], 'text');
  });

  test('runtime keys fall back to the designer key they were seeded under', () {
    final inst = instance();
    final agree = LuminaUmgElementBinding.element(inst, 'Agree');
    expect(LuminaUmgElementBinding.value<bool>(agree, 'isChecked', false), isTrue);
    agree!['isChecked'] = false;
    expect(LuminaUmgElementBinding.value<bool>(agree, 'isChecked', true), isFalse);
    final quality = LuminaUmgElementBinding.element(inst, 'Quality');
    expect(LuminaUmgElementBinding.value<String>(quality, 'selectedOption', ''), 'High');
    expect(LuminaUmgElementBinding.options(quality, const []), ['Low', 'High']);
    quality!['options'] = ['Ultra'];
    expect(LuminaUmgElementBinding.options(quality, const []), ['Ultra']);
    final name = LuminaUmgElementBinding.element(inst, 'Name');
    expect(LuminaUmgElementBinding.value<String>(name, 'hintText', ''), 'Enter name');
  });

  test('color accepts the designer hex and the [r, g, b, a] the element nodes write', () {
    final label = LuminaUmgElementBinding.element(instance(), 'Label')!;
    expect(LuminaUmgElementBinding.color(label, 'color', const Color(0xFF000000)), const Color(0xFFFF0000));
    label['color'] = [0.0, 1.0, 0.0, 0.5];
    expect(LuminaUmgElementBinding.color(label, 'color', const Color(0xFF000000)), const Color(0x8000FF00));
    label['color'] = 'not a colour';
    expect(LuminaUmgElementBinding.color(label, 'color', const Color(0xFF000000)), const Color(0xFF000000));
    expect(LuminaUmgElementBinding.parseColor('#80FF00FF'), const Color(0xFF80FF00), reason: '#RRGGBBAA: alpha last');
    expect(LuminaUmgElementBinding.parseColor('#FF000080'), const Color(0x80FF0000));
    expect(LuminaUmgElementBinding.parseColor('22C55E'), const Color(0xFF22C55E));
    expect(LuminaUmgElementBinding.parseColor(42), isNull);
  });

  test('shadow and outline read the element state over the designer fallback', () {
    const designer = LuminaUmgTextShadow(enabled: true, color: Color(0xB3000000), offsetX: 1, offsetY: 1, blur: 0);
    expect(LuminaUmgElementBinding.shadow(null, designer), designer, reason: 'a preview uses the designer shadow');
    final label = LuminaUmgElementBinding.element(instance(), 'Label')!;
    expect(LuminaUmgElementBinding.shadow(label, designer), designer, reason: 'no keys in the state: the designer values');
    label['shadowColor'] = '#FF000080';
    label['shadowOffsetX'] = 3;
    label['shadowOffsetY'] = 4.0;
    label['shadowBlur'] = 2;
    final s = LuminaUmgElementBinding.shadow(label, designer);
    expect(s.shadows, [const Shadow(color: Color(0x80FF0000), offset: Offset(3, 4), blurRadius: 2)]);
    label['shadowColor'] = [0.0, 0.0, 1.0, 1.0];
    label['shadowEnabled'] = false;
    expect(LuminaUmgElementBinding.shadow(label, designer).color, const Color(0xFF0000FF));
    expect(LuminaUmgElementBinding.shadow(label, designer).shadows, isEmpty, reason: 'disabled draws nothing');
    expect(const LuminaUmgTextShadow(enabled: true, color: Color(0x00000000)).shadows, isEmpty, reason: 'transparent draws nothing');

    expect(LuminaUmgElementBinding.outline(label, LuminaUmgTextOutline.defaults).isVisible, isFalse, reason: 'size 0 is off');
    label['outlineSize'] = 2;
    label['outlineColor'] = '#000000';
    final o = LuminaUmgElementBinding.outline(label, LuminaUmgTextOutline.defaults);
    expect(o, const LuminaUmgTextOutline(size: 2, color: Color(0xFF000000)));
    expect(o.strokePaint.style, PaintingStyle.stroke);
    expect(o.strokePaint.strokeWidth, 4, reason: 'a centred stroke of twice the size shows the size outside the glyph');
    expect(o.ringShadows, hasLength(8));
    expect(o.ringShadows.first, const Shadow(color: Color(0xFF000000), offset: Offset(2, 0)));
  });

  testWidgets('LuminaUmgText draws the outline as a stroked copy under the fill, with the shadow on the stroke layer', (tester) async {
    const shadow = Shadow(color: Color(0x80FF0000), offset: Offset(3, 4), blurRadius: 2);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LuminaUmgText('Title',
            style: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF), shadows: [shadow]),
            outline: LuminaUmgTextOutline(size: 2, color: Color(0xFF000000))),
      ),
    ));
    final texts = tester.widgetList<Text>(find.text('Title')).toList();
    expect(texts, hasLength(2));
    final stroke = texts.first.style!;
    final fill = texts.last.style!;
    expect(stroke.foreground!.style, PaintingStyle.stroke);
    expect(stroke.foreground!.strokeWidth, 4);
    expect(stroke.foreground!.color, const Color(0xFF000000));
    expect(stroke.shadows, [shadow]);
    expect(fill.color, const Color(0xFFFFFFFF));
    expect(fill.foreground, isNull);
    expect(fill.shadows, isEmpty);
    expect(tester.getRect(find.byWidget(texts.first)), tester.getRect(find.byWidget(texts.last)), reason: 'identical layout so the glyphs align');

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaUmgText('Plain', style: TextStyle(shadows: [shadow])),
    ));
    expect(find.text('Plain'), findsOneWidget, reason: 'no outline: one Text');
    expect(tester.widget<Text>(find.text('Plain')).style!.shadows, [shadow]);
  });

  test('a Container style reads the designer props and the element state over them', () {
    final props = <String, Object?>{
      'backgroundColor': '#1E1E2A',
      'borderColor': '#FB7C01',
      'borderWidth': 2,
      'cornerRadius': 12,
      'padding': 16,
      'margin': [1, 2, 3, 4],
      'shadows': [
        {'color': '#00000080', 'offsetX': 0, 'offsetY': 4, 'blur': 12, 'spread': 0},
      ],
      'gradient': {'type': 'linear', 'colors': ['#FF0000', '#0000FF'], 'begin': 'topLeft', 'end': [1, 1]},
      'alignment': 'center',
      'width': 300,
      'minHeight': 40,
    };
    final designer = LuminaUmgContainerStyle.fromProps(props);
    final d = designer.decoration();
    expect(d.color, const Color(0xFF1E1E2A));
    expect(d.borderRadius, BorderRadius.circular(12));
    expect(d.border, Border.all(color: const Color(0xFFFB7C01), width: 2));
    expect(d.boxShadow, [const BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 12)]);
    expect(d.gradient, const LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)], begin: Alignment.topLeft, end: Alignment(1, 1)));
    expect(designer.padding, const EdgeInsets.all(16));
    expect(designer.margin, const EdgeInsets.fromLTRB(1, 2, 3, 4));
    expect(designer.alignment, Alignment.center);
    expect(designer.width, 300);
    expect(designer.constraints, const BoxConstraints(minHeight: 40));

    final element = <String, Object?>{'backgroundColor': [1.0, 0.0, 0.0, 1.0], 'cornerRadius': [1, 2, 3, 4]};
    final live = LuminaUmgElementBinding.containerStyle(element, designer);
    expect(live.backgroundColor, const Color(0xFFFF0000));
    expect(live.cornerRadius, const BorderRadius.only(topLeft: Radius.circular(1), topRight: Radius.circular(2), bottomRight: Radius.circular(3), bottomLeft: Radius.circular(4)));
    expect(live.borderWidth, 2, reason: 'keys the element does not hold keep the designer value');
    expect(LuminaUmgElementBinding.containerStyle(null, designer), designer);
    expect(LuminaUmgElementBinding.edgeInsets(element, 'padding', const EdgeInsets.all(3)), const EdgeInsets.all(3));
    expect(LuminaUmgElementBinding.borderRadius({'r': 5}, 'r', BorderRadius.zero), BorderRadius.circular(5));

    // Some sides only: Flutter cannot round those corners, so the radius is dropped.
    final sides = LuminaUmgContainerStyle.fromProps({'borderColor': '#FFFFFF', 'borderWidth': 1, 'borderSides': [true, false, true, false], 'cornerRadius': 8});
    expect(sides.decoration().borderRadius, isNull);
    expect((sides.decoration().border! as Border).left, BorderSide.none);
  });

  test('a Kbd label parses into keyboard keys', () {
    expect(LuminaUmgStyleJson.keyboardKeys('Ctrl+Shift+S'), [LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS]);
    expect(LuminaUmgStyleJson.keyboardKeys('Esc'), [LogicalKeyboardKey.escape]);
    expect(LuminaUmgStyleJson.keyboardKeys('Ctrl + ??? + 1'), [LogicalKeyboardKey.control, LogicalKeyboardKey.digit1]);
  });

  testWidgets('LuminaUmgContainer is a Flutter Container painting the style', (tester) async {
    final style = LuminaUmgContainerStyle.fromProps({'backgroundColor': '#1E1E2A', 'cornerRadius': 12, 'padding': 16, 'width': 200, 'height': 100});
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: LuminaUmgContainer(style: style, child: const Text('child'))),
    ));
    final container = tester.widget<Container>(find.byType(Container));
    expect(container.decoration, style.decoration());
    expect(container.padding, const EdgeInsets.all(16));
    expect(tester.getSize(find.byType(LuminaUmgContainer)), const Size(200, 100));
    expect(find.text('child'), findsOneWidget);
  });

  test('common properties default to visible, enabled and opaque', () {
    final label = LuminaUmgElementBinding.element(instance(), 'Label');
    expect(LuminaUmgElementBinding.isVisible(label), isTrue);
    expect(LuminaUmgElementBinding.isEnabled(label), isTrue);
    expect(LuminaUmgElementBinding.renderOpacity(label), 1.0);
    label!['visibility'] = 'Collapsed';
    label['renderOpacity'] = 2.0;
    expect(LuminaUmgElementBinding.isVisible(label), isFalse);
    expect(LuminaUmgElementBinding.renderOpacity(label), 1.0);
    expect(LuminaUmgElementBinding.isVisible(null), isTrue);
  });

  test('write stores what the player changed so Get nodes read the screen', () {
    final inst = instance();
    expect(LuminaUmgElementBinding.write(inst, 'Agree', 'isChecked', false), isTrue);
    expect(LuminaUmgElementBinding.elementValue<bool>(inst, 'Agree', 'isChecked', true), isFalse);
    expect(LuminaUmgElementBinding.write(inst, 'Ghost', 'value', 0.3), isTrue, reason: 'creates the element state');
    expect(LuminaUmgElementBinding.elementValue<double>(inst, 'Ghost', 'value', 0.0), 0.3);
    expect(LuminaUmgElementBinding.write(null, 'Agree', 'isChecked', false), isFalse);
  });

  testWidgets('LuminaUmgElement without a layer builds once from the current state', (tester) async {
    final inst = instance();
    var builds = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaUmgElement(
        instance: inst,
        name: 'Label',
        builder: (context, e) {
          builds++;
          return Text(LuminaUmgElementBinding.value<String>(e, 'text', ''), textDirection: TextDirection.ltr);
        },
      ),
    ));
    expect(find.text('Hi'), findsOneWidget);
    expect(builds, 1);
    expect(LuminaUmgElementBinding.maybeOf(tester.element(find.byType(Text))), isNull);
  });
}
