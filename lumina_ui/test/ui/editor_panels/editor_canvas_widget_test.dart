import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorWidgetEvents;
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/canvas_item_painter.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/editor_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'native_widget_harness.dart';

/// The native canvas: hit regions report their item, draggable items send
/// throttled previews and one commit (Escape cancels), and the draw list is
/// diffed by id so one item's change repaints only that item.
void main() {
  const name = 'Overlay';

  Map<String, Object?> canvas() => {
        'space': 'local',
        'background': '#101014',
        'items': [
          {'id': 'guide', 'kind': 'line', 'points': [[0, 0], [400, 300]], 'stroke': '#555555', 'width': 1},
          {'id': 'pelvis', 'kind': 'circle', 'center': [100, 100], 'radius': 10, 'fill': '#F59E0B', 'hit': true, 'cursor': 'pointer'},
          {'id': 'box', 'kind': 'rect', 'rect': [200, 150, 60, 40], 'fill': '#4ADE80', 'hit': true, 'draggable': true, 'cursor': 'move'},
          {'id': 'arrow', 'kind': 'path', 'path': 'M 300 40 l 30 0 l -15 25 Z', 'fill': '#60A5FA', 'hit': true},
          {'id': 'label', 'kind': 'text', 'rect': [10, 270, 200, 20], 'text': 'pelvis', 'fontSize': 11},
        ],
      };

  Future<(NativeWidgetHarness, EditorCanvasState, Offset)> mount(WidgetTester tester) async {
    final h = NativeWidgetHarness(canvas());
    await h.pump(tester, (s) => EditorCanvas(name: name, state: s, onEvent: h.onEvent, onState: h.onState), size: const Size(400, 300));
    await tester.pump();
    final origin = tester.getTopLeft(find.byKey(const ValueKey('editor_canvas_$name')));
    return (h, tester.state<EditorCanvasState>(find.byType(EditorCanvas)), origin);
  }

  testWidgets('a click on a hit circle sends its id; a click on the background sends the position', (tester) async {
    final (h, _, o) = await mount(tester);
    await tester.tapAt(o + const Offset(103, 98), kind: PointerDeviceKind.mouse);
    await tester.pump();
    final clicked = h.named(LuminaEditorWidgetEvents.onItemClicked);
    expect(clicked, hasLength(1));
    expect(clicked.single.args['item_id'], 'pelvis');
    expect(clicked.single.args['x'], closeTo(103, 0.01));
    // The SVG path's triangle is a hit region too.
    await tester.tapAt(o + const Offset(315, 45), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(h.named(LuminaEditorWidgetEvents.onItemClicked).last.args['item_id'], 'arrow');
    await tester.tapAt(o + const Offset(380, 20), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(h.named(LuminaEditorWidgetEvents.onBackgroundClicked).single.args, {'x': 380.0, 'y': 20.0});
  });

  testWidgets('a draggable rect sends throttled previews and one commit; Escape cancels the next drag', (tester) async {
    final (h, s, o) = await mount(tester);
    final g = await tester.startGesture(o + const Offset(220, 160), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    for (var i = 0; i < 60; i++) {
      await g.moveBy(const Offset(1, 0.5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final moved = s.entries.firstWhere((e) => e.item.id == 'box').item.rect!;
    expect(moved[0], closeTo(260, 0.01), reason: 'moved locally at once');
    expect(moved[1], closeTo(180, 0.01));
    final previews = h.named(LuminaEditorWidgetEvents.onItemDragPreview);
    expect(previews.length, inInclusiveRange(5, 31), reason: 'at most 30 a second over ~1 s');
    expect(previews.every((e) => e.phase == 'preview'), isTrue);
    await g.up();
    await tester.pump();
    final commit = h.named(LuminaEditorWidgetEvents.onItemDragCommit);
    expect(commit, hasLength(1));
    expect(commit.single.args, {'item_id': 'box', 'x': 260.0, 'y': 180.0});
    final saved = (h.state.value['items']! as List).firstWhere((i) => (i as Map)['id'] == 'box') as Map;
    expect(saved['rect'], [260.0, 180.0, 60, 40]);
    expect(h.commits.last.$2, isTrue, reason: 'an edit');
    // Drag again and cancel.
    final g2 = await tester.startGesture(o + const Offset(280, 190), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await g2.moveBy(const Offset(30, 0));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(s.entries.firstWhere((e) => e.item.id == 'box').item.rect![0], closeTo(260, 0.01));
    expect(h.named(LuminaEditorWidgetEvents.onItemDragCancel).single.phase, 'cancel');
    await g2.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.named(LuminaEditorWidgetEvents.onItemDragCommit), hasLength(1));
  });

  testWidgets("changing one item's colour repaints only that item", (tester) async {
    final (h, _, _) = await mount(tester);
    CanvasItemPainter.paints.clear();
    final items = [
      for (final i in h.state.value['items']! as List) {...(i as Map).cast<String, Object?>()},
    ];
    items.firstWhere((i) => i['id'] == 'pelvis')['fill'] = '#EF4444';
    h.state.value = {...h.state.value, 'items': items};
    await tester.pump();
    expect(CanvasItemPainter.paints, {'pelvis': 1}, reason: 'the other items keep their layers');
  });
}
