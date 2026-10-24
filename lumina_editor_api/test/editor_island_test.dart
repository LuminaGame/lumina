import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The islands plugins build their panels with are the editor's own: the
/// same measurements, painted with the theme the host installs (Lumina Dark
/// outside the editor), so a plugin panel follows a theme switch.
void main() {
  tearDown(() => EditorIslandThemeData.active = EditorIslandThemeData.aurora);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        ShadcnApp(home: Scaffold(child: Center(child: SizedBox(width: 320, height: 240, child: child)))),
      );

  testWidgets('an island: the fill, a 1 px border, a 12 px radius and a 36 px upper-case header', (tester) async {
    await pump(
      tester,
      const EditorIsland(
        key: ValueKey('island'),
        header: EditorIslandHeader(title: 'Volumes', trailingInfo: '3'),
        child: EditorIslandSectionLabel('Generation'),
      ),
    );
    final box = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('island')), matching: find.byType(Container)).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, EditorIslandThemeData.aurora.island);
    expect(decoration.borderRadius, BorderRadius.circular(EditorIslandStyle.radius));
    expect((decoration.border! as Border).top.color, EditorIslandThemeData.aurora.border);
    expect(tester.getSize(find.byType(EditorIslandHeader)).height, EditorIslandStyle.headerHeight);
    expect(find.text('VOLUMES'), findsOneWidget);
    expect(find.text('GENERATION'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the host\'s theme paints the islands: a switch reaches a plugin island at its next build', (tester) async {
    const light = EditorIslandThemeData(
      island: Color(0xFFFAFAFA),
      ground: Color(0xFFEDEDED),
      border: Color(0xFFD4D4D4),
      fieldBorder: Color(0xFFC4C4C4),
      foreground: Color(0xFF111111),
      secondaryForeground: Color(0xFF333333),
      mutedForeground: Color(0xFF666666),
      muted: Color(0xFFE5E5E5),
      primary: Color(0xFF2563EB),
      primaryForeground: Color(0xFFFFFFFF),
      rowHover: Color(0x0A000000),
    );
    EditorIslandThemeData.active = light;
    await pump(tester, const EditorIslandGround(child: EditorIsland(key: ValueKey('island'), child: SizedBox.expand())));
    final ground = tester.widget<Container>(find.descendant(of: find.byType(EditorIslandGround), matching: find.byType(Container)).first);
    expect(ground.color, light.ground);
    final island = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('island')), matching: find.byType(Container)).first);
    expect((island.decoration! as BoxDecoration).color, light.island);
    expect(EditorTreeRowStyle.decoration(selected: true).color, light.primary);
    expect(EditorTreeRowStyle.foreground(selected: true), light.primaryForeground);
  });

  testWidgets('a tab header: the active tab on the muted chip, a tap selects another', (tester) async {
    var active = 0;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => EditorIsland(
          header: EditorIslandTabHeader(
            keyPrefix: 'p',
            tabs: const ['Graph', 'Volumes'],
            active: active,
            onSelect: (i) => setState(() => active = i),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    BoxDecoration chip(int i) => tester
        .widget<Container>(find.descendant(of: find.byKey(ValueKey('island_tab_p_$i')), matching: find.byType(Container)).first)
        .decoration! as BoxDecoration;
    expect(chip(0).color, EditorIslandThemeData.aurora.muted);
    await tester.tap(find.byKey(const ValueKey('island_tab_p_1')));
    await tester.pump();
    expect(active, 1);
    expect(chip(1).color, EditorIslandThemeData.aurora.muted);
    expect(chip(0).color, Colors.transparent);
  });
}
