import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// The plain-Flutter UMG widget set: no Material, no shadcn ancestor,
/// only an Overlay (which every game app has) for the combo box.
Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        // A fresh Overlay per pump: initialEntries are read once per state.
        child: Overlay(key: UniqueKey(), initialEntries: [
          OverlayEntry(builder: (_) => Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(20), child: child))),
        ]),
      ),
    );

void main() {
  testWidgets('LuminaUmgButton: tap fires onPressed; mouse enter/exit fire onHovered(true/false); every style builds', (tester) async {
    var pressed = 0;
    final hovers = <bool>[];
    await tester.pumpWidget(_host(LuminaUmgButton(
      onPressed: () => pressed++,
      onHovered: hovers.add,
      child: const Text('Start'),
    )));
    await tester.tap(find.text('Start'));
    expect(pressed, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(tester.getCenter(find.text('Start')));
    await tester.pump();
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(hovers, [true, false]);
    await mouse.removePointer();

    for (final style in LuminaUmgButtonStyle.values) {
      await tester.pumpWidget(_host(LuminaUmgButton(style: style, onPressed: () {}, child: Text(style.name))));
      expect(find.text(style.name), findsOneWidget);
    }
    // Disabled: no callback, no tap.
    await tester.pumpWidget(_host(const LuminaUmgButton(child: Text('Off'))));
    await tester.tap(find.text('Off'));
  });

  testWidgets('LuminaUmgSlider maps a tap at 75% of its width to 0.75 and drags follow the pointer', (tester) async {
    double? value;
    await tester.pumpWidget(_host(SizedBox(
      width: 200,
      child: LuminaUmgSlider(value: 0.2, onChanged: (v) => value = v),
    )));
    final box = tester.getRect(find.byType(LuminaUmgSlider));
    await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
    expect(value, closeTo(0.75, 0.01));
    await tester.dragFrom(Offset(box.left + box.width * 0.5, box.center.dy), Offset(box.width * 0.25, 0));
    expect(value, closeTo(0.75, 0.02));
    await tester.tapAt(Offset(box.right + 30, box.center.dy));
  });

  testWidgets('LuminaUmgCheckbox toggles and shows its label', (tester) async {
    var checked = false;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => LuminaUmgCheckbox(
        value: checked,
        onChanged: (v) => setState(() => checked = v),
        label: const Text('Invert Y'),
      ),
    )));
    await tester.tap(find.text('Invert Y'));
    await tester.pump();
    expect(checked, isTrue);
    await tester.tap(find.byType(LuminaUmgCheckbox));
    await tester.pump();
    expect(checked, isFalse);
  });

  testWidgets('LuminaUmgTextField reports typed text and shows its placeholder only when empty', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(_host(SizedBox(
      width: 240,
      child: LuminaUmgTextField(placeholder: 'Player name', onChanged: typed.add),
    )));
    expect(find.text('Player name'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Quinn');
    await tester.pump();
    expect(typed.last, 'Quinn');
    expect(find.text('Player name'), findsNothing);

    await tester.pumpWidget(_host(const SizedBox(width: 240, child: LuminaUmgTextField(initialValue: 'Manny'))));
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Manny');
  });

  testWidgets('LuminaUmgComboBox opens its options above the page and reports the pick', (tester) async {
    String? picked;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => SizedBox(
        width: 200,
        child: LuminaUmgComboBox(
          value: picked,
          options: const ['Low', 'Medium', 'High'],
          placeholder: 'Quality',
          onChanged: (v) => setState(() => picked = v),
        ),
      ),
    )));
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('High'), findsNothing);
    await tester.tap(find.text('Quality'));
    await tester.pump();
    expect(find.text('High'), findsOneWidget);
    await tester.tap(find.text('High'));
    await tester.pump();
    expect(picked, 'High');
    expect(find.text('Low'), findsNothing, reason: 'the list closes after a pick');
    expect(find.text('High'), findsOneWidget, reason: 'the box shows the pick');
  });

  testWidgets('LuminaUmgProgressBar clamps 1.4 to a full bar and -0.2 to an empty one; LuminaUmgBorder pads its child', (tester) async {
    Future<double> fillWidth(double p) async {
      await tester.pumpWidget(_host(SizedBox(width: 300, height: 12, child: LuminaUmgProgressBar(progress: p))));
      return tester.getSize(find.byKey(LuminaUmgProgressBar.fillKey)).width;
    }

    expect(await fillWidth(1.4), 300);
    expect(await fillWidth(0.5), 150);
    expect(await fillWidth(-0.2), 0);

    await tester.pumpWidget(_host(const LuminaUmgBorder(padding: EdgeInsets.all(10), child: SizedBox(width: 40, height: 20))));
    expect(tester.getSize(find.byType(LuminaUmgBorder)), const Size(60, 40));
  });

  testWidgets('LuminaUmgSkeleton lays out its lines like the text and paints pulsing rounded bones', (tester) async {
    const red = Color(0xFFFF0000);
    await tester.pumpWidget(_host(const SizedBox(width: 300, child: LuminaUmgSkeleton(lines: 4, color: red))));
    final rows = find.descendant(of: find.byType(LuminaUmgSkeleton), matching: find.byType(CustomPaint));
    expect(rows, findsNWidgets(4));
    expect(tester.getSize(rows.first).width, 300, reason: 'the rows stretch, as the shadcn skeleton column did');
    expect(find.text('Loading placeholder text line'), findsNWidgets(4), reason: 'the text sizes the rows');
    final faint = red.withValues(alpha: 0.05);
    final strong = red.withValues(alpha: 0.1);
    expect(rows.first, paints..rrect(color: faint));
    await tester.pump(const Duration(seconds: 1));
    expect(rows.first, paints..rrect(color: strong), reason: 'one pulse later the bone is at its strongest');
    await tester.pump(const Duration(seconds: 1));
    expect(rows.first, paints..rrect(color: faint), reason: 'and it pulses back');

    await tester.pumpWidget(_host(const SizedBox(width: 220, height: 30, child: LuminaUmgSkeleton(color: red))));
    expect(tester.takeException(), isNull, reason: 'a slot shorter than the lines clips them instead of overflowing');
    expect(tester.getSize(find.byType(LuminaUmgSkeleton)), const Size(220, 30));
  });
}
