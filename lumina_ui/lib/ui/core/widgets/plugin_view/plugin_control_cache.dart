import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_asset_ref_field_control.dart';
import 'plugin_bool_field_control.dart';
import 'plugin_button_control.dart';
import 'plugin_color_field_control.dart';
import 'plugin_divider_control.dart';
import 'plugin_enum_field_control.dart';
import 'plugin_image_control.dart';
import 'plugin_log_control.dart';
import 'plugin_number_field_control.dart';
import 'plugin_preview3d_control.dart';
import 'plugin_progress_control.dart';
import 'plugin_row_control.dart';
import 'plugin_section_control.dart';
import 'plugin_text_control.dart';
import 'plugin_text_field_control.dart';
import 'plugin_unsupported_control.dart';
import 'plugin_view_scope.dart';

/// Builds the widget of each control and remembers it by control id. When a
/// new spec arrives, a control that renders the same as before
/// ([pluginControlEquals]) gets its previous widget instance back, so
/// Flutter skips it entirely: only the controls a patch changed rebuild,
/// and an unchanged text field keeps its focus, caret and unsent typing.
class PluginControlCache {
  PluginControlCache(this.viewId);

  final String viewId;
  final Map<String, (PluginControl, Widget)> _built = {};
  Set<String> _visited = {};

  /// The widgets of [controls] (one pass over a spec's top level).
  List<Widget> buildAll(List<PluginControl> controls) {
    _visited = {};
    final out = [for (final c in controls) widgetFor(c)];
    _built.removeWhere((id, _) => !_visited.contains(id));
    return out;
  }

  /// The widget of [control]: the cached one when it renders the same.
  Widget widgetFor(PluginControl control) {
    _visited.add(control.id);
    final cached = _built[control.id];
    if (cached != null && pluginControlEquals(cached.$1, control)) {
      // Children are visited too, so they stay cached.
      _visitChildren(control);
      return cached.$2;
    }
    final widget = _create(control);
    _built[control.id] = (control, widget);
    return widget;
  }

  void _visitChildren(PluginControl c) {
    for (final k in c.children) {
      _visited.add(k.id);
      _visitChildren(k);
    }
  }

  Widget _create(PluginControl c) {
    final key = pluginControlKey(viewId, c.id);
    return switch (c.kind) {
      PluginControlKind.section =>
        PluginSectionControl(key: key, control: c, children: [for (final k in c.children) widgetFor(k)]),
      PluginControlKind.row =>
        PluginRowControl(key: key, control: c, children: [for (final k in c.children) (k, widgetFor(k))]),
      PluginControlKind.text => PluginTextControl(key: key, control: c),
      PluginControlKind.textField => PluginTextFieldControl(key: key, control: c),
      PluginControlKind.numberField => PluginNumberFieldControl(key: key, control: c),
      PluginControlKind.boolField => PluginBoolFieldControl(key: key, control: c),
      PluginControlKind.enumField => PluginEnumFieldControl(key: key, control: c),
      PluginControlKind.assetRefField => PluginAssetRefFieldControl(key: key, control: c),
      PluginControlKind.colorField => PluginColorFieldControl(key: key, control: c),
      PluginControlKind.button => PluginButtonControl(key: key, control: c),
      PluginControlKind.progress => PluginProgressControl(key: key, control: c),
      PluginControlKind.log => PluginLogControl(key: key, control: c),
      PluginControlKind.image => PluginImageControl(key: key, control: c),
      PluginControlKind.preview3d => PluginPreview3dControl(key: key, control: c),
      PluginControlKind.divider => PluginDividerControl(key: key, control: c),
      _ => PluginUnsupportedControl(key: key, control: c),
    };
  }
}
