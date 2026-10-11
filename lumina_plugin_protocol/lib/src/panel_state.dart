/// A plugin process's direct update of an editor panel's element states
/// (the `host.panelState` notification): the host applies each op to the
/// `elements[<element>]` map of every open instance of the panel, the same
/// keys the UMG renderer reads (`text`, `value`, `percent`, `options`,
/// `selected`, `visibility`, `isEnabled`, ...), so a status line or a progress
/// bar stays current without a graph round trip.
///
/// [panel] is the panel asset's path inside the plugin (`content/EPW_Tools.lmas`
/// or `EPW_Tools.lmas`), not an instance: a panel open twice gets the patch in
/// both. Malformed ops (no element name, a `set` that is not a map, keys that
/// are not strings) are dropped when reading, never applied.
class PluginPanelStatePatch {
  const PluginPanelStatePatch(this.panel, this.ops);

  final String panel;
  final List<PluginPanelStateOp> ops;

  Map<String, Object?> toJson() => {
        'panel': panel,
        'ops': [for (final o in ops) o.toJson()],
      };

  /// Reads a patch; returns null when [json] names no panel.
  static PluginPanelStatePatch? fromJson(Map<String, Object?> json) {
    final panel = json['panel'];
    if (panel is! String || panel.isEmpty) return null;
    final ops = <PluginPanelStateOp>[];
    final raw = json['ops'];
    if (raw is List) {
      for (final o in raw) {
        if (o is Map) {
          final op = PluginPanelStateOp.fromJson(o);
          if (op != null) ops.add(op);
        }
      }
    }
    return PluginPanelStatePatch(panel, ops);
  }

  /// [later] merged onto this patch (same panel): per element, later keys win.
  /// The host coalesces bursts this way before applying them.
  PluginPanelStatePatch merge(PluginPanelStatePatch later) {
    final merged = <String, Map<String, Object?>>{};
    for (final o in [...ops, ...later.ops]) {
      (merged[o.element] ??= <String, Object?>{}).addAll(o.set);
    }
    return PluginPanelStatePatch(panel, [for (final e in merged.entries) PluginPanelStateOp(e.key, e.value)]);
  }
}

/// Sets [set]'s keys on the state of the element named [element].
class PluginPanelStateOp {
  const PluginPanelStateOp(this.element, this.set);

  final String element;
  final Map<String, Object?> set;

  Map<String, Object?> toJson() => {'element': element, 'set': set};

  static PluginPanelStateOp? fromJson(Map<dynamic, dynamic> json) {
    final element = json['element'];
    final set = json['set'];
    if (element is! String || element.isEmpty || set is! Map) return null;
    return PluginPanelStateOp(element, {
      for (final e in set.entries)
        if (e.key is String) e.key as String: e.value,
    });
  }
}
