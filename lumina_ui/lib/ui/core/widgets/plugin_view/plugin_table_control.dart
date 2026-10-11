import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/table/editor_table.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_native_control.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.table]: the editor's native table over the control's
/// props ([PluginTableState]; `height`, default 220). Asset cells edit
/// through the editor's `EditorAssetPicker` when the view has the editor's
/// host context.
class PluginTableControl extends StatelessWidget {
  const PluginTableControl({super.key, required this.control});

  final PluginControl control;

  @override
  Widget build(BuildContext context) {
    final host = PluginViewScope.of(context).assetHost;
    return PluginNativeControl(
      control: control,
      defaultHeight: 220,
      builder: (context, state, onEvent, onState) => EditorTable(
        name: control.id,
        state: state,
        onEvent: onEvent,
        onState: onState,
        assetPicker: host == null
            ? null
            : (context, {required selectedPath, required types, required onSelected}) => EditorAssetPicker(
                  key: ValueKey('plugin_table_asset_picker_${control.id}'),
                  hostContext: host,
                  selectedPath: selectedPath,
                  typeFilter: types,
                  onSelected: onSelected,
                ),
      ),
    );
  }
}
