import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/node_library.dart';

/// The editor widget set editor panels lay out with (the designer's Editor
/// palette section) and the element events each one offers, plus
/// [onAssetDropped], which any element flagged "Accepts Asset Drops" fires in
/// an editor panel that takes Content Browser drops.
abstract final class LuminaEditorWidgetEvents {
  static const String editorSection = 'editorSection';
  static const String propertyRow = 'propertyRow';
  static const String treeView = 'treeView';
  static const String listView = 'listView';
  static const String assetPicker = 'assetPicker';
  static const String resizableSplit = 'resizableSplit';
  static const String editorToolbar = 'editorToolbar';
  static const String statusLine = 'statusLine';

  /// Every editor widget type name.
  static const Set<String> types = {
    editorSection,
    propertyRow,
    treeView,
    listView,
    assetPicker,
    resizableSplit,
    editorToolbar,
    statusLine,
  };

  static const String onItemSelected = 'OnItemSelected';
  static const String onItemDoubleClicked = 'OnItemDoubleClicked';
  static const String onItemContextMenu = 'OnItemContextMenu';
  static const String onItemExpanded = 'OnItemExpanded';
  static const String onAssetPicked = 'OnAssetPicked';
  static const String onSectionToggled = 'OnSectionToggled';

  /// A Content Browser asset dropped on an element (Asset Path, Asset Type).
  static const String onAssetDropped = 'OnAssetDropped';

  /// The events of editor widget [typeName] (empty for any other type).
  static List<String> forType(String typeName) => switch (typeName) {
        treeView => const [onItemSelected, onItemDoubleClicked, onItemContextMenu, onItemExpanded],
        listView => const [onItemSelected, onItemDoubleClicked, onItemContextMenu],
        assetPicker => const [onAssetPicked],
        editorSection => const [onSectionToggled],
        _ => const [],
      };

  static const LuminaBlueprintPinSpec _itemId = LuminaBlueprintPinSpec('item_id', 'Item Id', LuminaPinType.string, defaultValue: '');

  /// The data outputs of the bound event node of [event], or null when
  /// [event] is not an editor widget event.
  static List<LuminaBlueprintPinSpec>? outputsOf(String? event) => switch (event) {
        onItemSelected => const [
            _itemId,
            LuminaBlueprintPinSpec('selected_ids', 'Selected Ids', LuminaPinType.array, elementType: LuminaPinType.string),
          ],
        onItemDoubleClicked || onItemContextMenu => const [_itemId],
        onItemExpanded => const [
            _itemId,
            LuminaBlueprintPinSpec('expanded', 'Expanded', LuminaPinType.boolean, defaultValue: false),
          ],
        onAssetPicked => const [LuminaBlueprintPinSpec('asset_path', 'Asset Path', LuminaPinType.string, defaultValue: '')],
        onAssetDropped => const [
            LuminaBlueprintPinSpec('asset_path', 'Asset Path', LuminaPinType.string, defaultValue: ''),
            LuminaBlueprintPinSpec('asset_type', 'Asset Type', LuminaPinType.string, defaultValue: ''),
          ],
        onSectionToggled => const [LuminaBlueprintPinSpec('expanded', 'Expanded', LuminaPinType.boolean, defaultValue: true)],
        _ => null,
      };
}
