import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// Horizontal and Vertical Box panels: they stretch their children across
/// the cross axis when the parent bounds it, and size to their tallest
/// (widest) child when it does not (a box inside another box or a Scroll
/// Box), instead of failing layout with an infinite cross extent.
Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, height: 400, child: child)),
    );

/// A box child as the UMG slot emits it: padded and, unless it fills the
/// cross axis, aligned inside the box's cross extent.
Widget _slot(Widget child, {Alignment? align}) =>
    Padding(padding: const EdgeInsets.all(2), child: align == null ? child : Align(alignment: align, child: child));

void main() {
  const label = ValueKey('label');
  const combo = ValueKey('combo');
  Widget row() => LuminaUmgBox(direction: Axis.horizontal, children: [
        _slot(const SizedBox(key: label, width: 80, height: 16), align: Alignment.center),
        _slot(const SizedBox(key: combo, width: 160, height: 32)),
      ]);

  testWidgets('a horizontal box inside a vertical box is as tall as its tallest child and centres the shorter one', (tester) async {
    await tester.pumpWidget(_host(LuminaUmgBox(direction: Axis.vertical, children: [row(), const SizedBox(height: 10)])));
    expect(tester.takeException(), isNull);
    final rowBox = tester.getRect(find.byType(LuminaUmgBox).last);
    expect(rowBox.height, 36, reason: 'the 32 px combo plus its 2 px padding above and below');
    expect(rowBox.width, 600, reason: 'the vertical box stretches its rows across');
    expect(tester.getCenter(find.byKey(label)).dy, closeTo(tester.getCenter(find.byKey(combo)).dy, 0.01));
  });

  testWidgets('a horizontal box inside a vertical scroll view lays out at its content height', (tester) async {
    await tester.pumpWidget(_host(SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [row(), row()]))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LuminaUmgBox).first).height, 36);
    expect(find.byKey(combo), findsNWidgets(2));
  });

  testWidgets('a vertical box inside a horizontal box or a horizontal scroll view is as wide as its widest child', (tester) async {
    Widget column() => LuminaUmgBox(direction: Axis.vertical, children: [
          _slot(const SizedBox(key: label, width: 80, height: 16), align: Alignment.centerRight),
          _slot(const SizedBox(key: combo, width: 160, height: 32)),
        ]);
    await tester.pumpWidget(_host(LuminaUmgBox(direction: Axis.horizontal, children: [column()])));
    expect(tester.takeException(), isNull);
    final inRow = tester.getRect(find.byType(LuminaUmgBox).last);
    expect(inRow.width, 164);
    expect(inRow.height, 400, reason: 'the horizontal box stretches it to its height');
    expect(tester.getRect(find.byKey(label)).right, tester.getRect(find.byKey(combo)).right, reason: 'end-aligned within the column width');

    await tester.pumpWidget(_host(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [column(), column()]),
    )));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LuminaUmgBox).first).width, 164);
  });

  testWidgets('a box with a bounded cross axis stretches its children to it', (tester) async {
    await tester.pumpWidget(_host(row()));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LuminaUmgBox)), const Size(600, 400));
    expect(tester.getSize(find.byKey(combo)).height, 396, reason: 'a filling slot gets the full height');
  });

  testWidgets('nested boxes report intrinsic sizes (an IntrinsicHeight ancestor works)', (tester) async {
    await tester.pumpWidget(_host(SingleChildScrollView(child: IntrinsicHeight(child: row()))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LuminaUmgBox)).height, 36);
  });
}
