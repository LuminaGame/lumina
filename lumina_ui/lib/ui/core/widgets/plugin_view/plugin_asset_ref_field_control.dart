import 'dart:async';
import 'dart:isolate';

import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.assetRefField]: `value` (a project-relative path or
/// null) and `assetTypes` (`AssetType` names; absent = any asset), picked
/// with the editor's searchable asset picker ([AssetPickerSelect], the one
/// the Details panel uses) and its clear button, or by dropping a Content
/// Browser tile on it. Sends `changed` with the picked asset's
/// project-relative path, or null when cleared.
///
/// Inside the main editor the picker lists the editor's live asset list
/// ([AssetPickerScope]); elsewhere it scans `projectDir` once on a
/// background isolate and rescans when the project's assets change.
class PluginAssetRefFieldControl extends StatefulWidget {
  const PluginAssetRefFieldControl({super.key, required this.control});

  final PluginControl control;

  /// The asset types `assetTypes` names (unknown names are ignored); null
  /// for any asset.
  static Set<AssetType>? typesOf(PluginControl c) {
    final names = c.list('assetTypes');
    if (names == null || names.isEmpty) return null;
    return {
      for (final t in AssetType.values)
        if (names.contains(t.name)) t,
    };
  }

  /// The key prefix of the picker's popup (`<prefix>_search`,
  /// `<prefix>_item_<file name>`, `<prefix>_clear`).
  static String pickerPrefix(String viewId, String controlId) => 'plugin_view_${viewId}_$controlId';

  @override
  State<PluginAssetRefFieldControl> createState() => _PluginAssetRefFieldControlState();
}

class _PluginAssetRefFieldControlState extends State<PluginAssetRefFieldControl> {
  late String? _value = widget.control.string('value');
  List<RealAssetInfo> _scanned = const [];
  String? _scannedDir;
  StreamSubscription<void>? _changes;

  @override
  void didUpdateWidget(PluginAssetRefFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.control.string('value');
    if (next != oldWidget.control.string('value')) _value = next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inEditor = AssetPickerScope.maybeOf(context)?.allAssets != null;
    final dir = PluginViewScope.of(context).projectDir;
    if (!inEditor && dir != null && dir != _scannedDir) {
      _scannedDir = dir;
      _scan(dir);
      _changes ??= AssetRepository.onAssetsChanged.listen((_) {
        final d = _scannedDir;
        if (d != null) _scan(d);
      });
    }
  }

  Future<void> _scan(String dir) async {
    try {
      final assets = await PluginProjectAssets.scan(dir);
      if (mounted && dir == _scannedDir) setState(() => _scanned = assets);
    } catch (e) {
      debugPrint('[PluginAssetRefField] cannot scan $dir: $e');
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  void _commit(String? path) {
    final c = widget.control;
    if (!c.enabled) return;
    setState(() => _value = path);
    PluginViewScope.of(context).emit(c.id, 'changed', path);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final host = PluginViewScope.of(context);
    final scope = AssetPickerScope.maybeOf(context);
    final types = PluginAssetRefFieldControl.typesOf(c);
    final all = scope?.allAssets?.call() ?? _scanned;
    final assets = [
      for (final a in all)
        if (types == null || types.contains(a.type)) a,
    ];
    final value = _value;
    final prefix = PluginAssetRefFieldControl.pickerPrefix(host.viewId, c.id);
    final field = DragTarget<RealAssetInfo>(
      onWillAcceptWithDetails: (d) => c.enabled && (types == null || types.contains(d.data.type)),
      onAcceptWithDetails: (d) => _commit(d.data.relativePath),
      builder: (context, candidate, rejected) => Row(
        children: [
          Expanded(
            child: AssetPickerSelect(
              keyPrefix: prefix,
              assets: assets,
              selectedPath: value,
              enabled: c.enabled,
              placeholder: 'None',
              onSelected: (asset) => _commit(asset.relativePath),
              onCleared: () => _commit(null),
            ),
          ),
          if (value != null && value.isNotEmpty && c.enabled)
            GhostButton(
              key: ValueKey('${prefix}_reset'),
              density: ButtonDensity.icon,
              onPressed: () => _commit(null),
              child: const Icon(LucideIcons.x, size: 10),
            ),
        ],
      ),
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, child: field));
  }
}

/// A project's assets for pickers outside the main editor, scanned on a
/// background isolate (the scan reads the asset index and stats files).
abstract final class PluginProjectAssets {
  static Future<List<RealAssetInfo>> scan(String projectDir) =>
      Isolate.run(() => AssetRepository().scanProjectContents(projectDir));
}
