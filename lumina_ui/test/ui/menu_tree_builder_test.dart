import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_tree_builder.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// `(path, command, options)` entries → nested menus of any
/// depth, ordered, sectioned, checkable.
void main() {
  EditorCommand cmd(String label, {bool enabled = true, void Function()? run}) => EditorCommand(
        id: 'test.${label.toLowerCase()}',
        label: label,
        canExecute: () => enabled,
        execute: (_) => run?.call(),
      );

  MenuTreeEntry entry(String path, {int order = 0, String? section, ValueListenable<bool>? checked, bool enabled = true}) =>
      MenuTreeEntry(
        path: path.split('/'),
        command: cmd(path.split('/').last, enabled: enabled),
        options: EditorMenuItemOptions(order: order, section: section, checked: checked),
      );

  String describe(List<MenuTreeNode> nodes) => nodes
      .map((n) => switch (n) {
            MenuTreeLeaf(:final entry) => entry.command.label,
            MenuTreeSubmenu(:final title, :final children) => '$title[${describe(children)}]',
            MenuTreeDivider() => '|',
          })
      .join(',');

  test('A/B/C/Leaf1, A/B/Leaf2, A/Leaf3 nest three levels deep', () {
    final nodes = layoutMenuTree([entry('A/B/C/Leaf1'), entry('A/B/Leaf2'), entry('A/Leaf3')]);
    expect(describe(nodes), 'A[B[C[Leaf1],Leaf2],Leaf3]');
  });

  test('order 10 sorts after order 0; ties keep registration order', () {
    final nodes = layoutMenuTree([entry('Late', order: 10), entry('First'), entry('Second')]);
    expect(describe(nodes), 'First,Second,Late');
  });

  test('two sections → exactly one divider between them', () {
    final nodes = layoutMenuTree([
      entry('New', section: 'create'),
      entry('Run', section: 'run', order: 5),
      entry('Place', section: 'create'),
      entry('Clean', section: 'run', order: 6),
    ]);
    expect(describe(nodes), 'New,Place,|,Run,Clean');
    expect(nodes.whereType<MenuTreeDivider>(), hasLength(1));
  });

  Future<void> openMenu(WidgetTester tester, List<MenuTreeEntry> entries) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Builder(
          builder: (context) => Menubar(children: [
            MenuButton(subMenu: buildMenuTree(entries, commandContext: context), child: const Text('Root')),
          ]),
        ),
      ),
    ));
    await tester.tap(find.text('Root'));
    await tester.pumpAndSettle();
  }

  testWidgets('the nested menus open level by level', (tester) async {
    await openMenu(tester, [entry('A/B/C/Leaf1'), entry('A/B/Leaf2'), entry('A/Leaf3')]);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Leaf3'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('Leaf2'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(find.text('Leaf1'), findsOneWidget);
  });

  testWidgets('a checked notifier flipping true → false rebuilds the mark', (tester) async {
    final checked = ValueNotifier(true);
    addTearDown(checked.dispose);
    await openMenu(tester, [entry('Grid', checked: checked)]);
    MenuCheckbox box() => tester.widget<MenuCheckbox>(find.byKey(const ValueKey('menu_check_test.grid')));
    expect(box().value, isTrue);
    checked.value = false;
    await tester.pump();
    expect(box().value, isFalse);
  });

  testWidgets('canExecute false → the item is disabled; enabled items run their command', (tester) async {
    var ran = 0;
    await openMenu(tester, [
      entry('Off', enabled: false),
      MenuTreeEntry(path: const ['On'], command: cmd('On', run: () => ran++)),
    ]);
    expect(tester.widget<MenuButton>(find.byKey(const ValueKey('menu_item_test.off'))).onPressed, isNull);
    expect(tester.widget<MenuButton>(find.byKey(const ValueKey('menu_item_test.on'))).onPressed, isNotNull);
    await tester.tap(find.text('On'));
    await tester.pumpAndSettle();
    expect(ran, 1);
  });
}
