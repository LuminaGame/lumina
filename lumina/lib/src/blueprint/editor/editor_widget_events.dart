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

  /// The native timeline, table and canvas (per-frame interaction stays in
  /// the editor; the graph gets previews, commits and cancels).
  static const String timeline = 'editorTimeline';
  static const String table = 'editorTable';
  static const String canvas = 'editorCanvas';

  /// Whether [typeName] is the timeline, the table or the canvas.
  static bool isNative(String? typeName) => typeName == timeline || typeName == table || typeName == canvas;

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
    timeline,
    table,
    canvas,
  };

  static const String onItemSelected = 'OnItemSelected';
  static const String onItemDoubleClicked = 'OnItemDoubleClicked';
  static const String onItemContextMenu = 'OnItemContextMenu';
  static const String onItemExpanded = 'OnItemExpanded';
  static const String onAssetPicked = 'OnAssetPicked';
  static const String onSectionToggled = 'OnSectionToggled';

  /// A Content Browser asset dropped on an element (Asset Path, Asset Type).
  static const String onAssetDropped = 'OnAssetDropped';

  // Timeline: the playhead on release or a step (never per playback frame),
  // play / pause / loop, clip moves and resizes, clip text, key drags, keys
  // added and deleted, the selection and a track's context menu.
  static const String onPlayheadChanged = 'OnPlayheadChanged';
  static const String onPlayStateChanged = 'OnPlayStateChanged';
  static const String onClipPreview = 'OnClipPreview';
  static const String onClipCommit = 'OnClipCommit';
  static const String onClipCancel = 'OnClipCancel';
  static const String onClipTextCommitted = 'OnClipTextCommitted';
  static const String onKeyPreview = 'OnKeyPreview';
  static const String onKeyCommit = 'OnKeyCommit';
  static const String onKeyCancel = 'OnKeyCancel';
  static const String onKeyAdded = 'OnKeyAdded';
  static const String onKeysDeleted = 'OnKeysDeleted';
  static const String onSelectionChanged = 'OnSelectionChanged';
  static const String onTrackContextMenu = 'OnTrackContextMenu';

  // Table.
  static const String onCellCommitted = 'OnCellCommitted';
  static const String onRowSelected = 'OnRowSelected';
  static const String onRowDoubleClicked = 'OnRowDoubleClicked';
  static const String onRowContextMenu = 'OnRowContextMenu';
  static const String onSortChanged = 'OnSortChanged';

  // Canvas (positions in the canvas's item space).
  static const String onItemClicked = 'OnItemClicked';
  static const String onItemDragPreview = 'OnItemDragPreview';
  static const String onItemDragCommit = 'OnItemDragCommit';
  static const String onItemDragCancel = 'OnItemDragCancel';
  static const String onItemHover = 'OnItemHover';
  static const String onBackgroundClicked = 'OnBackgroundClicked';

  /// The events of editor widget [typeName] (empty for any other type).
  static List<String> forType(String typeName) => switch (typeName) {
        treeView => const [onItemSelected, onItemDoubleClicked, onItemContextMenu, onItemExpanded],
        listView => const [onItemSelected, onItemDoubleClicked, onItemContextMenu],
        assetPicker => const [onAssetPicked],
        editorSection => const [onSectionToggled],
        timeline => const [
            onPlayheadChanged,
            onPlayStateChanged,
            onClipPreview,
            onClipCommit,
            onClipCancel,
            onClipTextCommitted,
            onKeyPreview,
            onKeyCommit,
            onKeyCancel,
            onKeyAdded,
            onKeysDeleted,
            onSelectionChanged,
            onTrackContextMenu,
          ],
        table => const [onCellCommitted, onRowSelected, onRowDoubleClicked, onRowContextMenu, onSortChanged],
        canvas => const [onItemClicked, onItemDragPreview, onItemDragCommit, onItemDragCancel, onItemHover, onBackgroundClicked],
        _ => const [],
      };

  static const LuminaBlueprintPinSpec _itemId = LuminaBlueprintPinSpec('item_id', 'Item Id', LuminaPinType.string, defaultValue: '');

  static const LuminaBlueprintPinSpec _keyIds =
      LuminaBlueprintPinSpec('key_ids', 'Key Ids', LuminaPinType.array, elementType: LuminaPinType.string);
  static const LuminaBlueprintPinSpec _clipId = LuminaBlueprintPinSpec('clip_id', 'Clip Id', LuminaPinType.string, defaultValue: '');
  static const LuminaBlueprintPinSpec _rowId = LuminaBlueprintPinSpec('row_id', 'Row Id', LuminaPinType.string, defaultValue: '');
  static const LuminaBlueprintPinSpec _canvasItemId = LuminaBlueprintPinSpec('item_id', 'Item Id', LuminaPinType.string, defaultValue: '');
  static const LuminaBlueprintPinSpec _frame = LuminaBlueprintPinSpec('frame', 'Frame', LuminaPinType.integer, defaultValue: 0);
  static const LuminaBlueprintPinSpec _track = LuminaBlueprintPinSpec('track', 'Track', LuminaPinType.string, defaultValue: '');
  static const LuminaBlueprintPinSpec _x = LuminaBlueprintPinSpec('x', 'X', LuminaPinType.float, defaultValue: 0.0);
  static const LuminaBlueprintPinSpec _y = LuminaBlueprintPinSpec('y', 'Y', LuminaPinType.float, defaultValue: 0.0);

  /// The outputs of the timeline, table and canvas events.
  static List<LuminaBlueprintPinSpec>? _nativeOutputsOf(String? event) => switch (event) {
        onPlayheadChanged => const [_frame],
        onPlayStateChanged => const [
            LuminaBlueprintPinSpec('playing', 'Playing', LuminaPinType.boolean, defaultValue: false),
            LuminaBlueprintPinSpec('loop', 'Loop', LuminaPinType.boolean, defaultValue: false),
          ],
        onClipPreview || onClipCommit || onClipCancel => const [
            _clipId,
            LuminaBlueprintPinSpec('start', 'Start', LuminaPinType.integer, defaultValue: 0),
            LuminaBlueprintPinSpec('end', 'End', LuminaPinType.integer, defaultValue: 0),
          ],
        onClipTextCommitted => const [_clipId, LuminaBlueprintPinSpec('text', 'Text', LuminaPinType.string, defaultValue: '')],
        onKeyPreview || onKeyCommit || onKeyCancel => const [
            _keyIds,
            LuminaBlueprintPinSpec('delta_frames', 'Delta Frames', LuminaPinType.integer, defaultValue: 0),
          ],
        onKeyAdded || onTrackContextMenu => const [_track, _frame],
        onKeysDeleted => const [_keyIds],
        onSelectionChanged => const [
            LuminaBlueprintPinSpec('clip_ids', 'Clip Ids', LuminaPinType.array, elementType: LuminaPinType.string),
            _keyIds,
          ],
        onCellCommitted => const [
            _rowId,
            LuminaBlueprintPinSpec('column_id', 'Column Id', LuminaPinType.string, defaultValue: ''),
            LuminaBlueprintPinSpec('value', 'Value', LuminaPinType.json),
            // The value as text (what a label or a name field wants).
            LuminaBlueprintPinSpec('text', 'Text', LuminaPinType.string, defaultValue: ''),
          ],
        onRowSelected => const [LuminaBlueprintPinSpec('row_ids', 'Row Ids', LuminaPinType.array, elementType: LuminaPinType.string)],
        onRowDoubleClicked || onRowContextMenu => const [_rowId],
        onSortChanged => const [
            LuminaBlueprintPinSpec('column', 'Column', LuminaPinType.string, defaultValue: ''),
            LuminaBlueprintPinSpec('ascending', 'Ascending', LuminaPinType.boolean, defaultValue: true),
          ],
        onItemClicked || onItemDragPreview || onItemDragCommit || onItemDragCancel => const [_canvasItemId, _x, _y],
        onItemHover => const [_canvasItemId],
        onBackgroundClicked => const [_x, _y],
        _ => null,
      };

  /// The data outputs of the bound event node of [event], or null when
  /// [event] is not an editor widget event. [typeName] tells the timeline's
  /// On Selection Changed from another widget's.
  static List<LuminaBlueprintPinSpec>? outputsOf(String? event, [String? typeName]) =>
      isNative(typeName) ? _nativeOutputsOf(event) : _outputsOf(event);

  static List<LuminaBlueprintPinSpec>? _outputsOf(String? event) => switch (event) {
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
