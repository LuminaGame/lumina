import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginCanvasState, PluginTableState, PluginTimelineState;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';

const String _widgets = 'Editor|Panels|Native Widgets';

/// Typed setters for the native Timeline, Table and Canvas elements: one
/// call replaces a whole clip list, key list, row list or draw list (the
/// widgets diff by id). The value is checked against the widget's state
/// format first; a malformed one is logged and not written.
final List<EditorLibraryNode> nativeWidgetsLibraryNodes = [
  _setter('editor_timeline_set_clips', 'Timeline Set Clips', 'clips', 'Clips',
      'Replaces the clips of a Timeline element: a list of {id, track, start, end, text, color, minLength, maxLength, editableText} (frames).',
      (v) => PluginTimelineState.fromJson({'clips': v})),
  _setter('editor_timeline_set_keys', 'Timeline Set Keys', 'keys', 'Keys',
      'Replaces the keys of a Timeline element: a list of {id, track, frame, style, color, selected}.',
      (v) => PluginTimelineState.fromJson({'keys': v})),
  EditorLibraryNode(
    impureNode('editor_timeline_set_playhead', 'Timeline Set Playhead', _widgets,
        inputs: [strPin('element', 'Element'), intPin('frame', 'Frame')],
        tooltip: 'Moves a Timeline element\'s playhead to Frame (no On Playhead Changed).'),
    function: (c, i) {
      final call = editorPanelCall(c);
      final f = i['frame'];
      if (call != null && f is num) LuminaUmgElementBinding.write(call.instance.map, inStr(i, 'element'), 'playhead', f.round());
      return const {};
    },
  ),
  _setter('editor_table_set_rows', 'Table Set Rows', 'rows', 'Rows',
      'Replaces the rows of a Table element: a list of {id, cells: {column: value}, group, tone, tooltip}.',
      (v) => PluginTableState.fromJson({'rows': v})),
  _setter('editor_canvas_set_items', 'Canvas Set Items', 'items', 'Items',
      'Replaces the draw list of a Canvas element: a list of {id, kind, points | rect | center + radius | path | text | image, '
          'stroke, fill, width, hit, draggable, cursor}.',
      (v) => PluginCanvasState.fromJson({'items': v})),
];

EditorLibraryNode _setter(String id, String title, String key, String pinName, String tooltip, void Function(Object? value) check) =>
    EditorLibraryNode(
      impureNode(id, title, _widgets, inputs: [strPin('element', 'Element'), jsonPin('value', pinName)], tooltip: tooltip),
      function: (c, i) {
        final call = editorPanelCall(c);
        if (call == null) return const {};
        final value = LuminaJsonBlueprintNodes.plain(i['value']);
        try {
          check(value);
        } on FormatException catch (e) {
          call.host.vm.logger.log('$title (${inStr(i, 'element')}): ${e.message}', level: 'warning', source: 'Editor Panels');
          return const {};
        }
        LuminaUmgElementBinding.write(call.instance.map, inStr(i, 'element'), key, value);
        return const {};
      },
    );
