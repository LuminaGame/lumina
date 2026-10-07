import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'blueprint_codegen_golden_test.dart' show templateInputActions;

/// The Third Person template's character Event Graph reads
/// cleanly. There is one titled comment box per event chain, the boxes
/// are stacked at one left x, and each chain sits in a tidy row inside its box.
void main() {
  final document = LuminaThirdPersonContent.characterBlueprint(inputActions: templateInputActions());
  final graph = document.eventGraph;
  final comments = [for (final n in graph.nodes) if (LuminaBlueprintEditorNodes.isComment(n)) n];
  final nodes = [for (final n in graph.nodes) if (!LuminaBlueprintEditorNodes.isEditorOnly(n.registryId)) n];
  final connected = <String, Set<String>>{};
  for (final w in graph.wires) {
    (connected[w.toNodeId] ??= {}).add(w.toPinId);
  }
  ({double left, double top, double right, double bottom}) rectOf(LuminaBlueprintNode n) {
    if (LuminaBlueprintEditorNodes.isComment(n)) {
      return (
        left: n.x,
        top: n.y,
        right: n.x + LuminaBlueprintEditorNodes.commentWidth(n),
        bottom: n.y + LuminaBlueprintEditorNodes.commentHeight(n),
      );
    }
    final size = LuminaBlueprintGraphLayout.estimateSize(n, connectedInputs: connected[n.id] ?? const {});
    return (left: n.x, top: n.y, right: n.x + size.width, bottom: n.y + size.height);
  }

  bool inside(LuminaBlueprintNode node, LuminaBlueprintNode box) {
    final r = rectOf(node);
    final b = rectOf(box);
    return r.left >= b.left && r.top >= b.top && r.right <= b.right && r.bottom <= b.bottom;
  }

  bool overlap(LuminaBlueprintNode a, LuminaBlueprintNode b) {
    final ra = rectOf(a);
    final rb = rectOf(b);
    return ra.left < rb.right && rb.left < ra.right && ra.top < rb.bottom && rb.top < ra.bottom;
  }

  Map<String, LuminaBlueprintNode> boxOf() => {
        for (final n in nodes)
          for (final c in comments)
            if (inside(n, c)) n.id: c,
      };

  test('one titled comment box per event chain, in reading order', () {
    expect([for (final c in comments) c.literals['title']],
        ['Move', 'Look', 'Jump', 'Sprint', 'Dash', 'Free Look', 'Wall Trace']);
    expect([for (final c in comments) c.title], [for (final c in comments) c.literals['title']]);
  });

  test('every node sits inside exactly one comment box', () {
    for (final n in nodes) {
      final boxes = [for (final c in comments) if (inside(n, c)) c.literals['title']];
      expect(boxes, hasLength(1), reason: '${n.id} (${n.title}) is inside $boxes');
    }
    // Each event starts its own box.
    final box = boxOf();
    for (final event in nodes.where((n) => n.inputs.every((p) => p.type != LuminaPinType.exec) && !LuminaBlueprintGraphLayout.isPure(n))) {
      final first = nodes.firstWhere((n) => box[n.id] == box[event.id]);
      if (event.registryId != LuminaBlueprintNodeLibrary.customEvent) {
        expect(first.id, event.id, reason: '${event.id} leads its box');
      }
    }
  });

  test('the boxes share a left x, stack top to bottom with an even gap, and never overlap', () {
    expect(comments.map((c) => c.x).toSet(), hasLength(1));
    for (var i = 1; i < comments.length; i++) {
      final above = rectOf(comments[i - 1]);
      expect(comments[i].y - above.bottom, closeTo(LuminaBlueprintGraphLayout.sectionGap, 1e-6),
          reason: '${comments[i].literals['title']} follows ${comments[i - 1].literals['title']}');
    }
    for (var i = 0; i < comments.length; i++) {
      for (var j = i + 1; j < comments.length; j++) {
        expect(overlap(comments[i], comments[j]), isFalse);
      }
    }
  });

  test('inside a box the nodes run left to right with an even gap and never overlap', () {
    final box = boxOf();
    for (final c in comments) {
      final row = [for (final n in nodes) if (box[n.id] == c) n];
      expect(row.first.x - c.x, closeTo(LuminaBlueprintGraphLayout.padding, 1e-6));
      for (var i = 1; i < row.length; i++) {
        expect(row[i].x - rectOf(row[i - 1]).right, closeTo(LuminaBlueprintGraphLayout.nodeGap, 1e-6), reason: '${row[i].id} in ${c.title}');
      }
      for (var i = 0; i < row.length; i++) {
        for (var j = i + 1; j < row.length; j++) {
          expect(overlap(row[i], row[j]), isFalse, reason: '${row[i].id} / ${row[j].id}');
        }
      }
      // The exec row, with data-only nodes slightly below it; the box is
      // sized to its nodes plus padding.
      final execTop = c.y + LuminaBlueprintGraphLayout.titleBand;
      for (final n in row) {
        expect(n.y, closeTo(execTop + (LuminaBlueprintGraphLayout.isPure(n) ? LuminaBlueprintGraphLayout.pureDrop : 0), 1e-6), reason: n.id);
      }
      final r = rectOf(c);
      expect(r.right - rectOf(row.last).right, closeTo(LuminaBlueprintGraphLayout.padding, 1e-6));
      expect(r.bottom - row.map((n) => rectOf(n).bottom).reduce((a, b) => a > b ? a : b), closeTo(LuminaBlueprintGraphLayout.padding, 1e-6));
    }
  });

  test('no exec wire leaves its box; the one data wire across boxes is the documented Move → Dash forward vector', () {
    final box = boxOf();
    final across = [
      for (final w in graph.wires)
        if (box[w.fromNodeId] != box[w.toNodeId]) '${w.fromNodeId}.${w.fromPinId} → ${w.toNodeId}.${w.toPinId}',
    ];
    // The dash launches along Move's forward vector (the free-look-aware
    // move yaw): a pure value read from the Move chain, not an exec link.
    expect(across, ['forward.return_value → dash_velocity.a']);
    expect(LuminaThirdPersonContent.characterBlueprintCrossBoxWires, [('forward', 'return_value', 'dash_velocity', 'a')]);
  });

  test('the VM and the generator ignore the comment boxes', () {
    final engine = LuminaBlueprintEditorNodes.forEngine(document);
    expect(engine.eventGraph.nodes.where((n) => LuminaBlueprintEditorNodes.isComment(n)), isEmpty);
    expect(engine.eventGraph.nodes.map((n) => n.id), nodes.map((n) => n.id));
    expect(engine.eventGraph.wires.map((w) => w.id), graph.wires.map((w) => w.id));
    expect(validateBlueprint(document, inputActions: templateInputActions()).where((d) => d.isError).map((d) => d.message), isEmpty);
    final cls = LuminaBlueprintClass.fromDocument(document,
        name: LuminaThirdPersonContent.characterBlueprintName, inputActions: templateInputActions());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty);
    final generated = const BlueprintDartGenerator().generate(document,
        className: 'BpThirdPersonCharacter',
        assetPath: LuminaThirdPersonContent.characterBlueprintPath,
        inputActions: templateInputActions());
    expect(generated.issues.where((d) => d.isError), isEmpty);
    expect(generated.code, isNotNull);
  });

  test("ABP_Character's Event Graph: no two nodes overlap", () {
    final update = LuminaThirdPersonContent.animBlueprint.eventGraph;
    final wired = <String, Set<String>>{};
    for (final w in update.wires) {
      (wired[w.toNodeId] ??= {}).add(w.toPinId);
    }
    ({double left, double top, double right, double bottom}) r(LuminaBlueprintNode n) {
      final size = LuminaBlueprintGraphLayout.estimateSize(n, connectedInputs: wired[n.id] ?? const {});
      return (left: n.x, top: n.y, right: n.x + size.width, bottom: n.y + size.height);
    }

    final overlapping = <String>[];
    for (var i = 0; i < update.nodes.length; i++) {
      for (var j = i + 1; j < update.nodes.length; j++) {
        final a = r(update.nodes[i]);
        final b = r(update.nodes[j]);
        if (a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom) {
          overlapping.add('${update.nodes[i].id} / ${update.nodes[j].id}');
        }
      }
    }
    expect(overlapping, isEmpty);
  });
}
