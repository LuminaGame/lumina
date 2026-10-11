import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorWidgetEvents;
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_layout.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_playhead_painter.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_tracks_painter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'native_widget_harness.dart';

/// The native timeline's interaction contract: drags apply at once, send
/// throttled previews and one commit; Escape cancels and snaps back; clips
/// keep their length limits; clip text commits once; playback advances the
/// playhead locally at the state's fps; Ctrl + wheel zooms around the
/// cursor.
void main() {
  const name = 'Motion';

  Map<String, Object?> timeline({double zoom = 4}) => {
        'fps': 30,
        'length': 300,
        'zoom': zoom,
        'scroll': 0,
        'snap': 1,
        'tracks': [
          {'id': 'prompts', 'label': 'Text prompts', 'icon': 'text', 'group': 'Prompts', 'kind': 'clips'},
          {'id': 'body', 'label': 'Full Body', 'icon': 'person-standing', 'group': 'Constraints', 'kind': 'keys'},
        ],
        'clips': [
          {'id': 'p1', 'track': 'prompts', 'start': 0, 'end': 120, 'text': 'walk forward', 'minLength': 60, 'maxLength': 300, 'editableText': true},
        ],
        'keys': [
          {'id': 'k1', 'track': 'body', 'frame': 30},
        ],
      };

  Future<(NativeWidgetHarness, EditorTimelineState)> mount(WidgetTester tester, {double zoom = 4}) async {
    final h = NativeWidgetHarness(timeline(zoom: zoom));
    await h.pump(tester, (s) => EditorTimeline(name: name, state: s, onEvent: h.onEvent, onState: h.onState));
    return (h, tester.state<EditorTimelineState>(find.byType(EditorTimeline)));
  }

  /// A point in the track area: [frame] on [trackId]'s row.
  Offset at(WidgetTester tester, EditorTimelineState s, String trackId, double frame) {
    final origin = tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_${name}_tracks')));
    final l = s.model.layout();
    final row = l.rowOf(trackId)!;
    return origin + Offset(l.xOf(frame), row.top + row.height / 2);
  }

  int keyFrame(EditorTimelineState s) => s.model.keys.single.frame;

  testWidgets('dragging a key 30 → 32 shows it at once, throttles previews and commits once with delta 2', (tester) async {
    final (h, s) = await mount(tester);
    expect(find.byKey(const ValueKey('editor_timeline_${name}_track_body')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('editor_timeline_${name}_track_body'))).height, inInclusiveRange(22, 24));
    final g = await tester.startGesture(at(tester, s, 'body', 30), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await g.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(keyFrame(s), 32, reason: 'applied locally at once');
    // Two seconds of wiggling at 60 Hz, ending on frame 32.
    for (var i = 0; i < 120; i++) {
      await g.moveBy(Offset(i.isEven ? 4 : -4, 0));
      await tester.pump(const Duration(milliseconds: 1000 ~/ 60));
    }
    expect(keyFrame(s), 32);
    final previews = h.named(LuminaEditorWidgetEvents.onKeyPreview);
    expect(previews.length, inInclusiveRange(10, 61), reason: 'at most 30 a second over 2 s');
    expect(h.named(LuminaEditorWidgetEvents.onKeyCommit), isEmpty, reason: 'nothing commits before the release');
    await g.up();
    await tester.pump();
    final commits = h.named(LuminaEditorWidgetEvents.onKeyCommit);
    expect(commits, hasLength(1));
    expect(commits.single.args, {'key_ids': ['k1'], 'delta_frames': 2});
    expect(commits.single.phase, 'commit');
    expect(((h.state.value['keys']! as List).single as Map)['frame'], 32, reason: 'the committed state');
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.named(LuminaEditorWidgetEvents.onKeyPreview).length, previews.length, reason: 'no preview after the commit');
  });

  testWidgets('Escape mid-drag sends On Key Cancel and puts the key back at 30', (tester) async {
    final (h, s) = await mount(tester);
    final g = await tester.startGesture(at(tester, s, 'body', 30), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await g.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(keyFrame(s), 35);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(keyFrame(s), 30);
    final cancels = h.named(LuminaEditorWidgetEvents.onKeyCancel);
    expect(cancels, hasLength(1));
    expect(cancels.single.phase, 'cancel');
    await g.moveBy(const Offset(20, 0));
    await g.up();
    await tester.pump();
    expect(keyFrame(s), 30);
    expect(h.named(LuminaEditorWidgetEvents.onKeyCommit), isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('resizing a 4 s clip below its 2 s minimum stops at 2 s', (tester) async {
    final (h, s) = await mount(tester, zoom: 2);
    final edge = at(tester, s, 'prompts', 120) - const Offset(2, 0);
    final g = await tester.startGesture(edge, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(s.model.clips.single.end, 60, reason: '2 s at 30 fps');
    await g.up();
    await tester.pump();
    final commit = h.named(LuminaEditorWidgetEvents.onClipCommit).single;
    expect(commit.args, {'clip_id': 'p1', 'start': 0, 'end': 60});
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("editing a clip's text commits once", (tester) async {
    final (h, s) = await mount(tester, zoom: 2);
    final middle = at(tester, s, 'prompts', 60);
    await tester.tapAt(middle, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(middle, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    final field = find.byKey(const ValueKey('editor_timeline_${name}_clip_text_p1'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'turn left');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(field, findsNothing);
    final texts = h.named(LuminaEditorWidgetEvents.onClipTextCommitted);
    expect(texts, hasLength(1));
    expect(texts.single.args, {'clip_id': 'p1', 'text': 'turn left'});
    expect(s.model.clips.single.text, 'turn left');
  });

  testWidgets('Space plays at 30 fps for 1 s with no On Playhead Changed until pause, repainting only the playhead', (tester) async {
    final (h, s) = await mount(tester);
    await tester.tapAt(at(tester, s, 'body', 150), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    h.events.clear();
    final tracksBefore = TimelineTracksPainter.paints;
    final playheadBefore = TimelinePlayheadPainter.paints;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(microseconds: 1000000 ~/ 60));
    }
    expect(h.events.map((e) => e.event), [LuminaEditorWidgetEvents.onPlayStateChanged]);
    expect(s.model.playhead.value, closeTo(30, 2), reason: '1 s at 30 fps');
    expect(h.named(LuminaEditorWidgetEvents.onPlayheadChanged), isEmpty);
    expect(h.named(LuminaEditorWidgetEvents.onPlayStateChanged).single.args, {'playing': true, 'loop': false});
    expect(TimelinePlayheadPainter.paints - playheadBefore, greaterThan(20));
    expect(TimelineTracksPainter.paints - tracksBefore, lessThanOrEqualTo(1), reason: 'clips and keys do not repaint per frame');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final changed = h.named(LuminaEditorWidgetEvents.onPlayheadChanged);
    expect(changed, hasLength(1));
    expect(changed.single.args['frame'], s.model.playhead.value.floor());
    expect(h.named(LuminaEditorWidgetEvents.onPlayStateChanged).last.args['playing'], isFalse);
    expect(h.state.value['playhead'], s.model.playhead.value.floor());
  });

  testWidgets('Ctrl + wheel zooms around the cursor', (tester) async {
    final (h, s) = await mount(tester);
    final p = at(tester, s, 'body', 50);
    final origin = tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_${name}_tracks')));
    double frameUnder() => s.model.layout().frameAt(p.dx - origin.dx);
    final before = frameUnder();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: p, scrollDelta: const Offset(0, -40), kind: PointerDeviceKind.mouse));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: p, scrollDelta: const Offset(0, -40), kind: PointerDeviceKind.mouse));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(s.model.zoom, greaterThan(5.5));
    expect(frameUnder(), closeTo(before, 0.01), reason: 'the frame under the cursor stays put');
    expect(h.state.value['zoom'], closeTo(s.model.zoom, 0.01), reason: 'the view is kept in the state');
    expect(TimelineLayout.headerWidth, 168);
  });
}
