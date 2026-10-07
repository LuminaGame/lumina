import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The host's own contributions through the plugin API. Its former demo
/// registrations — a "Test Panel" panel and menu item, a toolbar Play button
/// duplicating the toolbar's own, and a glTF importer duplicating the import
/// pipeline — were removed once the plugin extension points were wired:
/// they would have shown as placeholder UI.
class BuiltInEditorPlugin extends LuminaEditorPlugin {
  final EditorViewModel viewModel;

  BuiltInEditorPlugin(this.viewModel);

  @override
  String get pluginName => 'BuiltIn';

  @override
  void register(LuminaEditorContext context) {
    // Tools menu: the built-in sub-editors.
    context.registerMenuItem('Tools/Material Editor', EditorCommand(
      id: 'tools.materialEditor', label: 'Material Editor', canExecute: () => true, execute: (ctx) => viewModel.openSubEditorTab('material', title: 'Material Editor')
    ));
    context.registerMenuItem('Tools/Blueprint Editor', EditorCommand(
      id: 'tools.blueprintEditor', label: 'Blueprint Editor', canExecute: () => true, execute: (ctx) => viewModel.openSubEditorTab('blueprint', title: 'Blueprint Editor')
    ));
    context.registerMenuItem('Tools/Mesh Inspector', EditorCommand(
      id: 'tools.meshInspector', label: 'Mesh Inspector', canExecute: () => true, execute: (ctx) => viewModel.openSubEditorTab('mesh', title: 'Mesh Inspector')
    ));

    // Console command (Output Log command line).
    context.registerConsoleCommand('ping', 'Pings the editor', (args) {
      viewModel.logger.log('Pong! Args: $args', level: 'info', source: 'BuiltInPlugin');
    });
  }

  @override
  void unregister(LuminaEditorContext context) {}
}
