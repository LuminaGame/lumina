import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaUmgElementBinding;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/assets_library.dart' show assetTypesOf;
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/editor_tree_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// The editor widget set an editor panel lays out with: Editor Section,
/// Property Row, Tree View, List View, Asset Picker, Resizable Split,
/// Editor Toolbar and Status Line, in the Level Editor's tokens
/// (PANEL_AND_TREE_UNIFORMITY). Each reads its element state (the keys the
/// graph and `host.panelState` set) and fires its element events into the
/// panel's graph.
class EditorWidgetSet {
  EditorWidgetSet(this.host, this.instance);

  final EditorPanelHost host;
  final EditorPanelInstance instance;

  T _v<T>(Map<String, Object?>? e, UmgNode n, String key, T fallback) =>
      LuminaUmgElementBinding.value<T>(e, key, n.props[key] is T ? n.props[key] as T : fallback);

  void _write(UmgNode n, String key, Object? value) => LuminaUmgElementBinding.write(instance.map, n.name, key, value);

  void _fire(UmgNode n, String event, Map<String, Object?> args) => host.fire(instance, n.name, event, args);

  List<String> _ids(Object? v) => v is List ? [for (final e in v) '$e'] : const [];

  Widget build(BuildContext context, UmgNode node, Map<String, Object?>? e, Widget Function(UmgNode) child) {
    switch (node.type) {
      case UmgWidgetType.editorSection:
        final expanded = _v<bool>(e, node, 'expanded', true);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            key: ValueKey('editor_section_${node.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _write(node, 'expanded', !expanded);
              instance.refresh();
              _fire(node, 'OnSectionToggled', {'expanded': !expanded});
            },
            child: Container(
              height: EditorDensity.panelHeaderHeight,
              padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
              decoration: const BoxDecoration(
                color: EditorColors.cardHeader,
                border: Border(bottom: BorderSide(color: EditorColors.border)),
              ),
              child: Row(children: [
                Icon(expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_v<String>(e, node, 'title', 'Section'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                ),
              ]),
            ),
          ),
          if (expanded)
            Container(
              color: EditorColors.card,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                for (final c in node.children) child(c),
              ]),
            ),
        ]);
      case UmgWidgetType.propertyRow:
        return Container(
          constraints: const BoxConstraints(minHeight: EditorDensity.rowHeight),
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter, vertical: 2),
          child: Row(children: [
            SizedBox(
              width: (_v<num>(e, node, 'labelWidth', 110)).toDouble(),
              child: Text(_v<String>(e, node, 'label', 'Property'),
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            ),
            Expanded(child: node.children.isEmpty ? const SizedBox.shrink() : child(node.children.first)),
          ]),
        );
      case UmgWidgetType.treeView:
      case UmgWidgetType.listView:
        return EditorTreeView(
          elementName: node.name,
          items: EditorTreeItem.parse(e?['items'] ?? node.props['items']),
          selected: _ids(e?['selected'] ?? node.props['selected']),
          expanded: _ids(e?['expanded'] ?? node.props['expanded']),
          // Ctrl toggles and Shift extends, as in the Outliner.
          multiSelect: _v<bool>(e, node, 'multiSelect', true),
          onPointer: (p) => instance.lastPointer = p,
          onSelection: (ids) {
            _write(node, 'selected', ids);
            instance.refresh();
          },
          onExpanded: (ids) {
            _write(node, 'expanded', ids);
            instance.refresh();
          },
          onEvent: (event, args) => _fire(node, event, args),
        );
      case UmgWidgetType.assetPicker:
        final value = _v<String>(e, node, 'value', '');
        return SizedBox(
          height: EditorDensity.rowHeight + 4,
          child: EditorAssetPicker(
            key: ValueKey('editor_asset_picker_${node.name}'),
            hostContext: host.vm.extensionRegistry,
            selectedPath: value.isEmpty ? null : value,
            typeFilter: assetTypesOf(_v<String>(e, node, 'typeFilter', '')),
            placeholder: _v<String>(e, node, 'placeholder', 'None'),
            allowClear: _v<bool>(e, node, 'allowClear', true),
            onSelected: (path) {
              _write(node, 'value', path ?? '');
              instance.refresh();
              _fire(node, 'OnAssetPicked', {'asset_path': path ?? ''});
            },
          ),
        );
      case UmgWidgetType.resizableSplit:
        return _split(node, e, child);
      case UmgWidgetType.editorToolbar:
        return Container(
          constraints: const BoxConstraints(minHeight: EditorDensity.panelHeaderHeight),
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter, vertical: 3),
          decoration: const BoxDecoration(
            color: EditorColors.cardHeader,
            border: Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Wrap(spacing: 4, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final c in node.children) child(c),
          ]),
        );
      case UmgWidgetType.statusLine:
        final tone = _v<String>(e, node, 'tone', 'info');
        return Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
          decoration: const BoxDecoration(
            color: EditorColors.sidebar,
            border: Border(top: BorderSide(color: EditorColors.border)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(_v<String>(e, node, 'text', ''),
              key: ValueKey('editor_status_${node.name}'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: switch (tone) {
                  'error' => EditorColors.logError,
                  'warning' => EditorColors.logWarning,
                  'success' => EditorColors.logSuccess,
                  _ => EditorColors.mutedForeground,
                },
              )),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Two panes split horizontally or vertically, each at least its minimum;
  /// the split (a 0–1 fraction) is kept in the element state, so it survives
  /// a reload and is restored when the panel is shown again.
  Widget _split(UmgNode node, Map<String, Object?>? e, Widget Function(UmgNode) child) {
    final vertical = _v<String>(e, node, 'orientation', 'horizontal') == 'vertical';
    final split = _v<num>(e, node, 'split', 0.5).toDouble().clamp(0.05, 0.95);
    final minFirst = _v<num>(e, node, 'minFirst', 120).toDouble();
    final minSecond = _v<num>(e, node, 'minSecond', 120).toDouble();
    final first = node.children.isNotEmpty ? child(node.children[0]) : const SizedBox.shrink();
    final second = node.children.length > 1 ? child(node.children[1]) : const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final total = vertical ? c.maxHeight : c.maxWidth;
      final size = total.isFinite ? (total * split).clamp(minFirst, (total - minSecond).clamp(minFirst, total)) : 200.0;
      final panes = [
        ResizablePane(
          key: ValueKey('editor_split_${node.name}_first'),
          initialSize: size.toDouble(),
          minSize: minFirst,
          onSizeChangeEnd: (s) {
            if (total.isFinite && total > 0) _write(node, 'split', s / total);
          },
          child: first,
        ),
        ResizablePane.flex(minSize: minSecond, child: second),
      ];
      return vertical
          ? ResizablePanel.vertical(draggerBuilder: (_) => const VerticalResizableDragger(), children: panes)
          : ResizablePanel.horizontal(draggerBuilder: (_) => const HorizontalResizableDragger(), children: panes);
    });
  }
}
