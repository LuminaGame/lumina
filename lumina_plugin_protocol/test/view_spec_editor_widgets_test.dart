import 'dart:convert';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';
import 'package:test/test.dart';

/// The timeline, table and canvas states (editor panel element state and
/// JSON spec control props) through JSON text as on the wire.
String _text(Map<String, Object?> json) => jsonEncode(json);
Map<String, Object?> _wire(String text) => (jsonDecode(text) as Map).cast();

PluginTimelineState _timeline() => PluginTimelineState(
      fps: 30,
      length: 300,
      playhead: 12,
      loop: true,
      zoom: 6,
      tracks: const [
        PluginTimelineTrack(id: 'prompts', label: 'Text prompts', icon: 'text', group: 'Prompts', kind: PluginTimelineTrackKind.clips),
        PluginTimelineTrack(id: 'body', label: 'Full Body', icon: 'person-standing', group: 'Constraints'),
        PluginTimelineTrack(id: 'root', label: '2D Root', icon: 'move', group: 'Constraints', color: '#4ADE80'),
        PluginTimelineTrack(id: 'lhand', label: 'Left Hand', icon: 'hand', group: 'Constraints'),
        PluginTimelineTrack(id: 'rhand', label: 'Right Hand', icon: 'hand', group: 'Constraints'),
        PluginTimelineTrack(id: 'lfoot', label: 'Left Foot', icon: 'footprints', group: 'Constraints', locked: true),
        PluginTimelineTrack(id: 'rfoot', label: 'Right Foot', icon: 'footprints', group: 'Constraints', height: 28),
      ],
      clips: const [
        PluginTimelineClip(id: 'p1', track: 'prompts', start: 0, end: 120, text: 'walk forward', minLength: 60, maxLength: 300, editableText: true),
        PluginTimelineClip(id: 'p2', track: 'prompts', start: 120, end: 210, text: 'turn left', color: '#60A5FAFF'),
      ],
      keys: const [
        PluginTimelineKey(id: 'k1', track: 'body', frame: 30),
        PluginTimelineKey(id: 'k2', track: 'root', frame: 60, style: PluginTimelineKeyStyle.circle, selected: true),
        PluginTimelineKey(id: 'k3', track: 'lfoot', frame: 90, style: PluginTimelineKeyStyle.square, color: '#F59E0B'),
      ],
      rangeStart: 0,
      rangeEnd: 210,
      snap: 3,
      boundViewport: const PluginBoundViewport(element: 'Preview', node: 'node_1'),
    );

PluginTableState _table() => const PluginTableState(
      columns: [
        PluginTableColumn(id: 'bone', label: 'Bone', width: 140),
        PluginTableColumn(id: 'weight', label: 'Weight', kind: PluginTableColumnKind.number, editable: true),
        PluginTableColumn(id: 'axis', label: 'Axis', kind: PluginTableColumnKind.enumeration, editable: true, options: ['X', 'Y', 'Z']),
        PluginTableColumn(id: 'mesh', label: 'Mesh', kind: PluginTableColumnKind.assetRef, editable: true, typeFilter: 'SkeletalMesh', sortable: false),
      ],
      rows: [
        PluginTableRow(id: 'r1', cells: {'bone': 'pelvis', 'weight': 1.0, 'axis': 'Z', 'mesh': 'contents/meshes/SKM_A.lmas'}),
        PluginTableRow(id: 'r2', cells: {'bone': 'spine_01', 'weight': 0.5, 'axis': 'Y', 'mesh': null}, group: 'Spine', tone: PluginTableRowTone.warning),
        PluginTableRow(id: 'r3', cells: {'bone': 'head', 'weight': 0, 'axis': 'X'}, tooltip: 'unmapped', tone: PluginTableRowTone.error),
      ],
      sortColumn: 'bone',
      sortAscending: false,
      selection: 'multi',
      selected: ['r2'],
      filter: true,
    );

PluginCanvasState _canvas() => const PluginCanvasState(
      space: PluginCanvasSpace.normalized,
      background: '#101014',
      items: [
        PluginCanvasItem(id: 'l', kind: PluginCanvasItemKind.line, points: [[0.1, 0.1], [0.9, 0.5]], stroke: '#FFFFFF', width: 2),
        PluginCanvasItem(id: 'c', kind: PluginCanvasItemKind.circle, center: [0.5, 0.5], radius: 0.05, fill: '#F59E0B', hit: true, draggable: true, cursor: 'move'),
        PluginCanvasItem(id: 't', kind: PluginCanvasItemKind.text, rect: [0.05, 0.9, 0.5, 0.08], text: 'pelvis', fontSize: 11),
      ],
      viewBox: [0, 0, 1, 1],
      panZoom: true,
    );

void main() {
  test('a timeline with 7 tracks, 2 clips and 3 keys round-trips byte-identically', () {
    final text = _text(_timeline().toJson());
    final back = PluginTimelineState.fromJson(_wire(text));
    expect(_text(back.toJson()), text);
    expect(back.tracks, hasLength(7));
    expect(back.clips.map((c) => c.length), [120, 90]);
    expect(back.keys.map((k) => k.frame), [30, 60, 90]);
    expect(back.boundViewport!.node, 'node_1');
  });

  test('a table with 4 typed columns and 3 rows round-trips byte-identically', () {
    final text = _text(_table().toJson());
    final back = PluginTableState.fromJson(_wire(text));
    expect(_text(back.toJson()), text);
    expect(back.columns.map((c) => c.kind), ['text', 'number', 'enum', 'assetRef']);
    expect(back.rows.map((r) => r.tone), ['normal', 'warning', 'error']);
  });

  test('a canvas with a line, a circle and a text round-trips byte-identically', () {
    final text = _text(_canvas().toJson());
    final back = PluginCanvasState.fromJson(_wire(text));
    expect(_text(back.toJson()), text);
    expect(back.items.map((i) => i.kind), ['line', 'circle', 'text']);
  });

  test('the spec controls carry the same fields and keep them through a view spec', () {
    final spec = PluginViewSpec(id: 'motion', children: [
      PluginControl.timeline('tl', _timeline(), height: 220),
      PluginControl.table('map', _table()),
      PluginControl.canvas('overlay', _canvas()),
    ]);
    final text = jsonEncode(spec.toJson());
    final back = PluginViewSpec.fromJson(_wire(text));
    expect(jsonEncode(back.toJson()), text);
    expect(back.find('tl')!.kind, PluginControlKind.timeline);
    expect(PluginTimelineState.fromJson(back.find('tl')!.props).toJson(), _timeline().toJson());
    expect(PluginTableState.fromJson(back.find('map')!.props).toJson(), _table().toJson());
    expect(PluginCanvasState.fromJson(back.find('overlay')!.props).toJson(), _canvas().toJson());
    // A patch replaces one field.
    final patched = back.apply(const PluginViewPatch([
      PluginViewPatchOp.set('tl', {'playhead': 45}),
    ]));
    expect(PluginTimelineState.fromJson(patched.find('tl')!.props).playhead, 45);
  });

  test('a view event carries its phase', () {
    const e = PluginViewEvent(
      viewId: 'motion',
      controlId: 'tl',
      kind: PluginEditorWidgetEventKind.keysMoved,
      phase: PluginViewEventPhase.commit,
      value: {'key_ids': ['k1'], 'delta_frames': 2},
    );
    final back = PluginViewEvent.fromJson(_wire(jsonEncode(e.toJson())));
    expect(back.phase, 'commit');
    expect(back.value, {'key_ids': ['k1'], 'delta_frames': 2});
    expect(PluginViewEvent.fromJson(_wire(jsonEncode(const PluginViewEvent(viewId: 'v', controlId: 'b', kind: 'pressed').toJson()))).phase,
        isNull);
  });

  test('kind "sparkline" is a decode error naming the field', () {
    final json = _wire(_text(_canvas().toJson()));
    ((json['items'] as List)[1] as Map)['kind'] = 'sparkline';
    expect(
      () => PluginCanvasState.fromJson(json),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', allOf(contains('canvas.items[1]'), contains('"kind"'), contains('sparkline')))),
    );
    final timeline = _wire(_text(_timeline().toJson()));
    ((timeline['tracks'] as List)[2] as Map)['kind'] = 'sparkline';
    expect(() => PluginTimelineState.fromJson(timeline),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('timeline.tracks[2]'), contains('"kind"')))));
    final table = _wire(_text(_table().toJson()));
    ((table['columns'] as List)[0] as Map)['kind'] = 'sparkline';
    expect(() => PluginTableState.fromJson(table),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('table.columns[0]'), contains('"kind"')))));
    expect(() => PluginTimelineState.fromJson({'clips': [{'id': 'c', 'track': 't', 'start': 'soon', 'end': 3}]}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"start"'))));
  });
}
