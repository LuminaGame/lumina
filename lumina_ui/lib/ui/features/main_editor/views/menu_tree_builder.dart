import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorMenuItemOptions;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../commands/editor_command.dart';

/// One menu item to place: [path] runs from the first submenu
/// under the menu it belongs to down to the item's own slot (its last
/// segment); the item shows [command]'s label.
class MenuTreeEntry {
  final List<String> path;
  final EditorCommand command;
  final EditorMenuItemOptions options;

  const MenuTreeEntry({required this.path, required this.command, this.options = const EditorMenuItemOptions()});
}

/// The laid-out menu: items, submenus and the dividers between sections.
sealed class MenuTreeNode {
  const MenuTreeNode();
}

class MenuTreeLeaf extends MenuTreeNode {
  final MenuTreeEntry entry;
  const MenuTreeLeaf(this.entry);
}

class MenuTreeSubmenu extends MenuTreeNode {
  final String title;
  final List<MenuTreeNode> children;
  const MenuTreeSubmenu(this.title, this.children);
}

class MenuTreeDivider extends MenuTreeNode {
  const MenuTreeDivider();
}

/// Lays [entries] out as a tree of any depth. Within each (sub)menu the
/// children sort by `order` (a submenu takes its lowest descendant's order
/// and its first item's section), ties keep registration order; children of
/// different sections are grouped in the order their sections first appear,
/// with one divider between neighbouring groups.
List<MenuTreeNode> layoutMenuTree(Iterable<MenuTreeEntry> entries) => _layout(entries.toList(), 0);

List<MenuTreeNode> _layout(List<MenuTreeEntry> entries, int depth) {
  // Children in first-registration order: a leaf, or a submenu collecting
  // every entry that continues under its title.
  final children = <({String? submenu, List<MenuTreeEntry> entries})>[];
  final submenuIndex = <String, int>{};
  for (final e in entries) {
    if (e.path.length - depth <= 1) {
      children.add((submenu: null, entries: [e]));
      continue;
    }
    final title = e.path[depth];
    final at = submenuIndex[title];
    if (at == null) {
      submenuIndex[title] = children.length;
      children.add((submenu: title, entries: [e]));
    } else {
      children[at].entries.add(e);
    }
  }

  int orderOf(List<MenuTreeEntry> es) => es.map((e) => e.options.order).reduce((a, b) => a < b ? a : b);
  final sorted = children.asMap().entries.toList()
    ..sort((a, b) {
      final byOrder = orderOf(a.value.entries).compareTo(orderOf(b.value.entries));
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });

  // Group by section in first-appearance order.
  final sections = <String?, List<MenuTreeNode>>{};
  for (final c in sorted.map((e) => e.value)) {
    final node = c.submenu == null
        ? MenuTreeLeaf(c.entries.single)
        : MenuTreeSubmenu(c.submenu!, _layout(c.entries, depth + 1));
    sections.putIfAbsent(c.entries.first.options.section, () => []).add(node);
  }
  final out = <MenuTreeNode>[];
  for (final group in sections.values) {
    if (out.isNotEmpty) out.add(const MenuTreeDivider());
    out.addAll(group);
  }
  return out;
}

/// Builds shadcn menu items for [entries] ([layoutMenuTree]). Items run their
/// command with [commandContext] when given (a context that outlives the
/// closed menu) and are disabled while `canExecute` is false; a `checked`
/// item shows a live check mark. [itemBuilder] replaces the default button
/// for plain (unchecked) items.
List<MenuItem> buildMenuTree(
  Iterable<MenuTreeEntry> entries, {
  BuildContext? commandContext,
  MenuItem Function(MenuTreeEntry entry)? itemBuilder,
}) =>
    _build(layoutMenuTree(entries), commandContext, itemBuilder);

List<MenuItem> _build(List<MenuTreeNode> nodes, BuildContext? commandContext, MenuItem Function(MenuTreeEntry)? itemBuilder) => [
      for (final n in nodes)
        switch (n) {
          MenuTreeDivider() => const MenuDivider(),
          MenuTreeSubmenu(:final title, :final children) => MenuButton(
              key: ValueKey('menu_submenu_$title'),
              subMenu: _build(children, commandContext, itemBuilder),
              child: Text(title, style: const TextStyle(fontSize: 10)),
            ),
          MenuTreeLeaf(:final entry) => entry.options.checked != null
              ? _CheckedMenuItem(entry: entry, commandContext: commandContext)
              : itemBuilder?.call(entry) ?? menuTreeButton(entry.command, commandContext: commandContext),
        },
    ];

/// The default menu button for [command]: icon, label, shortcut, disabled
/// while `canExecute` is false.
MenuButton menuTreeButton(EditorCommand command, {BuildContext? commandContext, String? label}) {
  final canExec = command.canExecute();
  return MenuButton(
    key: ValueKey('menu_item_${command.id}'),
    leading: command.icon != null ? Icon(command.icon, size: 14) : null,
    trailing: command.shortcutLabel.isNotEmpty
        ? Text(command.shortcutLabel, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
        : null,
    onPressed: canExec ? (ctx) => command.execute(commandContext ?? ctx) : null,
    child: Text(
      label ?? command.label,
      style: TextStyle(fontSize: 10, color: canExec ? null : EditorColors.mutedForeground),
    ),
  );
}

/// A built-in menu's checkbox row: [command]
/// with a check that follows [checked] while the menu is open, keyed
/// `menu_check_<command id>` like the plugin rows.
MenuItem menuCheckboxItem(EditorCommand command, ValueListenable<bool> checked, {BuildContext? commandContext}) =>
    _CheckedMenuItem(
      entry: MenuTreeEntry(path: [command.label], command: command, options: EditorMenuItemOptions(checked: checked)),
      commandContext: commandContext,
    );

/// A command item whose check mark follows `options.checked`, rebuilt while
/// the menu is open.
class _CheckedMenuItem extends StatelessWidget implements MenuItem {
  final MenuTreeEntry entry;
  final BuildContext? commandContext;

  const _CheckedMenuItem({required this.entry, this.commandContext});

  @override
  bool get hasLeading => true;

  @override
  OverlayController? get overlayController => null;

  @override
  Widget build(BuildContext context) {
    final command = entry.command;
    return ValueListenableBuilder<bool>(
      valueListenable: entry.options.checked!,
      builder: (context, checked, _) {
        final canExec = command.canExecute();
        return MenuCheckbox(
          key: ValueKey('menu_check_${command.id}'),
          value: checked,
          enabled: canExec,
          onChanged: canExec ? (ctx, _) => command.execute(commandContext ?? ctx) : null,
          trailing: command.shortcutLabel.isNotEmpty
              ? Text(command.shortcutLabel, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
              : null,
          child: Text(command.label, style: const TextStyle(fontSize: 10)),
        );
      },
    );
  }
}
