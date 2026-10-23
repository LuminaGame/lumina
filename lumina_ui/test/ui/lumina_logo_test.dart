import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/lumina_logo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Prism L mark and the LUMINA / Studio lockup.
void main() {
  Widget host(Widget child) => ShadcnApp(theme: luminaEditorTheme(), home: Center(child: child));

  testWidgets('the mark paints five facets in the three blues at any size', (tester) async {
    for (final size in [20.0, 30.0, 150.0]) {
      await tester.pumpWidget(host(LuminaMark(size: size)));
      final box = tester.renderObject<RenderBox>(find.byType(LuminaMark));
      expect(box.size, Size(size, size));
      final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(LuminaMark), matching: find.byType(CustomPaint))).painter as PrismLPainter;
      expect(painter.facets.length, 5);
      expect(painter.facets.map((f) => f.color).toSet(), {LuminaBrand.blueDeep, LuminaBrand.blueMid, LuminaBrand.blueLight});
      expect(painter.facets.last.opacity, closeTo(0.55, 0.001), reason: 'the under-shard is faint');
    }
  });

  testWidgets('the mono mark is one colour and drops the under-shard', (tester) async {
    await tester.pumpWidget(host(const LuminaMark(size: 20, mono: true, color: Color(0xFF123456))));
    final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(LuminaMark), matching: find.byType(CustomPaint))).painter as PrismLPainter;
    expect(painter.facets.length, 4);
    expect(painter.facets.map((f) => f.color).toSet(), {const Color(0xFF123456)});
    expect(painter.facets.every((f) => f.opacity == 1), isTrue);
  });

  testWidgets('the lockup is the mark beside LUMINA over Studio; compact is one line', (tester) async {
    await tester.pumpWidget(host(const LuminaLockup()));
    expect(find.byType(LuminaMark), findsOneWidget);
    final title = tester.widget<Text>(find.text('LUMINA'));
    expect(title.style!.fontWeight, FontWeight.w800);
    expect(title.style!.letterSpacing, closeTo(12 * 0.12, 0.01));
    expect(find.text('Studio'), findsOneWidget);
    final mark = tester.getRect(find.byType(LuminaMark));
    final word = tester.getRect(find.text('LUMINA'));
    final sub = tester.getRect(find.text('Studio'));
    expect(mark.width, 30);
    expect(word.left, greaterThan(mark.right));
    expect(sub.top, greaterThanOrEqualTo(word.bottom - 1), reason: 'Studio sits under LUMINA');

    await tester.pumpWidget(host(const LuminaLockup(compact: true)));
    expect(find.text('Studio'), findsNothing);
    expect(find.text('LUMINA'), findsOneWidget);
  });
}
