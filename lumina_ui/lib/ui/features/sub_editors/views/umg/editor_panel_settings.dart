import 'dart:convert';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorPanelCapability, LuminaEditorPanelDock, LuminaEditorPanelInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_trust_prompt.dart' show editorPanelCapabilityText;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

/// Class Settings ▸ Editor Panel: turns the Widget Blueprint into an editor
/// panel (the `editorPanel` block) and edits its title, icon, dock, options,
/// menu path, minimum size and capabilities.
class UmgEditorPanelSettings extends StatelessWidget {
  const UmgEditorPanelSettings({super.key, required this.vm});

  final UmgEditorViewModel vm;

  LuminaEditorPanelInfo? get _info => vm.document.editorPanel;

  void _set(LuminaEditorPanelInfo? info) => vm.setEditorPanel(info);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _check(String key, String label, bool value, void Function(bool) onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Checkbox(
            key: ValueKey('umg_editor_panel_$key'),
            state: value ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) => onChanged(s == CheckboxState.checked),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.foreground))),
        ]),
      );

  Widget _text(String key, String label, String value, void Function(String) onSubmitted) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            key: ValueKey('umg_editor_panel_${key}_$value'),
            initialValue: value,
            style: const TextStyle(fontSize: 9.5),
            onSubmitted: onSubmitted,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _check(
          'enabled',
          'Editor Panel (runs in Lumina Studio, never in the game)',
          info != null,
          (on) => _set(on ? LuminaEditorPanelInfo(title: vm.className.replaceFirst(RegExp(r'^(WBP_|EPW_)'), ''), dock: LuminaEditorPanelDock.right) : null),
        ),
        if (info != null) ...[
          _text('title', 'Title', info.title, (v) => v.trim().isEmpty ? null : _set(info.copyWith(title: v.trim()))),
          _text('icon', 'Icon (Lucide name)', info.icon ?? '', (v) => _set(info.copyWith(icon: v.trim()))),
          _label('Dock'),
          Select<LuminaEditorPanelDock>(
            key: const ValueKey('umg_editor_panel_dock'),
            value: info.dock,
            onChanged: (d) {
              if (d != null) _set(info.copyWith(dock: d));
            },
            itemBuilder: (_, d) => Text(d.name, style: const TextStyle(fontSize: 9.5)),
            popup: SelectPopup(
              items: SelectItemList(children: [
                for (final d in LuminaEditorPanelDock.values)
                  SelectItemButton(value: d, child: Text(d.name, style: const TextStyle(fontSize: 9.5))),
              ]),
            ).call,
          ),
          const SizedBox(height: 4),
          _check('always', 'Show in every editor tab by default', info.defaultAlwaysVisible,
              (v) => _set(info.copyWith(defaultAlwaysVisible: v))),
          _check('droppable', 'Accepts Content Browser drops', info.contentDroppable, (v) => _set(info.copyWith(contentDroppable: v))),
          if (info.dock == LuminaEditorPanelDock.tab)
            _check('browser', 'Content Browser docked at the bottom', info.contentBrowserOpened,
                (v) => _set(info.copyWith(contentBrowserOpened: v))),
          _text('menu', 'Menu path (empty: the default)', info.menuPath ?? '', (v) => _set(info.copyWith(menuPath: v.trim()))),
          Row(children: [
            Expanded(
              child: _text('min_width', 'Min width', info.minWidth.toStringAsFixed(0), (v) {
                final n = double.tryParse(v);
                if (n != null && n > 0) _set(info.copyWith(minWidth: n));
              }),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _text('min_height', 'Min height', info.minHeight.toStringAsFixed(0), (v) {
                final n = double.tryParse(v);
                if (n != null && n > 0) _set(info.copyWith(minHeight: n));
              }),
            ),
          ]),
          _label('Capabilities (what its graph may do; reads need none)'),
          for (final c in LuminaEditorPanelCapability.values)
            _check('cap_${c.name}', '${c.name}: ${editorPanelCapabilityText(c)}', info.allows(c), (on) {
              final caps = {...info.capabilities};
              on ? caps.add(c) : caps.remove(c);
              _set(info.copyWith(capabilities: {for (final x in LuminaEditorPanelCapability.values) if (caps.contains(x)) x}));
            }),
        ],
      ]),
    );
  }
}

/// An element's editor panel settings: "Accepts Asset Drops" with its type
/// filter (a `contentDroppable` panel), and the editor widget set's own
/// properties.
class UmgEditorElementSettings extends StatelessWidget {
  const UmgEditorElementSettings({super.key, required this.vm, required this.node});

  final UmgEditorViewModel vm;
  final UmgNode node;

  static const Map<UmgWidgetType, List<String>> _textProps = {
    UmgWidgetType.editorSection: ['title'],
    UmgWidgetType.propertyRow: ['label'],
    UmgWidgetType.assetPicker: ['typeFilter', 'placeholder'],
    UmgWidgetType.resizableSplit: ['orientation', 'split', 'minFirst', 'minSecond'],
    UmgWidgetType.statusLine: ['text', 'tone'],
    UmgWidgetType.treeView: ['items'],
    UmgWidgetType.listView: ['items'],
    // The static fields; clips, keys, rows and items come from the graph
    // or the plugin process at run time.
    UmgWidgetType.editorTimeline: ['fps', 'length', 'snap', 'tracks', 'boundViewport'],
    UmgWidgetType.editorTable: ['columns', 'selection', 'filter'],
    UmgWidgetType.editorCanvas: ['space', 'background', 'items'],
  };

  @override
  Widget build(BuildContext context) {
    final info = vm.document.editorPanel;
    if (info == null) return const SizedBox.shrink();
    final drops = node.props['acceptsAssetDrops'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (info.contentDroppable) ...[
          Row(children: [
            Checkbox(
              key: ValueKey('umg_accepts_asset_drops_${node.id}'),
              state: drops ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: (s) => vm.setProp(node.id, 'acceptsAssetDrops', s == CheckboxState.checked),
            ),
            const SizedBox(width: 6),
            const Expanded(child: Text('Accepts Asset Drops (fires On Asset Dropped)', style: TextStyle(fontSize: 9))),
          ]),
          if (drops) _field('assetDropTypes', 'Drop types (asset types, comma-separated; empty: any)'),
        ],
        for (final key in _textProps[node.type] ?? const <String>[]) _field(key, key),
      ]),
    );
  }

  Widget _field(String key, String label) {
    final raw = node.props[key];
    final text = raw is String ? raw : (raw == null ? '' : jsonEncode(raw));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      ),
      TextField(
        key: ValueKey('umg_editor_prop_${key}_${node.id}_$text'),
        initialValue: text,
        style: const TextStyle(fontSize: 9.5),
        onSubmitted: (v) {
          Object? value = v;
          // Lists and numbers are entered as Json.
          if (raw is! String) {
            try {
              value = jsonDecode(v);
            } on FormatException {
              value = v;
            }
          }
          vm.setProp(node.id, key, value);
        },
      ),
    ]);
  }
}
