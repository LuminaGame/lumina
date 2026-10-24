import 'package:flutter/gestures.dart' show kMiddleMouseButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/typed_tab_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The typed tab bar: each tab carries its type's icon and colour, the active
/// one a 2 px underline in that colour; an unsaved tab shows the amber dot
/// and the pointer turns it into the close cross; tabs that do not fit
/// collapse into a `+N` menu.
void main() {
  List<EditorTypedTab> tabs(int count, {Set<int> dirty = const {}}) => [
        for (var i = 0; i < count; i++)
          EditorTypedTab(
            key: ValueKey('tab_$i'),
            title: i == 0 ? 'L_Main' : 'M_Asset_$i',
            icon: i == 0 ? LucideIcons.map : LucideIcons.palette,
            color: i == 0 ? EditorColors.assetTypeLevel : EditorColors.assetTypeMaterial,
            dirty: dirty.contains(i),
            closable: i > 0,
          ),
      ];

  Future<void> pump(WidgetTester tester, Widget bar, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: Column(children: [bar]))));
    await tester.pump();
  }

  BoxDecoration decorationOf(WidgetTester tester, Key key) =>
      (tester.widget<Container>(find.byKey(key))).decoration! as BoxDecoration;

  testWidgets('a Material tab shows the material icon in its colour and a matching underline when active', (tester) async {
    var selected = -1;
    await pump(
      tester,
      EditorTypedTabBar(tabs: tabs(3), activeIndex: 1, onSelect: (i) => selected = i, onClose: (_) {}),
    );
    expect(tester.getSize(find.byType(EditorTypedTabBar)).height, EditorTypedTabBar.barHeight);
    final active = decorationOf(tester, const ValueKey('tab_1'));
    final border = active.border! as Border;
    expect(border.bottom.width, 2);
    expect(border.bottom.color.toARGB32(), EditorColors.assetTypeMaterial.toARGB32());
    expect(active.color!.toARGB32(), EditorColors.sidebar.toARGB32(), reason: 'the active tab sits on the island fill');
    final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('tab_1')), matching: find.byType(Icon)).first);
    expect(icon.icon, LucideIcons.palette);
    expect(icon.color!.toARGB32(), EditorColors.assetTypeMaterial.toARGB32());
    final inactive = (decorationOf(tester, const ValueKey('tab_2')).border! as Border).bottom;
    expect(inactive.color.a, 0, reason: 'inactive tabs carry no underline');
    expect(find.text('L_Main'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab_2')));
    expect(selected, 2);
  });

  testWidgets('an unsaved tab shows the dot, hover turns it into the cross, clicking it asks to close', (tester) async {
    var closed = -1;
    await pump(
      tester,
      EditorTypedTabBar(tabs: tabs(3, dirty: {2}), activeIndex: 0, onSelect: (_) {}, onClose: (i) => closed = i),
    );
    expect(find.byKey(const ValueKey('workspace_tab_unsaved_dot')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tab_2')), matching: find.byKey(const ValueKey('workspace_tab_close'))),
        findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('tab_2'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('workspace_tab_unsaved_dot')), findsNothing, reason: 'the pointer reveals the cross');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('tab_2')), matching: find.byKey(const ValueKey('workspace_tab_close'))));
    expect(closed, 2, reason: 'the bar asks its owner, which prompts for unsaved changes');
    // The level tab cannot be closed.
    expect(find.descendant(of: find.byKey(const ValueKey('tab_0')), matching: find.byKey(const ValueKey('workspace_tab_close'))),
        findsNothing);
  });

  testWidgets('a middle click closes a tab', (tester) async {
    var closed = -1;
    await pump(tester, EditorTypedTabBar(tabs: tabs(2), activeIndex: 0, onSelect: (_) {}, onClose: (i) => closed = i));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('tab_1'))),
        kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await gesture.up();
    expect(closed, 1);
  });

  testWidgets('nine tabs in 600 px collapse the rest into +N, which lists and selects them; + adds', (tester) async {
    var selected = -1;
    var added = 0;
    await pump(
      tester,
      EditorTypedTabBar(tabs: tabs(9), activeIndex: 0, onSelect: (i) => selected = i, onClose: (_) {}, onAdd: () => added++),
      width: 600,
    );
    // (600 - 92) / 156 = 3 tabs fit.
    expect(find.byKey(const ValueKey('tab_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab_3')), findsNothing);
    expect(find.text('+6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace_tab_overflow')));
    await tester.pumpAndSettle();
    expect(find.text('M_Asset_8'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace_tab_overflow_8')));
    await tester.pumpAndSettle();
    expect(selected, 8);
    await tester.tap(find.byKey(const ValueKey('workspace_tab_add')));
    expect(added, 1);
  });

  testWidgets('the active tab is always visible, even when it would overflow', (tester) async {
    await pump(tester, EditorTypedTabBar(tabs: tabs(9), activeIndex: 7, onSelect: (_) {}, onClose: (_) {}), width: 600);
    expect(find.byKey(const ValueKey('tab_7')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab_2')), findsNothing, reason: 'the last slot went to the active tab');
    expect(find.text('+6'), findsOneWidget);
  });
}
